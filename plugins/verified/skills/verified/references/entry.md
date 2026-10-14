# The entry, worked

Read with `SKILL.md`. Each example is one bullet under its topic.

## Pinned by a test

```markdown
- **An idle PostgreSQL queue is polled every five seconds unless its listener says otherwise.** Set `PollingInterval(250 ms)` on every listener. Evidence: `QueueTransportTests.Both_queues_are_polled_at_the_transport_interval` reads the interval off the running endpoints; six round trips took 4.9 to 5.1 s with the default and 205 to 306 ms with 250 ms (spike, 2026-10-13). [slice #3]
```

The claim says what a reader would get wrong. What to do follows, because the claim alone does not say it. The evidence names the test and what it observed, then what only the spike measured, marked as such.

## Seen, not pinned

```markdown
- **`AddGlobalObjectIdentification()` with no Node type fails schema construction.** A host needs a module with a `Node` type before it starts. Evidence: the host failed to start in a scratch application, HotChocolate 16.6.7, 2026-10-13; no test pins it, since no composition here lacks a Node type. [slice #2]
```

Where no test can pin a fact, the evidence says where and when it was seen, and why no test pins it.

## A fallback

```markdown
- **`UseNpgsqlDataSource()` exists only on the main store.** An ancillary store is `AddMartenStore<T>(Func<IServiceProvider, StoreOptions>)` with `options.Connection(dataSource)`. Evidence: reflection on Marten 9.45.0; `ProbeCompositionTests`. [slice #2]
```

What to do is the fallback taken: what is used instead of what did not hold.

## Corrected

```markdown
- **A document that only an Inline `EventProjection` stores is declared by the projection.** JFXEVT006 makes the projection `partial`; its indexes still need `Schema.For<T>()`. Evidence: `TransportsStoreTests` found `transports.mt_doc_transportjournalline` declared with `Schema.For` removed. [slice #3, corrected slice #17]
```

The entry says what is true now. What it said before is in git; the source names the slice that corrected it.

## A table row

A file that kept its facts in tables, `Item | What was checked | Source | Outcome / fallback`, under the heading `## Verify items`:

```markdown
| `.UseNpgsqlDataSource()` on shared ancillary stores | Exists only on the main store's `MartenConfigurationExpression` | Reflection, Marten 9.45.0 | Fallback: `AddMartenStore<T>(Func<IServiceProvider, StoreOptions>)` |
```

becomes

```markdown
- **`.UseNpgsqlDataSource()` exists only on the main store's `MartenConfigurationExpression`, not on shared ancillary stores.** Fallback: `AddMartenStore<T>(Func<IServiceProvider, StoreOptions>)`. Evidence: reflection, Marten 9.45.0. [verify items]
```

- The item and what was checked make the claim. An outcome of "Confirmed" or "As spec" means the claim holds as checked: the row is a fact like any other.
- The outcome or fallback is what to do.
- The "Source" column is evidence, never the bracketed source: it says how the fact was checked, not where in the work it was found. A table whose columns are named otherwise (`What | How | Evidence | Result`) maps the same way: what and how make the claim, evidence and result the evidence.
- The bracketed source comes from the heading: a slice, a task, a spec, an issue or a dated spike, as the heading names them (`## Walkthrough (Task 10)` → `[task 10]`, `## Review minors of the ops area (issues 53, 59)` → `[issues 53, 59]`). A heading that names no slice, task, spec, issue or date gives its own words, lowercased, up to any colon: `## Verify items` → `[verify items]`.
- A cell that names its own provenance, "(Task 6)" or "(final review)", gives the source instead of the heading, and that text leaves the claim.
- A table cell's escaped bar (`\|`) is a plain `|` in the bullet.
