#!/usr/bin/env bash
# Exercises scripts/model-policy.sh with sample dispatches. Run: bash tests/run.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../scripts/model-policy.sh"
export MODEL_POLICY_LOG=$(mktemp -t model-policy-test.XXXXXX)
fail=0

dispatch() { # type model prompt
  jq -n --arg t "$1" --arg m "$2" --arg p "$3" \
    '{session_id:"abcdef1234",cwd:"/tmp/proj",tool_name:"Agent",tool_input:({description:"d",subagent_type:$t,prompt:$p} + (if $m=="" then {} else {model:$m} end))}' \
    | bash "$SCRIPT"
}
check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected [$2] got [$3]"; fail=1; fi
}

out=$(dispatch Explore "" "look around")
check "Explore without model is filled with haiku" haiku "$(jq -r '.hookSpecificOutput.updatedInput.model' <<<"$out")"
check "filled dispatch keeps its prompt" "look around" "$(jq -r '.hookSpecificOutput.updatedInput.prompt' <<<"$out")"

out=$(dispatch general-purpose "" "implement task 1")
check "general-purpose without model is filled with sonnet" sonnet "$(jq -r '.hookSpecificOutput.updatedInput.model' <<<"$out")"

out=$(dispatch general-purpose inherit "implement task 1")
check "inherit counts as unset" sonnet "$(jq -r '.hookSpecificOutput.updatedInput.model' <<<"$out")"

out=$(dispatch general-purpose opus "review task 1")
check "opus passes through with no output" "" "$out"

out=$(dispatch general-purpose fable "bring it all together")
check "fable without a reason is denied" deny "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$out")"

out=$(dispatch general-purpose fable $'Verify the whole.\nModel policy: fable because this pass integrates five subagent rounds.')
check "fable with a reason passes through" "" "$out"

out=$(dispatch general-purpose claude-fable-5-1 "x")
check "a full fable model id is also gated" deny "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$out")"

out=$(jq -n '{tool_name:"Bash",tool_input:{command:"ls"}}' | bash "$SCRIPT")
check "other tools are ignored" "" "$out"

out=$(echo 'not json' | bash "$SCRIPT"; echo "exit=$?")
check "garbage stdin exits 0 silently" "exit=0" "$out"

lines=$(wc -l <"$MODEL_POLICY_LOG" | tr -d ' ')
check "log has a header and one line per Agent dispatch" 8 "$lines"
check "log records the action" "filled" "$(sed -n 2p "$MODEL_POLICY_LOG" | cut -f7)"
check "log records the denied dispatch" "denied" "$(sed -n 6p "$MODEL_POLICY_LOG" | cut -f7)"

rm -f "$MODEL_POLICY_LOG"
[ $fail -eq 0 ] && echo "all passed" || { echo "some failed"; exit 1; }
