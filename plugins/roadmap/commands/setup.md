---
description: Prepare this project for the roadmap (its .roadmap.json and practices, the tracker's labels, the pull request check and the agent permissions)
allowed-tools: Bash(bash *)
---
Set this project up for the roadmap plugin with its GitHub backend.

1. Tell the user what `roadmap setup` changes, and that each is skipped when it is already there: it writes `.roadmap.json`; creates the labels `initiative`, `slice`, `bug`, `debt`, `enhancement` and `decision` on GitHub; installs `.github/workflows/pr-title.yml`; and adds permissions to `.claude/settings.json` (allow `git add`, `git commit`, `git push` and `gh pr ready`; ask on every form of force push).
2. Ask which practices the project follows, and say what each is: `findings` (what is found on the way is fixed, filed or dropped), `ready` (what must hold before work is marked ready), `stacking` (units that build on each other, and a slice that does not fit a session) and `merge` (the session that claimed a unit merges it once its checks pass). The first three are the default. `merge` changes who merges and also allows `gh pr merge`, `gh pr checks`, `gh pr view` and `gh run rerun`, so name it only when the user asks for it.
3. Wait for the user to agree. If they want only some of the changes, say that they can run `roadmap setup` themselves in a terminal, where it asks before each one.
4. When they agree, run `bash "${CLAUDE_PLUGIN_ROOT}/bin/roadmap" setup github --yes --practices <the names, comma-separated>` and relay what it printed, including the command that makes the check required. Do not run that command: it needs admin rights and changes how the whole team merges.
5. Do not commit. Say which files were written so the user can review them.
