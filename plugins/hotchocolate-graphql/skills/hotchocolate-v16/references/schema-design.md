# GraphQL Schema Design — Principles & HotChocolate Mapping

Library-agnostic schema architecture principles. Each ends with **In HotChocolate**: the concrete v16 mechanism.

---

## Demand-oriented vs resource-oriented design

The real fault line in schema design isn't schema-first vs code-first — it's **demand-oriented vs resource-oriented**. Resource-oriented (schema mirrors DB tables/entities) is the path of least resistance but calcifies DB structure into a public contract. Demand-oriented design surveys actual client needs and keeps the schema an abstracted contract, decoupled from storage.

**In HotChocolate**: `[ObjectType<T>]` exposes domain entities directly — there's no DTO tier forcing demand-orientation for you. Discipline is enforced by curation: `[GraphQLIgnore]` to hide storage-only properties, `[BindMember]` to replace a raw FK with a navigation, computed fields for anything a client needs that storage doesn't shape directly. Treat `BookNode.cs` as the client contract, not a passthrough.

---

## Relay conventions and why

The Node interface (`node(id: ID!): Node`, opaque global ID) and Connection spec (`edges { cursor, node }`, `pageInfo`) exist to enable **normalized client caching** — objects cache by `type:id` and merge across queries regardless of query shape. This is the load-bearing link between "boring spec compliance" and client performance; without it, normalized caches fall back to per-type heuristics.

**In HotChocolate**: `AddGlobalObjectIdentification()` + `.ID<T>()` on the identity field + `[NodeResolver]` implement Node identity. `[UsePaging]` / `PagingArguments` + `QueryContext<T>` implement the Connection spec (see SKILL.md's Pagination section).

---

## Nullability & evolution

Nullable-by-default is deliberate (Lee Byron's rationale): `Int → Int!` is non-breaking, `Int! → Int` is breaking, so defaulting nullable keeps evolution additive. GraphQL has no built-in versioning story — one schema, evolved via additive changes plus `@deprecated(reason:)`, fields removed only after usage telemetry hits zero.

This is a genuine, unresolved debate: aggressive non-null early communicates real guarantees to clients but limits future evolution. There's no universal answer — pick deliberately per field, not by default habit.

**In HotChocolate**: nullability is inferred from the CLR property's nullability annotations, so C#'s nullable reference types drive the schema directly — treat enabling `<Nullable>` project-wide as a schema-design decision, not just a C# hygiene one. `[GraphQLDeprecated("reason")]` marks the removal path.

---

## Error handling: two schools

- **Shopify style** — mutation payload carries `userErrors: [UserError!]!`; top-level spec `errors[]` reserved for exceptional/system failures; HTTP always 200.
- **GitHub style** — result is a **union** of success type + explicit error types, forcing exhaustive client handling via fragments; fully typed, heavier schema surface.

Both agree on the same dividing line: top-level `errors[]` is for exceptional failures, not expected business-rule violations.

**In HotChocolate**: `AddMutationConventions()` + `[Error<T>]` is the GitHub-style pattern baked into the framework — see SKILL.md's Mutation conventions section for the full payload/union shape it generates. The same marker-interface mechanism (`[UnionType]`) generalizes to **query-level** result unions, e.g. `IUserByEmailResult` implemented by both `User` and `UserNotFoundError` — see SKILL.md's Interfaces & unions section.

---

## Interfaces vs unions

Use an **interface** when implementors share meaningful common fields queryable without a fragment. Use a **union** when types are unrelated (search results, "value or error"). Both need inline fragments (`... on ConcreteType`) for type-specific fields; interfaces additionally allow direct field access on the shared surface. This choice is made at schema-design time and directly determines whether client queries need `... on X` spreads at all.

**In HotChocolate**: `[InterfaceType("Name")]` / `[UnionType("Name")]` on a marker interface implemented by the CLR types that compose it — no custom `ResolveType` delegate needed, resolution is inferred from the runtime type. See SKILL.md's Interfaces & unions section for the code pattern.

---

## Fragments

Fragments are the core mechanism that makes component-oriented client code possible.

- **Problem solved**: a fragment lets a UI component declare its own data requirements as a named, reusable selection set, instead of threading the requirement top-down through a page query and prop-drilling it to descendants.
- **Colocation pattern**: popularized by Relay, now standard in Apollo Client / urql — each component ships its fragment alongside its code; a compiler/codegen step composes fragments into the actual network query. The component stays decoupled from its parent's query; data-need changes stay local to the component.
- **Fragment/data masking**: Relay enforces by construction that a component can only read fields it declared, via `useFragment` as the sole access point, even though the full response is fetched over the wire. Apollo Client added this as opt-in in v3.12, building on GraphQL Codegen's client-preset masking types — **the two masking systems are incompatible**; teams pick one (Apollo's own `useFragment` + `@unmask` escape hatch is the current recommended path over Codegen masking).
- **Named vs inline**: named fragments are what colocation/masking target; inline fragments (`... on X`) are for interface/union type-narrowing and aren't typically colocated with components.
- **Gotchas**: fragment cycles are spec-invalid (`no-fragment-cycles`); overlapping fields spread from multiple fragments must resolve to equivalent field+args (`overlapping fields can be merged` rule) — commonly violated when two fragments select the same field with different arguments.

**Schema stays agnostic** — nothing in SDL changes to "support" fragments; it's purely client-side query composition. But schema choices make colocation practical: small focused types rather than 80-field god-types, the Node interface for stable cache identity, and consistent field naming across contexts (the same concept shouldn't be spelled differently in different types — that breaks fragment reuse).

**In HotChocolate**: `__typename` resolution is automatic, no config needed. The main server-side lever is the interface-vs-union choice above, made once at schema-design time.

---

## Layered performance defenses

Depth limiting (reject queries past max nesting) + cost/complexity analysis (per-field weighted cost budget) + persisted queries/trusted documents (pre-registered query allowlist by hash — viable for first-party clients only, not public APIs) + DataLoader (per-request batching + memoization, request-scoped, nothing leaks across requests). These compose — none is a substitute for the others. Connection-spec pagination with an enforced max page size doubles as a cost-limiting mechanism.

**In HotChocolate**: all four are first-class and mostly on by default — see SKILL.md's Production hardening section for the specific knobs (`MaxFieldCost`/`MaxTypeCost`, `AddMaxExecutionDepthRule`, persisted operations, `ModifyPagingOptions`).

---

## Modularity & governance at scale

Federation beat schema stitching because stitching is a runtime/gateway concern (imperative, redeploy-the-gateway-to-change-anything) while federation is declarative and composes at build time. Netflix runs 70+ subgraphs organized by domain ownership, with a schema working-group for governance and `@deprecated`/`@experimental` tags for lifecycle — evidence that federation solves technical modularity, but org-level governance (naming collisions, duplicate concepts, god-types) still needs a human review process on top. Tooling doesn't replace governance.

**In HotChocolate**: Fusion is the federation layer — see `references/fusion.md`. Within a single service, the same governance need applies to cross-feature `[ObjectType<T>]` extensions (SKILL.md's Cross-feature type extensions section); a schema working-group habit scales just as well to feature-folder ownership as to subgraph ownership.
