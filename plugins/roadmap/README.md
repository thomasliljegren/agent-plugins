# roadmap

Agents sharing work through the team's own tracker. Several agent sessions on one project need to know what is done, what someone else has taken and what comes next, and they need to take work in a way the others can see. This plugin gives every session a live snapshot of that at its start, one command to claim work and one to release it, and a short set of rules. Status is derived from the tracker on every run and stored nowhere.

The backend today is GitHub: initiatives are issues, slices are their sub-issues, and a claim is a draft pull request that closes them.

## Install

```
/plugin marketplace add thomasliljegren/agent-plugins
/plugin install roadmap@agent-plugins
```

It needs `bash`, `git` and `jq`, and `gh` signed in for the GitHub backend.

## Opt a project in

In the project, run `/roadmap:setup`, or `roadmap setup` in a terminal. It asks before each change:

- writes `.roadmap.json`, with the practices you choose
- creates the labels `initiative`, `slice`, `bug`, `debt`, `enhancement` and `decision`
- installs `.github/workflows/pr-title.yml`, which checks the pull request's title, its branch name and that it closes an issue
- adds agent permissions to `.claude/settings.json`: allow `git add`, `git commit`, `git push` and `gh pr ready`; ask on every form of force push. Rules the project already has are kept, and a command it denies stays denied.

A project without `.roadmap.json` is left alone: the hook prints nothing there.

```json
{
  "backend": "github",
  "rules": "CLAUDE.md",
  "practices": ["findings", "ready", "stacking"],
  "staleAfterHours": 168,
  "github": {
    "labels": { "initiative": "initiative", "slice": "slice", "bug": "bug", "debt": "debt", "enhancement": "enhancement", "decision": "decision" },
    "types": ["feat", "fix", "refactor", "perf", "docs", "test", "build", "ci", "chore"]
  }
}
```

`{ "backend": "github" }` is a complete file, with the practices shown. `rules` names the file with the project's own additions to the rules; the snapshot points at it. `staleAfterHours` is how long a claim may stand still before the roadmap calls it stale: seven days where the file does not say, and a day or less suits a project whose sessions finish within hours.

## Practices

The core rules are the same everywhere: start from the snapshot, propose a workload, claim before working, file what you find. On top of them a project names the practices it follows, and the snapshot tells every session which they are:

| Practice | Rules |
| --- | --- |
| `findings` | What is found on the way is fixed, filed or dropped, and what an item of each kind must name before it is filed. |
| `ready` | What must hold before work is marked ready: checks green locally, a review of the whole change, a description that says what changed and how it was tested. |
| `stacking` | Units that build on each other, and what to do with a slice that does not fit a session. |
| `merge` | The session that claimed a unit merges it once it is ready and its checks pass. Not a default: `roadmap setup --practices findings,ready,stacking,merge` names it in a new project, and adds the permissions for `gh pr merge`, `gh pr checks`, `gh pr view` and `gh run rerun`. |

A project that already has `.roadmap.json` changes its practices by editing the list there, and runs `roadmap setup` again when it adds `merge`, for the permissions. `"practices": []` is a project with the core rules only. The pages are `skills/roadmap/practices/<name>.md`; what each needs on GitHub is in `skills/roadmap/references/github.md`.

## Use

| Command | Does |
| --- | --- |
| `roadmap` | the snapshot for this checkout |
| `roadmap --report` or `/roadmap:report` | the Markdown report: every open slice, bugs, decisions, claims and what it suggests taking next |
| `roadmap --changes` | only what changed since this checkout last looked |
| `roadmap claim <ids...> --type <type> --title "<type(scope): title>"` | claim items with a draft pull request |
| `roadmap release <ids...>` | withdraw a claim |
| `roadmap overlap [paths...]` | the open pull requests that change the files this branch changes, or the paths named |
| `roadmap --state` | the state as JSON |

An issue that waits for another is marked with GitHub's blocked-by relation; the roadmap prints it as blocked and keeps it out of what comes next.

What several sessions at once need beyond that:

- **Two claims at the same moment.** `roadmap claim` reads the open pull requests again after it opened its own. The one opened first keeps the issue; the other releases it and fails.
- **A free slice after a claimed one** is printed `next, behind PR #N`: it may build on work that has not merged.
- **A claim that holds nothing.** A draft with no commit but the claim's own says `nothing pushed since the claim`, and a stale one like that is to close, not to pick up.
- **What changed since the last look.** A snapshot after the first ends with `CHANGED since`: the slices, claims, bugs and decisions that moved. A subagent starts with one line that tells it to run `roadmap` itself.
- **Two claims in one file.** `roadmap overlap` names the pull requests that change the same files, before the second of them finds out at merge.

The rules agents follow are in `skills/roadmap/SKILL.md`; what is particular to GitHub is in `skills/roadmap/references/github.md`.

When the tracker cannot be reached a session starts with one line, `ROADMAP UNAVAILABLE: <reason>. Do not assume project status.`, and the rules tell the agent to fix access instead of guessing.

## Limits

- **Claude Code only, in a local checkout.** A cloud session does not install plugins a repository enables, so it gets no snapshot and no rules. The GitHub adapter itself uses REST only and works there once the plugin does.
- **claude.ai and Cowork do not install this plugin**, because it ships a `bin/` directory.
- **One thing is kept between runs**: a line for each item of a checkout's last look, in that checkout's git directory, to say what changed since. Status itself is asked every time.
- **Claims are read from closing keywords** in pull request bodies (`Closes #N`), for issues of the same repository.
- **A team's own adapter runs as code.** `backend` may name a directory in the repository; its `state` command then runs at every session start. Opt in only in repositories you trust, as with any project hook.

## Tests

```
bash plugins/roadmap/tests/run.sh
```

No network: the GitHub adapter runs against a stand-in `gh`. `--accept` rewrites the expected files after an intended change.

## Writing an adapter

`skills/roadmap/references/adapter-contract.md`.
