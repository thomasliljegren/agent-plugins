# Roadmap

`example/enzure`, live from github at 2026-09-21 14:13 UTC, printed by `roadmap --report`.

## Initiatives

**#50 Routes: the planner** · 1/1 done, nothing open: add slices or close it

**#52 Depots: opening hours** · 1/1 done, nothing open: add slices or close it

**#62 Customs: papers at the border** · 0/1 done · blocked by #54

| Slice | Title                  | Status | Blocked by |
|-------|------------------------|--------|------------|
| #63   | Customs: a declaration | next   |            |

**#64 Returns: a refused pallet** · 0/1 done

| Slice | Title                      | Status         | Blocked by |
|-------|----------------------------|----------------|------------|
| #65   | Returns: back to the depot | PR #66 (draft) |            |

**#67 Archive: last year's routes** · 1/1 done (60 slices, 0 dropped, only the first 1 read), nothing open: add slices or close it

Not brainstormed (no slices):

- #54 Invoices: per carrier
- #55 Invoices: credit notes · blocked by #54
- #56 Drivers: shifts

## Bugs (4 open)

| Bug | Title                     | Status         | Blocked by |
|-----|---------------------------|----------------|------------|
| #57 | A plan for a closed depot | open           |            |
| #58 | A route with no stops     | open           |            |
| #59 | A shift across midnight   | PR #66 (draft) |            |
| #69 | A depot with two names    | open           |            |

## Decisions for the owner

None open.

## Enhancements

None open.

## Debt

1 open (`gh issue list --label debt`).

## Open pull requests

| Claim  | Branch                            | Claims                             | Flags                                                 |
|--------|-----------------------------------|------------------------------------|-------------------------------------------------------|
| PR #66 | feat/65-returns-back-to-the-depot | #65, #59                           | draft, idle 11d: STALE, close it to release the claim |
| PR #60 | chore/bump-jq                     | no closing link: it claims nothing | draft, idle 20d: STALE, close it to release the claim |

## Suggested next

By rule from the tables above: decisions first, then claims that stand still or claim nothing, the next slices of an initiative that is not blocked (the one with the fewest open first), bugs nobody has claimed, initiatives to close and, when no slice is free to take, one to brainstorm.

1. Pick up or close PR #66, idle 11 days: it holds #65 and #59.
2. Pick up or close PR #60, idle 20 days: it claims nothing.
3. Fix a bug nobody has claimed: #57, #58 and #69.
4. Close #50 and #52, or add slices: no slice is left open.
5. Brainstorm an initiative, since no slice is free to take: #54 and #56.
