# Sourced by the *.test.sh files.
set -u
TESTS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$TESTS/.." && pwd)
HOOK="$ROOT/scripts/model-policy.sh"
SCRATCH=$(mktemp -d -t model-policy-test.XXXXXX)
trap 'rm -rf "$SCRATCH"' EXIT
export MODEL_POLICY_LOG="$SCRATCH/state/dispatches.tsv"
export MODEL_POLICY_CONFIG="$SCRATCH/no-override.json"
unset COPILOT_CLI CURSOR_VERSION CURSOR_PLUGIN_ROOT MODEL_POLICY_DEBUG
fail=0

check() { # NAME EXPECTED ACTUAL
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected [$2] got [$3]"; fail=1; fi
}

finish() {
  if [ $fail -eq 0 ]; then echo "passed"; else echo "failed"; exit 1; fi
}

# payload HARNESS AGENT_TYPE MODEL PROMPT: a subagent dispatch in that harness's hook payload shape.
# An empty MODEL leaves the model field out.
payload() {
  jq -n --arg h "$1" --arg t "$2" --arg m "$3" --arg p "$4" '
    ($m | if . == "" then {} else {model: .} end) as $model
    | if $h == "claude-code" then
        {session_id: "abcdef1234", cwd: "/tmp/proj", hook_event_name: "PreToolUse", tool_name: "Agent",
         tool_input: ({description: "d", subagent_type: $t, prompt: $p} + $model)}
      elif $h == "copilot" then
        {hook_event_name: "PreToolUse", session_id: "abcdef1234", timestamp: "2026-09-23T09:00:00Z", cwd: "/tmp/proj",
         tool_name: "Agent", tool_input: ({name: "n", description: "d", agent_type: $t, mode: "sync", prompt: $p} + $model)}
      elif $h == "codex" then
        {session_id: "abcdef1234", cwd: "/tmp/proj", hook_event_name: "PreToolUse", turn_id: "t", tool_use_id: "u",
         tool_name: "spawn_agent", tool_input: ({agent_type: $t, task_name: "d", message: $p} + $model)}
      else
        {conversation_id: "abcdef1234", generation_id: "g", hook_event_name: "preToolUse", workspace_roots: ["/tmp/proj"],
         tool_name: "Task", tool_use_id: "u", tool_input: ({subagent_type: $t, description: "d", prompt: $p} + $model)}
      end'
}

hook() { payload "$@" | bash "$HOOK" --harness "$1"; } # hook HARNESS AGENT_TYPE MODEL PROMPT

decision() { # HARNESS OUTPUT -> allow | deny | ""
  case "$1" in
    copilot) jq -r '.permissionDecision // ""' <<<"$2" ;;
    cursor) jq -r '.permission // ""' <<<"$2" ;;
    *) jq -r '.hookSpecificOutput.permissionDecision // ""' <<<"$2" ;;
  esac
}

reason() { # HARNESS OUTPUT -> the text the agent sees
  case "$1" in
    copilot) jq -r '.permissionDecisionReason // ""' <<<"$2" ;;
    cursor) jq -r '.agent_message // ""' <<<"$2" ;;
    *) jq -r '.hookSpecificOutput.permissionDecisionReason // ""' <<<"$2" ;;
  esac
}

rewritten() { # HARNESS OUTPUT -> the rewritten tool input, or {}
  case "$1" in
    copilot) jq -c '.modifiedArgs // {}' <<<"$2" ;;
    cursor) jq -c '.updated_input // {}' <<<"$2" ;;
    *) jq -c '.hookSpecificOutput.updatedInput // {}' <<<"$2" ;;
  esac
}

last_log() { tail -n 1 "$MODEL_POLICY_LOG" | cut -f"$1"; } # last_log FIELD_NUMBER (1-based)
