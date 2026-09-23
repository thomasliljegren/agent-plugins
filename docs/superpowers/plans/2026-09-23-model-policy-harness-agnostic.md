# model-policy: harness-agnostic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `plugins/model-policy` enforce the same subagent model policy on Claude Code, Copilot CLI, Codex CLI and Cursor, using the vendor-neutral tiers fast/standard/strong/frontier mapped to each harness's models through a user-overridable JSON map.

**Architecture:** A bash wrapper (`scripts/model-policy.sh`) picks the harness from `--harness` (falling back to the environment), loads the tier map through `scripts/lib/config.sh` (bundled `config/models.json` deep-merged with a user override), and hands the payload to a jq program (`scripts/policy.jq`). That program normalizes the payload, decides, and renders output in the harness's format. Each harness has its own manifest and hook file that call the wrapper with an explicit `--harness`. The skill and README take their defaults tables from the config, and a test keeps them in sync.

**Tech Stack:** bash, jq (≥1.6; developed against 1.7.1), plus the Claude Code, Copilot CLI, Codex CLI and Cursor plugin/hook formats.

**Spec:** `docs/superpowers/specs/2026-09-23-model-policy-harness-agnostic-design.md` (copied into the repo in Task 1 from the session file `files/2026-09-23-model-policy-harness-agnostic-design.md`).

All paths below are relative to the repo root `/Users/dk8ThoLi/dev/copilot-worktrees/agent-plugins/thomasliljegren-curly-train`, and `P=plugins/model-policy`.

## Global Constraints

- Runtime dependencies: bash and jq only. No jq means the hook exits 0 and does nothing.
- Hook stdout carries at most one JSON object. Every internal failure exits 0 with empty stdout, because Copilot CLI treats a non-zero exit as a deny.
- Tiers are exactly `fast`, `standard`, `strong`, `frontier`. Unmatched models get tier `unknown` and pass through.
- Classification checks tiers in the order frontier → strong → standard → fast. Patterns are case-insensitive shell globs, the first match wins, and a trailing `[...]` suffix is stripped first.
- The justification line is `Model policy: frontier because <reason>`. The legacy `Model policy: fable because <reason>` is also accepted. It must start a line, and the reason must be at least 3 characters.
- Override file: `${MODEL_POLICY_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/model-policy/config.json}`, merged with jq `*` (objects merge, arrays replace). A missing or invalid override is ignored.
- Log: `${MODEL_POLICY_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/model-policy/dispatches.tsv}`. Columns: `time session harness project agent_type requested effective tier action prompt_chars description`.
- Debug: `MODEL_POLICY_DEBUG` (any non-empty value) appends `{time, harness, payload}` lines to `payloads.jsonl` in the log's directory.
- Harness names: `claude-code`, `copilot`, `codex`, `cursor`.
- Plugin version is `0.2.0` in all four manifests, and the marketplace metadata version is `0.4.0`.
- Commits end with the trailer `Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>`.

## Review Focus

1. **An override blanks or removes a tier default, or the harness block is missing.** The hook must never emit `"model": null` or `""`. It keeps the dispatch, logs tier `unknown`, and exits 0. Pinned in Task 3.
2. **Another harness loads the Claude hook file** (`--harness claude-code` running under Copilot, with `COPILOT_CLI=1`). The output must be in Copilot's format. Claude Code launched from inside a Copilot shell (a `subagent_type` payload) must still get Claude's format. Pinned in Task 3.
3. **A prompt or description contains tabs or newlines.** The log line must stay one line with 11 columns. Pinned in Task 2.
4. **A model ID contains regex metacharacters or mixed case** (`gpt-5x4` against pattern `gpt-5.4`, or `Claude-Opus-5.5`). Matching uses glob semantics and ignores case. Pinned in Task 2.
5. **The report is pointed at an old 0.1 log (9 columns), or given a non-numeric day count.** It prints a clear message and no misparsed tables. Pinned in Task 4.

---

## File map

| File | Responsibility |
|---|---|
| `P/config/models.json` | Bundled tier map, per harness: tier defaults and match patterns, agent type → tier |
| `P/scripts/lib/config.sh` | Sourced helpers: log/override paths, log header, effective (merged) config |
| `P/scripts/policy.jq` | normalize → decide → render, plus the log record |
| `P/scripts/model-policy.sh` | Hook entrypoint: harness choice, debug capture, run policy, write log, print output |
| `P/scripts/defaults-table.sh` | Prints the effective defaults as markdown tables (`tiers`, `agent-types`) |
| `P/scripts/report.sh` | Log summary with an optional harness filter |
| `P/hooks/hooks{,-copilot,-codex,-cursor}.json` | Per-harness hook registration |
| `P/.claude-plugin/`, `P/.github/plugin/`, `P/.codex-plugin/`, `P/.cursor-plugin/` `plugin.json` | Per-harness manifests |
| `P/skills/model-policy/SKILL.md` | Portable, tier-based guidance |
| `P/commands/report.md` | Claude Code slash command |
| `P/README.md` | What it does, Defaults, Configuration, Install, Log and report, Debug, Test |
| `P/tests/run.sh` | Runs every `*.test.sh` |
| `P/tests/lib.sh` | Shared test helpers and per-harness payload fixtures |
| `P/tests/{config,hook,harness,report,packaging,docs}.test.sh` | Test files, one per concern |

### Task 1: Tier map, config loader, defaults table, test runner

**Files:**
- Create: `docs/superpowers/specs/2026-09-23-model-policy-harness-agnostic-design.md` (copy of the session spec)
- Create: `docs/superpowers/plans/2026-09-23-model-policy-harness-agnostic.md` (copy of this plan)
- Create: `P/config/models.json`, `P/scripts/lib/config.sh`, `P/scripts/defaults-table.sh`
- Move: `P/tests/run.sh` → `P/tests/hook.test.sh` (unchanged for now; Task 2 rewrites it)
- Create: `P/tests/run.sh` (runner), `P/tests/lib.sh`, `P/tests/config.test.sh`

**Interfaces:**
- Produces (sourced from `scripts/lib/config.sh`):
  - `MODEL_POLICY_LOG_HEADER`: the TSV header string (11 tab-separated columns)
  - `model_policy_root`: prints the absolute plugin root
  - `model_policy_log_path`: prints the log path
  - `model_policy_override_path`: prints the override path
  - `model_policy_config`: prints the merged config as one-line JSON; returns 1 if the bundled file is unreadable
- Produces: `bash scripts/defaults-table.sh tiers|agent-types` prints markdown tables (exit 2 on a bad argument)
- Produces (sourced from `tests/lib.sh`): `ROOT`, `HOOK`, `SCRATCH`, `check NAME EXPECTED ACTUAL`, `finish`. It exports an isolated `MODEL_POLICY_LOG` and `MODEL_POLICY_CONFIG`, and unsets the `COPILOT_CLI`, `CURSOR_VERSION`, `CURSOR_PLUGIN_ROOT` and `MODEL_POLICY_DEBUG` variables.

- [ ] **Step 1: Copy the spec and plan into the repo**

```bash
mkdir -p docs/superpowers/specs docs/superpowers/plans
cp /Users/dk8ThoLi/.copilot/session-state/add02b30-798a-4134-b84b-b91835b87009/files/2026-09-23-model-policy-harness-agnostic-design.md docs/superpowers/specs/
cp /Users/dk8ThoLi/.copilot/session-state/add02b30-798a-4134-b84b-b91835b87009/plan.md docs/superpowers/plans/2026-09-23-model-policy-harness-agnostic.md
```

- [ ] **Step 2: Move the old test and create the runner and helpers**

