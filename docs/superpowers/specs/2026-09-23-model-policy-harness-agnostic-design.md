# model-policy: harness-agnostic design

Date: 2026-09-23
Status: approved in brainstorming, pending written-spec review

## Intent

`plugins/model-policy` keeps subagents on the cheapest model that fits. Today it only works on Claude Code: it hard-codes the `Agent` tool payload (`subagent_type`), the Anthropic aliases `haiku`/`sonnet`/`opus`/`fable`, Claude's hook output shape, and a `~/.claude/logs` log path.

Goal: the same policy enforced on **Claude Code, GitHub Copilot CLI, OpenAI Codex CLI and Cursor**, expressed in **vendor-neutral tiers** mapped to each harness's models, while the skill remains usable as guidance by any Agent Skills-compatible agent.

Success criteria:

- On each of the four harnesses, a subagent dispatch without a model is filled with the tier default for its agent type, a frontier-tier dispatch without a justification line is denied, and every dispatch is logged.
- No Anthropic model name is baked into the policy logic; all model names live in a JSON map a user can override.
- Existing Claude Code behaviour is preserved (same fills, same gate), apart from the renamed justification line (old form still accepted) and the new log path.

## Harness facts the design relies on

| | Claude Code | Copilot CLI | Codex CLI | Cursor |
|---|---|---|---|---|
| Dispatch tool (payload `tool_name`) | `Agent` | `Agent` (PascalCase `PreToolUse` maps runtime `task` to `Agent`) | `spawn_agent` (matcher alias `Agent`) | `Task` |
| Agent-type field | `subagent_type` | `agent_type` | `agent_type` | `subagent_type` (UNVERIFIED; accept `agent_type` too) |
| Model field | `model` | `model` | `model` | `model` (UNVERIFIED) |
| Prompt field | `prompt` | `prompt` | `message` | `prompt` (UNVERIFIED; accept `task`) |
| Rewrite output | `hookSpecificOutput.updatedInput` | top-level `modifiedArgs` | `hookSpecificOutput.updatedInput` | `updated_input` |
| Deny output | `hookSpecificOutput.permissionDecision: deny` + `permissionDecisionReason` | top-level `permissionDecision: deny` + `permissionDecisionReason` | same as Claude | `permission: deny` + `agent_message` + `user_message` |
| Plugin root var in hook command | `${CLAUDE_PLUGIN_ROOT}` | `${CLAUDE_PLUGIN_ROOT}` (also sets `COPILOT_CLI=1`) | `${PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_ROOT}` | relative to plugin root; `${CURSOR_PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_ROOT}` (UNVERIFIED for hooks) |
| Non-zero exit | non-blocking error | **deny** (fail-closed) | hook failure, call continues | fail-open by default |

Sources: docs.github.com Copilot hooks and CLI plugin references; developers.openai.com/codex/hooks and plugins docs, plus `openai/codex` `multi_agents_spec.rs` / `hook_names.rs`; cursor.com/docs/hooks, /subagents, /reference/plugins. Items marked UNVERIFIED are confirmed by a live capture during implementation (see Testing).

## Packaging and layout

```
plugins/model-policy/
├─ .claude-plugin/plugin.json     # Claude Code; default hooks/hooks.json
├─ .github/plugin/plugin.json     # Copilot CLI (found before .claude-plugin); "hooks": "hooks/hooks-copilot.json"
├─ .codex-plugin/plugin.json      # Codex; "hooks": "./hooks/hooks-codex.json"
├─ .cursor-plugin/plugin.json     # Cursor; "hooks": "./hooks/hooks-cursor.json"
├─ hooks/
│  ├─ hooks.json                  # PreToolUse matcher Agent -> model-policy.sh --harness claude-code
│  ├─ hooks-copilot.json          # PreToolUse matcher Agent -> --harness copilot
│  ├─ hooks-codex.json            # PreToolUse matcher spawn_agent -> --harness codex
│  └─ hooks-cursor.json           # version 1, preToolUse matcher Task -> --harness cursor
├─ config/models.json             # bundled tier map
├─ scripts/model-policy.sh        # hook: normalize -> decide -> render
├─ scripts/report.sh              # log summary, optional harness filter
├─ skills/model-policy/SKILL.md   # portable, tier-based
├─ commands/report.md             # Claude Code slash command (only)
├─ tests/run.sh
└─ README.md
```

Decisions:

