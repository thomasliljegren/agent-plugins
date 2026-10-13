# Writing an adapter

An adapter is a directory with four executables, `state`, `claim`, `release` and `setup`, and a fifth where its backend can answer it, `overlap`. `.roadmap.json` names it in `backend`: a name under the plugin's `adapters/`, or a path (absolute, or relative to the repository) to a team's own.

Each command receives:

| Variable | Holds |
| --- | --- |
| `ROADMAP_ROOT` | the repository root |
| `ROADMAP_BRANCH` | the current branch, empty when detached |
| `ROADMAP_CONFIG` | the adapter's section of `.roadmap.json` as JSON (`{}` when it has none); the section is named after the adapter's directory |
| `ROADMAP_NOW` | the time of the run, in epoch seconds |

## `state`

Prints one JSON document on stdout and exits 0. `scripts/contract.jq` checks a document: `jq -r -f scripts/contract.jq state.json` prints nothing when it holds.

```json
{
  "project": "example/enzure",
  "backend": "github",
  "defaultBranch": "main",
  "initiatives": [
    { "id": "#35", "title": "Accounts", "total": 5, "read": 5, "claims": [], "blockedBy": [],
      "slices": [
        { "id": "#168", "title": "Provision a tenant database", "state": "open", "claims": ["PR #180"],
          "blockedBy": [ { "id": "#140", "claims": [] } ],
          "notes": [ { "text": "unlabelled", "fix": "gh issue edit N --add-label slice" } ] }
      ] }
  ],
  "moreInitiatives": 0,
  "other": [
    { "kind": "bug", "heading": "Bugs", "noun": "Bug", "open": 2, "list": "gh issue list --label bug",
      "items": [ { "id": "#134", "title": "A flaky test", "claims": [], "blockedBy": [] } ] },
    { "kind": "decision", "heading": "Decisions for the owner", "noun": "Decision", "open": 1, "list": "gh issue list --label decision",
      "items": [ { "id": "#140", "title": "Which region hosts a tenant", "blocks": ["#168"] } ] },
    { "kind": "enhancement", "heading": "Enhancements", "noun": "Enhancement", "open": 4, "list": "gh issue list --label enhancement", "items": [] },
    { "kind": "debt", "heading": "Debt", "noun": "Debt", "open": 22, "list": "gh issue list --label debt", "items": [] }
  ],
  "claimsHeading": "Open pull requests",
  "claims": [
    { "id": "PR #204", "ref": "feat/177-failed-readings", "tentative": false, "idleHours": 0, "started": null, "items": ["#177"], "note": null, "fix": null }
  ],
  "here": { "branch": "feat/170-link-insurer", "state": "unclaimed", "claim": null, "tentative": false, "items": [],
            "hint": "no pull request. Propose the session's workload and claim it before working: the roadmap skill." }
}
```

- **Ids** are display strings; only the adapter interprets them. `claim` and `release` accept them as printed and in the bare form a person would type (`170` for `#170`).
- **Never truncate silently.** `total` is how many slices the initiative has and `read` how many are in `slices`; `moreInitiatives` counts initiatives left out; an `other` entry's `open` against the length of its `items` says the same for that list. The renderer prints what was left out.
- **A slice's `state`** is `open`, `done` or `dropped`. Its `claims` are the ids of the claims on it.
- **A slice's `notes`** are remarks the renderer prints as given. A note without a `fix` is counted on the initiative's progress line (`1 closed by hand, not by a merged PR`). A note with a `fix` gets a line that lists the slices that carry it, with the fix (`unlabelled: #13, #16 (gh issue edit N --add-label slice)`).
- **`blockedBy`**, on an initiative, a slice and an item of other work, lists the items it waits for that are still open, each with its `id` and the ids of the claims on it. A blocker that has closed is left out. It is `[]` when nothing blocks; the renderer keeps a blocked slice out of `next`. An adapter that knows an item is blocked and did not read by what puts that in the id's place (`2 not read`), never `[]`.
- **`other`** is printed in the order given: `bug`, `decision`, `enhancement`, `debt`. `noun` names one item and heads the first column of the entry's table. An entry with `items` is printed as a table, and what `open` exceeds them by as "more", with the `list` command; one with no `items` is printed as its count.
- **An item of the `decision` entry** carries `blocks`, the ids of the open items that wait for it, and neither `claims` nor `blockedBy`.
- **A claim** is `tentative` while its backend marks it as not yet up for review. `idleHours` is how long it has stood still; the renderer calls it stale after the hours the project names in `staleAfterHours`, 168 where it names none. `started` is `false` where the adapter knows nothing was added since the claim was made, `true` where it knows something was and `null` where it did not ask. `items` are the ids it claims; when it claims none, `note` says why and `fix` what to do about it, in the backend's words (`fix` is null when there is nothing to do).
- **`here`** is the checkout's own branch. `state` is one of `default-branch`, `detached`, `unclaimed`, `claimed`, `merged`, `closed`, `unlinked`, `unknown`. For `claimed`, `claim`, `tentative` and `items` (each with `id`, `title` and `show`, a command that shows the item) are printed. For every other state the renderer prints the branch and then `hint`, the adapter's sentence on what the branch is and what to do about it.
- **Clean every title, branch name and note** before printing it: control characters become spaces and the text is cut at 120 characters. This text is written by whoever can open an issue and reaches every session. The renderer cleans it again.

When `state` cannot answer it prints one line, `ROADMAP UNAVAILABLE: <reason>. Do not assume project status.`, and exits 0. It has five seconds; on `TERM` it stops what it started.

## `claim`, `release`, `setup`

- `claim <ids...> [options]` makes the claim and prints what it made. `release <ids...>` withdraws it. Both exit non-zero with a one-line reason when they could not, and both are safe to repeat: a claim that stopped partway is finished by the same command.
- A claim must be atomic where the backend does not derive it: two sessions that claim the same item at once must not both succeed. Where the backend does derive it, `claim` looks once more after it made the claim: the one made first stands, and the other withdraws its own and fails. A repeated claim withdraws nothing; it names the other claims on its items.
- `overlap [paths...]` prints the claims that change what this checkout changes, or the paths named, and changes nothing. It is asked for and is no part of `state`, so it is not held to five seconds. An adapter without it leaves `roadmap overlap` to fail with one line.
- `setup [--yes]` prepares the backend and the repository, asking before each change. It adds and never removes, and it leaves what the project already decided.

## Tests

Check an adapter's `state` output with `scripts/contract.jq`, and render it with `scripts/render.jq` against the expected text in `tests/testdata`: those fixtures are backend-neutral.
