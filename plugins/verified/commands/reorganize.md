---
description: Bring VERIFIED.md, or another file of verified facts, into the topic layout of the verified skill, proposing every move, merge and deletion before writing
argument-hint: "[path, default VERIFIED.md]"
allowed-tools: Bash(bash *)
---
Load the `verified` skill, then follow its `references/reorganize.md` for the file `$ARGUMENTS` (`VERIFIED.md` when that is empty). The preservation check is `bash "${CLAUDE_PLUGIN_ROOT}/skills/verified/scripts/preserved.sh"`. Stop after phase 3 and wait for the user's yes before writing anything.
