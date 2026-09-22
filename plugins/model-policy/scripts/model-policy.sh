#!/usr/bin/env bash
# PreToolUse hook for the Agent tool.
#
# Reads the dispatch on stdin, then:
#   - fills in a model when the dispatch names none (or says "inherit"),
#     by agent type: Explore and claude-code-guide -> haiku, everything else -> sonnet;
#   - lets haiku, sonnet and opus through untouched;
#   - allows a top-tier model (fable, mythos, best) only when the prompt carries a line
#       Model policy: fable because <reason>
#     and denies the dispatch otherwise, telling the caller what to do instead;
#   - appends one line per dispatch to the log (default ~/.claude/logs/model-policy.tsv).
#
# Nothing but JSON goes to stdout. Any failure inside the script exits 0 without output,
# so a broken hook never blocks a dispatch.
set -u

command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat) || exit 0

TOOL=$(jq -r '.tool_name // empty' <<<"$INPUT" 2>/dev/null) || exit 0
[ "$TOOL" = "Agent" ] || exit 0

TYPE=$(jq -r '.tool_input.subagent_type // "general-purpose"' <<<"$INPUT")
REQUESTED=$(jq -r '.tool_input.model // ""' <<<"$INPUT")
PROMPT=$(jq -r '.tool_input.prompt // ""' <<<"$INPUT")
DESCRIPTION=$(jq -r '.tool_input.description // ""' <<<"$INPUT" | tr '\t\n' '  ')
SESSION=$(jq -r '.session_id // ""' <<<"$INPUT")
PROJECT=$(basename "$(jq -r '.cwd // ""' <<<"$INPUT")")
CHARS=${#PROMPT}
LOG=${MODEL_POLICY_LOG:-$HOME/.claude/logs/model-policy.tsv}

default_for() {
  case "$1" in
    Explore|claude-code-guide) echo haiku ;;
    *) echo sonnet ;;
  esac
}

is_top_tier() {
  case "$1" in
    best|*fable*|*mythos*) return 0 ;;
    *) return 1 ;;
  esac
}

ACTION=kept
EFFECTIVE=$REQUESTED
if [ -z "$REQUESTED" ] || [ "$REQUESTED" = "inherit" ]; then
  EFFECTIVE=$(default_for "$TYPE")
  ACTION=filled
elif is_top_tier "$REQUESTED"; then
  if grep -qiE '^[[:space:]]*Model policy: *fable because .{3,}' <<<"$PROMPT"; then
    ACTION=justified
  else
    ACTION=denied
    EFFECTIVE=-
  fi
fi

{
  mkdir -p "$(dirname "$LOG")"
  if [ ! -s "$LOG" ]; then
    printf 'time\tsession\tproject\tagent_type\trequested\teffective\taction\tprompt_chars\tdescription\n' >>"$LOG"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${SESSION:0:8}" "$PROJECT" "$TYPE" "${REQUESTED:--}" "$EFFECTIVE" "$ACTION" "$CHARS" "$DESCRIPTION" >>"$LOG"
} 2>/dev/null

case "$ACTION" in
  kept|justified)
    exit 0
    ;;
  filled)
    jq -n --argjson input "$(jq -c '.tool_input' <<<"$INPUT")" --arg model "$EFFECTIVE" --arg type "$TYPE" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        permissionDecisionReason: ("model-policy: no model named, " + $type + " runs on " + $model),
        updatedInput: ($input + {model: $model})
      }
    }'
    ;;
  denied)
    jq -n --arg model "$REQUESTED" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("model-policy: subagents do not run on " + $model + " without a reason. Re-dispatch on opus (judgement, review, fix rounds) or sonnet (implementation from a plan, verification against a spec). Use " + $model + " only for the pass that brings several rounds of subagent work together or verifies the whole, and then add this line to the prompt: \"Model policy: fable because <reason>\".")
      }
    }'
    ;;
esac
exit 0
