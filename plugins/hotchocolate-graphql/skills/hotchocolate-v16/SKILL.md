---
name: hotchocolate-v16
description: >
  Architecture patterns, code conventions, and structural decisions for building
  HotChocolate v16 GraphQL servers. Use this skill whenever working on anything
  in the GraphQL layer: adding a new query, mutation, subscription, object type,
  DataLoader, batch resolver, interface, union, type extension, input type, or
  error type; pagination and projection (QueryContext/.With()); wiring up Fusion
  subgraph lookups; setting up mutation conventions; production hardening (cost
  analysis, persisted operations, execution depth); authorization; schema CI and
  breaking-change detection; or deciding where a new file belongs. Also use when
  the user asks about the node pattern, cross-feature type extensions, mapping
  strategy, GraphQL schema design principles (demand-oriented design, Relay
  conventions, error-union patterns, fragments), or Fusion cross-subgraph entity
  extension. When in doubt about any HC v16 or Fusion pattern, consult this skill first.
---

# HotChocolate v16 — Architecture Reference

## Stack at a glance

- **HotChocolate v16** (next.chillicream.com) — implementation-first, source generators
- **Fusion v2** for distributed subgraphs (same `[ObjectType<T>]` model, extended with `[Lookup]`)
- **Source generator attributes**: `[QueryType]`, `[MutationType]`, `[SubscriptionType]`, `[ObjectType<T>]`, `[DataLoader]`
- **No fluent descriptor API** for new code; `static partial void Configure(IObjectTypeDescriptor<T> d)` only as escape hatch
- **No parallel DTO tier** — domain entities exposed directly via `[ObjectType<T>]`
- **Hand-rolled mapping** via extension methods; no AutoMapper/Mapster/Mapperly

---

## Folder structure

```
MyApp.Api/
├─ Program.cs
├─ Properties/ModuleInfo.cs             // [assembly: Module("MyApp")]
├─ Data/                                // EF Core only — no HC references
│  ├─ AppDbContext.cs
│  └─ Entities/
└─ GraphQL/
   ├─ Common/
   │  ├─ Scalars/
   │  ├─ Errors/        (NotFoundException, ValidationException, …)
   │  └─ Nodes/         ([InterfaceType<IEntity>] if using Relay Node interface)
   ├─ Authors/
   │  ├─ AuthorQueries.cs             [QueryType]
   │  ├─ AuthorMutations.cs           [MutationType]
   │  ├─ AuthorNode.cs                [ObjectType<Author>]   ← canonical owner
   │  ├─ AuthorDataLoaders.cs         [DataLoader]
   │  └─ AuthorMappings.cs
   ├─ Books/
   │  ├─ BookQueries.cs               [QueryType]
   │  ├─ BookMutations.cs             [MutationType]
   │  ├─ BookSubscriptions.cs         [SubscriptionType]
   │  ├─ BookNode.cs                  [ObjectType<Book>]
   │  ├─ AuthorBookExtensions.cs      [ObjectType<Author>]   ← contributes `books`
   │  ├─ BookDataLoaders.cs           [DataLoader]
   │  ├─ CreateBookInput.cs
   │  ├─ UpdateBookInput.cs
   │  ├─ BookExceptions.cs
   │  └─ BookMappings.cs
   └─ Reviews/
      ├─ ReviewQueries.cs             [QueryType]
      ├─ ReviewMutations.cs           [MutationType]
      ├─ ReviewNode.cs                [ObjectType<Review>]
      ├─ AuthorReviewExtensions.cs    [ObjectType<Author>]   ← contributes `reviews`
      ├─ BookReviewExtensions.cs      [ObjectType<Book>]     ← contributes `reviews`
      ├─ ReviewDataLoaders.cs
      └─ ReviewMappings.cs
```

**Cross-feature extension naming**: `<ForeignType><OwningFeature>Extensions.cs`.  
Any `Author*Extensions.cs` outside `Authors/` is a cross-feature contribution.  
**Rule**: one `[ObjectType<T>]` partial per (owning-feature, T) pair.

---

## Source generator mechanics

Every `[QueryType]` / `[MutationType]` / `[ObjectType<T>]` must be `static partial class`.  
The generator merges all partials of the same type across all files into one root type — no central `Query.cs` needed.

```csharp
// Any number of these across feature folders merge into one Query root
[QueryType]
public static partial class BookQueries { ... }

[QueryType]
public static partial class AuthorQueries { ... }
```

DI is auto-detected from method parameters in v14+. `[Service]` is no longer required.  
`[Parent("PropA PropB")]` declares data requirements; fails at compile time if property names drift.