- Each hook file passes `--harness` explicitly. Env detection (`COPILOT_CLI`, `CURSOR_PLUGIN_ROOT`/`CURSOR_VERSION`, `PLUGIN_ROOT` without `CLAUDE_*`-only, else claude-code) is a fallback when the flag is absent.
- All four manifests carry the same `name`, `version`, `description`, `author`, `keywords`; a test asserts they agree.
- No root `plugin.json` (Agent Plugins 1.0): Copilot would then switch to the `com.github.copilot/` component layout.
- Copilot's legacy manifest search order is `.plugin/`, root, `.github/plugin/`, `.claude-plugin/`; so `.github/plugin/plugin.json` wins over `.claude-plugin/plugin.json` and Claude Code is unaffected.
- The repo-level `.claude-plugin/marketplace.json` stays the single marketplace (Copilot and Codex read it). Cursor and Codex marketplace files are out of scope; Cursor installs locally.

## Tier map (`config/models.json`)

Tiers: `fast`, `standard`, `strong`, `frontier`.

Shape:

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
        "fast":     { "default": "gpt-5.4-mini",     "match": ["*haiku*", "*-mini", "*flash*", "*luna*"] },
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

The Copilot `fast` default is `gpt-5.4-mini`, not `claude-haiku-4.5`. Copilot's `explore` agent runs at reasoning effort `low`, and a live check showed an explicitly set `claude-haiku-4.5` fails there with "Reasoning effort 'low' is not supported".

Classification rules:

- Strip a Cursor-style bracket suffix (`claude-opus-5[effort=high]` -> `claude-opus-5`) before matching.
- Check tiers in order `frontier`, `strong`, `standard`, `fast`; within a tier, match patterns as shell globs, case-insensitive; first match wins.
- No match -> tier `unknown`, dispatch kept.
- Agent type lookup: exact key, then `*`.

User override: `${MODEL_POLICY_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/model-policy/config.json}`, deep-merged over the bundled map with jq `*` (objects merge, arrays replace). A missing or invalid override is ignored (bundled map used).

## Hook script flow (`scripts/model-policy.sh`)

`model-policy.sh [--harness claude-code|copilot|codex|cursor]`, stdin = hook payload.

1. **Normalize** to `{tool, agent_type, model, prompt, description, session, cwd}`.
   - Dispatch tools: claude-code/copilot `Agent` (also `Task`, `task`); codex `spawn_agent` (also `Agent`); cursor `Task`. Anything else: exit 0, no output, no log.
   - Agent type: `subagent_type // agent_type // "general-purpose"`.
   - Prompt: `prompt // message // task // ""`. Description: `description // task_name // name // ""`.
   - Session: `session_id // sessionId // conversation_id`. Cwd: `cwd // workspace_roots[0]`.
   - The prompt field name is remembered so a rewrite keeps the original input untouched except for `model`.
2. **Decide** (harness-neutral):
   - model empty or `inherit` -> tier = agentTypes lookup, model = that tier's default, action `filled`.
   - tier `frontier` -> `justified` if the prompt has a line matching `^\s*Model policy: *(frontier|fable) because .{3,}` (case-insensitive), else `denied`.
   - otherwise `kept` (includes `unknown`).
3. **Render** per harness:
   - filled: claude-code/codex `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":…,"updatedInput":<input+model>}}`; copilot `{"permissionDecision":"allow","permissionDecisionReason":…,"modifiedArgs":<input+model>}`; cursor `{"permission":"allow","updated_input":<input+model>}`.
   - denied: claude-code/codex `hookSpecificOutput` with `permissionDecision:"deny"` + reason; copilot top-level `permissionDecision:"deny"` + `permissionDecisionReason`; cursor `{"permission":"deny","agent_message":…,"user_message":…}`. The reason names the harness's `strong` and `standard` defaults and the justification line.
   - kept/justified: no output.

Safety: every failure path (no jq, bad JSON, bad config) exits 0 with no stdout. This matters most on Copilot, where a non-zero exit denies the call. Only one JSON object is ever written to stdout.

Debug: `MODEL_POLICY_DEBUG=1` appends the raw stdin payload (one line, with harness and timestamp) to `payloads.jsonl` next to the log. Used for the live-capture check.

## Logging and report

