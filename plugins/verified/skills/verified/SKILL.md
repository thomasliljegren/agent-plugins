---
name: verified
description: Where and how a project records what was checked against a framework, library, tool or platform it depends on, with the evidence and every fallback taken (VERIFIED.md, or verified/ once it splits). Use before recording a finding about a dependency, after checking a framework API before using it, when writing, moving or correcting an entry in VERIFIED.md or verified/, when deciding whether something belongs there, and when asked where a framework fact is recorded.
---

# Verified: what was checked against a framework

A project keeps what it checked against the frameworks, libraries, tools and platforms it depends on in `VERIFIED.md` at its root: each fact with its evidence, and every fallback taken when something did not hold. The file is ordered by topic, so everything known about one area of a framework is under one heading and a new fact has one place to go.

## What belongs

A fact about a dependency, checked: how an API behaves, what a default is, what failed and what was done instead. The project's own behaviour does not belong; that is its code, its tests, its ADRs and its specs.

## Where the rest goes

| An entry that says | goes to |
| --- | --- |
| how the system differs on purpose from what it replaces or ports | the spec or ADR of the area |
| how the work went wrong (a test written after its code, a step skipped) | the project's findings practice where it has one (the `roadmap` plugin's `findings`); otherwise nowhere, git keeps it |
| a quirk of a machine, a shell or a tool's environment | the `CLAUDE.md` of the area, or the root's |
| what was not verified | the spec as open scope, or the tracker |

Destinations the project's `CLAUDE.md` names win. A document the project treats as frozen, such as a spec or a plan whose branch has merged, is never a destination: the area's ADR or `CLAUDE.md` takes the entry instead.

## The file

It opens with one paragraph saying what it is and that this skill keeps it, then an index with one line per topic. Then the topics, each a `##` heading named after what was checked: `## Marten: events and projections`, `## Wolverine: PostgreSQL transport`, `## Tooling`. A heading is never a slice, a task, a spec or a date.

## The entry

```markdown
- **A blind `Events.Append` leaves `IEvent.Version` at 0 under an Inline projection.** Seed with `StartStream` or `FetchForWriting`. Evidence: `ProbeStreamTests.A_note_appends_to_the_stream_and_the_view_follows` (version 3 after one start and two notes). [slice #2]
```

Four parts, in this order:

1. **The claim**: one bold sentence that reads on its own. A pitfall list or a wiki quotes it without its context.
2. **What to do**, when the claim does not make it obvious.
3. **The evidence**: the test that pins it and what it observed; where no test can, where it was seen (a spike, a reflection call, a release note, a documentation page) and when.
4. **The source**, in brackets at the end: `[slice #17]`, `[spec 006, task 4]`, `[spike 2026-10-02]`.

Identifiers, test names, commit hashes, versions, numbers, error messages and code stay exactly as observed. `references/entry.md` has worked examples.

## Keeping it true

- A new entry goes under its topic, never at the end of the file. A new topic gets its line in the index.
- A fact that stops holding is corrected in place, in the commit that finds out, and its source names the correction: `[slice #3, corrected slice #17]`. Nothing is marked superseded and kept.
- An entry about a dependency the project no longer has is deleted.
- Two entries that say one thing become one, with the evidence of both.
- Where the project keeps a pitfall list (a "Known pitfalls" section in `CLAUDE.md`), the warning goes there and its evidence here, both in one commit.

## Splitting

Past 400 lines the file becomes a folder: `verified/<topic>.md`, one file per topic, each opening with its heading. `VERIFIED.md` stays as the opening paragraph and the index, each line now a link to its file, so a reference to `VERIFIED.md` from code or a document still lands where the reader can follow the topic. A topic file past 400 lines splits by sub-area: `verified/marten-events.md`, `verified/marten-documents.md`.

## Reorganising a file

A file grown another way (a section per slice, per task or per date; a table; superseded rows) is brought into this shape by `references/reorganize.md`: inventory, classify, propose and wait for the owner's yes, then write, and run `scripts/preserved.sh` to prove no identifier, hash, version, measurement or line of code was lost. In Claude Code, `/verified:reorganize` runs it.

## What the project keeps

The project's `CLAUDE.md` says to record what was checked against a framework in `VERIFIED.md`, by this skill, and holds what only the project knows: the documentation to query before writing an API, what publishes the file, and destinations the table above does not name.
