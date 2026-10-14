# Reorganising a file of verified facts

Read with `SKILL.md`. This brings a file grown another way (a section per slice, per task or per date; tables; superseded rows; entries that are not framework facts) into the skill's shape. The input is `VERIFIED.md` unless the owner names another file, or an index with its `verified/` folder.

Work on the project's own branch for this change. Keep a copy of every file as it was, in one file: the check in phase 4 reads it. With the input split already, that is the index and each topic file: `for f in $(git ls-files VERIFIED.md 'verified/*.md'); do git show "HEAD:$f"; done > <scratch>/old.md` (with a file of another name, use its path). `git ls-files` lists what exists, so the loop runs in a shell that refuses a pattern matching nothing (zsh) too.

## 1. Inventory

Read the whole file. List every entry: a bullet, a table row, or a paragraph under a heading that makes one claim. Read each entry's source from the heading it sits under: `## Slice #3 findings` → `[slice #3]`, `## Spec 002, Task 4: Sources module` → `[spec 002, task 4]`, `## Spike results (2026-10-02)` → `[spike 2026-10-02]`. Count them; every one is accounted for in phase 3.

Then find what cites the file (`git grep -n VERIFIED.md`): code comments, `CLAUDE.md` pitfall lists, ADRs. Check that each fact they cite is in the file. A cited fact that is not is a finding for the proposal: the comment points at evidence nobody recorded.

## 2. Classify

Each entry is exactly one of:

- **A fact**, with the topic it goes under. Name topics after what was checked (`Marten: events and projections`), reusing the file's own vocabulary; aim for topics of five to forty entries.
- **A duplicate** of another entry: the two become one, with the evidence of both.
- **Superseded**, by which entry: the two become one corrected entry, its source naming both (`[spec 002, task 2, corrected task 6]`).
- **Obsolete**: its dependency is gone. Name the package reference, or the project file, whose absence shows it.
- **Elsewhere**: it goes to the destination the skill's table gives (a divergence to the spec or ADR of the area; a process slip to the findings practice or nowhere; an environment quirk to a `CLAUDE.md`; a gap to the spec or the tracker). A destination the project treats as frozen (a merged spec or plan) is replaced by the area's ADR or `CLAUDE.md`.

## 3. Propose, and stop

Show the owner:

- the topics, in order, with the number of entries under each;
- every entry that leaves or changes: each merge, supersession, deletion and move, with the entry's first words, its source and the reason;
- the documents outside the file that will change, and how;
- the line count of the result, and whether it passes 400 lines and so becomes `verified/<topic>.md` with `VERIFIED.md` as its index;
- the counts: entries in, facts kept, merged, deleted, moved, dropped. They add up to the inventory.

Then stop. Nothing is written before the owner says yes. A change the owner asks for is made to the proposal, which is shown again.

## 4. Write

1. Write the file, or the index and its folder, in the skill's shape: the opening paragraph, the index, the topics. Rewrite each fact as an entry (claim, what to do, evidence, source); a table row becomes a bullet, as `references/entry.md` shows, and a table cell's escaped bar (`\|`) becomes a plain `|` in it. Entries move, so an entry that points at another by position ("the same test", "the code above", "the finding above") names it instead. Carry identifiers, test names, commit hashes, versions, numbers, error messages and code across unchanged.
2. Write each move into its destination, in that document's own style. A move to a tracker follows the project's findings practice where it has one; otherwise list it for the owner and file nothing.
3. Find references to the old headings elsewhere in the repository (`grep -rn "Slice #4 findings"`, and the like for each old heading) and point them at the new topic, except in documents the project treats as frozen.
4. Write the tokens the approved proposal deletes to `<scratch>/deleted.txt`, one per line, as `scripts/preserved.sh --tokens <scratch>/old.md` prints them.
5. Collect what the moves added, and only that: a destination already repeats many tokens of the file (a pitfall list quotes its claims), and checking against the whole destination would hide a fact dropped by mistake.

   ```
   git diff -U0 HEAD -- <each destination changed> | grep '^+' | grep -v '^+++' | sed 's/^+//' > <scratch>/moved.md
   ```

6. Run the check:

   ```
   bash scripts/preserved.sh <scratch>/old.md VERIFIED.md [verified/*.md] --moved <scratch>/moved.md --deleted <scratch>/deleted.txt
   ```

   It prints each token of the old file found in none of them. Put each one back, or, when the approved proposal deleted it, add it to `deleted.txt`. Run it until it exits 0.
7. Run the project's own checks where the file is published or linked (a wiki build, a link check).
8. Commit once: the file, the destinations and the fixed references together.