```bash
git mv plugins/model-policy/tests/run.sh plugins/model-policy/tests/hook.test.sh
```

`P/tests/run.sh`:

```bash
#!/usr/bin/env bash
# Runs every model-policy test file. Run: bash plugins/model-policy/tests/run.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
status=0
for t in "$HERE"/*.test.sh; do
  echo "== $(basename "$t")"
  bash "$t" || status=1
done
if [ $status -eq 0 ]; then echo "ALL PASSED"; else echo "SOME FAILED"; exit 1; fi
```

`P/tests/lib.sh`:

```bash
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
```

- [ ] **Step 3: Write the failing config test**

`P/tests/config.test.sh`:

```bash
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
```

- [ ] **Step 4: Run it to verify it fails**

Run: `bash plugins/model-policy/tests/config.test.sh`
Expected: error sourcing `scripts/lib/config.sh` (No such file), then FAIL lines.

- [ ] **Step 5: Write the tier map**

`P/config/models.json`:

```json
{
  "harnesses": {
    "claude-code": {
      "tiers": {
        "fast":     { "default": "haiku",  "match": ["haiku", "*haiku*"] },
        "standard": { "default": "sonnet", "match": ["sonnet", "*sonnet*"] },
        "strong":   { "default": "opus",   "match": ["opus", "*opus*"] },
        "frontier": { "default": "fable",  "match": ["fable", "best", "*fable*", "*mythos*"] }
      },
      "agentTypes": { "Explore": "fast", "claude-code-guide": "fast", "*": "standard" }
    },
    "copilot": {
      "tiers": {
        "fast":     { "default": "claude-haiku-4.5", "match": ["*haiku*", "*-mini", "*flash*", "*luna*"] },
        "standard": { "default": "claude-sonnet-5",  "match": ["*sonnet*", "gpt-5.6-terra", "gpt-5.5", "gpt-5.4", "*codex*"] },
        "strong":   { "default": "claude-opus-5",    "match": ["claude-opus-5", "claude-opus-4.*", "gpt-5.6-sol", "gpt-6-astra"] },
        "frontier": { "default": "claude-opus-5.5",  "match": ["claude-opus-5.5", "gpt-6-sol", "*fable*", "*mythos*"] }
      },
      "agentTypes": { "explore": "fast", "*": "standard" }
    },
    "codex": {
      "tiers": {
        "fast":     { "default": "gpt-6-luna",  "match": ["gpt-6-luna", "*-mini", "*luna*"] },
        "standard": { "default": "gpt-6-astra", "match": ["gpt-6-astra"] },
        "strong":   { "default": "gpt-5.6-sol", "match": ["gpt-5.6-sol"] },
        "frontier": { "default": "gpt-6-sol",   "match": ["gpt-6-sol"] }
      },
      "agentTypes": { "explorer": "fast", "*": "standard" }
    },
    "cursor": {
      "tiers": {
        "fast":     { "default": "composer-2.5",    "match": ["composer-*", "*haiku*", "*-mini", "*flash*", "*luna*"] },
        "standard": { "default": "claude-sonnet-5", "match": ["*sonnet*", "gpt-5.6-terra"] },
        "strong":   { "default": "claude-opus-5",   "match": ["claude-opus-5", "claude-opus-4*", "gpt-5.6-sol"] },
        "frontier": { "default": "claude-opus-5.5", "match": ["claude-opus-5.5", "gpt-6-sol", "*fable*", "*mythos*"] }
      },
      "agentTypes": { "explore": "fast", "*": "standard" }
    }
  }
}
```

- [ ] **Step 6: Write the config loader**

`P/scripts/lib/config.sh`:

```bash
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
```

- [ ] **Step 7: Write the defaults table script**

`P/scripts/defaults-table.sh`:

```bash
#!/usr/bin/env bash
# Prints the effective tier map (bundled defaults plus your override) as markdown tables.
# Run: bash scripts/defaults-table.sh [tiers|agent-types]
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$HERE/lib/config.sh"
CONFIG=$(model_policy_config) || { echo "cannot read config/models.json" >&2; exit 1; }
case "${1:-tiers}" in
  tiers)
    jq -r '
      "| Harness | fast | standard | strong | frontier |",
      "|---|---|---|---|---|",
      (.harnesses | to_entries[]
        | "| \(.key) | " + ([.value.tiers[("fast", "standard", "strong", "frontier")].default | "`\(.)`"] | join(" | ")) + " |")' <<<"$CONFIG"
    ;;
  agent-types)
    jq -r '
      "| Harness | Agent type | Tier |",
      "|---|---|---|",
      (.harnesses | to_entries[] | .key as $h | .value.agentTypes | to_entries[]
        | "| \($h) | `\(.key)` | \(.value) |")' <<<"$CONFIG"
    ;;
  *)
    echo "usage: defaults-table.sh [tiers|agent-types]" >&2
    exit 2
    ;;
esac
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `bash plugins/model-policy/tests/run.sh`
Expected: `config.test.sh` all `ok`, and `hook.test.sh` (the old suite, still against the old script) `all passed`, ending in `ALL PASSED`.

- [ ] **Step 9: Commit**

```bash
git add docs/superpowers plugins/model-policy/config plugins/model-policy/scripts/lib plugins/model-policy/scripts/defaults-table.sh plugins/model-policy/tests
git commit -m "model-policy: add tier map, config loader and test runner

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: Harness-neutral policy core (normalize → decide → render) and log

**Files:**
- Create: `P/scripts/policy.jq`
- Rewrite: `P/scripts/model-policy.sh`
- Modify: `P/tests/lib.sh` (append the payload fixtures and output readers)
- Rewrite: `P/tests/hook.test.sh`

**Interfaces:**
- Consumes: `model_policy_config`, `model_policy_log_path`, `MODEL_POLICY_LOG_HEADER` (Task 1).
- Produces: `bash scripts/model-policy.sh --harness H < payload` → prints zero or one JSON object and always exits 0. In this task `H` defaults to `claude-code` when no flag is given; Task 3 adds detection.
- Produces: `jq -c --arg harness H --argjson config CFG -f scripts/policy.jq` → `{"skip":true}`, or `{"skip":false,"record":{session,project,agent_type,requested,effective,tier,action,prompt_chars,description},"output":<object|null>}`.
- Produces (in `tests/lib.sh`): `payload H AGENT_TYPE MODEL PROMPT` (an empty MODEL omits the field), `hook H AGENT_TYPE MODEL PROMPT`, `decision H OUT`, `reason H OUT`, `rewritten H OUT`, `last_log FIELD`.

- [ ] **Step 1: Append the fixtures to `P/tests/lib.sh`**

```bash

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
```

- [ ] **Step 2: Rewrite `P/tests/hook.test.sh` (failing test)**

