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

- writes `.roadmap.json`
- creates the labels `initiative`, `slice`, `bug` and `debt`
- installs `.github/workflows/pr-title.yml`, which checks the pull request's title, its branch name and that it closes an issue
- adds agent permissions to `.claude/settings.json`: allow `git add`, `git commit`, `git push` and `gh pr ready`; ask on every form of force push. Rules the project already has are kept, and a command it denies stays denied.

A project without `.roadmap.json` is left alone: the hook prints nothing there.

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

`{ "backend": "github" }` is a complete file. `rules` names the file with the project's own additions to the rules; the snapshot points at it.

## Use

| Command | Does |
| --- | --- |
| `roadmap` | the snapshot for this checkout |
| `roadmap --report` or `/roadmap:report` | the Markdown report, every open slice listed |
| `roadmap claim <ids...> --type <type> --title "<type(scope): title>"` | claim items with a draft pull request |
| `roadmap release <ids...>` | withdraw a claim |
| `roadmap --state` | the state as JSON |

The rules agents follow are in `skills/roadmap/SKILL.md`; what is particular to GitHub is in `skills/roadmap/references/github.md`.

When the tracker cannot be reached a session starts with one line, `ROADMAP UNAVAILABLE: <reason>. Do not assume project status.`, and the rules tell the agent to fix access instead of guessing.

## Limits

- **Claude Code only, in a local checkout.** A cloud session does not install plugins a repository enables, so it gets no snapshot and no rules. The GitHub adapter itself uses REST only and works there once the plugin does.
- **claude.ai and Cowork do not install this plugin**, because it ships a `bin/` directory.
- **Claims are read from closing keywords** in pull request bodies (`Closes #N`), for issues of the same repository.
- **A team's own adapter runs as code.** `backend` may name a directory in the repository; its `state` command then runs at every session start. Opt in only in repositories you trust, as with any project hook.

## Tests

```
bash plugins/roadmap/tests/run.sh
```

No network: the GitHub adapter runs against a stand-in `gh`. `--accept` rewrites the expected files after an intended change.

## Writing an adapter

`skills/roadmap/references/adapter-contract.md`.