**Registration** (Program.cs):
```csharp
builder.Services
    .AddGraphQL()
    .AddTypes()                         // source-generated per [assembly: Module("MyApp")]
    .AddGlobalObjectIdentification()
    .AddMutationConventions()
    .AddFiltering()
    .AddSorting()
    .AddProjections()
    .AddPagingArguments();

app.MapGraphQL();
app.RunWithGraphQLCommands(args);       // enables `dotnet run -- schema export`
```

---

## The Node pattern

`[ObjectType<Book>]` **is** the mapping. No parallel `BookDto`, no `ToApiType()`.  
HotChocolate reads public properties of `Book` and infers the schema. `BookNode.cs` is where you adjust that binding — not where you translate between two type hierarchies.

| Goal | How |
|---|---|
| Hide a property | `[GraphQLIgnore]` or `d.Ignore(x => x.InternalFlag)` |
| Rename a field | `[GraphQLName("title")]` |
| Replace FK with navigation | `[BindMember(nameof(Book.AuthorId))]` on resolver |
| Add computed field | Public static method on `[ObjectType<Book>]` partial |
| Expose as Relay Node | `d.Field(x => x.Id).ID<Book>()` + `[NodeResolver]` |

```csharp
[ObjectType<Book>]
public static partial class BookNode
{
    static partial void Configure(IObjectTypeDescriptor<Book> d)
    {
        d.Field(b => b.Id).ID<Book>();
    }

    [NodeResolver]
    public static Task<Book?> GetBookByIdAsync(
        Guid id, IBookByIdDataLoader byId, CancellationToken ct)
        => byId.LoadAsync(id, ct);

    // Replace FK scalar with navigation
    [BindMember(nameof(Book.AuthorId))]
    public static Task<Author> GetAuthorAsync(
        [Parent] Book b, IAuthorByIdDataLoader byId, CancellationToken ct)
        => byId.LoadRequiredAsync(b.AuthorId, ct);

    // Computed field
    public static string Slug([Parent("Title")] Book b)
        => b.Title.ToLowerInvariant().Replace(' ', '-');
}
```

**When you do need separate types**: input types (always), computed read-models with no persistent identity, and cases where domain and API shape diverge beyond what `[BindMember]` handles.

---

## Cross-feature type extensions

The same `[ObjectType<T>]` merging that works within one assembly works across feature folders. A field contributed by Books to Author lives in `Books/AuthorBookExtensions.cs`, not in `Authors/AuthorNode.cs`.

```csharp
// GraphQL/Books/AuthorBookExtensions.cs
[ObjectType<Author>]
public static partial class AuthorBookExtensions
{
    [UsePaging, UseFiltering, UseSorting]
    public static IQueryable<Book> GetBooks(
        [Parent] Author author,
        IAppReadContext db)
        => db.Books.Where(b => b.AuthorId == author.Id);
}
```

Authors/ stays free of Book dependencies. Books/ owns the extension. Merge happens at compile time.

---

## Mutation conventions (`AddMutationConventions()`)

Automatically wraps every mutation in Relay-style input/payload/errors without hand-writing the types.

A method returning `Task<Book>` with `[Error<T>]` attributes becomes:

```graphql
type Mutation {
  createBook(input: CreateBookInput!): CreateBookPayload!
}
type CreateBookPayload {
  book: Book
  errors: [CreateBookError!]
}
union CreateBookError = AuthorNotFoundError | DuplicateIsbnError
```

```csharp
[MutationType]
public static partial class BookMutations
{
    [Error<AuthorNotFoundException>]
    [Error<DuplicateIsbnException>]
    public static async Task<Book> CreateBookAsync(
        CreateBookInput input,
        IAppDbContext db,
        CancellationToken ct)
    {
        var book = input.ToEntity();
        db.Books.Add(book);
        await db.SaveChangesAsync(ct);
        return book;
    }
}
```

Declared `[Error<T>]` exceptions land in `payload.errors` (typed union). Undeclared exceptions bubble to the top-level GraphQL `errors` array.

To opt in per-method instead of globally, pass `new MutationConventionOptions { ApplyToAllMutations = false }` and annotate specific methods with `[UseMutationConvention]`.

---

## Mapping discipline

Three extension methods per feature — that's the whole job:

```csharp
// BookMappings.cs — static, no services, no async
public static class BookMappings
{
    public static Book ToEntity(this CreateBookInput i)
        => new() { Title = i.Title, AuthorId = i.AuthorId, Isbn = i.Isbn };

    public static CreateBookCommand ToCommand(this CreateBookInput i)
        => new(i.Title, i.AuthorId, i.Isbn);

    public static void ApplyTo(this UpdateBookInput i, Book b)
    {
        if (i.Title is { } t) b.Title = t;
        if (i.Isbn  is { } s) b.Isbn  = s;
    }
}
```

