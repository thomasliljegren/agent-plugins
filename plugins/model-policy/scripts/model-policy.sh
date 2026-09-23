#!/usr/bin/env bash
# model-policy: PreToolUse hook for subagent dispatches on Claude Code, Copilot CLI, Codex CLI and Cursor.
# Fills a missing model with the tier default for the agent type, denies frontier-tier models unless the
# prompt carries a one-line justification, and logs every dispatch. See README.md.
# Every internal failure exits 0 with no output: this hook must never block a dispatch by accident.
set -u
command -v jq >/dev/null 2>&1 || exit 0
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) || exit 0
. "$HERE/lib/config.sh" || exit 0

# Prints the harness whose output format to use. See README.md "Harness detection".
detect_harness() { # FLAG PAYLOAD
  local cursor_payload
  cursor_payload=$(jq -r 'has("conversation_id") or has("workspace_roots")' <<<"$2" 2>/dev/null)
  case "$1" in
    "")
      if [ -n "${COPILOT_CLI:-}" ]; then echo copilot
      elif [ "$cursor_payload" = true ] || [ -n "${CURSOR_VERSION:-}${CURSOR_PLUGIN_ROOT:-}" ]; then echo cursor
      elif [ "$(jq -r '.tool_name // ""' <<<"$2" 2>/dev/null)" = spawn_agent ]; then echo codex
      else echo claude-code
      fi
      ;;
    claude-code)
      if [ "$cursor_payload" = true ]; then echo cursor
      elif [ -n "${COPILOT_CLI:-}" ] &&
        [ "$(jq -r '(.tool_input // {}) | type == "object" and has("subagent_type")' <<<"$2" 2>/dev/null)" != true ]; then
        echo copilot
      else echo claude-code
      fi
      ;;
    *) echo "$1" ;;
  esac
}

harness=""
while [ $# -gt 0 ]; do
  case "$1" in
    --harness) harness="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    --harness=*) harness="${1#*=}"; shift ;;
    *) shift ;;
  esac
done

payload=$(cat) || exit 0
jq -e 'type == "object"' >/dev/null 2>&1 <<<"$payload" || exit 0
harness=$(detect_harness "$harness" "$payload")

if [ -n "${MODEL_POLICY_DEBUG:-}" ]; then
  {
    debug_dir=$(dirname "$(model_policy_log_path)") &&
      mkdir -p "$debug_dir" &&
      jq -c --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg harness "$harness" \
        '{time: $time, harness: $harness, payload: .}' <<<"$payload" >>"$debug_dir/payloads.jsonl"
  } 2>/dev/null || true
fi

config=$(model_policy_config) || exit 0
result=$(jq -c --arg harness "$harness" --argjson config "$config" -f "$HERE/policy.jq" <<<"$payload" 2>/dev/null) || exit 0
[ "$(jq -r '.skip' <<<"$result" 2>/dev/null)" = false ] || exit 0

log=$(model_policy_log_path)
{
  mkdir -p "$(dirname "$log")" &&
    { [ -s "$log" ] || printf '%s\n' "$MODEL_POLICY_LOG_HEADER" >"$log"; } &&
    jq -r --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg harness "$harness" '
      .record | [$time, .session, $harness, .project, .agent_type, .requested, .effective,
                 .tier, .action, (.prompt_chars | tostring), .description] | join("\t")' \
      <<<"$result" >>"$log"
} 2>/dev/null || true

out=$(jq -c '.output // empty' <<<"$result" 2>/dev/null) || exit 0
[ -n "$out" ] && printf '%s\n' "$out"
exit 0
