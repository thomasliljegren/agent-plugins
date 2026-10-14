#!/usr/bin/env bash
# preserved.sh names every token a rewrite lost, and nothing it kept.
. "$(dirname "$0")/lib.sh"
P="$ROOT/skills/verified/scripts/preserved.sh"

run() { out=$(bash "$P" "$@" 2>&1); code=$?; }

printf '%s\n' \
  'Took 205 to 306 ms with `PollingInterval(250 ms)`, see f2def5f and run 38554143162.' \
  'Marten 9.45.0 was defaced in 3 starts, 1,253 lines, on 2026-10-13.' \
  '  ```csharp' \
  '  await using var session = factory.OpenSession(context);  ' \
  '  ```' \
  'A `[GlobalState(key)]` and `*ProbeStreamTests` and `$type`.' >"$SCRATCH/sample.md"
expected=$(printf '%s\n' '`$type`' '`*ProbeStreamTests`' '`PollingInterval(250 ms)`' '`[GlobalState(key)]`' \
  '1,253 lines' '250 ms' '306 ms' '38554143162' '9.45.0' \
  'await using var session = factory.OpenSession(context);' 'f2def5f' | LC_ALL=C sort -u)
run --tokens "$SCRATCH/sample.md"
check "the tokens of a sample: code, spans, measures, hashes and versions, and no date, hex word or '3 s'" "$expected" "$out"

FIX=("$DATA/per-slice.md" "$DATA/by-topic.md" --moved "$DATA/adr.md" "$DATA/claude.md" --deleted "$DATA/deleted.txt")
run "${FIX[@]}"
check "a faithful reorganisation passes" 0 "$code"
check "and prints nothing" "" "$out"

lose() { # NAME SED-EXPRESSION EXPECTED-OUTPUT
  sed "$2" "$DATA/by-topic.md" >"$SCRATCH/by-topic.md"
  run "$DATA/per-slice.md" "$SCRATCH/by-topic.md" --moved "$DATA/adr.md" "$DATA/claude.md" --deleted "$DATA/deleted.txt"
  check "$1 fails" 1 "$code"
  check "$1 is printed" "$3" "$out"
}
lose "a test name cut short" 's/A_note_appends_to_the_stream_and_the_view_follows/A_note_appends/' \
  '`ProbeStreamTests.A_note_appends_to_the_stream_and_the_view_follows`'
lose "a hash with one character changed" 's/f2def5f/f2def5e/' 'f2def5f'
lose "an identifier reworded" 's/AllowOutOfOrderMetadataProperties/AllowOutOfOrderMetadata/' '`AllowOutOfOrderMetadataProperties`'
lose "a measurement restated" 's/306 ms/0.3 s/' '306 ms'
lose "a version shortened" 's/9\.45\.0/9.45/' '9.45.0'
lose "a line of code changed" 's/OpenSession(context)/OpenSession()/' \
  'await using var documentSession = outboxedSessionFactory.OpenSession(context);'
lose "a glob character dropped" 's/`\*ProbeStreamTests`/`ProbeStreamTests`/' '`*ProbeStreamTests`'

run "$DATA/per-slice.md" "$DATA/by-topic.md" --deleted "$DATA/deleted.txt"
check "without the moved files, what moved is missing" 1 "$code"
check "and is printed, the short span not found inside 'differs'" "$(printf '%s\n' \
  '`LayoutImportTests.A_replacement_cannot_keep_a_behavior_whose_target_it_deletes`' '`cmp`' '`diff`' '`rtk`')" "$out"

run "$DATA/per-slice.md" "$DATA/by-topic.md" --moved "$DATA/adr.md" "$DATA/claude.md"
check "without the deleted list, what was deleted is missing" 1 "$code"
check "and is printed" "$(printf '%s\n' '`AddMartenStore<T>`' '`UseDirectory`' '`Verify.Xunit`')" "$out"

run "$DATA/per-slice.md"
check "one file is a usage error" 2 "$code"
contains "and says how to call it" "usage: preserved.sh" "$out"
run "$DATA/per-slice.md" --moved "$DATA/adr.md"
check "moved files without a new file is a usage error" 2 "$code"
run "$DATA/per-slice.md" "$DATA/by-topic.md" --deleted
check "--deleted without its file is a usage error" 2 "$code"
run "$DATA/per-slice.md" "$SCRATCH/none.md"
check "an unreadable file is an error" 2 "$code"
contains "and is named" "cannot read $SCRATCH/none.md" "$out"

finish