```bash
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
  fill_decision=allow; [ "$h" = codex ] && fill_decision=""  # Codex gets updatedInput only
  check "$h: a fill is allowed" "$fill_decision" "$(decision "$h" "$out")"
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
copilot|explore|claude-haiku-4.5|claude-sonnet-5|claude-opus-5|claude-opus-5.5
codex|explorer|gpt-6-luna|gpt-6-astra|gpt-5.6-sol|gpt-6-sol
cursor|explore|composer-2.5|claude-sonnet-5|claude-opus-5|claude-opus-5.5
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
check "copilot: matching ignores case" deny "$(decision copilot "$(hook copilot general-purpose Claude-Opus-5.5 x)")"
hook cursor general-purpose 'claude-opus-5[effort=high]' x >/dev/null
check "cursor: a bracket suffix is ignored when classifying" strong "$(last_log 8)"
check "cursor: a bracketed frontier model is still gated" deny "$(decision cursor "$(hook cursor general-purpose 'claude-opus-5.5[effort=high]' x)")"
check "cursor: a denial also tells the user" true "$(hook cursor general-purpose claude-opus-5.5 x | jq '.user_message | length > 0')"

# Things that are not dispatches
lines=$(wc -l <"$MODEL_POLICY_LOG" | tr -d ' ')
check "claude-code: other tools are ignored" "" "$(jq -n '{tool_name:"Bash",tool_input:{command:"ls"}}' | bash "$HOOK" --harness claude-code)"
check "codex: other tools are ignored" "" "$(jq -n '{tool_name:"shell",tool_input:{command:["ls"]}}' | bash "$HOOK" --harness codex)"
check "codex: an Agent-shaped call is still a dispatch" gpt-6-astra "$(payload claude-code Explore "" x | bash "$HOOK" --harness codex | jq -r '.hookSpecificOutput.updatedInput.model')"
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
```

- [ ] **Step 3: Run it to verify it fails**

Run: `bash plugins/model-policy/tests/hook.test.sh`
Expected: many FAIL lines (the old script ignores `--harness`, knows no tiers, and writes 9 columns).

- [ ] **Step 4: Write `P/scripts/policy.jq`**

```jq
# model-policy decision core. Input: one hook payload. Args: --arg harness H --argjson config CFG.
# Output: {"skip":true} for non-dispatch calls, else {"skip":false,"record":{...},"output":<object|null>}.

def tier_order: ["frontier", "strong", "standard", "fast"];
def dispatch_tools: {
  "claude-code": ["Agent", "Task"],
  "copilot": ["Agent", "Task", "task"],
  "codex": ["spawn_agent", "Agent"],
  "cursor": ["Task", "Agent"]
};

def str: if type == "string" then . else "" end;
def oneline: str | gsub("[\t\r\n]+"; " ");
def glob_re: "^" + (gsub("(?<c>[.+^${}()|\\[\\]\\\\])"; "\\\(.c)") | gsub("\\*"; ".*") | gsub("\\?"; ".")) + "$";
def glob_match($p): ascii_downcase | test($p | ascii_downcase | glob_re);
def base_model: sub("\\[[^\\]]*\\]$"; "");
def justified: test("(^|\n)[ \t]*model policy: *(frontier|fable) because [^\n]{3,}"; "i");

def h: ($config.harnesses[$harness] // {}) | if type == "object" then . else {} end;
def tier_default($t): h.tiers[$t].default // "" | str;
def classify($m):
  ($m | base_model) as $b
  | first(tier_order[] as $t
      | select(any((h.tiers[$t].match // [])[] | strings; . as $p | $b | glob_match($p)))
      | $t) // "unknown";
def agent_tier($type): h.agentTypes[$type] // h.agentTypes["*"] // "standard" | str;

def tool_input:
  (.tool_input // .toolArgs // {})
  | if type == "string" then (try fromjson catch {}) else . end
  | if type == "object" then . else {} end;

def normalize:
  tool_input as $in
  | {
      tool: (.tool_name // .toolName // "" | str),
      in: $in,
      agent_type: ($in.subagent_type // $in.agent_type // $in.subagentType // "" | str),
      model: ($in.model // $in.subagent_model // "" | str),
      prompt: ($in.prompt // $in.message // $in.task // "" | str),
      description: ($in.description // $in.task_name // $in.name // "" | str),
      session: (.session_id // .sessionId // .conversation_id // "" | str | .[0:8]),
      project: (.cwd // (.workspace_roots // [])[0] // "" | str | sub("/+$"; "") | split("/") | last // "")
    };

def decide:
  normalize as $n
  | if ((dispatch_tools[$harness] // []) | index($n.tool)) == null then {skip: true}
    else
      ($n.model | if . == "inherit" then "" else . end) as $req
      | $n + {skip: false, requested: $n.model}
      + if $req == "" then
          agent_tier($n.agent_type) as $t
          | tier_default($t) as $d
          | if $d == "" then {effective: "", tier: "unknown", action: "kept"}
            else {effective: $d, tier: $t, action: "filled"} end
        else
          classify($req) as $t
          | if $t != "frontier" then {effective: $req, tier: $t, action: "kept"}
            elif $n.prompt | justified then {effective: $req, tier: $t, action: "justified"}
            else {effective: "-", tier: $t, action: "denied"} end
        end
    end;

def fill_reason($d):
  "model-policy: no model named, \(if $d.agent_type == "" then "subagent" else $d.agent_type end) runs on \($d.effective) (\($d.tier) tier)";

def deny_reason($d):
  "model-policy: subagents do not run on \($d.requested) (frontier tier) without a reason. "
  + "Re-dispatch on \(tier_default("strong")) (strong tier: judgement, review, fix rounds) "
  + "or \(tier_default("standard")) (standard tier: implementation from a plan, verification against a spec). "
  + "Use the frontier tier only for the pass that brings several rounds of subagent work together or verifies the whole, "
  + "and then add this line to the prompt: \"Model policy: frontier because <reason>\".";

def render($d):
  if $d.action == "filled" then
    ($d.in + {model: $d.effective}) as $u | fill_reason($d) as $r
    | if $harness == "copilot" then {permissionDecision: "allow", permissionDecisionReason: $r, modifiedArgs: $u}
      elif $harness == "cursor" then {permission: "allow", updated_input: $u}
      elif $harness == "codex" then {hookSpecificOutput: {hookEventName: "PreToolUse", updatedInput: $u}}
      else {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", permissionDecisionReason: $r, updatedInput: $u}}
      end
  elif $d.action == "denied" then
    deny_reason($d) as $r
    | if $harness == "copilot" then {permissionDecision: "deny", permissionDecisionReason: $r}
      elif $harness == "cursor" then {permission: "deny", user_message: $r, agent_message: $r}
      else {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}
      end
  else null
  end;

def record($d):
  $d
  | {session, project, agent_type, requested, effective, tier, action, description}
  | map_values(oneline | if . == "" then "-" else . end)
  | .prompt_chars = ($d.prompt | length);

decide as $d
| if $d.skip then {skip: true}
  else {skip: false, record: record($d), output: render($d)}
  end
```

- [ ] **Step 5: Rewrite `P/scripts/model-policy.sh`**

```bash
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
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bash plugins/model-policy/tests/run.sh`
Expected: `config.test.sh` and `hook.test.sh` all `ok`, then `ALL PASSED`. If a check fails, fix `policy.jq` or the script. Do not weaken the test.

- [ ] **Step 7: Commit**

