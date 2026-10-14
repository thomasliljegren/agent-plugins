#!/usr/bin/env bash
# The plugin is packaged the way Claude Code loads it, and its documents name what exists.
. "$(dirname "$0")/lib.sh"
REPO=$(cd "$ROOT/../.." && pwd)

M="$ROOT/.claude-plugin/plugin.json"
check "the manifest parses" 0 "$(jq -e . "$M" >/dev/null 2>&1; echo $?)"
check "the plugin is named verified" verified "$(jq -r .name "$M")"
check "version is 0.1.0" 0.1.0 "$(jq -r .version "$M")"
entry=$(jq -c '.plugins[] | select(.name == "verified")' "$REPO/.claude-plugin/marketplace.json")
check "the marketplace lists the plugin" ./plugins/verified "$(jq -r .source <<<"$entry")"
check "the marketplace and the manifest describe it alike" "$(jq -r .description "$M")" "$(jq -r .description <<<"$entry")"
check "the marketplace version is 0.7.0" 0.7.0 "$(jq -r .metadata.version "$REPO/.claude-plugin/marketplace.json")"
contains "the repository README lists the plugin" "[verified](plugins/verified)" "$(cat "$REPO/README.md")"
check "preserved.sh is executable in git" 100755 \
  "$(git -C "$REPO" ls-files -s plugins/verified/skills/verified/scripts/preserved.sh | cut -d' ' -f1)"

S="$ROOT/skills/verified/SKILL.md"
check "the skill is named verified" "name: verified" "$(sed -n '2p' "$S")"
check "the skill's description says when to use it" 1 "$(sed -n '3p' "$S" | grep -c '^description: .*Use ')"
for destination in "the spec or ADR of the area" "findings practice" "\`CLAUDE.md\` of the area" "open scope" "frozen"; do
  contains "the skill names the destination: $destination" "$destination" "$(cat "$S")"
done
for part in "**The claim**" "**What to do**" "**The evidence**" "**The source**"; do
  contains "the skill names the entry's part $part" "$part" "$(cat "$S")"
done
contains "the skill says where the file splits" "Past 400 lines" "$(cat "$S")"
contains "the skill says how a correction is marked" "corrected slice" "$(cat "$S")"
contains "the skill forbids keeping superseded entries" "Nothing is marked superseded and kept" "$(cat "$S")"
for f in references/entry.md scripts/preserved.sh; do
  contains "the skill names $f" "\`$f\`" "$(cat "$S")"
  check "$f exists" yes "$([ -f "$ROOT/skills/verified/$f" ] && echo yes)"
done
contains "the README says what the plugin needs" "awk" "$(cat "$ROOT/README.md")"

R="$ROOT/skills/verified/references/reorganize.md"
check "the procedure exists" yes "$([ -f "$R" ] && echo yes)"
contains "the skill names the procedure" "\`references/reorganize.md\`" "$(cat "$S")"
for phase in "## 1. Inventory" "## 2. Classify" "## 3. Propose, and stop" "## 4. Write"; do
  check "the procedure has the phase $phase" 1 "$(grep -cxF "$phase" "$R" 2>/dev/null)"
done
contains "the procedure runs the preservation check" "scripts/preserved.sh" "$(cat "$R" 2>/dev/null)"
contains "the procedure waits for the owner" "Nothing is written before" "$(cat "$R" 2>/dev/null)"
contains "the procedure spares frozen documents" "frozen" "$(cat "$R" 2>/dev/null)"
C="$ROOT/commands/reorganize.md"
check "the command exists" yes "$([ -f "$C" ] && echo yes)"
check "the command has a description" 1 "$(sed -n '2p' "$C" 2>/dev/null | grep -c '^description: ')"
contains "the command follows the procedure" "references/reorganize.md" "$(cat "$C" 2>/dev/null)"
contains "the command runs the check from the plugin" '${CLAUDE_PLUGIN_ROOT}/skills/verified/scripts/preserved.sh' "$(cat "$C" 2>/dev/null)"
contains "the skill names the command" "/verified:reorganize" "$(cat "$S")"
contains "the README names the command" "/verified:reorganize" "$(cat "$ROOT/README.md")"

contains "the procedure keeps every old file, the folder's too" 'for f in VERIFIED.md verified/*.md' "$(cat "$R")"
contains "the procedure checks a move against the lines it added only" "git diff -U0" "$(cat "$R")"
contains "the procedure says a table cell's escaped bar becomes a bar" '`\|`' "$(cat "$R")"
E="$ROOT/skills/verified/references/entry.md"
check "the examples convert a table row" 1 "$(grep -cxF "## A table row" "$E")"
contains "the examples say where a Source column goes" 'The "Source" column is evidence' "$(cat "$E")"
contains "the examples say the source of a heading that names no slice" "names no slice" "$(cat "$E")"

finish
