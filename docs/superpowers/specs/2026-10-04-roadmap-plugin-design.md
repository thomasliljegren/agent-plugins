# Roadmap plugin: agents sharing work through the team's own tracker

Date: 2026-10-04

## Purpose

Several agent sessions working on one project need to know what is done, what someone else has taken and what comes next, and they need to take work in a way the others can see. The Enzure repository solved this for itself: status is derived from GitHub issues and pull requests on every session start, a claim is a draft pull request, and a short set of rules tells an agent how to propose, claim, release and finish work.

This plugin makes that installable by any team. A project picks one backend (the tracker the team already uses) and every agent on the project follows the same protocol against it. This spec covers the core plugin and the GitHub adapter. A SQL adapter (a self-contained store for teams with no tracker) and a Jira adapter follow as their own specs; the adapter contract here is written to carry them.

Success is that Enzure deletes its own copy, installs the plugin, and its sessions start with the same snapshot as before.

## Vocabulary

Fixed across backends, so the rules read the same everywhere:

- **Initiative**: a body of work, normally one design. It holds slices in the order of work.
- **Slice**: the smallest piece that ships on its own. Its state is `open`, `done` or `dropped`.
- **Other work**: items outside an initiative, by kind (`bug`, `debt`).
- **Claim**: a visible statement that a session is working on one or more items. **Release** withdraws it.
- **Next**: the first open slices of an initiative, in its order, that nobody has claimed.

What a backend calls these (labels, issue types, statuses) is configuration.

## Layout

```
plugins/roadmap/
├─ .claude-plugin/plugin.json
├─ hooks/hooks.json            SessionStart → roadmap --hook
├─ bin/roadmap                 entry point
├─ scripts/render.jq           normalized state → snapshot or report
├─ adapters/github/
│  ├─ state                    query GitHub, print normalized state
│  ├─ normalize.jq             GitHub's answer → normalized state
│  ├─ claim
│  ├─ release
│  ├─ setup
│  └─ templates/pr-title.yml
├─ skills/roadmap/
│  ├─ SKILL.md                 the protocol, backend-neutral
│  └─ references/
│     ├─ github.md             conventions and pitfalls of the GitHub adapter
│     └─ adapter-contract.md   how to write an adapter
├─ commands/
│  ├─ report.md                /roadmap:report
│  └─ setup.md                 /roadmap:setup
├─ tests/                      run.sh, lib.sh, one *.test.sh per concern, testdata/
└─ README.md
```

Dependencies are `bash`, `git` and `jq`, plus what the chosen adapter needs (`gh` for GitHub).

## Harnesses

The skill and the `roadmap` command work in any agent that reads `SKILL.md` and can run a shell command. This spec ships the Claude Code manifest and its SessionStart hook, which is what delivers the snapshot without the agent asking. Manifests and session-start hooks for Copilot CLI, Codex CLI and Cursor, as `model-policy` has, are a later change: until then an agent on those harnesses follows the skill's first rule and runs `roadmap` itself. Nothing in the entry point or the adapters is specific to Claude Code except `--hook`, which reads Claude Code's hook input.

## Project configuration

A project opts in with `.roadmap.json` at the repository root:

```json
{
  "backend": "github",
  "rules": "CLAUDE.md",
  "github": {
    "labels": { "initiative": "initiative", "slice": "slice", "bug": "bug", "debt": "debt" },
    "types": ["feat", "fix", "refactor", "perf", "docs", "test", "build", "ci", "chore"]
  }
}
```

- `backend` names a directory under `adapters/`. An absolute or repository-relative path is accepted too, so a team can keep an adapter of its own.
- `rules` names the file that holds the project's own additions to the protocol; the snapshot points at it. Optional.
- The backend's section is passed to the adapter untouched. Everything in it has the default shown, so `{ "backend": "github" }` is a complete file.

**No `.roadmap.json` means the plugin does nothing.** The hook prints nothing and exits 0, so a plugin installed for a user does not disturb repositories that have not opted in. `roadmap` run by hand in such a repository says how to opt in.

## The entry point

