# Writing an adapter

An adapter is a directory with four executables: `state`, `claim`, `release` and `setup`. `.roadmap.json` names it in `backend`: a name under the plugin's `adapters/`, or a path (absolute, or relative to the repository) to a team's own.

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
    { "id": "#35", "title": "Accounts", "total": 5, "read": 5, "claims": [],
      "slices": [
        { "id": "#168", "title": "Provision a tenant database", "state": "open", "claims": ["PR #180"],
          "notes": [ { "text": "unlabelled", "fix": "gh issue edit N --add-label slice" } ] }
      ] }
  ],
  "moreInitiatives": 0,
  "other": [
    { "kind": "bug", "heading": "Bugs", "open": 2, "list": "gh issue list --label bug",
      "items": [ { "id": "#134", "title": "A flaky test", "claims": [] } ] },
    { "kind": "debt", "heading": "Debt", "open": 22, "list": "gh issue list --label debt", "items": [] }
  ],
  "claimsHeading": "Open pull requests",
  "claims": [
    { "id": "PR #204", "ref": "feat/177-failed-readings", "tentative": false, "idleDays": 0, "items": ["#177"], "note": null }
  ],
  "here": { "branch": "feat/170-link-insurer", "state": "unclaimed", "claim": null, "tentative": false, "items": [],
            "hint": "no pull request. Propose the session's workload and claim it before working: the roadmap skill." }
}
```

- **Ids** are display strings; only the adapter interprets them. `claim` and `release` accept them as printed and in the bare form a person would type (`170` for `#170`).
- **Never truncate silently.** `total` is how many slices the initiative has and `read` how many are in `slices`; `moreInitiatives` counts initiatives left out; an `other` entry's `open` against the length of its `items` says the same for that list. The renderer prints what was left out.
- **A slice's `state`** is `open`, `done` or `dropped`. Its `claims` are the ids of the claims on it.
- **A slice's `notes`** are remarks the renderer prints as given. A note without a `fix` is counted on the initiative's progress line (`1 closed by hand, not by a merged PR`). A note with a `fix` gets a line that lists the slices that carry it, with the fix (`unlabelled #13, #16 (gh issue edit N --add-label slice)`).
- **An `other` entry** with `items` is printed as a list, and what `open` exceeds them by as "more", with the `list` command. One with no `items` is printed as its count.
- **A claim** is `tentative` while its backend marks it as not yet up for review. `idleDays` lets the renderer call a claim stale at seven days. `items` are the ids it claims; when it claims none, `note` says why.
- **`here`** is the checkout's own branch. `state` is one of `default-branch`, `detached`, `unclaimed`, `claimed`, `merged`, `closed`, `unlinked`, `unknown`. For `claimed`, `claim`, `tentative` and `items` (each with `id`, `title` and `show`, a command that shows the item) are printed. For every other state the renderer prints the branch and then `hint`, the adapter's sentence on what the branch is and what to do about it.
- **Clean every title, branch name and note** before printing it: control characters become spaces and the text is cut at 120 characters. This text is written by whoever can open an issue and reaches every session. The renderer cleans it again.

When `state` cannot answer it prints one line, `ROADMAP UNAVAILABLE: <reason>. Do not assume project status.`, and exits 0. It has five seconds; on `TERM` it stops what it started.

## `claim`, `release`, `setup`

- `claim <ids...> [options]` makes the claim and prints what it made. `release <ids...>` withdraws it. Both exit non-zero with a one-line reason when they could not, and both are safe to repeat: a claim that stopped partway is finished by the same command.
- A claim must be atomic where the backend does not derive it: two sessions that claim the same item at once must not both succeed.
- `setup [--yes]` prepares the backend and the repository, asking before each change. It adds and never removes, and it leaves what the project already decided.

## Tests

Check an adapter's `state` output with `scripts/contract.jq`, and render it with `scripts/render.jq` against the expected text in `tests/testdata`: those fixtures are backend-neutral.
