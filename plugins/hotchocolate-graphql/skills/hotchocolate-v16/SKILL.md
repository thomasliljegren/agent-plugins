---
name: hotchocolate-v16
description: >
  Architecture patterns, code conventions, and structural decisions for building
  HotChocolate v16 GraphQL servers. Use this skill whenever working on anything
  in the GraphQL layer: adding a new query, mutation, subscription, object type,
  DataLoader, type extension, input type, or error type; wiring up Fusion v2
  subgraph lookups; setting up mutation conventions; or deciding where a new file
  belongs. Also use when the user asks about the node pattern, cross-feature type
  extensions, mapping strategy, or Fusion v2 cross-subgraph entity extension.
  When in doubt about any HC v16 or Fusion v2 pattern, consult this skill first.
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
        ISelectorBuilder selector,
        CancellationToken ct)
        => await db.Books.Where(b => ids.Contains(b.Id))
            .Select(b => b.Id, selector)
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

Use `ISelectorBuilder selector` + `.Select(b => b.Id, selector)` to push the client's field selection into SQL.

---

## Fusion v2 (cross-subgraph extension)

See `references/fusion-v2.md` for the full reference.

**Short version**: the exact same `[ObjectType<T>]` partial pattern works across subgraph assemblies. Each subgraph declares its own `[ObjectType<Author>]` with whatever fields it owns and a `[Lookup]` resolver (marked `[Internal]` on non-owning subgraphs). Composition is CLI-time (`fusion compose`), not runtime. No `@key`, no `[ReferenceResolver]`, no representations protocol.
