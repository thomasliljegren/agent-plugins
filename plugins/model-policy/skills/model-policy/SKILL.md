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
| copilot | `gpt-5.4-mini` | `claude-sonnet-5` | `claude-opus-5.5` | `gpt-6-astra` |
| codex | `gpt-6-luna` | `gpt-5.6-terra` | `gpt-6-sol` | `gpt-6-astra` |
| cursor | `composer-2.5` | `claude-sonnet-5` | `claude-opus-5.5` | `gpt-6-astra` |
<!-- defaults:tiers:end -->

The tiers are price bands, and each default is the model that gives the most for its price in its band. Other models your harness offers belong to the band of the model closest in price: small, mini, flash and luna models are fast, and the most expensive models are frontier. A newer model is not always dearer. When a newer model is both stronger and cheaper than an older one (Claude Opus 5.5 against Opus 5, GPT-6 Sol against GPT-5.6 Sol), always use the newer one.

The hook denies a frontier-tier dispatch unless the prompt has this on a line of its own:

```
Model policy: frontier because <reason>
```

Write that line only for the integration or whole-verification pass. If a denial comes back for anything else, re-dispatch on the strong or standard tier. Do not add the line just to get past the gate. Where the hook is not installed, treat this page as guidance and follow it anyway.

One code rule still applies: when a subagent authors code, the plan it works from contains the code verbatim, and the subagent lists any deviation the compiler forces. That is what makes the standard tier safe for implementation.

Escalate one tier when a subagent reports it is stuck for lack of reasoning, not for lack of context. Lack of context is fixed by a better brief on the same tier.
