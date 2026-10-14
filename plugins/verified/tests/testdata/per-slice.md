# Verified facts

What was checked against a framework, with the evidence. A new section per slice.

## Slice #2 findings

- **A blind `Events.Append` leaves `IEvent.Version` at 0 under an Inline projection.** Seed with `StartStream`. Re-run: `ProbeStreamTests.A_note_appends_to_the_stream_and_the_view_follows`.
- **An idle queue is polled every five seconds.** Six round trips took 205 to 306 ms with `PollingInterval(250 ms)`.
- **The shell hook rewrites `diff` through `rtk`.** Compare files with `cmp`.
- **`Verify.Xunit` snapshots need `UseDirectory`.** The package is no longer referenced.

## Slice #3 findings

| Item | What was checked | Outcome |
| --- | --- | --- |
| `UseNpgsqlDataSource()` | Exists only on the main store (SUPERSEDED: see the next row) | Fallback: `AddMartenStore<T>` |
| `UseNpgsqlDataSource()` on ancillary stores | Reflection, Marten 9.45.0 | Fallback: `AddMartenStore<T>(Func<IServiceProvider, StoreOptions>)` with `options.Connection(dataSource)` |

- **A `[GlobalState(key)]` parameter without a default fails its field.** Evidence: commit f2def5f.
- **The source let a replacement keep a behavior whose target it deleted.** Evidence: `LayoutImportTests.A_replacement_cannot_keep_a_behavior_whose_target_it_deletes`.
- **The catalogue's domain tests were written after the code they test.** The tests passed on first run.
- **Not verified in this slice:** two imports that overlap.

## Slice #17 findings

- **`IEvent.Timestamp` differs below the microsecond on Linux.** CI run 38554143162 failed; `PgTimestamp.Encode` divides the ticks by ten. The generated code:

```csharp
await using var documentSession = outboxedSessionFactory.OpenSession(context);
```

- **`$type` discriminators need `AllowOutOfOrderMetadataProperties`.**
- **A filter for `*ProbeStreamTests` ran zero tests.**
