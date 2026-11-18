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
Fit with the target repo's architecture and decisions: module boundaries, communication rules, data
ownership, and the decision records that apply. Take the specifics from the repo's own agent
instructions (`AGENTS.md`, `CLAUDE.md`) and architecture docs.

### `operations-runtime`
What happens when it runs for real: failure modes, retries, idempotency, observability, cost,
deployment and rollback, and the day-to-day experience of the people operating it.

## Optional menu

Add one of these at invoke time (`lenses=pragmatist,domain-architecture,security`) or at the
checkpoint when the problem calls for it.

### `security`
Trust boundaries, authentication and authorization, secrets handling, input validation, and what an
attacker or a careless caller could do.

### `api`
The contract callers see, whatever the transport (HTTP, RPC, events, a library's public surface, a
CLI): shape, naming, required and optional fields, errors, pagination, versioning, and how the
contract evolves without breaking callers.

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

## Lens fit

The defaults and the menu are a starting set, not a fit for every problem. Each time the
checkpoint is shown (SKILL.md, Checkpoint), rate each slot's lens against `framing.md`, however the
lens was chosen: a default, a defaults file, the invocation, or free text.

- Rate each lens `fits` or `weak`, with a one-line reason. For `fits`, name the R, SC or Q items
  in the framing the lens would argue about. For `weak`, name the items the framing turns on that
  the lens does not reach.
- Rate a repeated lens once and name its slots.
- For each `weak` lens, suggest 2–3 replacements. Each is a name from this file or a one-sentence
  free-text brief written for this problem. Prefer a free-text brief when no named lens covers
  what the framing turns on. A brief contains no double quote, comma or colon, so it survives the
  `lenses=` list and the approval line.
- End with one ready-to-paste line listing exactly N lenses in slot order: each fitting lens as it
  is, your top suggestion in each weak slot (the same one in every slot of a repeated lens), and
  every free-text brief in double quotes, for example
  `edit lenses=pragmatist,api,"the clerk who reconciles the ledger at month end"`.
- When every lens fits, say so in one line, with no suggestions.

Show the result at the checkpoint only. Never write it into `framing.md`: designers receive the
framing verbatim, and a note that their lens is weak would bias them. Never change a lens yourself;
only the user's `edit lenses=...` does. After any `edit`, rate the lenses again.
