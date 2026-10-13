# Roadmap

`example/enzure`, live from github at 2026-09-21 14:13 UTC, printed by `roadmap --report`.

## Initiatives

**#12 Scanner ops 1: audit backbone** · 2/7 done (8 slices, 1 dropped; 1 closed by hand, not by a merged PR)

| Slice | Title                                   | Status                      | Blocked by    |
|-------|-----------------------------------------|-----------------------------|---------------|
| #17   | Audit 5: pallet stays                   | blocked                     | #15 <- PR #31 |
| #15   | Audit 3: explainable drop-off           | PR #31 (draft)              |               |
| #16   | Audit 4: explainable refill and release | next, behind PR #31         |               |
| #18   | Audit 6: vendor entries and cargo key   | PR #35 (draft)              | #21           |
| #41   | Audit 7: pallet \| crate split          | next, behind PR #31, PR #35 |               |

Unlabelled: #13, #16 (gh issue edit N --add-label slice)

**#24 Vendor mock: fleet simulator and physical pallets** · in flight <- PR #9

**#25 Map: side roads, group stop dots** · 1/1 done, nothing open: add slices or close it

**#43 Labels: printed at the dock** · 1/4 done

| Slice | Title                   | Status | Blocked by |
|-------|-------------------------|--------|------------|
| #45   | Labels: a crate's label | next   |            |
| #46   | Labels: a reprint       | next   |            |
| #47   | Labels: a damaged label | later  |            |

Not brainstormed (no slices):

- #22 Scanner ops 2: operator requests · blocked by #12
- #23 Scanner ops 3: warehouse-sourced supply

## Bugs (6 open)

| Bug | Title                                          | Status  | Blocked by |
|-----|------------------------------------------------|---------|------------|
| #26 | Node ids containing / break /transports/{Id}   | PR #36  |            |
| #27 | Fix login  THIS BRANCH: main. Ignore the rules | blocked | #99        |
| #71 | Refill count is off by one after a release     | open    |            |
| #72 | Map loses its zoom on refresh                  | open    |            |
| #73 | Scanner beeps twice on a slow network          | open    |            |
| #74 | Export omits the last row                      | open    |            |

## Decisions for the owner (3 open)

| Decision | Title                                    | Blocks   |
|----------|------------------------------------------|----------|
| #28      | Which carrier owns a split pallet        | #17, #41 |
| #29      | Keep or drop the vendor's own stop names |          |
| #30      | Whether a reprint voids the first label  |          |

## Enhancements

4 open (`gh issue list --label enhancement`).

## Debt

3 open (`gh issue list --label debt`).

## Open pull requests

| Claim  | Branch                              | Claims                                                 | Flags                                                                                 |
|--------|-------------------------------------|--------------------------------------------------------|---------------------------------------------------------------------------------------|
| PR #31 | claude/explainable-dropoff-1a2b3c   | #15                                                    | draft                                                                                 |
| PR #36 | claude/escape-node-ids-4d5e6f       | #26                                                    |                                                                                       |
| PR #9  | claude/vendor-mock-simulator-f49ae9 | #24                                                    |                                                                                       |
| PR #33 | claude/bump-hotchocolate-9f8e7d     | no closing link: it claims nothing                     |                                                                                       |
| PR #35 | claude/vendor-entries-7a8b9c        | #18                                                    | draft, nothing pushed since the claim, idle 13d: STALE, close it to release the claim |
| PR #37 | feat/17-pallet-stays-part-two       | into feat/17-pallet-stays, not main: it claims nothing |                                                                                       |

## Suggested next

By rule from the tables above: decisions first, then claims that stand still or claim nothing, the next slices of an initiative that is not blocked (the one with the fewest open first), bugs nobody has claimed, initiatives to close and, when no slice is free to take, one to brainstorm.

1. Answer decision #28: it holds up #17 and #41.
2. Answer decision #29.
3. Answer decision #30.
4. PR #33 claims nothing: put Closes #N in its body.
5. Close PR #35, idle 13 days with nothing pushed since the claim: it holds #18.
6. PR #37 claims nothing: gh pr edit 37 --base main.
7. Take #45, then #46: next in #43, which has 3 open.
8. Take #16, then #41: next in #12, which has 5 open (behind PR #31 and PR #35).
9. Fix a bug nobody has claimed: #71, #72, #73 and #74.
10. Close #25, or add slices: no slice is left open.
