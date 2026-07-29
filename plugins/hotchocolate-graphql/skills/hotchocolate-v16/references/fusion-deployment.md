# Fusion — Deployment, CI/CD, and Aspire Reference (v16)

Companion to `fusion.md`. That file covers *how you model* a distributed graph;
this one covers *how you ship it* and what has to happen when a subgraph changes.

---

## Mental model: what actually binds the gateway to your subgraphs

The gateway binary contains **no subgraph-specific code**. Everything that ties it
to your fleet lives in the **Fusion archive** (`.far`), produced by composition:

- the composite (execution) schema
- lookup / key / ownership metadata, embedded as directives
- each subgraph's transport URL and HTTP client name, from its `schema-settings.json`

The gateway loads this archive and never sees raw source schemas, only the composed result.

So "do I need to redeploy the gateway?" is really **"does a new archive need to reach
the gateway, and how does it get there?"** Three delivery models:

| Delivery | Wiring | New archive reaches gateway by |
|---|---|---|
| **Nitro** (recommended) | `AddNitro()` / `AddNitro().AddDefaults()` | `nitro fusion publish` → gateway subscribed to the stage **hot-swaps without a restart** |
| **File system** | `AddFileSystemConfiguration("./gateway.far")` | The file ships inside the gateway's image/artifact → **new archive = new gateway deployment** |
| **Custom** | `AddConfigurationProvider(...)` + `IFusionConfigurationProvider` | Whatever you implement (also `AddInMemoryConfiguration`) |

---

## Do I need to redeploy the gateway after a subgraph change?

**Short answer: only if the subgraph's exported SDL or `schema-settings.json` changed — and even
then, with Nitro you publish a new configuration rather than redeploying the gateway.**

| What changed in the subgraph | Re-export + recompose | Publish new config | Gateway restart / redeploy |
|---|---|---|---|
| Resolver body, DataLoader, DB query, perf fix, bug fix — **exported SDL byte-identical** | No | No | **No** — just deploy the subgraph |
| Additive SDL change (new field, type, lookup, enum value) | Yes | Yes | No with Nitro (hot-swap) · Yes with file-system archive |
| Breaking SDL change (removed/renamed field, changed type) | Yes | Yes | Same as above |
| `schema-settings.json` change (subgraph URL, `name`, `clientName`) | Yes — **the URL is baked into the archive** | Yes | Same as above |
| Subgraph added or removed entirely | Yes | Yes | Same as above |
| Subgraph scaled / replaced behind the *same* URL | No | No | **No** |
| Gateway's own `Program.cs`, package upgrade, header propagation, auth | — | — | **Yes** — ordinary app deploy |

**The trap:** a subgraph's transport URL lives in `schema-settings.json` and is composed *into*
the archive. Changing where a subgraph is reachable is a **composition-affecting change**, even
though no GraphQL type moved. This is not runtime service discovery.

**The other trap:** `dotnet run -- schema export` regenerates `schema.graphqls`. Diff it in CI.
If it is unchanged, you have a pure implementation change and the entire composition/publish
pipeline is a no-op you can skip.

---

## Deploy ordering rules

### Additive changes: deploy the subgraph *first*, publish *second*

`nitro fusion publish` must run **after** the subgraph application has been deployed and is
reachable at its production URL. Once publish succeeds, gateways subscribed to that stage start
routing against the new schema, and every subgraph endpoint it references must already accept
requests. Publishing first and deploying second opens a window where the gateway sends traffic
to a URL that isn't live yet.

This is why the documented pipeline splits into a **build job** (export + `nitro fusion upload`,
tagged by commit SHA) and a **deploy job** (ship the app, *then* `nitro fusion publish`).

### Removing a shared field

If several subgraphs provide the field, just remove it from one — the gateway resolves it from
the remaining subgraphs that still provide it. No deprecation dance needed.

If it is the *last* provider, it is a client-facing breaking change: `@deprecated` → let clients
migrate → remove → recompose → publish.

