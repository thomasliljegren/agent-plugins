# Fusion v2 — Cross-Subgraph Extension Reference

## Model overview

Fusion v2 is **not Apollo Federation in C# paint**. Key differences:

| | Apollo Federation | HotChocolate Fusion v2 |
|---|---|---|
| Entity key | `@key` directive on type | `[Lookup]` on a root field |
| Reference resolver | `[ReferenceResolver]` method | `[Lookup, Internal]` in contributing subgraph |
| Representations | `_entities(representations: …)` query | Gateway calls `[Internal]` lookup fields |
| Type matching | `@key` fields | GraphQL type name |
| Composition | `rover supergraph compose` | `fusion compose` CLI |

Composition matches types by **GraphQL type name**. `Author` in Authors.Api and `Author` in Books.Api are the same type because the name matches — not because of a CLR identity or `@key` declaration.

---

## Directives / attributes

All from `HotChocolate.Fusion.SourceSchema` NuGet package.

| SDL | C# | Purpose |
|---|---|---|
| `@lookup` | `[Lookup]` | Marks root field as entity lookup — the gateway uses this to rehydrate entities |
| `@internal` | `[Internal]` | Hides lookup from public gateway schema; only the gateway calls it |
| `@is(field: "id")` | directive on arg | Maps arg name to a different entity field when names don't match |

**`[NodeResolver]` + `AddGlobalObjectIdentification()`** is equivalent to `[Lookup]` for Relay/global-ID scenarios. Use `[NodeResolver]` if the product already uses global IDs; use `[Lookup]` for plain typed keys. They do not conflict.

---

## Canonical code pattern

### Owning subgraph (Authors.Api)

```csharp
public sealed class Author
{
    public Guid Id { get; set; }
    public string Name { get; set; } = default!;
    public string Bio { get; set; } = default!;
}

[ObjectType<Author>]
public static partial class AuthorNode
{
    public static string DisplayName([Parent] Author a) => a.Name.ToUpperInvariant();
}

[QueryType]
public static partial class AuthorQueries
{
    [Lookup]
    public static Task<Author?> GetAuthorById(
        Guid id, IAuthorByIdDataLoader loader, CancellationToken ct)
        => loader.LoadAsync(id, ct);

    [UsePaging, UseFiltering, UseSorting]
    public static IQueryable<Author> GetAuthors(IAppReadContext db)
        => db.Authors;
}
```

Program.cs — a subgraph is just a normal HC server; no `.AsSubgraph()` call:

```csharp
builder.Services
    .AddGraphQL()
    .AddTypes()
    .AddGlobalObjectIdentification()
    .AddFiltering().AddSorting().AddPagingArguments();

app.MapGraphQL();
app.RunWithGraphQLCommands(args);   // required for `dotnet run -- schema export`
```

---

### Contributing subgraph (Books.Api)

The `Author` class here is a **stub** — key field only. Don't duplicate `Name`/`Bio`; that causes composition conflicts.

```csharp
// Minimal stub — key field only
public sealed class Author
{
    public Guid Id { get; set; }
}

public sealed class Book
{
    public Guid Id { get; set; }
    public Guid AuthorId { get; set; }
    public string Title { get; set; } = default!;
}

// Extends Author with `books` — same [ObjectType<T>] pattern as within one assembly
[ObjectType<Author>]
public static partial class AuthorBookExtensions
{
    [UsePaging, UseFiltering, UseSorting]
    public static IQueryable<Book> GetBooks(
        [Parent] Author author, IAppReadContext db)
        => db.Books.Where(b => b.AuthorId == author.Id);
}

[ObjectType<Book>]
public static partial class BookNode
{
    // Returns stub — gateway fills in Name/Bio from Authors.Api
    public static Author GetAuthor([Parent] Book b)
        => new() { Id = b.AuthorId };
}

[QueryType]
public static partial class BookQueries
{
    [UsePaging, UseFiltering, UseSorting]
    public static IQueryable<Book> GetBooks(IAppReadContext db) => db.Books;

    // REQUIRED: Books.Api needs its own Author lookup so the gateway can
    // rehydrate an Author that entered the graph via Books.
    // [Internal] keeps it off the public gateway schema.
    [Lookup, Internal]
    public static Author GetAuthorById(Guid id) => new() { Id = id };
}
```

---

## Composed gateway schema

