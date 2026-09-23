#!/usr/bin/env bash
# The bundled tier map, the override merge and the defaults tables.
. "$(dirname "$0")/lib.sh"
. "$ROOT/scripts/lib/config.sh"

cfg=$(model_policy_config)
check "bundled config loads" 0 "$?"
check "four harnesses" "claude-code codex copilot cursor" "$(jq -r '.harnesses | keys | join(" ")' <<<"$cfg")"
check "every harness has the four tiers with a default and match patterns" true \
  "$(jq '[.harnesses[] | .tiers | (keys == ["fast","frontier","standard","strong"]) and all(.[]; (.default | type == "string" and length > 0) and (.match | type == "array" and length > 0))] | all' <<<"$cfg")"
check "every harness has a * agent type" true "$(jq '[.harnesses[] | .agentTypes["*"] != null] | all' <<<"$cfg")"
check "no override means the bundled map" "$(jq -c . "$ROOT/config/models.json")" "$cfg"

echo '{"harnesses":{"copilot":{"tiers":{"fast":{"default":"gpt-5-mini"}}}}}' >"$MODEL_POLICY_CONFIG"
cfg=$(model_policy_config)
check "override replaces a default" gpt-5-mini "$(jq -r '.harnesses.copilot.tiers.fast.default' <<<"$cfg")"
check "override keeps sibling match patterns" true "$(jq '.harnesses.copilot.tiers.fast.match | index("*haiku*") != null' <<<"$cfg")"
check "override leaves other harnesses alone" haiku "$(jq -r '.harnesses["claude-code"].tiers.fast.default' <<<"$cfg")"

echo '{"harnesses":{"copilot":{"tiers":{"fast":{"match":["only-this"]}}}}}' >"$MODEL_POLICY_CONFIG"
check "override arrays replace" '["only-this"]' "$(model_policy_config | jq -c '.harnesses.copilot.tiers.fast.match')"

echo 'not json' >"$MODEL_POLICY_CONFIG"
check "invalid override is ignored" claude-haiku-4.5 "$(model_policy_config | jq -r '.harnesses.copilot.tiers.fast.default')"
echo '[1,2]' >"$MODEL_POLICY_CONFIG"
check "non-object override is ignored" claude-haiku-4.5 "$(model_policy_config | jq -r '.harnesses.copilot.tiers.fast.default')"
rm -f "$MODEL_POLICY_CONFIG"

check "log path follows XDG_STATE_HOME" /x/model-policy/dispatches.tsv "$(unset MODEL_POLICY_LOG; XDG_STATE_HOME=/x model_policy_log_path)"
check "log path falls back to ~/.local/state" "$HOME/.local/state/model-policy/dispatches.tsv" "$(unset MODEL_POLICY_LOG XDG_STATE_HOME; model_policy_log_path)"
check "override path follows XDG_CONFIG_HOME" /y/model-policy/config.json "$(unset MODEL_POLICY_CONFIG; XDG_CONFIG_HOME=/y model_policy_override_path)"
check "log header has 11 columns" 11 "$(awk -F'\t' '{print NF}' <<<"$MODEL_POLICY_LOG_HEADER")"

check "tiers table first row" '| claude-code | `haiku` | `sonnet` | `opus` | `fable` |' "$(bash "$ROOT/scripts/defaults-table.sh" tiers | sed -n 3p)"
check "agent-types table first row" '| claude-code | `Explore` | fast |' "$(bash "$ROOT/scripts/defaults-table.sh" agent-types | sed -n 3p)"
bash "$ROOT/scripts/defaults-table.sh" nope >/dev/null 2>&1
check "defaults-table rejects a bad argument" 2 "$?"

finish
