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

Toggle with `copilot plugin enable|disable model-policy@agent-plugins` (a bare `model-policy` also works). To try it without installing, start Copilot CLI with `copilot --plugin-dir plugins/model-policy` from a checkout. Copilot reads `.github/plugin/plugin.json`, which points at `hooks/hooks-copilot.json`. See [Copilot CLI plugins](https://docs.github.com/copilot/concepts/agents/about-plugins).

### Codex CLI

Install the plugin directory `plugins/model-policy` as described in [Codex plugins](https://developers.openai.com/plugins/build/plugins). Codex reads `.codex-plugin/plugin.json`, which registers the skill and `hooks/hooks-codex.json`.

### Cursor

Install the plugin directory `plugins/model-policy` as described in [Cursor plugins](https://cursor.com/docs/plugins). Cursor reads `.cursor-plugin/plugin.json`, which registers the skill and `hooks/hooks-cursor.json`.

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
