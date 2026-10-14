# Verified facts

What was checked against a framework, with the evidence, and every fallback taken, kept by the `verified` skill.

- [Marten: events and projections](#marten-events-and-projections)
- [Marten: stores](#marten-stores)
- [Wolverine: PostgreSQL transport](#wolverine-postgresql-transport)
- [HotChocolate: resolvers](#hotchocolate-resolvers)
- [Testing](#testing)

## Marten: events and projections

- **A blind `Events.Append` leaves `IEvent.Version` at 0 under an Inline projection.** Seed with `StartStream`. Evidence: `ProbeStreamTests.A_note_appends_to_the_stream_and_the_view_follows`. [slice #2]
- **`IEvent.Timestamp` differs below the microsecond on Linux.** `PgTimestamp.Encode` divides the ticks by ten. Evidence: CI run 38554143162 failed. The generated code: [slice #17]

  ```csharp
  await using var documentSession = outboxedSessionFactory.OpenSession(context);
  ```
- **`$type` discriminators need `AllowOutOfOrderMetadataProperties`.** [slice #17]

## Marten: stores

- **`UseNpgsqlDataSource()` exists only on the main store.** Fallback: `AddMartenStore<T>(Func<IServiceProvider, StoreOptions>)` with `options.Connection(dataSource)`. Evidence: reflection, Marten 9.45.0. [slice #3]

## Wolverine: PostgreSQL transport

- **An idle queue is polled every five seconds.** Evidence: six round trips took 205 to 306 ms with `PollingInterval(250 ms)`. [slice #2]

## HotChocolate: resolvers

- **A `[GlobalState(key)]` parameter without a default fails its field.** Evidence: commit f2def5f. [slice #3]

## Testing

- **A filter for `*ProbeStreamTests` ran zero tests.** [slice #17]
