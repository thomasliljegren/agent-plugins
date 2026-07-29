# Fusion — Cross-Subgraph Extension Reference (v16)

> **Deployment, CI/CD, Aspire, `schema-settings.json`, and "must I redeploy the gateway
> after a subgraph change?" are in `fusion-deployment.md`.** This file covers modelling.

## Model overview

HotChocolate Fusion is **not Apollo Federation in C# paint**. Key differences:

| | Apollo Federation | HotChocolate Fusion |
|---|---|---|
| Entity key | `@key` directive on type | `[Lookup]` on a root field |
| Reference resolver | `[ReferenceResolver]` method | `[Lookup, Internal]` in contributing subgraph |
| Representations | `_entities(representations: …)` query | Gateway calls `[Internal]` lookup fields |
| Type matching | `@key` fields | GraphQL type name |
| Composition | `rover supergraph compose` | `nitro fusion compose` CLI |
| Field-requires | `@requires` field directive | `[Require]`, **argument-level** — see below |

Composition matches types by **GraphQL type name**. `Author` in Authors.Api and `Author` in Books.Api are the same type because the name matches — not because of a CLR identity or `@key` declaration.

A dedicated **Apollo Federation migration guide** exists with a full concept map: `@key` → `[Lookup]`, `_entities` → ordinary callable/testable `[Lookup]` fields (no hidden protocol), `@requires` → `[Require]`, `@provides` → `[Parent(requires:)]`, `@shareable`/`@override`/`@inaccessible`/`@tag` map 1:1. Fusion 16 also ships an **Apollo Federation connector** that lets existing Apollo subgraphs run unmodified behind a Fusion gateway during incremental migration.

**When NOT to use Fusion** (per official guidance): single team/service, small/early-stage APIs, no clear domain boundaries yet, or the team is still learning GraphQL basics. The documented incremental-adoption path is to point Fusion at one existing monolith as the sole subgraph and split gradually — explicitly framed as "not a rewrite."

---

## Directives / attributes

All from `HotChocolate.Fusion.SourceSchema` NuGet package.

| SDL | C# | Purpose |
|---|---|---|
| `@lookup` | `[Lookup]` | Marks root field as entity lookup — the gateway uses this to rehydrate entities |
| `@internal` | `[Internal]` | Hides lookup from public gateway schema; only the gateway calls it |
| `@is(field: "id")` | directive on arg | Maps arg name to a different entity field when names don't match; supports choice-operator syntax (`@is(field: "{ id } | { username }")`) for multiple alternate keys on one lookup |
| `@requires` | `[Require]` | Declares a field-resolver dependency on another subgraph's data — **argument-level, not field-level**. This is the single biggest mental-model shift coming from Apollo, where `@requires` sits on the field. |
| `@provides` | `[Parent(requires: "...")]` | Declares that a resolver can supply fields another subgraph would otherwise need to fetch itself |

**`[NodeResolver]` + `AddGlobalObjectIdentification()`** is equivalent to `[Lookup]` for Relay/global-ID scenarios. Use `[NodeResolver]` if the product already uses global IDs; use `[Lookup]` for plain typed keys. They do not conflict.

**Federated Event Streams**: `[EventStream]` / `[EventCursor]` back GraphQL subscriptions with a message broker (Kafka, Azure Event Hubs, SQS, Redis, NATS) shared across subgraphs — a substantial new v16 capability for cross-subgraph subscriptions, distinct from the single-subgraph backplane story in SKILL.md's Subscriptions section.

`preprocessor.inferShareable` in `schema-settings.json` auto-marks overlapping fields `@shareable` during composition instead of requiring the attribute on every duplicated field.

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

The query planner was completely reworked in v16 to produce serializable/exportable plans (plan pinning, build-time planning, a visual inspector in Nitro) — no published algorithm name found, treat internals as an implementation detail. Parallel fan-out for independent subgraph calls is architecturally implied by the batching model above but not explicitly documented with guarantees; don't depend on a specific concurrency ordering. Request deduplication and a concurrency gate (`MaxConcurrentExecutions`, default 64) are confirmed new tuning knobs. OpenTelemetry support follows the standard GraphQL OTel spec.

---

## Shared contracts

**Local stubs (recommended)**: each subgraph defines the foreign entity with only the key. Zero coupling, fastest deploys. Drift risk is trivial — the stub is one property.

**Shared Contracts project**: a dedicated assembly with canonical DTOs. Better IDE navigation but couples subgraph deploys. Use only if the key type is a complex strongly-typed ID that needs shared logic.

For Relay global IDs: define `[ID("Author")] Guid id` in the owning subgraph and `[ID] Guid id` on lookup arguments in both. HC handles base64 encoding consistently because the composer preserves the `@id` binding.

---

## Composition tooling

The gateway artifact and CLI are `.far` / `nitro`, not the older `.fgp` / standalone `fusion` binary.

```bash
# Install once (any one of these)
npm install -g @chillicream/nitro
brew install ChilliCream/tools/nitro-cli
dotnet tool install --global ChilliCream.Nitro.CommandLine

# Per subgraph in CI
dotnet run --project src/Authors.Api -- schema export --output schema.graphql
dotnet run --project src/Books.Api   -- schema export --output schema.graphql

# Compose
nitro fusion compose \
  --source-schema-file src/Authors.Api/schema.graphqls \
  --source-schema-file src/Books.Api/schema.graphqls \
  --archive gateway.far
```

Each local schema file needs a companion `-settings.json` next to it (`schema.graphqls` →
`schema-settings.json`); both are produced by `schema export`. See `fusion-deployment.md`.

