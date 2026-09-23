#!/usr/bin/env bash
# model-policy: PreToolUse hook for subagent dispatches on Claude Code, Copilot CLI, Codex CLI and Cursor.
# Fills a missing model with the tier default for the agent type, denies frontier-tier models unless the
# prompt carries a one-line justification, and logs every dispatch. See README.md.
# Every internal failure exits 0 with no output: this hook must never block a dispatch by accident.
set -u
command -v jq >/dev/null 2>&1 || exit 0
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) || exit 0
. "$HERE/lib/config.sh" || exit 0

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
[ -n "$harness" ] || harness=claude-code

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