Note the asymmetry across subgraphs: `@deprecated` on a shareable field in **one** subgraph
deprecates it for all clients, while `@requiresOptIn` stays in force until **every** subgraph
that defines the field drops it.

### Moving field ownership between subgraphs

Documented four-step workflow using `[Override(from: "old-subgraph-name")]`:

1. Add the field to the **new** subgraph with `[Override(from: "products-api")]`.
2. Export schemas and compose — composition validates the override.
3. Deploy the new subgraph. The gateway routes the field to it.
4. Remove the old resolver from the original subgraph when ready.

Both subgraphs may define the field simultaneously during the transition; `[Override]` tells
composition which one wins, so you don't need `[Shareable]` and don't get a duplicate-field error.
`from` is the subgraph **name from `schema-settings.json`**, not the project or assembly name.

---

## Nitro CI/CD pipelines

### Prerequisites

- A Nitro account and organization.
- An **API ID** per gateway (looks like `QXBpCmcwMTk5MGUzNDVlMWU3MjMyYjc2MjYxYzFiNjRkMGQzYg==`).
- An **API key** with upload/publish/validate permission, stored as a CI secret.
- A **stage** (`dev`, `staging`, `production`) — created in Nitro, addressed by name.

All `nitro fusion` subcommands fall back to `NITRO_API_ID`, `NITRO_API_KEY`, `NITRO_STAGE`, and
`NITRO_TAG` env vars when the matching option is omitted. Set them at job level to keep commands
compact.

### Build job — export and upload the source schema

```bash
dotnet run --project ./src/SubgraphA -- schema export --output ./src/SubgraphA/schema.graphql
```

```yaml
- name: Upload source schema to Nitro
  uses: ChilliCream/nitro-fusion-upload@v16
  with:
    tag: ${{ github.sha }}
    api-id: ${{ secrets.NITRO_API_ID }}
    api-key: ${{ secrets.NITRO_API_KEY }}
    source-schema-files: |
      ./src/SubgraphA/schema.graphql
```

**The tag is the join key.** The tag passed to `upload` must match the tag referenced from
`publish`. If they drift, publish can't find the source schema and the deployment fails before
any traffic is rerouted.

### Deploy job — publish the Fusion configuration

```yaml
- name: Deploy subgraph
  run: # push container image, kubectl apply, etc.

- name: Publish Fusion configuration
  uses: ChilliCream/nitro-fusion-publish@v16
  with:
    tag: ${{ github.sha }}
    stage: production
    api-id: ${{ secrets.NITRO_API_ID }}
    api-key: ${{ secrets.NITRO_API_KEY }}
    source-schemas: |
      subgraph-a@${{ github.sha }}
```

`--source-schema` uses `name@version`: `name` is the `name` field from that subgraph's
`schema-settings.json`; `version` is the upload tag. Repeat it to pin sibling subgraphs:

```bash
nitro fusion publish \
  --tag "$GITHUB_SHA" \
  --stage production \
  --source-schema "subgraph-a@$GITHUB_SHA" \
  --source-schema "subgraph-b@v1.4.0" \
  --source-schema "subgraph-c@latest"
```

Nitro re-composes server-side from the registered source schemas, validates, and makes the new
archive available to every gateway subscribed to that stage. **You never ship the archive by hand.**

`publish` has three mutually exclusive input modes: `--archive` (pre-composed `.far`),
`--source-schema-file` (compose from local files), and `--source-schema` (uploaded `name@version`
refs — the mode the CI pipeline above uses).

### PR job — validate before merge

```yaml
- name: Validate against production stage
  uses: ChilliCream/nitro-fusion-validate@v16
  with:
    stage: production
    api-id: ${{ secrets.NITRO_API_ID }}
    api-key: ${{ secrets.NITRO_API_KEY }}
    source-schema-files: |
      ./src/SubgraphA/schema.graphql
```

This composes the proposed source schema against the **currently published** versions of the other
subgraphs and reports composition errors and breaking changes before the change reaches `main`.
**Validate against the same stage you will publish to** — the source schemas registered on `dev`
and `production` can differ, so validating against `dev` before publishing to `production` defeats
the purpose.

