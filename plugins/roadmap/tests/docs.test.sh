#!/usr/bin/env bash
# The plugin is packaged the way Claude Code loads it, and the documents name what exists.
. "$(dirname "$0")/lib.sh"
REPO=$(cd "$ROOT/../.." && pwd)

M="$ROOT/.claude-plugin/plugin.json"
check "the manifest parses" 0 "$(jq -e . "$M" >/dev/null 2>&1; echo $?)"
check "the plugin is named roadmap" roadmap "$(jq -r .name "$M")"
check "version is 0.1.0" 0.1.0 "$(jq -r .version "$M")"
check "the manifest uses the default hooks/hooks.json" null "$(jq -r .hooks "$M")"
entry=$(jq -c '.plugins[] | select(.name == "roadmap")' "$REPO/.claude-plugin/marketplace.json")
check "the marketplace lists the plugin" ./plugins/roadmap "$(jq -r .source <<<"$entry")"

for f in bin/roadmap adapters/github/state adapters/github/claim adapters/github/release adapters/github/setup; do
  check "$f is executable in git" 100755 "$(git -C "$REPO" ls-files -s "plugins/roadmap/$f" | cut -d' ' -f1)"
done

S="$ROOT/skills/roadmap/SKILL.md"
check "the skill is named roadmap" "name: roadmap" "$(sed -n '2p' "$S")"
check "the skill's description says when to use it" 1 "$(sed -n '3p' "$S" | grep -c '^description: .*Use ')"
for word in Initiative Slice "Other work" Claim Next; do
  contains "the skill defines $word" "**$word**" "$(cat "$S")"
done
for command in "roadmap --report" "roadmap claim" "roadmap release" "roadmap setup" "roadmap --state"; do
  contains "the skill names $command" "\`$command" "$(cat "$S")"
  contains "the README names $command" "\`$command" "$(cat "$ROOT/README.md")"
done
for adapter in "$ROOT"/adapters/*/; do
  name=$(basename "$adapter")
  check "the $name backend has its reference page" yes "$([ -f "$ROOT/skills/roadmap/references/$name.md" ] && echo yes)"
done
check "the skill is backend-neutral" "" "$(grep -n -i -E 'github|pull request|(^|[^a-z])gh ' "$S" || true)"

# The contract page's example is a state document that holds the contract and renders.
example=$(awk '/^```json/{p=1; next} /^```/{p=0} p' "$ROOT/skills/roadmap/references/adapter-contract.md")
check "the contract page's example holds the contract" "" "$(jq -r -f "$ROOT/scripts/contract.jq" <<<"$example")"
contains "…and renders" "THIS BRANCH: feat/170-link-insurer -> no pull request." \
  "$(jq -r -f "$ROOT/scripts/render.jq" --arg format snapshot --argjson now "$ROADMAP_NOW" --arg rules "" <<<"$example" 2>&1)"
for state in default-branch detached unclaimed claimed merged closed unlinked unknown; do
  contains "the contract page names the state $state" "\`$state\`" "$(cat "$ROOT/skills/roadmap/references/adapter-contract.md")"
done

for c in report setup; do
  check "commands/$c.md has a description" 1 "$(grep -c '^description: ' "$ROOT/commands/$c.md")"
  contains "commands/$c.md runs the plugin's own roadmap" '${CLAUDE_PLUGIN_ROOT}/bin/roadmap' "$(cat "$ROOT/commands/$c.md")"
done
contains "the repository README lists the plugin" "plugins/roadmap" "$(cat "$REPO/README.md")"
finish
