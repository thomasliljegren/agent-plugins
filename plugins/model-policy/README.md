# model-policy

Keeps subagents on the cheapest model that fits, and logs every dispatch so the effect can be seen.

## What it does

A `PreToolUse` hook on the `Agent` tool:

- **fills in a missing model** by agent type: `Explore` and `claude-code-guide` get `haiku`, everything else `sonnet` (`inherit` counts as missing);
- **lets `haiku`, `sonnet` and `opus` through** untouched;
- **gates the top tier** (`fable`, `best`, any fable or mythos id): allowed only when the prompt carries a line `Model policy: fable because <reason>`, denied otherwise with a reason that tells the caller what to do instead;
- **logs** one line per dispatch to `~/.claude/logs/model-policy.tsv` (override with `MODEL_POLICY_LOG`).

A skill states the tiering rules for the main model, and `/model-policy:report [days]` summarises the log.

## Pair it with

`CLAUDE_CODE_SUBAGENT_MODEL=sonnet` in the `env` block of `~/.claude/settings.json`. That floor holds even when the plugin is disabled; the plugin adds the haiku tier for reading, the top-tier gate and the log.

## Install

```
/plugin marketplace add thomasliljegren/agent-plugins
/plugin install model-policy@agent-plugins
```

Toggle with `claude plugin enable|disable model-policy@agent-plugins` or the Installed tab of `/plugin`; a plugin reload applies it without a restart.

## Test

```
bash plugins/model-policy/tests/run.sh
```