`nitro` is the umbrella CLI for the whole Nitro product (hosted schema registry, observability, governance); `fusion` is a command group inside it: `nitro fusion compose|validate|publish|download|run|upload|migrate|settings`. `nitro fusion publish` supports three input modes (pre-composed archive / local source schemas / uploaded `name@version` refs) plus a begin/start/validate/commit/cancel workflow for gated, blue-green deploys.

**Gateway Program.cs**:
```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpClient("fusion");

builder                                    // on the WebApplicationBuilder, not .Services
    .AddGraphQLGateway()
    .AddFileSystemConfiguration("./gateway.far");

var app = builder.Build();
app.MapGraphQL();
app.Run();
```

⚠️ `builder.Services.AddGraphQLGateway()` is a *different* overload that registers the execution
core **without an HTTP server**. For a hosted gateway use `builder.AddGraphQLGateway()` or
`builder.Services.AddGraphQLGatewayServer()`.

The gateway is a fully decoupled, open ASP.NET Core library — standard `IHttpClientFactory`, OpenTelemetry, and ASP.NET Core auth, not Fusion-specific mechanisms. (Rationale: the earlier gateway was built on top of HotChocolate's own type system and broke when core shipped internal fixes; rather than following competitors to a Rust/Go gateway, ChilliCream decoupled it into a plain library.)

**With Aspire** (dev loop only — see `fusion-deployment.md` for settings and partial graphs):

```csharp
var builder = DistributedApplication.CreateBuilder(args);

builder.AddGraphQLOrchestrator();          // once, first

var authors = builder.AddProject<Projects.MyApp_Authors_Api>("authors")
    .WithGraphQLSchemaEndpoint();
var books   = builder.AddProject<Projects.MyApp_Books_Api>("books")
    .WithGraphQLSchemaEndpoint();

builder.AddProject<Projects.MyApp_Gateway>("gateway")
    .WithGraphQLSchemaComposition()        // takes no subgraph arguments
    .WithReference(authors)                // subgraphs are discovered via WithReference
    .WithReference(books);

builder.Build().Run();
```

The orchestrator fetches each subgraph's live schema over HTTP and composes at AppHost build time. `WithGraphQLSchemaFile()` lets you mix live subgraphs with pre-exported schema files, useful for partial-graph local dev when not every subgraph is runnable locally.

Composition is **always build/CI-time**, not runtime request-time. Type conflicts and missing lookups fail composition before reaching production. Local hot-reload during plain `dotnet run` isn't quite real file-watch: with Aspire, recomposition happens on AppHost build; for the non-Aspire case use `nitro fusion compose --watch`.

Composition runs an **8-phase pipeline** (Parse → Preprocess → Enrich → Validate Source Schemas → Pre-Merge Validation → Merge → Post-Merge Validation → Validate Satisfiability) with stable diagnostic codes worth knowing when composition fails: `OUTPUT_FIELD_TYPES_NOT_MERGEABLE`, `INVALID_FIELD_SHARING`, `UNSATISFIABLE_QUERY_PATH`, among others. Full triage table in `fusion-deployment.md`.

---

## Nitro Cloud (hosted schema registry)

Subgraphs upload SDL tagged by commit SHA. `nitro fusion publish` composes server-side against a target stage and hot-swaps the running gateway with no restart (gateway side: `AddNitro().AddDefaults()`). `nitro fusion validate` at PR time composes the proposed schema against the currently-published siblings — this is the CI breaking-change gate for a federated graph, analogous to the single-service `MatchSnapshot()` gate in SKILL.md. Native GitHub Actions exist for all three steps (`nitro-fusion-upload`, `nitro-fusion-publish`, `nitro-fusion-validate`).

**Ordering matters**: deploy the subgraph app first, `publish` second — publishing first points the gateway at a URL that isn't live yet.

Self-hosting the registry (skipping Nitro) is documented but you own write-serialization, validation, persisted-operation safety, and atomic rollout yourself — not a drop-in replacement.

Full pipelines, YAML, and the redeploy decision table: `fusion-deployment.md`.

---

## Fusion — legacy patterns to ignore

**Ignore** any content showing:
- `@resolve`, `@delegate`, or `@extends` directives in `.ext.graphql` files — HC v13 schema-stitching legacy
- `@key`/`_entities`/`__resolveReference` — Apollo Federation patterns; don't translate literally (see the migration concept map above instead)
- `.fgp` files, `AddFusionGatewayServer()`, standalone `fusion compose` (no `nitro` prefix), or `SubgraphConfigurationFile` — pre-v16 gateway hosting, superseded by `.far` / `AddGraphQLGateway()` / `nitro fusion compose`
- `subgraph-config.json` — v15; migrate with `nitro fusion migrate subgraph-config` to `schema-settings.json`
- `dotnet tool install -g HotChocolate.Nitro.CommandLine.Tool` — wrong package id (see CLI install above)

---

## Known limitations

| Area | Status |
|---|---|
| Cross-subgraph filter predicates | Not supported — filters must resolve entirely within one subgraph. This is a general federation constraint, not a HotChocolate-specific gap, and should be assumed to still apply. |
| SSE subscription cancellation, dual-layer `AddAuthorization()` conflict (historical open issues) | Could not confirm current status by issue number this session. Structurally, subscriptions were substantially redesigned (event-stream model, see above) and auth is now standard ASP.NET Core with no Fusion-specific directives — both changes plausibly avoid the old failure classes, but neither is a confirmed fix. Verify directly if either is on your critical path. |
| `[ExtendObjectType<T>]` | Works but on deprecation path — use `[ObjectType<T>]` for all new code |

DataLoaders, `[UsePaging]`, `[UseFiltering]`, `[UseSorting]` all compose naturally within a single subgraph, including on cross-subgraph-contributed fields (because those fields resolve entirely inside the contributing subgraph).
