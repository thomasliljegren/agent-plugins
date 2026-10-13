# Roadmap plugin: blockers, decisions, what to take next, and practices a project composes

Date: 2026-10-13

## Purpose

`docs/superpowers/specs/2026-10-04-roadmap-plugin-design.md` made Enzure's roadmap installable, from Enzure as it was that day. Enzure has moved on in the nine days since, and the plugin has not merged. This spec brings the plugin level with Enzure's `scripts/roadmap.sh` and `CLAUDE.md` (Working here) as they are on its `main` today, and changes the same branch and pull request.

Four things are new in Enzure:

- An issue that waits for another says so with the tracker's blocked-by relation, and the roadmap keeps it out of `next`.
- Other work has two more kinds: a `decision`, which only the owner can answer, and an `enhancement`.
- The snapshot and the report print tables, and the report ends with `Suggested next`, worked out by rule.
- The rules grew: a finding is fixed, filed or dropped; what ready means; stacked units and a slice that does not fit a session; agents merging their own work once the checks pass.

The first three are the roadmap itself and every project gets them. The rules in the fourth are how one team chose to work, so they become **practices**: pages a project names in `.roadmap.json`.

Enzure's roadmap pane, and the `--json` and `--board` formats and `board.jq` that feed it, are left out. `roadmap --state` stays as the JSON a tool reads.

Success is unchanged from the first spec: Enzure deletes its own copy, installs the plugin, and its sessions start with the same snapshot as before.

## Vocabulary

Added to the first spec's:

- **Blocked**: an item that waits for another that is still open. The item it waits for is its **blocker**.
- **Next** now also leaves out what is blocked: the first open slices of an initiative, in its order, that nobody has claimed and nothing blocks.
- **Other work** has four kinds: `bug`, `decision`, `enhancement`, `debt`. A **decision** is a question only the owner can answer; it blocks what waits for it.
- **Practice**: a named set of rules a project opts into.

## Practices

`.roadmap.json` gains `practices`, a list of names:

```json
{
  "backend": "github",
  "rules": "CLAUDE.md",
  "practices": ["findings", "ready", "stacking", "merge"]
}
```

Each name is a page, `skills/roadmap/practices/<name>.md`:

| Practice | Rules | Besides the page |
| --- | --- | --- |
| `findings` | What is found on the way is fixed, filed or dropped, and what each kind of other work must name before it is filed. Search before filing. A decision is filed as the question and its options, blocks what waits for it, and closes when the owner answers. | nothing |
| `ready` | What must hold before work is marked ready: the project's checks pass locally; a reviewer that did not write the change has read the whole of it as it stands at the last commit, and every finding is fixed, filed or dropped; the description says what changed, how it was tested and that the review ran; the claim shows exactly the items claimed. | nothing |
| `stacking` | A unit that builds on an earlier one of the same session, and how the stack follows the default branch. A slice that does not fit a session: release what was not started, file the rest in its place in the order. | nothing |
| `merge` | The session that claimed a unit merges it once it is ready and its required checks pass, and only that unit. It stops merging on its own as soon as it changes the unit again. Rewriting shared history and merging past a failed check stay with the owner. | `setup` adds the permissions to merge |

