# Practice: stacked units, and a slice that does not fit

Read with `SKILL.md`.

## A unit that builds on an earlier one

A unit that builds on an earlier one of the same session branches from that one's branch, and its description says which unit merges first. When the default branch moves, merge it into the lowest branch of the stack and then each branch into the next. Never rebase a pushed branch: rewriting shared history is the owner's.

A unit higher in the stack is not merged, and is not set to merge on its own, until the one below it has merged and the default branch is merged into it.

## A slice that does not fit a session

A session that finds it will not finish:

1. releases the slices it has not started, with `roadmap release <ids...>`;
2. files the rest of the slice it has started as a new slice of the same initiative, and moves it to its place in the order, straight after the one it continues;
3. finishes what it has, so that its unit closes what it still claims.

`next` is read from the order, so a slice left at the end is a wrong roadmap.
