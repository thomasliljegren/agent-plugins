# Lenses

A lens is the point of view a designer argues from. Pass the lens brief verbatim into the designer
prompt. Lenses keep designers from converging on the same answer for the same reasons.

A lens may repeat across slots, for example `lenses=pragmatist,pragmatist,operations-runtime`. Each
slot keeps its own model, so a repeated lens shows how models differ under the same brief.

## Defaults (used when `lenses=` is not given)

### `pragmatist`
The simplest thing that works today for a small team. Fewest moving parts, least new tooling, least
maintenance. Distrusts speculative generality and machinery that guards against problems nobody has
seen yet.

### `domain-architecture`
Fit with the target repo's architecture and decisions: module boundaries, messaging rules, data
ownership, and the decided ADRs. Take the specifics from the repo's own agent instructions
(`AGENTS.md`, `CLAUDE.md`), architecture docs and decision records.

### `operations-runtime`
What happens when it runs for real: failure modes, retries, idempotency, observability, cost,
deployment and rollback, and the day-to-day experience of the people operating it.

## Optional menu

Add one of these at invoke time (`lenses=pragmatist,domain-architecture,security`) or at the
checkpoint when the problem calls for it.

### `security`
Trust boundaries, authentication and authorization, secrets handling, input validation, and what an
attacker or a careless caller could do.

### `graphql-api`
The contract consumers see: schema shape, naming, nullability, breaking-change risk, pagination,
and how the API evolves without breaking clients.

### `data-migration`
Data model, migrations on live data, backfills, consistency across stores, and how existing data
reaches the new shape without downtime.

### `delivery-testability`
How it gets built and proven: slicing into shippable steps, test strategy at each level, feature
flags, and how a reviewer can tell it works.

## Free-text lenses

Any lens value that is not a name above is used as-is as the lens brief, for example
`lenses=pragmatist,"the warehouse operator on night shift"`. Show it at the checkpoint as
"free-text lens".
