#!/usr/bin/env bash
# The four manifests agree, and every hook file registers the right matcher and a command that works.
. "$(dirname "$0")/lib.sh"

manifests=".claude-plugin/plugin.json .github/plugin/plugin.json .codex-plugin/plugin.json .cursor-plugin/plugin.json"
shared='{name, version, description, author, keywords}'
ref=$(jq -c "$shared" "$ROOT/.claude-plugin/plugin.json")
for m in $manifests; do
  check "$m parses" 0 "$(jq -e . "$ROOT/$m" >/dev/null 2>&1; echo $?)"
  check "$m matches the Claude manifest" "$ref" "$(jq -c "$shared" "$ROOT/$m")"
done
check "version is 0.2.0" 0.2.0 "$(jq -r .version "$ROOT/.claude-plugin/plugin.json")"
check "the Claude manifest uses the default hooks/hooks.json" null "$(jq -r .hooks "$ROOT/.claude-plugin/plugin.json")"
check "the manifests do not use the Agent Plugins 1.0 schema" 0 "$(cat $(for m in $manifests; do echo "$ROOT/$m"; done) | grep -c '\$schema')"

# manifest | hook file it names ("" = default hooks/hooks.json)
while IFS='|' read -r m hooks; do
  check "$m names $hooks" "$hooks" "$(jq -r '.hooks // ""' "$ROOT/$m")"
  [ -n "$hooks" ] && check "$m hook file exists" yes "$([ -f "$ROOT/${hooks#./}" ] && echo yes)"
done <<'EOF'
.github/plugin/plugin.json|hooks/hooks-copilot.json
.codex-plugin/plugin.json|./hooks/hooks-codex.json
.cursor-plugin/plugin.json|./hooks/hooks-cursor.json
EOF

commands() { jq -r '.. | objects | select(has("command")) | .command' "$ROOT/hooks/$1"; }
matchers() { jq -r '[.. | objects | select(has("matcher")) | .matcher] | join(",")' "$ROOT/hooks/$1"; }

# hook file | harness | event key | matcher | agent type | expected fill
while IFS='|' read -r file h event matcher type fill; do
  check "$file registers $event" true "$(jq --arg e "$event" '.hooks | has($e)' "$ROOT/hooks/$file")"
  check "$file matches $matcher" "$matcher" "$(matchers "$file")"
  check "$file has one command" 1 "$(commands "$file" | wc -l | tr -d ' ')"
  case "$(commands "$file")" in *"--harness $h"*) r=yes ;; *) r=no ;; esac
  check "$file passes --harness $h" yes "$r"
  out=$(payload "$h" "$type" "" x | (cd "$ROOT" && CLAUDE_PLUGIN_ROOT="$ROOT" PLUGIN_ROOT="$ROOT" bash -c "$(commands "$file")"))
  check "$file command runs and fills $fill" "$fill" "$(rewritten "$h" "$out" | jq -r .model)"
done <<'EOF'
hooks.json|claude-code|PreToolUse|Agent|Explore|haiku
hooks-copilot.json|copilot|PreToolUse|Agent|explore|claude-haiku-4.5
hooks-codex.json|codex|PreToolUse|spawn_agent|explorer|gpt-6-luna
hooks-cursor.json|cursor|preToolUse|Task|explore|composer-2.5
EOF
check "the Cursor hook file is version 1" 1 "$(jq -r .version "$ROOT/hooks/hooks-cursor.json")"

finish