**Rules**:
- `*Mappings.cs` files contain no `await`, no `DbContext`, no `[Service]`. Static and pure only.
- Never call `ToX()` on `IQueryable<T>` — it materialises the query and kills projection/paging.
- Anything needing a service belongs in a resolver method on `[ObjectType<T>]`.
- Naming: `ToCommand`, `ToEntity`, `ApplyTo`. Avoid `ToDto`, `ToGraphQL`, `ToDomain`.

---

## EF Core / read enforcement

Expose two interfaces from one concrete `DbContext`:

```csharp
// Read surface — IQueryable<T> only, no SaveChanges
public interface IAppReadContext
{
    IQueryable<Book>   Books   { get; }
    IQueryable<Author> Authors { get; }
}

// Write surface — full DbSet<T> + SaveChanges
public interface IAppDbContext
{
    DbSet<Book>   Books   { get; }
    DbSet<Author> Authors { get; }
    Task<int> SaveChangesAsync(CancellationToken ct);
}

// One concrete implementation
public class AppDbContext : DbContext, IAppDbContext, IAppReadContext
{
    IQueryable<Book>   IAppReadContext.Books   => Set<Book>().AsNoTracking();
    IQueryable<Author> IAppReadContext.Authors => Set<Author>().AsNoTracking();
}
```

GraphQL resolvers inject `IAppReadContext` — they cannot call `Add`/`SaveChanges`.  
Command handlers inject `IAppDbContext`.

Global EF query filters handle soft-delete and tenancy at the model level:
```csharp
mb.Entity<Book>().HasQueryFilter(b => !b.IsDeleted);
```

---

## DataLoaders

Source-generated. Return `IReadOnlyDictionary<TKey, TValue>` (single lookup) or `IReadOnlyDictionary<TKey, IReadOnlyList<TValue>>` (group by foreign key).

```csharp
public static class BookDataLoaders
{
    [DataLoader]
    public static async Task<IReadOnlyDictionary<Guid, Book>> BookByIdAsync(
        IReadOnlyList<Guid> ids,
        IAppReadContext db,
        CancellationToken ct)
        => await db.Books.Where(b => ids.Contains(b.Id))
            .ToDictionaryAsync(b => b.Id, ct);

    [DataLoader]
    public static async Task<IReadOnlyDictionary<Guid, IReadOnlyList<Book>>> BooksByAuthorIdAsync(
        IReadOnlyList<Guid> authorIds,
        IAppReadContext db,
        CancellationToken ct)
        => await db.Books.Where(b => authorIds.Contains(b.AuthorId))
            .GroupBy(b => b.AuthorId)
            .ToDictionaryAsync(g => g.Key, g => (IReadOnlyList<Book>)g.ToList(), ct);
}
```

---

## Pagination & projection

`.AddFiltering().AddSorting()` in Program.cs (already shown above) is a **prerequisite** for `QueryContext<T>`, not an unrelated feature.

Current v16 pattern is `QueryContext<T>` + `.With()` — **`ISelectorBuilder` is the pattern this replaced; don't use it in new code.**

```csharp
[UseFiltering, UseSorting]
public static async Task<Page<Product>> GetProductsAsync(
    PagingArguments pagingArgs, QueryContext<Product> query,
    CatalogContext db, CancellationToken ct)
    => await db.Products.With(query).ToPageAsync(pagingArgs, ct);
```

`QueryContext<T>` is derived from the GraphQL selection set. `.With(query)` applies projection, filter, and sort to the `IQueryable` **in the correct order automatically** — this fixes the historical "wrong order breaks EF translation" gotcha. `.ToPageAsync(pagingArgs, ct)` materializes.

**DataLoader-batched pagination**: `.ToBatchPageAsync(keySelector, pagingArgs, ct)`, e.g. for `AuthorBookExtensions.GetBooks` paginated per-author with batching.

**Global config**:
```csharp
builder.Services.AddGraphQL()
    .ModifyPagingOptions(o =>
    {
        o.DefaultPageSize = 25;
        o.MaxPageSize = 100;
        o.IncludeTotalCount = true;
    });
```

Offset paging (skip/take, `XCollectionSegment`) is `[UseOffsetPaging]` — use only when a client genuinely needs page numbers; cursor paging (`[UsePaging]`) is the default and composes with DataLoader batching, offset paging does not.

`[UseProjection]` is the pattern you **migrate from** — replace it with `QueryContext<T>` + `.With()` in new and touched code.

---

## Interfaces & unions

Marker-interface pattern for both — type resolution is inferred from the runtime CLR type implementing the interface, no custom `ResolveType` delegate needed.

```csharp
[InterfaceType("Message")]
public interface IMessage
{
    User Author { get; set; }
    DateTime CreatedAt { get; set; }
}

[UnionType("PostContent")]
public interface IPostContent { }   // no members — pure marker
```

The `[Error<T>]` mutation pattern (below) generalizes to **query-level** result unions via this same mechanism — e.g. `IUserByEmailResult` implemented by both `User` and `UserNotFoundError`. See `references/schema-design.md` for when to reach for an interface vs a union.

