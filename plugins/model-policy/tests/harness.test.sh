#!/usr/bin/env bash
# Harness detection, the env override of --harness claude-code, user overrides and debug capture.
. "$(dirname "$0")/lib.sh"

run() { bash "$HOOK" "$@"; } # stdin: payload

# Detection with no flag
check "no flag, Claude payload: Claude shape" haiku "$(payload claude-code Explore "" x | run | jq -r .hookSpecificOutput.updatedInput.model)"
check "no flag, COPILOT_CLI: Copilot shape" claude-haiku-4.5 "$(payload copilot explore "" x | COPILOT_CLI=1 run | jq -r .modifiedArgs.model)"
check "no flag, Cursor payload: Cursor shape" composer-2.5 "$(payload cursor explore "" x | run | jq -r .updated_input.model)"
check "no flag, CURSOR_VERSION: Cursor shape" composer-2.5 "$(payload claude-code explore "" x | CURSOR_VERSION=3 run | jq -r .updated_input.model)"
check "no flag, spawn_agent: Codex shape" gpt-6-luna "$(payload codex explorer "" x | run | jq -r .hookSpecificOutput.updatedInput.model)"
check "no flag, spawn_agent: logged as codex" codex "$(last_log 3)"

# The Claude hook file (--harness claude-code) loaded by another harness
check "Copilot loading the Claude hook: Copilot shape" claude-haiku-4.5 \
  "$(payload copilot explore "" x | COPILOT_CLI=1 run --harness claude-code | jq -r .modifiedArgs.model)"
check "Copilot loading the Claude hook: logged as copilot" copilot "$(last_log 3)"
check "Claude Code inside a Copilot shell stays Claude" haiku \
  "$(payload claude-code Explore "" x | COPILOT_CLI=1 run --harness claude-code | jq -r .hookSpecificOutput.updatedInput.model)"
check "Cursor loading the Claude hook: Cursor shape" deny \
  "$(payload cursor general-purpose claude-opus-5.5 x | run --harness claude-code | jq -r .permission)"
check "Claude Code inside a Cursor terminal stays Claude" haiku \
  "$(payload claude-code Explore "" x | CURSOR_VERSION=3 CURSOR_PLUGIN_ROOT=/x run --harness claude-code | jq -r .hookSpecificOutput.updatedInput.model)"

# Explicit flags win
check "--harness copilot without COPILOT_CLI" claude-sonnet-5 "$(payload copilot task "" x | run --harness copilot | jq -r .modifiedArgs.model)"
check "--harness=codex form" gpt-6-astra "$(payload codex worker "" x | run --harness=codex | jq -r .hookSpecificOutput.updatedInput.model)"
lines=$(wc -l <"$MODEL_POLICY_LOG" | tr -d ' ')
check "an unknown harness does nothing" "" "$(payload claude-code Explore "" x | run --harness foo)"
check "an unknown harness writes no log line" "$lines" "$(wc -l <"$MODEL_POLICY_LOG" | tr -d ' ')"

# User overrides (MODEL_POLICY_CONFIG)
override() { printf '%s\n' "$1" >"$MODEL_POLICY_CONFIG"; }
override '{"harnesses":{"copilot":{"tiers":{"fast":{"default":"gpt-5-mini"}}}}}'
check "override: new fast default is used" gpt-5-mini "$(hook copilot explore "" x | jq -r .modifiedArgs.model)"
override '{"harnesses":{"copilot":{"agentTypes":{"rubber-duck":"strong"}}}}'
check "override: new agent type mapping" claude-opus-5 "$(hook copilot rubber-duck "" x | jq -r .modifiedArgs.model)"
check "override: other agent types keep their mapping" claude-haiku-4.5 "$(hook copilot explore "" x | jq -r .modifiedArgs.model)"
override '{"harnesses":{"copilot":{"tiers":{"frontier":{"match":["my-big-model"]}}}}}'
check "override: a custom frontier model is gated" deny "$(decision copilot "$(hook copilot general-purpose my-big-model x)")"
check "override: match arrays replace, so the old frontier model is no longer gated" "" "$(hook copilot general-purpose claude-opus-5.5 x)"
for blank in '""' null 5; do
  override "{\"harnesses\":{\"copilot\":{\"tiers\":{\"fast\":{\"default\":$blank}}}}}"
  check "override: fast default $blank keeps the dispatch unchanged" "" "$(hook copilot explore "" x)"
  check "override: fast default $blank is logged as unknown" "unknown kept" "$(last_log 8) $(last_log 9)"
done
override '{"harnesses":{"copilot":null}}'
check "override: a removed harness block keeps the dispatch unchanged" "" "$(hook copilot explore "" x)"
check "override: a removed harness block still denies nothing" "" "$(hook copilot general-purpose claude-opus-5.5 x)"
override 'not json'
check "override: an invalid file is ignored" claude-haiku-4.5 "$(hook copilot explore "" x | jq -r .modifiedArgs.model)"
rm -f "$MODEL_POLICY_CONFIG"

# Debug capture
debug_file="$(dirname "$MODEL_POLICY_LOG")/payloads.jsonl"
hook copilot explore "" x >/dev/null
check "no capture without MODEL_POLICY_DEBUG" no "$([ -e "$debug_file" ] && echo yes || echo no)"
payload copilot explore "" x | MODEL_POLICY_DEBUG=1 run --harness copilot >/dev/null
jq -n '{tool_name:"bash",tool_input:{command:"ls"}}' | MODEL_POLICY_DEBUG=1 run --harness copilot >/dev/null
check "debug captures every payload" 2 "$(wc -l <"$debug_file" | tr -d ' ')"
check "debug records harness and payload" "copilot Agent" "$(head -n 1 "$debug_file" | jq -r '"\(.harness) \(.payload.tool_name)"')"
check "debug keeps non-dispatch payloads" bash "$(tail -n 1 "$debug_file" | jq -r .payload.tool_name)"

finish