This is the federated equivalent of the single-service `MatchSnapshot()` SDL gate in `SKILL.md`.

### Gated / blue-green deploys

For manual approval gates, use the publish sub-commands instead of one-shot `publish`:

`begin` (reserve a slot; `--wait-for-approval`) → `start` (compose) → `validate` → `commit`.
`cancel` aborts. `--request-id` is cached from `begin`, so later steps usually omit it.

---

## Gateway runtime wiring

**Canonical minimal gateway** (what the `gateway` template scaffolds):

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpClient("fusion");

builder
    .AddGraphQLGateway()                              // extension on the WebApplicationBuilder
    .AddFileSystemConfiguration("./gateway.far");

var app = builder.Build();
app.MapGraphQL();
app.Run();
```

**Which overload?** Three similarly-named methods exist and picking the wrong one silently gives
you a gateway with no HTTP server:

| Call | Receiver | Gives you |
|---|---|---|
| `builder.AddGraphQLGateway()` | `IHostApplicationBuilder` | Full gateway **+ ASP.NET Core server**. Use this. |
| `builder.Services.AddGraphQLGatewayServer()` | `IServiceCollection` | Same thing, service-collection style |
| `builder.Services.AddGraphQLGateway()` | `IServiceCollection` | **Execution core only — no HTTP server.** Not what you want in a hosted gateway. |

Like a single HC server, the gateway is **secure by default**: it disables introspection outside
`Development` and adds the max-allowed-field-cycle-depth rule unless you pass
`disableDefaultSecurity: true`. `MaxConcurrentExecutions` gates concurrent execution.

**Nitro-backed configuration** (closes the CI/CD loop — subscribes to the stage and hot-swaps):

```csharp
builder.Services.AddNitro().AddDefaults();

builder.Services
    .AddGraphQLGatewayServer()
    .ModifyNitroOptions(o =>
    {
        o.Service.ApiId  = "...";
        o.Service.ApiKey = "...";
        o.Service.Stage  = "production";
    });
```

`AddDefaults()` is source-generated by the `ChilliCream.Nitro` package and requires a
`ChilliCream.Nitro.Fusion` package reference. If it isn't available, check package references or
use the explicit `.AddFusion()` method. The gateway-builder shorthand
`builder.AddGraphQLGateway().AddNitro()` also appears in the docs.

**Header propagation** — the HTTP client name must match `transports.http.clientName` in each
subgraph's `schema-settings.json` (default `"fusion"`), and must be configured **per client** or it
silently does nothing:

```csharp
builder.Services.AddHeaderPropagation(o => o.Headers.Add("Authorization"));
builder.Services.AddHttpClient("fusion").AddHeaderPropagation();
// ...
app.UseHeaderPropagation();
```

---

## `schema-settings.json` and environments

Generated on first `dotnet run -- schema export`, sits next to `schema.graphqls`, and is
**required** — every local `.graphql`/`.graphqls` file must have a companion `-settings.json`
(`schema.graphqls` → `schema-settings.json`).

```json
{
  "name": "products-api",
  "transports": {
    "http": {
      "clientName": "fusion",
      "url": "{{API_URL}}"
    }
  },
  "environments": {
    "development": { "API_URL": "http://localhost:5100/graphql" },
    "production":  { "API_URL": "https://products.example.com/graphql" }
  }
}
```

**Environment substitution happens at compose time, and `environments` does not survive into the
archive.** Consequence: **one archive per environment.** Select with
`nitro fusion compose --environment production` (defaults to `ASPNETCORE_ENVIRONMENT`, else
`Development`), or `GraphQLCompositionSettings.EnvironmentName` under Aspire. You cannot repoint a
`production.far` at staging URLs after the fact — recompose.

`name` must be unique across subgraphs and is what `[Override(from: ...)]` and
`--source-schema name@version` refer to. `AddGraphQL("Products")` in the subgraph's `Program.cs`
seeds it.

---

## Aspire integration (the dev loop)

Package `HotChocolate.Fusion.Aspire` on the AppHost; subgraphs need
`HotChocolate.AspNetCore.CommandLine` so their schema endpoint exists.

```csharp
var builder = DistributedApplication.CreateBuilder(args);

