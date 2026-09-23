#!/usr/bin/env bash
# The hook's decisions, output shapes and log lines on every harness.
. "$(dirname "$0")/lib.sh"

JUSTIFIED=$'Verify the whole.\nModel policy: frontier because this pass integrates five subagent rounds.'
LEGACY=$'Verify the whole.\nModel policy: fable because this pass integrates five subagent rounds.'
INLINE='As agreed, Model policy: frontier because it is big.'

# harness | fast agent type | fast default | standard default | a strong model | a frontier model
while IFS='|' read -r h fast_type fast std strong frontier; do
  prompt_field=prompt; [ "$h" = codex ] && prompt_field=message

  out=$(hook "$h" "$fast_type" "" "look around")
  check "$h: $fast_type without a model is filled with $fast" "$fast" "$(rewritten "$h" "$out" | jq -r .model)"
  check "$h: a fill is allowed" allow "$(decision "$h" "$out")"
  check "$h: a fill keeps the prompt" "look around" "$(rewritten "$h" "$out" | jq -r ".$prompt_field")"
  check "$h: a fill keeps the rest of the input" d "$(rewritten "$h" "$out" | jq -r '.description // .task_name')"
  check "$h: a fill prints exactly one JSON object" 1 "$(jq -s length <<<"$out")"
  check "$h: the log records the harness" "$h" "$(last_log 3)"
  check "$h: the log records the tier" fast "$(last_log 8)"
  check "$h: the log records the action" filled "$(last_log 9)"

  out=$(hook "$h" general-purpose "" "implement task 1")
  check "$h: general-purpose without a model is filled with $std" "$std" "$(rewritten "$h" "$out" | jq -r .model)"

  out=$(hook "$h" general-purpose inherit "implement task 1")
  check "$h: inherit counts as no model" "$std" "$(rewritten "$h" "$out" | jq -r .model)"

  out=$(hook "$h" general-purpose "$strong" "review task 1")
  check "$h: $strong passes through with no output" "" "$out"
  check "$h: $strong is logged as strong and kept" "strong kept" "$(last_log 8) $(last_log 9)"

  out=$(hook "$h" general-purpose "$frontier" "bring it all together")
  check "$h: $frontier without a reason is denied" deny "$(decision "$h" "$out")"
  case "$(reason "$h" "$out")" in *"$strong"*"Model policy: frontier because"*) r=names-strong-and-line ;; *) r=missing ;; esac
  check "$h: the denial names the strong model and the justification line" names-strong-and-line "$r"
  check "$h: the denial is logged" "frontier denied -" "$(last_log 8) $(last_log 9) $(last_log 7)"

  check "$h: $frontier with a reason passes through" "" "$(hook "$h" general-purpose "$frontier" "$JUSTIFIED")"
  check "$h: the justified dispatch is logged" justified "$(last_log 9)"
  check "$h: the legacy fable line still counts" "" "$(hook "$h" general-purpose "$frontier" "$LEGACY")"
  check "$h: a justification inside a sentence does not count" deny "$(decision "$h" "$(hook "$h" general-purpose "$frontier" "$INLINE")")"

  check "$h: an unknown model passes through" "" "$(hook "$h" general-purpose some-new-model-9 "x")"
  check "$h: an unknown model is logged as unknown" "unknown kept some-new-model-9" "$(last_log 8) $(last_log 9) $(last_log 6)"
done <<'EOF'
claude-code|Explore|haiku|sonnet|opus|fable
copilot|explore|gpt-5.4-mini|claude-sonnet-5|claude-opus-5.5|gpt-6-astra
codex|explorer|gpt-6-luna|gpt-5.6-terra|gpt-6-sol|gpt-6-astra
cursor|explore|composer-2.5|claude-sonnet-5|claude-opus-5.5|gpt-6-astra
EOF

# Harness-specific model names
check "claude-code: claude-code-guide gets haiku" haiku "$(rewritten claude-code "$(hook claude-code claude-code-guide "" x)" | jq -r .model)"
check "claude-code: best is frontier" deny "$(decision claude-code "$(hook claude-code general-purpose best x)")"
check "claude-code: a full fable id is frontier" deny "$(decision claude-code "$(hook claude-code general-purpose claude-fable-5-1 x)")"
check "claude-code: the fill output names the event" PreToolUse "$(hook claude-code Explore "" x | jq -r .hookSpecificOutput.hookEventName)"
check "codex: the fill output names the event" PreToolUse "$(hook codex explorer "" x | jq -r .hookSpecificOutput.hookEventName)"
hook copilot general-purpose gpt-5.4-mini x >/dev/null
check "copilot: gpt-5.4-mini is fast" fast "$(last_log 8)"
hook copilot general-purpose gpt-5x4 x >/dev/null
check "copilot: a dot in a pattern is literal (gpt-5x4 is not gpt-5.4)" unknown "$(last_log 8)"
check "copilot: matching ignores case" deny "$(decision copilot "$(hook copilot general-purpose GPT-6-Astra x)")"
hook cursor general-purpose 'claude-opus-4.8[effort=high]' x >/dev/null
check "cursor: a bracket suffix is ignored when classifying" strong "$(last_log 8)"
check "cursor: a bracketed frontier model is still gated" deny "$(decision cursor "$(hook cursor general-purpose 'gpt-6-astra[effort=high]' x)")"
check "cursor: a denial also tells the user" true "$(hook cursor general-purpose gpt-6-astra x | jq '.user_message | length > 0')"

