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