- Log: `${MODEL_POLICY_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/model-policy/dispatches.tsv}`.
- Columns: `time session harness project agent_type requested effective tier action prompt_chars description`.
- The old `~/.claude/logs/model-policy.tsv` is not migrated or deleted; the README says where it was.
- `report.sh [days] [harness]`: same sections as today plus "By tier" and "By harness"; optional harness filter; column indexes updated. Top-tier section reads `frontier` tier rows.
- `commands/report.md` (Claude Code) calls `report.sh 14`; its wording uses tiers.

## Skill (`skills/model-policy/SKILL.md`)

- Description triggers on dispatching/re-dispatching/escalating a subagent via `Agent`, `task`, `spawn_agent` or `Task`, or on a model-policy denial.
- Work table by tier: fast = read/search/summarise; standard = implement from a plan with code, run tests, verify against spec; strong = review, debug, fix rounds 4–5, planning, weighing options; frontier = the single integration or whole-verification pass.
- Compact table "tier -> default model" per harness (generated from `config/models.json`; a test asserts the skill table matches).
- Justification line `Model policy: frontier because <reason>`; don't add it just to get past the gate.
- Note: without the hook (other agents), treat the table as guidance and pick the closest model your harness offers; a user override file may change the defaults.
- Keep the existing "plan contains the code" and "escalate one tier for lack of reasoning, not context" rules.

## Docs

- Plugin README, sections in this order:
  1. **What it does**, in tier wording.
  2. **Defaults**, with two tables taken from `config/models.json`. The first maps each harness to its default model for every tier. The second maps agent types to tiers per harness, including the `*` fallback. After the tables, the README states the classification rules (frontier → fast, first match wins, `unknown` passes through) and names the justification line.
  3. **Configuration**: where the override file lives (`MODEL_POLICY_CONFIG`, then `$XDG_CONFIG_HOME/model-policy/config.json`, then `~/.config/model-policy/config.json`) and how merging works (objects merge, arrays replace, an invalid file is ignored). It includes three worked examples: change Copilot's `fast` default to `gpt-5-mini`, add a match pattern to a tier, and map a custom agent type to `strong`. It also lists every environment variable with its default: `MODEL_POLICY_CONFIG`, `MODEL_POLICY_LOG`, `MODEL_POLICY_DEBUG`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`. For Claude Code it keeps the `CLAUDE_CODE_SUBAGENT_MODEL` pairing advice.
  4. **Install and enable/disable** for each harness.
  5. **Log and report**: the path, the columns, `report.sh [days] [harness]`, and where the old log was.
  6. **Debug capture** and **Test**.
- A test asserts that the README defaults tables match `config/models.json`, the same check used for the skill table.
- Repo README plugins table and docs/INSTALL.md: model-policy ships hooks for Claude Code, Copilot CLI, Codex CLI and Cursor; the skill is portable elsewhere.
- `.claude-plugin/marketplace.json` model-policy description: tier wording, no Claude-only claims. Plugin version 0.2.0 in all manifests; marketplace metadata version bump.

## Testing (`tests/run.sh`, bash + jq)

- Fixture builder per harness producing that harness's payload shape.
- For each harness: fill by agent type (fast and standard), `inherit` counts as unset, standard/strong kept with no output, frontier denied, frontier justified, legacy `fable because` accepted, unknown model kept and logged as `unknown`, non-dispatch tool ignored, garbage stdin exits 0 silently.
- Output shape per harness (correct field names, model injected, rest of input preserved).
- Harness autodetect fallback via env when `--harness` is absent.
- Override file: changing Copilot `fast.default` changes the filled model; invalid override falls back to bundled.
- Cursor bracket suffix classified correctly.
- Log: header + columns, harness and tier recorded.
- Report: runs on a sample log, harness filter works.
- Manifests: all four parse and agree on name/version; each hook file parses and references `--harness <name>`.
- The skill table and both README defaults tables (tier defaults and agent-type tiers) match `config/models.json`.

Live checks (manual, recorded in the PR): Copilot CLI with the plugin installed from a local path, `MODEL_POLICY_DEBUG=1`, one `task` dispatch without a model and one frontier dispatch. Cursor and Codex payload fields are marked for a live capture with the same debug flag; the normalizer already accepts the documented alternatives.

## Out of scope

- Slash commands for non-Claude harnesses (they run `report.sh` directly).
- Cursor/Codex marketplace files, Agent Plugins 1.0 root manifest.
- Mapping tiers to reasoning effort.
- Migrating the old log file.
