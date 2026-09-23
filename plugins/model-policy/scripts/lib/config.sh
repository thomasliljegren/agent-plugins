# Sourced by the model-policy scripts. Needs jq.

MODEL_POLICY_LOG_HEADER=$'time\tsession\tharness\tproject\tagent_type\trequested\teffective\ttier\taction\tprompt_chars\tdescription'

model_policy_root() { (cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd); }

model_policy_log_path() {
  printf '%s\n' "${MODEL_POLICY_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/model-policy/dispatches.tsv}"
}

model_policy_override_path() {
  printf '%s\n' "${MODEL_POLICY_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/model-policy/config.json}"
}

# Prints the effective tier map: config/models.json deep-merged with the override file.
# Objects merge, arrays replace. A missing or invalid override is ignored.
model_policy_config() {
  local bundled override config merged
  bundled="$(model_policy_root)/config/models.json"
  override=$(model_policy_override_path)
  config=$(jq -ce 'select(type == "object")' "$bundled" 2>/dev/null) || return 1
  if [ -f "$override" ]; then
    merged=$(jq -ce --slurpfile o "$override" \
      'select(($o | length) == 1 and ($o[0] | type) == "object") | . * $o[0]' <<<"$config" 2>/dev/null) \
      && config=$merged
  fi
  printf '%s\n' "$config"
}