```bash
git add plugins/model-policy/scripts plugins/model-policy/tests
git commit -m "model-policy: harness-neutral policy core with tiers

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

### Task 3: Harness detection, env override and debug capture

**Files:**
- Modify: `P/scripts/model-policy.sh`
- Create: `P/tests/harness.test.sh`

**Interfaces:**
- Consumes: the `payload`, `hook`, `decision`, `rewritten` and `last_log` helpers (Task 2), and `model_policy_log_path` (Task 1).
- Produces: `detect_harness FLAG PAYLOAD` inside `model-policy.sh`, which prints the effective harness. The rules:
  1. **No flag:** `COPILOT_CLI` set → `copilot`. Otherwise a Cursor payload (`conversation_id` or `workspace_roots`) or `CURSOR_VERSION`/`CURSOR_PLUGIN_ROOT` set → `cursor`. Otherwise `tool_name == "spawn_agent"` → `codex`. Otherwise `claude-code`.
  2. **`--harness claude-code`:** a Cursor-shaped payload → `cursor`. Otherwise, `COPILOT_CLI` set and `tool_input` without `subagent_type` → `copilot`. Otherwise `claude-code`. This covers Cursor and Copilot loading the Claude hook file, and Claude Code running in a Copilot or Cursor terminal.
  3. **Any other flag** is used as given.
- Produces: `MODEL_POLICY_DEBUG` non-empty → one `{time, harness, payload}` line per object payload, appended to `$(dirname log)/payloads.jsonl` before the policy runs.

Deviation note: the spec detects Cursor with `CURSOR_VERSION`. The plan detects it from the payload shape (plus the env vars only when no flag is given). A Claude Code session started in Cursor's integrated terminal may inherit Cursor env vars, and Claude Code would silently ignore a Cursor-shaped reply.

- [ ] **Step 1: Write the failing test**

`P/tests/harness.test.sh`:

```bash
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/model-policy/tests/harness.test.sh`
Expected: FAIL on the detection, env override and debug checks. The override checks already pass after Task 2, which is fine: they pin behaviour.

- [ ] **Step 3: Add detection and debug capture to `P/scripts/model-policy.sh`**

Insert after the `. "$HERE/lib/config.sh" || exit 0` line:

```bash

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
```

Replace the line `[ -n "$harness" ] || harness=claude-code` with:

```bash
harness=$(detect_harness "$harness" "$payload")

if [ -n "${MODEL_POLICY_DEBUG:-}" ]; then
  {
    debug_dir=$(dirname "$(model_policy_log_path)") &&
      mkdir -p "$debug_dir" &&
      jq -c --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg harness "$harness" \
        '{time: $time, harness: $harness, payload: .}' <<<"$payload" >>"$debug_dir/payloads.jsonl"
  } 2>/dev/null || true
fi
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash plugins/model-policy/tests/run.sh`
Expected: all files pass, then `ALL PASSED`.

- [ ] **Step 5: Commit**

```bash
git add plugins/model-policy/scripts/model-policy.sh plugins/model-policy/tests/harness.test.sh
git commit -m "model-policy: detect the harness and add debug capture

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

### Task 4: Report on the new log

**Files:**
- Rewrite: `P/scripts/report.sh`
- Modify: `P/commands/report.md`
- Create: `P/tests/report.test.sh`

**Interfaces:**
- Consumes: `model_policy_log_path`, `MODEL_POLICY_LOG_HEADER` (Task 1), and the `hook` helper (Task 2).
- Produces: `bash scripts/report.sh [days] [harness]`. It exits 2 if days is not a whole number. It prints a one-line message and exits 0 when the log is missing or has another header. Each section line is `  %5d  <key>`.

- [ ] **Step 1: Write the failing test**

`P/tests/report.test.sh`:

```bash
#!/usr/bin/env bash
# scripts/report.sh on the 0.2 log.
. "$(dirname "$0")/lib.sh"
REPORT="$ROOT/scripts/report.sh"

case "$(bash "$REPORT")" in "No dispatches logged yet"*) r=empty ;; *) r=other ;; esac
check "no log yet" empty "$r"

hook copilot explore "" x >/dev/null
hook copilot general-purpose claude-opus-5.5 "bring it together" >/dev/null
hook codex explorer "" x >/dev/null
printf '2000-01-01T00:00:00Z\tsess0000\tclaude-code\tproj\tExplore\t-\thaiku\tfast\tfilled\t1\told\n' >>"$MODEL_POLICY_LOG"

out=$(bash "$REPORT" 14)
check "total in the window" yes "$(grep -qx 'Total dispatches: 3' <<<"$out" && echo yes)"
check "by harness" yes "$(grep -qx '      2  copilot' <<<"$out" && echo yes)"
check "by tier" yes "$(grep -qx '      2  fast' <<<"$out" && echo yes)"
check "by action" yes "$(grep -qx '      1  denied' <<<"$out" && echo yes)"
check "by harness, agent type and model" yes "$(grep -qx '      1  codex explorer -> gpt-6-luna' <<<"$out" && echo yes)"
check "frontier section lists the denial" yes "$(grep -q 'denied.*claude-opus-5.5' <<<"$out" && echo yes)"
out=$(bash "$REPORT" 14 copilot)
check "harness filter" yes "$(grep -qx 'Total dispatches: 2' <<<"$out" && echo yes)"
out=$(bash "$REPORT" 36500)
check "a wider window includes old rows" yes "$(grep -qx 'Total dispatches: 4' <<<"$out" && echo yes)"

bash "$REPORT" abc >/dev/null 2>&1
check "non-numeric days is rejected" 2 "$?"

printf 'time\tsession\tproject\tagent_type\trequested\teffective\taction\tprompt_chars\tdescription\n' >"$MODEL_POLICY_LOG"
out=$(bash "$REPORT" 14); status=$?
check "an 0.1 log exits 0" 0 "$status"
case "$out" in *"not a model-policy 0.2 log"*) r=explained ;; *) r=other ;; esac
check "an 0.1 log is explained" explained "$r"
check "an 0.1 log prints no tables" no "$(grep -q 'Total dispatches' <<<"$out" && echo yes || echo no)"

finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/model-policy/tests/report.test.sh`
Expected: FAIL (the old report reads `~/.claude/logs/model-policy.tsv` and the old columns).

- [ ] **Step 3: Rewrite `P/scripts/report.sh`**

```bash
#!/usr/bin/env bash
# Summarises the model-policy log. Run: bash scripts/report.sh [days] [harness]
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$HERE/lib/config.sh"
LOG=$(model_policy_log_path)
DAYS=${1:-14}
HARNESS=${2:-}
case "$DAYS" in
  '' | *[!0-9]*) echo "usage: report.sh [days] [harness] (days is a whole number)" >&2; exit 2 ;;
esac
if [ ! -s "$LOG" ]; then
  echo "No dispatches logged yet ($LOG). The hook writes a line per subagent dispatch while the plugin is enabled."
  exit 0
fi
if [ "$(head -n 1 "$LOG")" != "$MODEL_POLICY_LOG_HEADER" ]; then
  echo "$LOG is not a model-policy 0.2 log (its header differs; 0.1 logs had 9 columns). Move it away or set MODEL_POLICY_LOG to a new file."
  exit 0
fi

SINCE=$(date -u -v-"${DAYS}"d +%Y-%m-%d 2>/dev/null || date -u -d "-${DAYS} days" +%Y-%m-%d)
ROWS=$(mktemp "${TMPDIR:-/tmp}/model-policy-report.XXXXXX") || exit 1
trap 'rm -f "$ROWS"' EXIT
# Columns: 1 time, 2 session, 3 harness, 4 project, 5 agent_type, 6 requested, 7 effective, 8 tier, 9 action, 10 prompt_chars, 11 description
awk -F'\t' -v since="$SINCE" -v h="$HARNESS" 'NR > 1 && substr($1, 1, 10) >= since && (h == "" || $3 == h)' "$LOG" >"$ROWS"

section() { # TITLE AWK_KEY [SORT_ARGS]
  echo
  echo "$1:"
  awk -F'\t' "{ c[$2]++ } END { for (k in c) printf \"  %5d  %s\\n\", c[k], k }" "$ROWS" | sort ${3:--rn}
}

echo "model-policy dispatches since $SINCE, ${HARNESS:-all harnesses} ($LOG)"
echo
echo "Total dispatches: $(wc -l <"$ROWS" | tr -d ' ')"
section "By harness" '$3'
section "By tier (fast, standard, strong, frontier; unknown = model not in the tier map)" '$8'
section "By effective model" '$7'
section "By action (kept = caller named the model, filled = hook chose it, denied = frontier without a reason, justified = frontier with a reason)" '$9'
section "By harness, agent type and effective model" '$3 " " $5 " -> " $7'
section "By day" 'substr($1, 1, 10)' '-k2'
echo
echo "Frontier dispatches and their reasons (justified or denied):"
awk -F'\t' '$8 == "frontier" { printf "  %s %-11s %-9s %-16s %s\n", substr($1, 1, 16), $3, $9, $6, $11 }' "$ROWS"
```

