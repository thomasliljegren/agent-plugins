# Practice: a finding is fixed, filed or dropped

Read with `SKILL.md`. This holds for a reviewer's finding and for anything else you find on the way.

## Fixed, filed or dropped

- **Fixed** on your branch, when your change made it and it is more than a nit or a preference: it is in the diff, or the diff made something else untrue (a document, a comment, a test's name). A change does not file its own defects. A fix too large for it means its item is not finished: the rest becomes that item's remaining work, a new slice in its place in the order.
- **Filed**, when your change did not make it and it clears the bar of its kind, below.
- **Dropped**, the rest, wherever it is: a nit (it changes nothing a reader or a user could get wrong), a preference, and what has not been seen happen and a reload, a retry, a rerun or the next change puts right. A dropped finding is one line under "Dropped" in the description of your change, with its reason, and nowhere else. A session with no change of its own says it in what it tells the owner.

## The bar of each kind

One item, one kind.

- **`bug`**: the system does something wrong. **`debt`**: what exists needs cleaning up, whether code, tests, tooling or a document that is wrong, duplicated or stale. A defect of either kind names a failure that has been seen happen, or one that stays: what someone does, what goes wrong, and that nothing short of a repair to data, code or a document puts it right. Cleanup that is no failure (duplication, a slow or misleading test) is `debt` when the item states what the next change there pays for it: two places to edit, a test that hides a failure, a measured time.
- **`enhancement`**: scope a design or an item names as left out or deferred, which no open item builds. When an initiative takes it, it becomes a slice.
- **`decision`**: a question only the owner can answer, which named work waits for. Write it as the question and its options, and mark what waits for it as blocked by it in the tracker, never only in words. It closes when the owner answers: the answer is a comment on the item, and the session that got the answer closes it. It is the one item closed by hand.

## Search before filing

What an open item already names is a comment there. What an open slice will build is a comment on that slice.

## Why there is a bar

Filing is cheaper than fixing for the session that files, and dearer for everyone after it. An item costs a session to read, fix, review and merge, and one that nobody would miss costs the same.