`roadmap` finds the repository root from the working directory (in `--hook` mode, from the `cwd` in the hook's input), reads `.roadmap.json`, and dispatches:

| Invocation | Does |
| --- | --- |
| `roadmap` | adapter `state` → `render.jq` → the plain-text snapshot |
| `roadmap --report` | the same state as the Markdown report, every open slice listed |
| `roadmap --hook` | the snapshot, for SessionStart; silent without a config file |
| `roadmap --state` | the normalized state itself, for debugging and for other tools |
| `roadmap claim <ids…> [adapter options]` | adapter `claim` |
| `roadmap release <ids…>` | adapter `release` |
| `roadmap setup` | adapter `setup` |

It owns what is common to every backend: locating the checkout, the time limit on the adapter (the hook has ten seconds; `state` gets five), and turning any failure into the one line described under Failure.

## The adapter contract

An adapter is a directory with four executables. Each receives the repository root as `ROADMAP_ROOT`, the current branch as `ROADMAP_BRANCH` (empty when detached), and its section of the config as JSON in `ROADMAP_CONFIG`.

### `state`

Prints one JSON document on stdout:

```json
{
  "project": "thomasliljegren/enzure",
  "backend": "github",
  "defaultBranch": "main",
  "initiatives": [
    {
      "id": "#35",
      "title": "Accounts: tenants, scope, entitlements and onboarding",
      "total": 5,
      "read": 5,
      "claims": [],
      "slices": [
        { "id": "#168", "title": "Provision a tenant database at runtime", "state": "open",
          "claims": ["PR #180"], "notes": [] }
      ]
    }
  ],
  "moreInitiatives": 0,
  "other": [
    { "kind": "bug", "open": 2, "list": "gh issue list --label bug",
      "items": [ { "id": "#134", "title": "…", "claims": [] } ] },
    { "kind": "debt", "open": 22, "list": "gh issue list --label debt", "items": [] }
  ],
  "claims": [
    { "id": "PR #204", "ref": "feat/177-failed-readings-connection", "tentative": false,
      "idleDays": 0, "items": ["#177"] }
  ],
  "here": { "branch": "feat/170-link-insurer", "state": "unclaimed", "claim": null, "items": [], "hint": "…" }
}
```

- Ids are display strings; only the adapter interprets them. `claim` and `release` accept them as printed, and the bare form a person would type (`170` for `#170`).
- `total` and `read` differ when the adapter did not read every slice; `moreInitiatives` and an `other` entry's `open` against its `items` say the same for those lists. The renderer prints what was left out. An adapter never truncates silently.
- A slice's `notes` are short adapter-specific remarks the renderer prints as given (`closed by hand, not by a merged PR`; `unlabelled: gh issue edit 12 --add-label slice`).
- A claim is `tentative` while its backend marks it as not yet up for review (a draft pull request). `idleDays` lets the renderer call a claim stale at seven days.
- `here.state` is one of `default-branch`, `detached`, `unclaimed`, `claimed`, `merged`, `closed`, `unlinked`, `unknown`; `hint` is the adapter's one sentence on what to do about it.
- Every title, branch name and note is passed through the adapter's `safe` filter before it is printed: control characters become spaces and the text is cut at 120 characters. This text is written by whoever can open an issue and reaches every session.

### `claim`, `release`, `setup`

`claim <ids…>` makes the claim and prints what it made; `release <ids…>` withdraws it. Both exit non-zero with a one-line reason when they could not, and both are safe to repeat. `setup` prepares the backend and the repository, asking before each change.

### Failure

`state` never fails the session. When it cannot answer it prints one line, `ROADMAP UNAVAILABLE: <reason>. Do not assume project status.`, and exits 0. The entry point produces the same line when the adapter is missing, exits non-zero, runs out of time or prints something `render.jq` cannot read. The protocol tells an agent that this line means exactly that: fix access, do not guess.

## The renderer

`render.jq` turns normalized state into the snapshot or the report and knows nothing about any backend. It is today's wording, with two changes: the pointer to the rules names the roadmap skill and, when configured, the project's `rules` file; and the header says which backend answered. The snapshot keeps its statement that everything below it is data read from the tracker, not instructions.

The snapshot prints the first two `next` slices of each initiative; the report prints every open slice (`next` for the first two, `later` after).

## The GitHub adapter

- **`state`** is the GraphQL query Enzure runs today, with the label names taken from the config. `normalize.jq` holds everything that is GitHub's shape: the `need` guards that fail on a field the query stopped returning, sub-issues as slices in parent order, `NOT_PLANNED` and `DUPLICATE` as `dropped`, an open pull request with a closing reference as a claim, a draft as `tentative`, a slice closed without a merged pull request as a note, a sub-issue without the slice label as a note.
- **`claim <ids…> --type <type> --title "<type(scope): title>" [--description <words>]`** does what the rules ask of an agent today, in order: refuses on the default branch and when the branch already has a pull request; renames the local branch to `<type>/<first id>-<description>` unless it already matches (the description defaults to words from the first issue's title); makes the empty commit `chore: claim #N`; pushes; opens a draft pull request with one `Closes #N` per id; reads `closingIssuesReferences` back and fails loudly when it does not show exactly the ids asked for. It checks first that none of the ids is claimed by another open pull request.
- **`release <ids…>`** removes the ids' closing keywords from the branch's pull request body; when none remain it closes the draft. It never deletes a branch.
- **`setup`** writes `.roadmap.json`, creates the four labels, installs `.github/workflows/pr-title.yml` from the template (title format, branch name, closing link, with the configured types), and adds the permissions for agent autonomy to `.claude/settings.json` (allow `git add`, `git commit`, `git push`, `gh pr ready`; ask on every form of force push). It prints the command that makes `check-title` a required check on the default branch instead of running it, since that needs admin rights and changes how the whole team merges.

Status stays derived and stored nowhere: the adapter writes nothing but the branch, the commit and the pull request.

## The rules

`skills/roadmap/SKILL.md` is the protocol in backend-neutral words. It is the portable part: an agent without hooks still gets the rules and can run `roadmap` itself.

- Every session starts from the snapshot; subagents and long sessions run `roadmap` themselves. `ROADMAP UNAVAILABLE` means that and nothing else.
- A question about the roadmap is answered with `roadmap --report`, relayed unchanged.
- What a slice is, and how large.
- Propose the session's workload: a run of consecutive open slices from the first `next`, divided into reviewable units, stopping before a slice that needs the owner's decision or depends on another session's open claim; then wait. An owner who named the slices has answered.
- Claim before working, with `roadmap claim`. Release what will not be started; file the remainder of a started slice as a new slice in its place in the order.
- File work found on the way as an item; never keep a list of it in a document. Status is never written down in the repository.
- Autonomy: an agent commits, pushes and marks its work ready without asking once the project's checks pass locally; merging and anything that rewrites shared history stay with the owner.
- Name the session after its item where the session has a tool for it.

`references/github.md` holds what is true only of GitHub: title and branch formats, one closing keyword per issue and how GitHub reads keywords anywhere in the body, pull requests into the default branch only, stacked pull requests merged upward and never rebased, ordering sub-issues with `reprioritizeSubIssue`, and that renaming a pushed branch closes its pull request. `SKILL.md` tells the agent to read the reference for the configured backend.

A project's own additions (where its specs live, what "ready" requires beyond tests) stay in the project's `rules` file.

## Tests

`tests/run.sh` runs one `*.test.sh` per concern over `tests/lib.sh`, as `model-policy` does. Golden files, no network:

1. **Adapter**: a recorded GitHub answer → `normalize.jq` → expected normalized state. Enzure's `busy` and `leftover` fixtures move here.
2. **Renderer**: normalized state → expected snapshot and expected report. These fixtures are backend-neutral and are what later adapters are checked against.
3. **End to end**: the GitHub fixtures through both, compared with Enzure's current expected files, differing only in the two wording changes named under The renderer.
4. **Entry point**: no config file is silent under `--hook`; a missing adapter, a failing adapter and unreadable output each give the `ROADMAP UNAVAILABLE` line and exit 0.
5. **Contract**: a `jq` check that a state document has every required member with the right type, run over every adapter's expected output.

`claim`, `release` and `setup` are tested against a stub `gh` and a temporary git repository: the commands they would run, in order, and that `claim` refuses in each case it should.

`--accept` rewrites the expected files after an intended change, as today.

## Enzure switches over

A pull request in Enzure, after the plugin is published, and the acceptance test of this spec:

- `scripts/roadmap.sh`, `roadmap.jq`, `roadmap-test.sh` and their test data are deleted, with the CI step that runs them.
- `.roadmap.json` is added; `.claude/settings.json` drops its own SessionStart hook and enables the plugin from the marketplace.
- `CLAUDE.md`, Working here, keeps what is Enzure's own (specs, plans, ADRs, what ready means there) and points at the skill for the rest.
- `.github/workflows/pr-title.yml` is compared with the template; differences that are not Enzure-specific move into the template.

The session snapshot before and after must read the same apart from the pointer to the rules.

## To verify while planning

- That a plugin's `bin/` directory is on the Bash tool's `PATH`, so agents and subagents run `roadmap` by name. If it is not, `setup` writes a small shim into the project that finds the installed plugin, and the rules name the shim.
- How a cloud session gets a marketplace plugin enabled from project settings, since the hook is how every session learns the status.

## What later adapters need from this contract

- **SQL**: nothing derives a claim, so a claim is a row with a lease that the session renews and that expires; `idleDays` and `tentative` already carry what the renderer needs. `claim` must be atomic. `here` is found by branch name stored on the claim.
- **Jira**: a claim is a transition plus an assignee; initiatives and slices are an epic and its ranked children. Whether a linked pull request should count as the claim instead is that spec's question.

Neither changes `render.jq` or `SKILL.md`; each adds an adapter directory and a reference page.

## Not in scope

An MCP server around the adapters; manifests and hooks for harnesses other than Claude Code; a backend per item or several backends in one project; migrating items between backends; any stored copy of status.