---

## Modularity across assemblies

There's no `[Module]` attribute or assembly-scanning convention. The actual scale lever: `[QueryType]` / `[MutationType]` / `[ObjectType<T>]` partial classes merge **across assemblies**, not just across files in one project — split by assembly per bounded context for team-ownership boundaries. This is the same mechanism Fusion subgraphs use to extend foreign types (`references/fusion.md`), just within one process instead of across a gateway.

`ITypeModule` is a separate, unrelated mechanism for *dynamic* runtime-driven schemas (implement `CreateTypesAsync`, fire `TypesChanged` for hot-reload) — reach for it only when the schema itself is driven by external metadata, not as a general modularity tool.

---

## `[BatchResolver]` vs `[DataLoader]`

`[BatchResolver]` has a fuller contract than a plain field resolver: the parent parameter must be `[Parent] List<T>`, and the return type must be a list with the **same count and order** as the input — this is a contract, not compiler-enforced. Per-item error handling uses `ResolverResult.Ok(...)` / `.Fail(...)` without failing the whole batch.

Distinguish by intent: **batch resolver** = field-scoped, non-cacheable, one-off; **DataLoader** = cross-request/cross-field reusable caching. Default to DataLoader; reach for `[BatchResolver]` only when the batching is genuinely local to one field and caching would be wasted effort.

---

## Subscriptions

`[SubscriptionType]` follows the same partial-class merge story as queries and mutations; `[Subscribe]` + `[EventMessage]` on the parameter.

The **backplane is a real production decision**, not a default to leave alone: the in-memory default is single-instance only — any horizontally scaled deployment needs a shared backplane (Redis, NATS, RabbitMQ, or Postgres), all configured via `SubscriptionOptions` (`TopicBufferCapacity`, overflow mode).

---

## Production hardening

HotChocolate is **secure-by-default** — left at framework defaults, `AddGraphQL()` already enables cost analysis, disables introspection outside `Development`, and enforces a max field-cycle depth in production. Don't re-add these; tune them explicitly where the defaults don't fit:

```csharp
builder.Services.AddGraphQL()
    .AddMaxExecutionDepthRule(15)
    .ModifyCostOptions(o =>
    {
        o.MaxFieldCost = 1_000_000;
        o.MaxTypeCost = 1_000_000;
        o.EnforceCostLimits = true;
    })
    .ModifyRequestOptions(o => o.ExecutionTimeout = TimeSpan.FromSeconds(30));
```

**Persisted operations** are the recommended hardening for private/first-party APIs — not just a perf tweak, they eliminate parser/validator exposure entirely:

```csharp
app.MapGraphQL().UsePersistedOperationPipeline();
// and: OnlyAllowPersistedDocuments = true
```

---

## Authorization

`[Authorize]` must come from `HotChocolate.Authorization` — **not** the ASP.NET Core one. The ASP.NET Core attribute does not integrate with the GraphQL execution pipeline (field-level enforcement, error shaping) and will silently no-op in ways that are easy to miss in review.

`Roles = [...]` is any-match; `Policy = "..."` requires all stacked policies to pass. Type-level `[Authorize]` cascades to fields; field-level `[Authorize]` overrides it.

---

## Schema export, CI, and breaking-change detection

`dotnet run -- schema export` for ad-hoc export; `.ExportSchemaOnStartup(path)` for CI/registry integration at boot.

The officially sanctioned breaking-change detector is **snapshot-testing the SDL**, not a bespoke diff script:

```csharp
[Fact]
public Task Schema_has_not_changed_unexpectedly()
{
    var executor = /* build request executor */;
    return executor.Schema.MatchSnapshot();
}
```

Wire this into CI as the standard schema-diff gate.

**v16 breaking change**: `@semanticNonNull` is no longer auto-applied at the main endpoint. Opt in via `dotnet run -- schema export --semantic-non-null`, or serve a parallel endpoint with `app.MapGraphQLSemanticNonNullSchema()`.

---

## Fusion (cross-subgraph extension)

See `references/fusion.md` for the full reference.

**Short version**: the exact same `[ObjectType<T>]` partial pattern works across subgraph assemblies. Each subgraph declares its own `[ObjectType<Author>]` with whatever fields it owns and a `[Lookup]` resolver (marked `[Internal]` on non-owning subgraphs). Composition is CLI-time (`nitro fusion compose`), not runtime. No `@key`, no `[ReferenceResolver]`, no representations protocol.

---

## Schema design principles

See `references/schema-design.md` for library-agnostic schema architecture — demand-oriented vs resource-oriented design, Relay conventions, nullability/evolution, error-handling schools, fragments and colocation, layered performance defenses, and modularity/governance at scale — each mapped to the concrete HC v16 mechanism above.
