---
description: Prepare this project for the roadmap (its .roadmap.json, the tracker's labels, the pull request check and the agent permissions)
allowed-tools: Bash(bash *)
---
Set this project up for the roadmap plugin with its GitHub backend.

1. Tell the user what `roadmap setup` changes, and that each is skipped when it is already there: it writes `.roadmap.json`; creates the labels `initiative`, `slice`, `bug` and `debt` on GitHub; installs `.github/workflows/pr-title.yml`; and adds permissions to `.claude/settings.json` (allow `git add`, `git commit`, `git push` and `gh pr ready`; ask on every form of force push).
2. Wait for the user to agree. If they want only some of the changes, say that they can run `roadmap setup` themselves in a terminal, where it asks before each one.
3. When they agree to all of it, run `bash "${CLAUDE_PLUGIN_ROOT}/bin/roadmap" setup github --yes` and relay what it printed, including the command that makes the check required. Do not run that command: it needs admin rights and changes how the whole team merges.
4. Do not commit. Say which files were written so the user can review them.