builder.AddGraphQLOrchestrator();                     // once, first, on the app builder

var productsApi = builder
    .AddProject<Projects.Products>("products-api")
    .WithGraphQLSchemaEndpoint();                     // live schema over HTTP

var reviewsApi = builder
    .AddProject<Projects.Reviews>("reviews-api")
    .WithGraphQLSchemaEndpoint();

builder
    .AddProject<Projects.Gateway>("gateway-api")
    .WithGraphQLSchemaComposition()                   // marks the gateway as needing composition
    .WithReference(productsApi)                       // plain Aspire — selects what gets composed
    .WithReference(reviewsApi);

builder.Build().Run();
```

`WithGraphQLSchemaComposition()` takes **no subgraph arguments** — subgraphs are discovered through
ordinary `WithReference()` calls. The orchestrator starts each subgraph, waits for it to become
healthy, GETs `/graphql/schema.graphql` (overridable via `path`, `endpointName`,
`sourceSchemaName`), composes, and writes `gateway.far` into the gateway project directory. If a
subgraph isn't ready within the timeout, the orchestrator errors and stops the AppHost.
`sourceSchemaName` defaults to the Aspire resource name.

**Partial graphs** — you don't have to run every subgraph locally. `WithGraphQLSchemaFile()` reads
a checked-in `schema.graphqls` + `schema-settings.json` from the project directory instead of
starting the service. Mix freely with live subgraphs in one composition:

```csharp
var shippingApi = builder
    .AddProject<Projects.Shipping>("shipping-api")
    .WithGraphQLSchemaFile();                          // other team's subgraph, not running locally
```

Keep those exported files in source control so teammates can compose without running your services.

**Composition settings:**

```csharp
.WithGraphQLSchemaComposition(
    settings: new GraphQLCompositionSettings
    {
        EnableGlobalObjectIdentification = true,
        NodeResolution = NodeResolution.SourceSchema,   // requires the flag above
        EnvironmentName = "aspire"
    })
```

Also available: `AllowNonResolvableInterfaceObjects`, `ShareableFieldRuntimeTypeRouting`, and
`outputFileName:` (default `gateway.far`).

**Dev loop:** change subgraph code → build/run the AppHost → orchestrator extracts schemas and
composes → gateway loads the new archive → query. **Composition failure stops the AppHost** with
the same diagnostics the Nitro CLI produces, so schema conflicts surface at F5 rather than in CI.

Aspire replaces the manual export/compose/restart cycle **for local development**. It is not the
production delivery mechanism — production is `nitro fusion publish` (or a shipped `.far`).

---

## Composing without Aspire and without Nitro

```bash
nitro fusion compose \
  --source-schema-file ./src/SubgraphA/schema.graphqls \
  --source-schema-file ./src/SubgraphB/schema.graphqls \
  --archive ./gateway.far