# Superseded models are rewritten to their stronger, cheaper successor
out=$(hook copilot general-purpose claude-opus-5 "review task 1")
check "copilot: claude-opus-5 is rewritten to claude-opus-5.5" claude-opus-5.5 "$(rewritten copilot "$out" | jq -r .model)"
check "copilot: an upgrade is allowed" allow "$(decision copilot "$out")"
check "copilot: an upgrade keeps the prompt" "review task 1" "$(rewritten copilot "$out" | jq -r .prompt)"
case "$(reason copilot "$out")" in *"claude-opus-5 is superseded by claude-opus-5.5"*) r=names-both ;; *) r=missing ;; esac
check "copilot: the upgrade reason names both models" names-both "$r"
check "copilot: an upgrade is logged" "claude-opus-5 claude-opus-5.5 strong upgraded" "$(last_log 6) $(last_log 7) $(last_log 8) $(last_log 9)"
out=$(hook codex worker gpt-5.6-sol "review task 1")
check "codex: gpt-5.6-sol is rewritten to gpt-6-sol" gpt-6-sol "$(rewritten codex "$out" | jq -r .model)"
check "codex: an upgrade is allowed" allow "$(decision codex "$out")"
check "codex: an upgrade keeps the message" "review task 1" "$(rewritten codex "$out" | jq -r .message)"
check "cursor: an upgrade keeps the bracket suffix" 'claude-opus-5.5[effort=high]' \
  "$(rewritten cursor "$(hook cursor general-purpose 'claude-opus-5[effort=high]' x)" | jq -r .model)"
check "copilot: superseded matching ignores case" claude-opus-5.5 "$(rewritten copilot "$(hook copilot general-purpose Claude-Opus-5 x)" | jq -r .model)"
check "copilot: a successor is not itself rewritten" "" "$(hook copilot general-purpose claude-opus-5.5 x)"
check "claude-code: named models are never rewritten" "" "$(hook claude-code general-purpose opus x)"
printf '%s\n' '{"harnesses":{"copilot":{"supersededBy":{"claude-opus-5":""}}}}' >"$MODEL_POLICY_CONFIG"
check "override: an empty successor turns the rewrite off" "" "$(hook copilot general-purpose claude-opus-5 x)"
check "override: the other entries stay" gpt-6-sol "$(rewritten copilot "$(hook copilot general-purpose gpt-5.6-sol x)" | jq -r .model)"
printf '%s\n' '{"harnesses":{"copilot":{"supersededBy":{"claude-opus-5":null}}}}' >"$MODEL_POLICY_CONFIG"
check "override: a null successor turns the rewrite off" "" "$(hook copilot general-purpose claude-opus-5 x)"
printf '%s\n' '{"harnesses":{"copilot":{"supersededBy":{"gpt-6-sol":"gpt-6-astra"}}}}' >"$MODEL_POLICY_CONFIG"
check "never upgrades into the frontier tier" "" "$(hook copilot general-purpose gpt-6-sol x)"
check "a skipped upgrade is logged as kept on the named model" "gpt-6-sol strong kept" "$(last_log 7) $(last_log 8) $(last_log 9)"
rm -f "$MODEL_POLICY_CONFIG"

# Things that are not dispatches
lines=$(wc -l <"$MODEL_POLICY_LOG" | tr -d ' ')
check "claude-code: other tools are ignored" "" "$(jq -n '{tool_name:"Bash",tool_input:{command:"ls"}}' | bash "$HOOK" --harness claude-code)"
check "codex: other tools are ignored" "" "$(jq -n '{tool_name:"shell",tool_input:{command:["ls"]}}' | bash "$HOOK" --harness codex)"
check "codex: an Agent-shaped call is still a dispatch" gpt-5.6-terra "$(payload claude-code Explore "" x | bash "$HOOK" --harness codex | jq -r '.hookSpecificOutput.updatedInput.model')"
check "ignored tools write no log line" $((lines + 1)) "$(wc -l <"$MODEL_POLICY_LOG" | tr -d ' ')"
check "garbage stdin exits 0 silently" "exit=0" "$(echo 'not json' | bash "$HOOK" --harness copilot; echo "exit=$?")"
check "a JSON array on stdin exits 0 silently" "exit=0" "$(echo '[1]' | bash "$HOOK" --harness copilot; echo "exit=$?")"

# Log format
. "$ROOT/scripts/lib/config.sh"
check "the log starts with the header" "$MODEL_POLICY_LOG_HEADER" "$(head -n 1 "$MODEL_POLICY_LOG")"
check "the log records the project and short session" "proj abcdef12" "$(last_log 4) $(last_log 2)"
jq -n '{session_id:"s",cwd:"/tmp/proj",tool_name:"Agent",tool_input:{subagent_type:"Explore",prompt:"a\tb",description:"line one\nline\ttwo"}}' \
  | bash "$HOOK" --harness claude-code >/dev/null
check "tabs and newlines in the description stay on one log line" "line one line two" "$(last_log 11)"
check "every log line has 11 columns" 11 "$(awk -F'\t' '{print NF}' "$MODEL_POLICY_LOG" | sort -u | tr '\n' ' ' | tr -d ' ')"

finish