- [ ] **Step 4: Update `P/commands/report.md`**

```markdown
---
description: Summarise the subagent dispatches the model-policy hook has logged (by harness, tier, model, action, agent type and day)
allowed-tools: Bash(bash *)
---
Here is the model-policy log summary for the last 14 days:

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/report.sh" 14`

Relay the tables above to the user as they are, then say in two or three sentences whether the policy is doing anything: how many dispatches the hook filled or denied, and which tier carries most of the subagent work. Do not speculate about token savings; the log records dispatches, not tokens.
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash plugins/model-policy/tests/run.sh`
Expected: `ALL PASSED`.

- [ ] **Step 6: Commit**

```bash
git add plugins/model-policy/scripts/report.sh plugins/model-policy/commands/report.md plugins/model-policy/tests/report.test.sh
git commit -m "model-policy: report by harness and tier

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

### Task 5: Per-harness manifests and hook files

**Files:**
- Modify: `P/.claude-plugin/plugin.json` (version, description), `P/hooks/hooks.json` (add `--harness claude-code`)
- Create: `P/.github/plugin/plugin.json`, `P/.codex-plugin/plugin.json`, `P/.cursor-plugin/plugin.json`
- Create: `P/hooks/hooks-copilot.json`, `P/hooks/hooks-codex.json`, `P/hooks/hooks-cursor.json`
- Create: `P/tests/packaging.test.sh`

**Interfaces:**
- Consumes: `payload`, `decision`, `rewritten` (Task 2).
- Produces: the manifest and hook paths the docs refer to in Task 6.

- [ ] **Step 1: Write the failing test**

`P/tests/packaging.test.sh`:

```bash
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/model-policy/tests/packaging.test.sh`
Expected: FAIL (missing manifests and hook files, version 0.1.0).

- [ ] **Step 3: Write the manifests**

`P/.claude-plugin/plugin.json`:

```json
{
  "name": "model-policy",
  "description": "Keeps subagents on the cheapest model tier that fits, on Claude Code, Copilot CLI, Codex CLI and Cursor: fills a missing model by agent type, requires a written reason for a frontier-tier subagent, and logs every dispatch so the effect can be measured.",
  "version": "0.2.0",
  "author": {
    "name": "Thomas Liljegren",
    "email": "thliljegren@gmail.com"
  },
  "keywords": ["subagents", "model", "cost", "tokens", "hooks"]
}
```

`P/.github/plugin/plugin.json` (read by Copilot CLI before `.claude-plugin/plugin.json`):

```json
{
  "name": "model-policy",
  "description": "Keeps subagents on the cheapest model tier that fits, on Claude Code, Copilot CLI, Codex CLI and Cursor: fills a missing model by agent type, requires a written reason for a frontier-tier subagent, and logs every dispatch so the effect can be measured.",
  "version": "0.2.0",
  "author": {
    "name": "Thomas Liljegren",
    "email": "thliljegren@gmail.com"
  },
  "keywords": ["subagents", "model", "cost", "tokens", "hooks"],
  "hooks": "hooks/hooks-copilot.json"
}
```

`P/.codex-plugin/plugin.json`:

```json
{
  "name": "model-policy",
  "description": "Keeps subagents on the cheapest model tier that fits, on Claude Code, Copilot CLI, Codex CLI and Cursor: fills a missing model by agent type, requires a written reason for a frontier-tier subagent, and logs every dispatch so the effect can be measured.",
  "version": "0.2.0",
  "author": {
    "name": "Thomas Liljegren",
    "email": "thliljegren@gmail.com"
  },
  "keywords": ["subagents", "model", "cost", "tokens", "hooks"],
  "skills": "./skills/",
  "hooks": "./hooks/hooks-codex.json"
}
```

`P/.cursor-plugin/plugin.json`:

```json
{
  "name": "model-policy",
  "description": "Keeps subagents on the cheapest model tier that fits, on Claude Code, Copilot CLI, Codex CLI and Cursor: fills a missing model by agent type, requires a written reason for a frontier-tier subagent, and logs every dispatch so the effect can be measured.",
  "version": "0.2.0",
  "author": {
    "name": "Thomas Liljegren",
    "email": "thliljegren@gmail.com"
  },
  "keywords": ["subagents", "model", "cost", "tokens", "hooks"],
  "skills": "./skills/",
  "hooks": "./hooks/hooks-cursor.json"
}
```

- [ ] **Step 4: Write the hook files**

`P/hooks/hooks.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/model-policy.sh\" --harness claude-code",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

`P/hooks/hooks-copilot.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/model-policy.sh\" --harness copilot",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

`P/hooks/hooks-codex.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "spawn_agent",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${PLUGIN_ROOT}/scripts/model-policy.sh\" --harness codex",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

`P/hooks/hooks-cursor.json`:

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      {
        "command": "bash ./scripts/model-policy.sh --harness cursor",
        "matcher": "Task"
      }
    ]
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash plugins/model-policy/tests/run.sh`
Expected: `ALL PASSED`.

- [ ] **Step 6: Commit**

```bash
git add plugins/model-policy/.claude-plugin plugins/model-policy/.github plugins/model-policy/.codex-plugin plugins/model-policy/.cursor-plugin plugins/model-policy/hooks plugins/model-policy/tests/packaging.test.sh
git commit -m "model-policy: ship manifests and hooks for Copilot CLI, Codex CLI and Cursor

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

### Task 6: Skill, README, repo docs and marketplace

**Files:**
- Rewrite: `P/skills/model-policy/SKILL.md`, `P/README.md`
- Modify: `README.md`, `docs/INSTALL.md`, `.claude-plugin/marketplace.json`
- Create: `P/tests/docs.test.sh`

**Interfaces:**
- Consumes: `bash scripts/defaults-table.sh tiers|agent-types` (Task 1) and the manifest and hook paths (Task 5).
- Produces: docs whose generated tables sit between `<!-- defaults:tiers:begin -->` / `<!-- defaults:tiers:end -->` and `<!-- defaults:agent-types:begin -->` / `<!-- defaults:agent-types:end -->`. After any change to `config/models.json`, regenerate them with `bash plugins/model-policy/scripts/defaults-table.sh` (run with `MODEL_POLICY_CONFIG=/nonexistent`, so a local override doesn't leak in).

Before writing the install section, verify the doc URLs with `web_fetch`, and check the Copilot commands with `copilot plugin --help` and `copilot plugin install --help`. Use these URLs, or the page each one redirects to:
- Copilot: `https://docs.github.com/copilot/concepts/agents/copilot-cli/about-cli-plugins`
- Codex: `https://developers.openai.com/codex/plugins`
- Cursor: `https://cursor.com/docs/plugins`

If a URL is dead, search the vendor's docs for the plugins page. Don't invent install commands for Codex or Cursor: say "install the plugin directory `plugins/model-policy` as described in <link>".

- [ ] **Step 1: Write the failing test**

`P/tests/docs.test.sh`:

```bash
#!/usr/bin/env bash
# The docs agree with the config and name every setting.
. "$(dirname "$0")/lib.sh"
REPO=$(cd "$ROOT/../.." && pwd)
README="$ROOT/README.md"
SKILL="$ROOT/skills/model-policy/SKILL.md"

between() { awk -v b="<!-- defaults:$2:begin -->" -v e="<!-- defaults:$2:end -->" '$0 == e {f = 0} f && NF {print} $0 == b {f = 1}' "$1"; }

tiers=$(bash "$ROOT/scripts/defaults-table.sh" tiers)
types=$(bash "$ROOT/scripts/defaults-table.sh" agent-types)
check "README tier table matches config/models.json" "$tiers" "$(between "$README" tiers)"
check "README agent type table matches config/models.json" "$types" "$(between "$README" agent-types)"
check "SKILL tier table matches config/models.json" "$tiers" "$(between "$SKILL" tiers)"

for v in MODEL_POLICY_CONFIG MODEL_POLICY_LOG MODEL_POLICY_DEBUG XDG_CONFIG_HOME XDG_STATE_HOME CLAUDE_CODE_SUBAGENT_MODEL; do
  check "README documents $v" yes "$(grep -q "$v" "$README" && echo yes)"
done
for h in "Claude Code" "Copilot CLI" "Codex CLI" "Cursor"; do
  check "README has install notes for $h" yes "$(grep -q "^### $h" "$README" && echo yes)"
done
bad=0
while IFS= read -r block; do jq -e . >/dev/null 2>&1 <<<"$block" || bad=$((bad + 1)); done < <(
  awk '/^```json$/ {f = 1; b = ""; next} /^```$/ && f {f = 0; gsub(/\n/, " ", b); print b; next} f {b = b "\n" $0}' "$README")
check "every json block in the README parses" 0 "$bad"
check "README has worked override examples" yes "$([ "$(grep -c '^```json$' "$README")" -ge 3 ] && echo yes)"

description=$(awk '/^description:/ {sub(/^description: */, ""); print; exit}' "$SKILL")
for tool in Agent task spawn_agent Task; do
  case " $description " in *"$tool"*) r=yes ;; *) r=no ;; esac
  check "SKILL description names the $tool tool" yes "$r"
done
for f in "$README" "$SKILL"; do
  check "$(basename "$f") shows the justification line" yes "$(grep -q 'Model policy: frontier because <reason>' "$f" && echo yes)"
done

check "marketplace metadata version" 0.4.0 "$(jq -r .metadata.version "$REPO/.claude-plugin/marketplace.json")"
case "$(jq -r '.plugins[] | select(.name == "model-policy") | .description' "$REPO/.claude-plugin/marketplace.json")" in
  *tier*Copilot*) r=yes ;; *) r=no ;;
esac
check "marketplace description uses tiers and names other harnesses" yes "$r"
check "repo README says model-policy covers four harnesses" yes "$(grep 'model-policy' "$REPO/README.md" | grep -q 'Codex' && echo yes)"
check "INSTALL.md mentions model-policy hooks" yes "$(grep -q 'model-policy' "$REPO/docs/INSTALL.md" && echo yes)"

finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/model-policy/tests/docs.test.sh`
Expected: FAIL (no markers, no env var docs, marketplace 0.3.0).

- [ ] **Step 3: Rewrite `P/skills/model-policy/SKILL.md`**

````markdown
---
name: model-policy
description: Which model to name when dispatching a subagent (the Agent tool in Claude Code, task in Copilot CLI, spawn_agent in Codex CLI, Task in Cursor, or a workflow agent() call), so the cheapest model tier that fits does the work. Use whenever you are about to dispatch, re-dispatch or escalate a subagent, or when a dispatch was denied with a model-policy reason.
---

# Model policy for subagents

The main conversation runs on a capable model. Subagents should not, unless there is a reason. Pick a tier for the work, then name that tier's model on the dispatch. If you name no model, the model-policy hook (where it is installed) fills in the tier default for the agent type: the fast tier for exploring and reading agents, standard for everything else. That is fine for reading, but it is not a choice.

| Work | Tier | Why |
|---|---|---|
| Reading, searching, looking things up, summarising files or docs | fast | No judgement needed, output is facts |
| Implementing from a plan that contains the code, running tests, verifying against a spec | standard | The plan carries the judgement; the subagent transcribes and checks |
| Reviewing, debugging, fix rounds 4 and 5, planning a task, anything that needs to weigh options | strong | Judgement without the frontier price |
| The one pass that brings several rounds of subagent work together, or verifies the whole against the original intent | frontier | Only when the pieces have to be held in one head |

Default model per tier (the user may have changed these in `~/.config/model-policy/config.json`):

<!-- defaults:tiers:begin -->
| Harness | fast | standard | strong | frontier |
|---|---|---|---|---|
| claude-code | `haiku` | `sonnet` | `opus` | `fable` |
| copilot | `claude-haiku-4.5` | `claude-sonnet-5` | `claude-opus-5` | `claude-opus-5.5` |
| codex | `gpt-6-luna` | `gpt-6-astra` | `gpt-5.6-sol` | `gpt-6-sol` |
| cursor | `composer-2.5` | `claude-sonnet-5` | `claude-opus-5` | `claude-opus-5.5` |
<!-- defaults:tiers:end -->

Other models your harness offers belong to the tier of the closest model above: small, mini, flash and luna models are fast; the flagship of a vendor's current generation is frontier.

The hook denies a frontier-tier dispatch unless the prompt has this on a line of its own:

```
Model policy: frontier because <reason>
```

Write that line only for the integration or whole-verification pass. If a denial comes back for anything else, re-dispatch on the strong or standard tier. Do not add the line just to get past the gate. Where the hook is not installed, treat this page as guidance and follow it anyway.

One code rule still applies: when a subagent authors code, the plan it works from contains the code verbatim, and the subagent lists any deviation the compiler forces. That is what makes the standard tier safe for implementation.

Escalate one tier when a subagent reports it is stuck for lack of reasoning, not for lack of context. Lack of context is fixed by a better brief on the same tier.
````

- [ ] **Step 4: Rewrite `P/README.md`**

Fill in `<copilot-docs>`, `<codex-docs>` and `<cursor-docs>` with the URLs you verified earlier.

````markdown
# model-policy

Keeps subagents on the cheapest model tier that fits, and logs every dispatch so the effect can be seen. Works on Claude Code, GitHub Copilot CLI, OpenAI Codex CLI and Cursor. The skill is plain `SKILL.md`, so any other agent can use it as guidance.

## What it does

A hook runs before every subagent dispatch: `Agent` in Claude Code and Copilot CLI (Copilot's `task` tool), `spawn_agent` in Codex CLI, and `Task` in Cursor. It:

- **fills in a missing model** with the default model for the agent type's tier (`inherit` counts as missing);
- **lets fast, standard and strong models through** untouched;
- **gates the frontier tier**: a frontier model is allowed only when the prompt carries a line `Model policy: frontier because <reason>`, and denied otherwise with a reason that says what to do instead;
- **lets unknown models through** (models that match no tier) and logs them with tier `unknown`, so a new model never blocks work;
- **logs** one line per dispatch (see [Log and report](#log-and-report)).

The hook needs `bash` and `jq`. When anything goes wrong (no jq, a bad payload, an unreadable config) it exits quietly and leaves the dispatch alone.

A skill states the tiering rules for the main model. In Claude Code, `/model-policy:report [days]` summarises the log.

## Defaults

Default model per tier, the model a dispatch gets when it names none:

<!-- defaults:tiers:begin -->
| Harness | fast | standard | strong | frontier |
|---|---|---|---|---|
| claude-code | `haiku` | `sonnet` | `opus` | `fable` |
| copilot | `claude-haiku-4.5` | `claude-sonnet-5` | `claude-opus-5` | `claude-opus-5.5` |
| codex | `gpt-6-luna` | `gpt-6-astra` | `gpt-5.6-sol` | `gpt-6-sol` |
| cursor | `composer-2.5` | `claude-sonnet-5` | `claude-opus-5` | `claude-opus-5.5` |
<!-- defaults:tiers:end -->

Tier per agent type, used when the dispatch names no model (`*` covers every other type):

<!-- defaults:agent-types:begin -->
| Harness | Agent type | Tier |
|---|---|---|
| claude-code | `Explore` | fast |
| claude-code | `claude-code-guide` | fast |
| claude-code | `*` | standard |
| copilot | `explore` | fast |
| copilot | `*` | standard |
| codex | `explorer` | fast |
| codex | `*` | standard |
| cursor | `explore` | fast |
| cursor | `*` | standard |
<!-- defaults:agent-types:end -->

How a named model gets its tier:

- Each tier has a list of `match` patterns in [`config/models.json`](config/models.json). A pattern is a shell-style glob (`*` is any text, `?` is one character, everything else is literal) and matching ignores case.
- Tiers are tried in the order frontier, strong, standard, fast, and the first match wins.
- A trailing bracket suffix such as Cursor's `[effort=high]` is ignored.
- A model that matches nothing is tier `unknown`. It passes through and is logged.

The frontier gate looks for the justification on a line of its own in the prompt, not inside a sentence:

```
Model policy: frontier because <reason>
```

The 0.1 form `Model policy: fable because <reason>` is still accepted.

## Configuration

To change the defaults, write an override file. The hook uses the first path that is set:

1. `$MODEL_POLICY_CONFIG`
2. `$XDG_CONFIG_HOME/model-policy/config.json`
3. `~/.config/model-policy/config.json`

The override is deep-merged over `config/models.json`: objects merge key by key, and arrays (the `match` lists) replace the bundled array entirely. A file that is not a JSON object is ignored. A tier whose `default` you set to `""` or `null` stops filling: dispatches without a model for that tier are left alone and logged as `unknown`.

Use a fast Copilot default of `gpt-5-mini`:

```json
{ "harnesses": { "copilot": { "tiers": { "fast": { "default": "gpt-5-mini" } } } } }
```

Treat your own model as frontier on Cursor. Arrays replace, so repeat the bundled patterns you want to keep:

```json
{
  "harnesses": {
    "cursor": {
      "tiers": { "frontier": { "match": ["claude-opus-5.5", "gpt-6-sol", "*fable*", "*mythos*", "my-big-model*"] } }
    }
  }
}
```

Send a custom Copilot agent type to the strong tier:

```json
{ "harnesses": { "copilot": { "agentTypes": { "rubber-duck": "strong" } } } }
```

To see the effective defaults with your override applied, run `bash plugins/model-policy/scripts/defaults-table.sh tiers` (or `agent-types`).

| Variable | Default | Effect |
|---|---|---|
| `MODEL_POLICY_CONFIG` | `$XDG_CONFIG_HOME/model-policy/config.json` | Override file |
| `MODEL_POLICY_LOG` | `$XDG_STATE_HOME/model-policy/dispatches.tsv` | Log file |
| `MODEL_POLICY_DEBUG` | unset | Any value turns on [debug capture](#debug-capture) |
| `XDG_CONFIG_HOME` | `~/.config` | Base directory for the override file |
| `XDG_STATE_HOME` | `~/.local/state` | Base directory for the log |

On Claude Code, also set `CLAUDE_CODE_SUBAGENT_MODEL=sonnet` in the `env` block of `~/.claude/settings.json`. That floor holds even when the plugin is disabled; the plugin adds the fast tier for reading, the frontier gate and the log.

### How the harness is chosen

Each harness loads its own hook file, and each hook file passes `--harness`. Some harnesses also read another harness's files (Copilot CLI and Cursor can load Claude Code hooks). So when the hook is called with `--harness claude-code`, it answers in Cursor's format if the payload is Cursor's, and in Copilot's format if `COPILOT_CLI` is set and the payload has no Claude `subagent_type`. With no flag, it goes by `COPILOT_CLI`, then the Cursor payload or `CURSOR_VERSION`, then a Codex `spawn_agent` call, and otherwise assumes Claude Code.

## Install

### Claude Code

```
/plugin marketplace add thomasliljegren/agent-plugins
/plugin install model-policy@agent-plugins
```

Toggle with `claude plugin enable|disable model-policy@agent-plugins` or the Installed tab of `/plugin`. A plugin reload applies it without a restart.

### Copilot CLI

```
copilot plugin marketplace add thomasliljegren/agent-plugins
copilot plugin install model-policy@agent-plugins
```

Toggle with `copilot plugin enable|disable model-policy`. To try it without installing, start Copilot CLI with `copilot --plugin-dir plugins/model-policy` from a checkout. Copilot reads `.github/plugin/plugin.json`, which points at `hooks/hooks-copilot.json`. See [Copilot CLI plugins](<copilot-docs>).

### Codex CLI

Install the plugin directory `plugins/model-policy` as described in [Codex plugins](<codex-docs>). Codex reads `.codex-plugin/plugin.json`, which registers the skill and `hooks/hooks-codex.json`.

### Cursor

Install the plugin directory `plugins/model-policy` as described in [Cursor plugins](<cursor-docs>). Cursor reads `.cursor-plugin/plugin.json`, which registers the skill and `hooks/hooks-cursor.json`.

## Log and report

The hook appends one tab-separated line per dispatch to `$XDG_STATE_HOME/model-policy/dispatches.tsv` (default `~/.local/state/model-policy/dispatches.tsv`, or wherever `MODEL_POLICY_LOG` points). All harnesses share the file. The columns are:

`time session harness project agent_type requested effective tier action prompt_chars description`

`action` is `kept` (the caller named the model), `filled` (the hook chose it), `denied` (frontier without a reason) or `justified` (frontier with a reason).

```
bash plugins/model-policy/scripts/report.sh [days] [harness]
```

This summarises the last `days` (default 14) by harness, tier, model, action, agent type and day, and lists the frontier dispatches. Version 0.1 logged to `~/.claude/logs/model-policy.tsv` with different columns. The report does not read that file, and the hook no longer writes to it.

## Debug capture

With `MODEL_POLICY_DEBUG=1` in the harness's environment, the hook also appends every payload it receives to `payloads.jsonl` next to the log, as `{time, harness, payload}`. Use this to check which fields a harness sends before changing `config/models.json`. Payloads contain your prompts, so turn it off again when you are done.

## Test

```
bash plugins/model-policy/tests/run.sh
```
````

- [ ] **Step 5: Update the repo docs and marketplace**

In `.claude-plugin/marketplace.json`, set `metadata.version` to `"0.4.0"` and set the model-policy entry's `description` to:

```
Keeps subagents on the cheapest model tier that fits on Claude Code, Copilot CLI, Codex CLI and Cursor: fills a missing model by agent type, gates frontier-tier subagents behind a written reason, logs every dispatch.
```

In `README.md`:
- Replace the model-policy row of the Plugins table with:

```
| [model-policy](plugins/model-policy) | Keeps subagents on the cheapest model tier that fits, gates frontier-tier subagents behind a written reason, logs every dispatch. Ships hooks for Claude Code, Copilot CLI, Codex CLI and Cursor. |
```

- Add these lines to the Layout tree, after the `hooks/hooks.json` line:

```
├─ .github/plugin/plugin.json   # Copilot CLI manifest (optional, when Copilot needs different hooks)
├─ .codex-plugin/plugin.json    # Codex CLI manifest (optional)
├─ .cursor-plugin/plugin.json   # Cursor manifest (optional)
```

- Replace the sentence after the tree with: "Skills are the portable core; any standard-compliant agent can use them unchanged. Commands, subagents, hooks and MCP wiring are harness extras bundled in the same plugin. Most plugins ship them for Claude Code only. A plugin that needs hooks elsewhere adds that harness's manifest (see [model-policy](plugins/model-policy))."

In `docs/INSTALL.md`, add this section before `## MCP servers`:

```markdown
## Plugins with hooks (model-policy)

`model-policy` enforces its rules with a hook, and a hook only runs when the plugin is installed as a plugin, not when you copy the skill folder. It ships manifests and hooks for Claude Code, Copilot CLI (`copilot plugin install model-policy@agent-plugins` after `copilot plugin marketplace add thomasliljegren/agent-plugins`), Codex CLI and Cursor. See [plugins/model-policy/README.md](../plugins/model-policy/README.md#install). On any other agent, the skill works as guidance only.
```

- [ ] **Step 6: Verify the install commands before relying on them**

Run: `copilot plugin enable --help`
Expected: the usage names the argument form. If it takes `plugin@marketplace`, change the README's toggle line to `copilot plugin enable|disable model-policy@agent-plugins`.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `bash plugins/model-policy/tests/run.sh`
Expected: `ALL PASSED`. If a table check fails, regenerate the block with `MODEL_POLICY_CONFIG=/nonexistent bash plugins/model-policy/scripts/defaults-table.sh tiers` (or `agent-types`) and paste the output between the markers.

- [ ] **Step 8: Commit**

```bash
git add README.md docs/INSTALL.md .claude-plugin/marketplace.json plugins/model-policy/README.md plugins/model-policy/skills plugins/model-policy/tests/docs.test.sh
git commit -m "model-policy: document tiers, configuration and install on every harness

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

### Task 7: Full verification and live harness checks

**Files:**
- Possibly modify: `P/.claude-plugin/plugin.json`, `P/hooks/*` (only if the double-load contingency below triggers)
- Possibly modify: `P/scripts/policy.jq` field fallbacks (only if a captured payload shows different field names)

Every live check costs model requests and runs a real agent session. **Ask the user before running each one** (use ask_user with the command shown). Every check uses `--plugin-dir` and a temp log dir, so nothing is installed and no user config changes.

- [ ] **Step 1: Full test run**

Run: `bash plugins/model-policy/tests/run.sh`
Expected: every file passes, then `ALL PASSED`.

- [ ] **Step 2: Live Copilot CLI check (ask first)**

```bash
T=$(mktemp -d)
MODEL_POLICY_DEBUG=1 MODEL_POLICY_LOG="$T/dispatches.tsv" \
  copilot --plugin-dir plugins/model-policy --allow-all-tools --model claude-haiku-4.5 \
  -p "Use the task tool exactly once: agent_type explore, do not set a model, prompt 'List the files in plugins/model-policy/scripts.' Report the list."
cat "$T/dispatches.tsv"; jq -c '{harness, tool: .payload.tool_name, input: .payload.tool_input}' "$T/payloads.jsonl"
```

Expected:
- `payloads.jsonl` holds the `Agent` payload.
- `dispatches.tsv` has the header plus **exactly one** line with `copilot`, `explore`, `-`, `claude-haiku-4.5`, `fast` and `filled`.

Then try the gate:

```bash
MODEL_POLICY_LOG="$T/dispatches.tsv" copilot --plugin-dir plugins/model-policy --allow-all-tools --model claude-haiku-4.5 \
  -p "Use the task tool exactly once: agent_type general-purpose, model claude-opus-5.5, prompt 'Say hi.' If it is denied, quote the denial reason and stop."
tail -n 1 "$T/dispatches.tsv"
```

Expected: the reply quotes the model-policy reason, and the last log line shows `frontier` and `denied`.

Contingency if the dispatch shows up **twice** in the log (Copilot loaded both `hooks/hooks.json` and `hooks/hooks-copilot.json`):
- `git mv plugins/model-policy/hooks/hooks.json plugins/model-policy/hooks/hooks-claude.json`
- Add `"hooks": "./hooks/hooks-claude.json"` to `.claude-plugin/plugin.json`
- Update the packaging test rows and the Claude manifest check to expect `./hooks/hooks-claude.json`
- Re-run the tests and this step

Contingency if Copilot **ignores the fill** (look in the session's `events.jsonl` under `~/.copilot/session-state/`, reading only, for the subagent's model): record it in the README under Copilot CLI as a known limitation ("Copilot CLI logs and gates but may not apply the filled model"), and tell the user.

- [ ] **Step 3: Live Claude Code check (ask first)**

```bash
T=$(mktemp -d)
MODEL_POLICY_DEBUG=1 MODEL_POLICY_LOG="$T/dispatches.tsv" \
  claude --plugin-dir plugins/model-policy --model haiku --permission-mode bypassPermissions \
  -p "Use the Agent tool exactly once: subagent_type Explore, no model, prompt 'List the files in plugins/model-policy/scripts.' Report the list."
cat "$T/dispatches.tsv"
```

Expected: one line with `claude-code`, `Explore`, `haiku`, `fast` and `filled`. If `--permission-mode bypassPermissions` is refused, drop it and use `--allowedTools Agent`.

- [ ] **Step 4: Codex CLI and Cursor (ask whether to do them)**

Codex installs plugins only through a marketplace (`codex plugin marketplace add`, then `codex plugin add`), and that writes to `~/.codex/config.toml`. Cursor is not installed on this machine. Do not run either without an explicit yes. If the user agrees to the Codex run:

```bash
codex plugin marketplace add "$PWD"   # repo root; check with `codex plugin marketplace add --help` first
codex plugin add model-policy
MODEL_POLICY_DEBUG=1 MODEL_POLICY_LOG="$T/codex.tsv" codex exec "Spawn exactly one subagent with spawn_agent, agent_type explorer, no model, to list plugins/model-policy/scripts."
cat "$T/codex.tsv"; jq -c .payload.tool_input "$(dirname "$T/codex.tsv")/payloads.jsonl"
codex plugin remove model-policy      # and remove the marketplace again
```

If the captured `tool_input` names differ from `agent_type`, `model` and `message`, add the real names as fallbacks in `normalize` in `policy.jq`, add a `hook.test.sh` case using the captured payload, and re-run the tests.

Whatever is not run live, list in the final report as "not verified live", with the capture recipe: set `MODEL_POLICY_DEBUG=1`, dispatch one subagent, read `payloads.jsonl`.

- [ ] **Step 5: Commit any contingency changes**

```bash
git add -A plugins/model-policy
git commit -m "model-policy: adjust after live harness checks

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

Skip this step if nothing changed.

---

## Open risks carried into implementation

- **Copilot `modifiedArgs` under a PascalCase hook config.** Step 2 checks it; the fallback is the documented limitation.
- **Copilot loading both hook files.** Step 2 checks it; the fallback is the `hooks-claude.json` rename.
- **Cursor `Task` field names are unverified.** `normalize` accepts `subagent_type`/`agent_type`, `model`/`subagent_model` and `prompt`/`task`. The debug capture recipe is documented.
- **Codex `permissionDecision: "allow"`.** It is left out on purpose: Codex fills send only `updatedInput`.
- **Model IDs age.** They live in `config/models.json` plus the user override. Nothing else hard-codes them except the generated doc tables, and a test pins those.