```

- `--source-schema-file` / `-f` accepts a file **or a directory**; the `-settings.json` companion
  must sit next to it. With no `-f`/`--source-schema-url`, the CLI auto-discovers all
  `.graphql`/`.graphqls` files in the working directory.
- `--source-schema-url` fetches from a live subgraph; pair it with `--source-schema-settings-file`.
  **Pairing is positional** — Nitro matches the *n*-th URL to the *n*-th settings file, so keep
  each pair adjacent in scripts.
- `--archive` / `-a` is the output path (default `./gateway.far`). Re-running compose against an
  existing archive **adds** to it and preserves stored settings you don't re-specify.
- `nitro fusion compose --watch` re-composes on local file changes and re-fetches remote schemas.
  It does **not** poll remote URLs.
- `--exclude-by-tag <tag>` strips tagged fields/types — the mechanism for building a public-facing
  archive from an internal graph.
- `nitro fusion run gateway.far --port 5000` spins up a throwaway local gateway with the Nitro IDE.
- `nitro fusion download --stage production` pulls the currently-published archive (useful for
  local repro of a production composition).
- `nitro fusion settings set <name> <value> --archive gateway.far` edits composition settings in
  an existing archive (`global-object-identification`, `node-resolution`, `tag-merge-behavior`,
  `cache-control-merge-behavior`, …).

**What you take on by skipping Nitro** (documented explicitly — Nitro is the supported path):

- **Exclusive write access** — concurrent subgraph pipelines must serialize, or they compose
  against stale state and overwrite each other's archive.
- **Pre-publish validation** — you must download the deployed archive, re-compose with the
  proposed change, and check for breaking changes yourself.
- **Persisted operation safety** — removing a field still referenced by a persisted operation
  breaks live traffic.
- **Atomic rollout** — write-to-temp-then-rename, or use storage with atomic swap, so no request
  ever sees a half-written archive.

---

## Nitro CLI installation

```bash
npm install -g @chillicream/nitro                       # recommended; bundles native binaries
brew install ChilliCream/tools/nitro-cli                # macOS
dotnet tool install --global ChilliCream.Nitro.CommandLine
```

Cloud subcommands (`upload`, `publish`, `validate`, `download`) fall back to `NITRO_API_KEY`,
then to the session from `nitro login`.

---

## When composition fails in CI

Composition runs an 8-phase pipeline and **halts at the first phase that produces errors**
(several errors within one phase are reported together):

Parse → Preprocess → Enrich → Validate Source Schemas → Pre-Merge Validation → Merge →
Post-Merge Validation → Validate Satisfiability

Log codes are **stable identifiers and safe to match on in CI scripts**. The three that account
for most real failures:

| Code | Cause | Fix |
|---|---|---|
| `OUTPUT_FIELD_TYPES_NOT_MERGEABLE` | Same field, different types across subgraphs (`Float` vs `Int`) | Align them. Scalars and enums must match exactly; object/interface/union types merge only when one declared type is a supertype of the others. |
| `INVALID_FIELD_SHARING` | Field defined in multiple subgraphs without `@shareable` | Add `[Shareable]` to **every** definition (one diagnostic is emitted per non-shareable definition), or set `preprocessor.inferShareable: true` in that subgraph's `schema-settings.json` — only if another process guarantees the fields are semantically identical. Key fields are automatically shareable. |
| `UNSATISFIABLE_QUERY_PATH` | A reachable field can't be resolved by any subgraph via the available `@lookup`/`@key` paths | Usually a missing `[Lookup, Internal]` in the contributing subgraph. Add `--include-satisfiability-paths` for the diagnostic path. |

Also common: `KEY_INVALID_FIELDS`, `CONFLICTING_SOURCE_SCHEMA_NAME`, `EXTERNAL_MISSING_ON_BASE`,
`ENUM_VALUES_MISMATCH`, `OPT_IN_FEATURE_STABILITY_MISMATCH` (subgraphs disagree on
`OptInFeatureStability` for the same feature name).

Because composition is build-time, **a query the gateway accepts is guaranteed answerable by your
fleet** — satisfiability has already proven it. That is the whole point of the pipeline.

---

## Legacy / wrong patterns to reject

- `builder.Services.AddGraphQLGateway()` in a hosted gateway — that overload has no HTTP server.
- `AddFusionGatewayServer()`, `.fgp` files, `SubgraphConfigurationFile`, bare `fusion compose`
  (no `nitro` prefix) — pre-v16.
- `subgraph-config.json` — v15. Migrate with `nitro fusion migrate subgraph-config`
  (maps `subgraph` → `name`, `http.baseAddress` → `transports.http.url`; skips directories that
  already have a `schema-settings.json`).
- `dotnet tool install -g HotChocolate.Nitro.CommandLine.Tool` — wrong package id.
- Hand-editing `schema.graphqls` — it is generated by `dotnet run -- schema export`.
- Treating the subgraph URL as runtime config — it is composed into the archive.
- Assuming the Aspire orchestrator is a production deployment mechanism — it is a dev-loop tool.
