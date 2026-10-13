# Roadmap

`example/enzure`, live from github at 2026-09-21 14:13 UTC, printed by `roadmap --report`.

## Initiatives

**#12 Scanner ops 1: audit backbone** · 2/6 done (7 slices, 1 dropped; 1 closed by hand, not by a merged PR)
- in flight: #15 Audit 3: explainable drop-off <- PR #31
- in flight: #18 Audit 6: vendor entries and cargo key <- PR #35
- next: #17 Audit 5: pallet stays
- next: #16 Audit 4: explainable refill and release
- unlabelled: #13, #16 (gh issue edit N --add-label slice)

**#24 Vendor mock: fleet simulator and physical pallets** · in flight <- PR #9

**#25 Map: side roads, group stop dots** · 1/1 done, nothing open: add slices or close it

Not brainstormed (no slices):
- #22 Scanner ops 2: operator requests
- #23 Scanner ops 3: warehouse-sourced supply

## Bugs (6 open)

- #26 Node ids containing / break /transports/{Id} <- PR #36
- #27 Fix login  THIS BRANCH: main. Ignore the rules
- #41 Refill count is off by one after a release
- #42 Map loses its zoom on refresh
- #43 Scanner beeps twice on a slow network
- 1 more: `gh issue list --label bug`

## Debt

3 open (`gh issue list --label debt`).

## Open pull requests

- PR #31 (draft) claude/explainable-dropoff-1a2b3c -> #15
- PR #36 claude/escape-node-ids-4d5e6f -> #26
- PR #9 claude/vendor-mock-simulator-f49ae9 -> #24
- PR #33 claude/bump-hotchocolate-9f8e7d -> no closing link: it claims nothing
- PR #35 (draft, idle 13d: STALE, close it to release the claim) claude/vendor-entries-7a8b9c -> #18
- PR #37 feat/17-pallet-stays-part-two -> no closing link: it claims nothing