- **Without the key** a project has `findings`, `ready` and `stacking`. `merge` is asked for by name, because it changes who merges. `"practices": []` is a project with none.
- **The snapshot names them** on its second line: `Practices here: findings, ready, stacking (pages of the roadmap skill).` A project with none gets no such sentence. A name with no page is printed after the others as `unknown: <name>`, so a misspelt practice is seen and not silently dropped.
- **The pages are backend-neutral**, like `SKILL.md`. What a practice needs that is true only of GitHub (the commands, and the pitfalls Enzure recorded: a draft's skipped check counts as passed; a pull request in conflict gets no run; auto-merge turned off and on again can stay on and not merge) goes in `references/github.md`, one section per practice.
- **`SKILL.md` stays the core.** Its rule on autonomy becomes: commit, push and mark ready without asking; merging stays with the owner unless the project's practices include `merge`. Its rule on filing names the four kinds and leaves the bar for each to `findings`. It tells the agent to read the page of each practice the snapshot names before the work that practice governs.
- What is the project's own (which documents change with the code, what its checks are, a merge method other than squash) stays in the project's `rules` file.

Practices are not a plug-in point: the names are the pages the plugin ships. A project's own rules already have a place.

## The adapter contract

Additions to the state document. `scripts/contract.jq` and `references/adapter-contract.md` follow.

```json
{
  "initiatives": [
    { "id": "#12", "title": "…", "total": 8, "read": 8, "claims": [],
      "blockedBy": [],
      "slices": [
        { "id": "#17", "title": "…", "state": "open", "claims": [], "notes": [],
          "blockedBy": [ { "id": "#15", "claims": ["PR #31"] } ] }
      ] }
  ],
  "other": [
    { "kind": "bug", "heading": "Bugs", "noun": "Bug", "open": 3, "list": "gh issue list --label bug",
      "items": [ { "id": "#27", "title": "…", "claims": [], "blockedBy": [ { "id": "#99", "claims": [] } ] } ] },
    { "kind": "decision", "heading": "Decisions for the owner", "noun": "Decision", "open": 3, "list": "gh issue list --label decision",
      "items": [ { "id": "#28", "title": "…", "blocks": ["#17", "#41"] } ] },
    { "kind": "enhancement", "heading": "Enhancements", "noun": "Enhancement", "open": 4, "list": "gh issue list --label enhancement", "items": [] },
    { "kind": "debt", "heading": "Debt", "noun": "Debt", "open": 3, "list": "gh issue list --label debt", "items": [] }
  ],
  "claims": [
    { "id": "PR #33", "ref": "claude/bump-hotchocolate-9f8e7d", "tentative": false, "idleDays": 0, "items": [],
      "note": "no closing link: it claims nothing", "fix": "put Closes #N in its body" }
  ]
}
```

- **`blockedBy`** on an initiative, a slice and a bug item: the blockers that are still open, each with its `id` and the ids of the claims on it. A blocker that has closed is not listed. Required, and empty when nothing blocks.
- **`other`** is printed in the order given. An entry gains `noun`, the name of one item, which heads the first column of its table. An item of the `decision` entry carries `blocks`, the ids of the open items that wait for it, in place of `claims` and `blockedBy`.
- **A claim gains `fix`**, a string or null: what to do about a claim that claims nothing, in the backend's words. The renderer uses it in `Suggested next`.

## The renderer

`render.jq` takes over the layout and the rules of Enzure's `scripts/roadmap.jq`, without that file's `json` format. It still knows nothing about any backend.

**Status.** An open slice, or a listed bug, has one status: the claims on it (`PR #31 (draft)`, the word `draft` when the claim with that id is tentative), else `blocked`, else `next` for the first two slices of the initiative that are neither, else `later` (a bug: `open`).

**Tables.** A table is rows of strings, printed in aligned columns in the snapshot and as a Markdown table in the report; a `|` in a cell is escaped there.

| Table | Columns |
| --- | --- |
| An initiative's slices | Slice, Title, Status, Blocked by |
| Bugs | the entry's `noun`, Title, Status, Blocked by |
| Decisions | the entry's `noun`, Title, Blocks |
| Claims | Claim, Branch, Claims, Flags |

A blocker is printed with its claims: `#15 <- PR #31`. An initiative that is blocked says so after its progress (`; blocked by #12`), and so does one that is not brainstormed. The snapshot lists an initiative's open slices that are claimed, blocked or `next`; the report lists every open slice. A slice note with a `fix` keeps its own line under the table.

**`Suggested next`** ends the report. Every line follows from a rule over the same state, in this order:

1. each decision listed: `Answer decision #28: it holds up #17 and #41.`
2. each claim, when it is stale: `Pick up or close PR #35, idle 13 days: it holds #18.`; else when it claims nothing: `PR #33 claims nothing: put Closes #N in its body.`
3. each initiative that is not blocked and has a `next`, the one with the fewest open slices first: `Take #45, then #46: next in #43, which has 3 open.`
4. bugs: `Fix a bug nobody has claimed: #41 and #42 (1 more not read).`, the listed bugs that are neither claimed nor blocked
5. `Close #25, or add slices: no slice is left open.`, for the initiatives whose slices were all read and are all done
6. when no initiative has a slice free to take: `Brainstorm an initiative, since no slice is free to take: #23.`, the unplanned initiatives that are not blocked

It names candidates and claims nothing. With no line at all it says that nothing waits for anyone.

**Wording.** Enzure's text is kept except where it names GitHub or Enzure's files, as in the first spec. New in this round:

- the legend: `next = first open slices in order that nobody has claimed and nothing blocks`
- the claims table is headed Claim, Branch, Claims, Flags, where Enzure's says PR, Branch, Closes, Flags; a claim with no items prints its `note`
- `Fix a bug nobody has claimed`, where Enzure's says `no pull request has taken`
- the line for a claim that claims nothing is built from the claim's `fix`
- the sentence that introduces `Suggested next` says claims where Enzure's says pull requests

`render.jq` gains the argument `$practices`, the sentence for the second line, which the entry point writes.

## The GitHub adapter

Still REST only.

**`state`** asks in three rounds, each at once:

1. as before, and the open issues labelled `decision` and `enhancement`
2. the sub-issues of each initiative that has any, as before; the blockers of each initiative and bug whose `issue_dependencies_summary.blocked_by` is above zero (`…/issues/N/dependencies/blocked_by`); what each decision blocks, when its `blocking` is above zero (`…/issues/N/dependencies/blocking`)
3. the blockers of each open sub-issue whose `blocked_by` is above zero

Only an issue that has a blocker costs a request, and a project that uses no dependencies makes the same requests as before plus the two lists. One failed request still fails the answer.

**`normalize.jq`** keeps the blockers and the blocked issues that are open. A blocker's claims are the open pull requests whose body closes it, read with `closes.jq` like every other claim, so a blocker costs no request of its own. The bug list reads ten. A pull request that closes nothing gets `fix`: `put Closes #N in its body`. `need` guards `issue_dependencies_summary`: an answer without it fails loudly, as for every other member.

The config's labels gain `enhancement` and `decision`, each its own name by default.

**`setup`**:

- creates six labels: the four it had, `enhancement` and `decision`
- writes `practices` into the `.roadmap.json` it creates. It asks about each; `--yes` takes `findings`, `ready` and `stacking`; `--practices <a,b,…>` names them outright, and is how `merge` is chosen without a terminal. A file that is there already is left as it is and its practices are read from it.
- adds, when the project's practices include `merge`: allow `gh pr merge` and `gh run rerun`; ask on `gh pr merge` with `--admin`. As before, rules are added and never removed, and a command the project put under `deny` or `ask` stays there and is reported.

`claim`, `release`, `closes.jq` and the workflow template do not change.

**`references/github.md`** gains: how the two new kinds and the blocked-by relation map (`gh issue edit N --add-blocked-by M`, and `POST …/issues/N/dependencies/blocked_by` where GraphQL is refused); and a section for each of `ready`, `stacking`, `findings` and `merge` with the commands and the pitfalls named under Practices.

## The entry point and the commands

`bin/roadmap` reads `practices` (the three defaults without the key), checks each against the pages under `skills/roadmap/practices/`, and passes the sentence to `render.jq`. It has no new mode.

`/roadmap:report` is the view on demand, and now ends with `Suggested next`. `/roadmap:setup` asks which practices the project wants before it runs `roadmap setup --yes --practices …`.

## Tests

As in the first spec: golden files, no network, `--accept` after an intended change.

- **Fixtures.** `busy` and `leftover` are rebuilt from Enzure's fixtures as they are today, in REST's shape, and `drained` is added (a roadmap with nothing free to take, which is what reaches the brainstorm rule). `busy` keeps what the first round added to it: enough bugs to leave some unread, and a pull request into another branch, which claims nothing.
- **Renderer.** Each state document against its expected snapshot and report. The expected text is compared once with Enzure's `scripts/testdata/*.expected.txt` and `*.report.expected.md`: they differ in the wording named in the two specs and in the lines `busy`'s additions produce.
- **Adapter.** Blockers, a blocker's claims, decisions and what they block, the two new kinds, the `fix` of a claim that closes nothing; an answer without `issue_dependencies_summary` fails.
- **State.** The stand-in `gh` answers the two new lists and both dependency endpoints. Dependencies are asked only of issues whose summary counts one, and of no closed sub-issue.
- **Entry point.** The default practices, a named list, an empty list, an unknown name.
- **Setup.** Six labels; `practices` as asked for, interactively, with `--yes` and with `--practices`; the merge permissions only with `merge`; an existing `.roadmap.json` left alone.
- **Documents.** Every practice the plugin knows has its page; the pages are backend-neutral; `references/github.md` has a section for each; the contract page's example still holds the contract and renders.

## Verified

Checked on 2026-10-13 against `thomasliljegren/enzure`, with `gh api` over REST.

- **An issue carries `issue_dependencies_summary`**, in an issue list and in a parent's `sub_issues` alike: `blocked_by`, `blocking`, `total_blocked_by`, `total_blocking`. Issue 577, closed, whose one blocker has closed, answers `blocked_by: 0, total_blocked_by: 1`: the plain counts are of what is still open.
- **`GET …/issues/N/dependencies/blocked_by`** answers the blockers as issues with their `state` (578 answers 577, closed); **`…/dependencies/blocking`** answers what the issue blocks (577 answers 578).

Not checked: how long the third round takes against a project with many blocked slices. The live run under Verification in the plan measures it against Enzure; the limit stays five seconds.

## Not in scope

The roadmap pane and its `--json` and `--board` formats; a project's own practices; a merge method in the configuration; folding the title check into a project's own CI job, as Enzure did to save a billed minute; and everything the first spec left out. Enzure's switch to the plugin stays a pull request in that repository (its issue 209).