```graphql
type Author {
  id: ID!
  name: String!           # Authors.Api
  bio: String!            # Authors.Api
  displayName: String!    # Authors.Api
  books(...): BookConnection   # Books.Api
}

type Query {
  authorById(id: UUID!): Author   # Authors.Api (public)
  # Books.Api's authorById is @internal — hidden from clients
  authors(...): AuthorConnection
  books(...): BookConnection
}
```

**Query plan for** `{ authorById(id:"X") { name books { title } } }`:
1. Gateway → Authors.Api: `authorById(id:"X") { id name }`
2. Gateway → Books.Api: `authorById(id:"X") { books { title } }` (using returned `id`)
3. Merge on key, return single response.

For list queries, Fusion **batches** the second hop across all collected keys — combined with DataLoader inside each subgraph, you get two-layer N+1 prevention.

---

## Shared contracts

**Local stubs (recommended)**: each subgraph defines the foreign entity with only the key. Zero coupling, fastest deploys. Drift risk is trivial — the stub is one property.

**Shared Contracts project**: a dedicated assembly with canonical DTOs. Better IDE navigation but couples subgraph deploys. Use only if the key type is a complex strongly-typed ID that needs shared logic.

For Relay global IDs: define `[ID("Author")] Guid id` in the owning subgraph and `[ID] Guid id` on lookup arguments in both. HC handles base64 encoding consistently because the composer preserves the `@id` binding.

---

## Composition tooling

```bash
# Install once
dotnet tool install -g HotChocolate.Fusion.CommandLine

# Per subgraph in CI
cd src/Authors.Api
dotnet run -- schema export --output schema.graphql
fusion subgraph pack -s schema.graphql -c subgraph-config.json -p Authors.fsp

cd src/Books.Api
dotnet run -- schema export --output schema.graphql
fusion subgraph pack -s schema.graphql -c subgraph-config.json -p Books.fsp

# Compose
fusion compose -p gateway.fgp -s Authors.fsp -s Books.fsp --enable-nodes
```

**Gateway Program.cs**:
```csharp
builder.Services
    .AddFusionGatewayServer()
    .ConfigureFromFile("gateway.fgp", watchFileForUpdates: true);

app.MapGraphQL();
app.Run();
```

**With Aspire** (recommended for dev loop):
```csharp
var builder = DistributedApplication.CreateBuilder(args);
var authors = builder.AddProject<Projects.MyApp_Authors_Api>("authors");
var books   = builder.AddProject<Projects.MyApp_Books_Api>("books");

builder.AddFusionGateway<Projects.MyApp_Gateway>("gateway")
       .WithSubgraph(authors)
       .WithSubgraph(books);

builder.Build().Compose().Run();  // auto-composes on dotnet run
```

Composition is **always build/CI-time**, not runtime. Type conflicts and missing lookups fail `fusion compose` before reaching production.

---

## Fusion v1 vs v2 — what to ignore

**Ignore** any content showing:
- `@resolve`, `@delegate`, or `@extends` directives in `.ext.graphql` files — HC v13 schema-stitching legacy
- `@key`/`_entities`/`__resolveReference` — Apollo Federation patterns; don't translate literally
- v14 Fusion v1 docs showing `SubgraphConfigurationFile` — different composition model

The `/docs/fusion/v15/` and `/docs/fusion/v16/` doc trees are canonical. v15 is stable; v16 is preview as of April 2026 but the `[Lookup]` authoring model is identical.

---

## Known limitations

| Issue | Status |
|---|---|
| SSE subscription cancellation not propagated to subgraphs | Open (#8977) — use WebSockets or accept leaked streams on disconnect |
| Cross-subgraph filter predicates | Not supported — filters must resolve entirely within one subgraph |
| `ConfigureFromFile(watchFileForUpdates: true)` unreliable since 13.5.1 | Open (#6500) — prefer restart-on-deploy |
| `AddAuthorization()` on both gateway and subgraphs throws conflict | Open (#6333) — apply auth at one layer only |
| `fusion compose -w <dir>` treats `-w` as subgraph discovery path not working dir | Open (#6279) — use absolute paths in CI |
| `[ExtendObjectType<T>]` | Works but on deprecation path — use `[ObjectType<T>]` for all new code |

DataLoaders, `[UsePaging]`, `[UseFiltering]`, `[UseSorting]` all compose naturally within a single subgraph, including on cross-subgraph-contributed fields (because those fields resolve entirely inside the contributing subgraph).
