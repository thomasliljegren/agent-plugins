#!/usr/bin/env bash
# The docs agree with the config and name every setting.
. "$(dirname "$0")/lib.sh"
REPO=$(cd "$ROOT/../.." && pwd)
README="$ROOT/README.md"
SKILL="$ROOT/skills/model-policy/SKILL.md"

between() { awk -v b="<!-- defaults:$2:begin -->" -v e="<!-- defaults:$2:end -->" '$0 == e {f = 0} f && NF {print} $0 == b {f = 1}' "$1"; }

tiers=$(bash "$ROOT/scripts/defaults-table.sh" tiers)
types=$(bash "$ROOT/scripts/defaults-table.sh" agent-types)
check "README tier table matches config/models.json" "$tiers" "$(between "$README" tiers)"
check "README agent type table matches config/models.json" "$types" "$(between "$README" agent-types)"
check "SKILL tier table matches config/models.json" "$tiers" "$(between "$SKILL" tiers)"

for v in MODEL_POLICY_CONFIG MODEL_POLICY_LOG MODEL_POLICY_DEBUG XDG_CONFIG_HOME XDG_STATE_HOME CLAUDE_CODE_SUBAGENT_MODEL; do
  check "README documents $v" yes "$(grep -q "$v" "$README" && echo yes)"
done
for h in "Claude Code" "Copilot CLI" "Codex CLI" "Cursor"; do
  check "README has install notes for $h" yes "$(grep -q "^### $h" "$README" && echo yes)"
done
bad=0
while IFS= read -r block; do jq -e . >/dev/null 2>&1 <<<"$block" || bad=$((bad + 1)); done < <(
  awk '/^```json$/ {f = 1; b = ""; next} /^```$/ && f {f = 0; gsub(/\n/, " ", b); print b; next} f {b = b "\n" $0}' "$README")
check "every json block in the README parses" 0 "$bad"
check "README has worked override examples" yes "$([ "$(grep -c '^```json$' "$README")" -ge 3 ] && echo yes)"

description=$(awk '/^description:/ {sub(/^description: */, ""); print; exit}' "$SKILL")
for tool in Agent task spawn_agent Task; do
  case " $description " in *"$tool"*) r=yes ;; *) r=no ;; esac
  check "SKILL description names the $tool tool" yes "$r"
done
for f in "$README" "$SKILL"; do
  check "$(basename "$f") shows the justification line" yes "$(grep -q 'Model policy: frontier because <reason>' "$f" && echo yes)"
done

check "marketplace metadata version" 0.4.0 "$(jq -r .metadata.version "$REPO/.claude-plugin/marketplace.json")"
case "$(jq -r '.plugins[] | select(.name == "model-policy") | .description' "$REPO/.claude-plugin/marketplace.json")" in
  *tier*Copilot*) r=yes ;; *) r=no ;;
esac
check "marketplace description uses tiers and names other harnesses" yes "$r"
check "repo README says model-policy covers four harnesses" yes "$(grep 'model-policy' "$REPO/README.md" | grep -q 'Codex' && echo yes)"
check "INSTALL.md mentions model-policy hooks" yes "$(grep -q 'model-policy' "$REPO/docs/INSTALL.md" && echo yes)"

finish
