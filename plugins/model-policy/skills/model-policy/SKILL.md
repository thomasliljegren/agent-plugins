---
name: model-policy
description: Which model to name when dispatching a subagent (Agent tool, workflow agent() calls), so the cheapest model that fits does the work. Use whenever you are about to dispatch, re-dispatch or escalate a subagent, or when a dispatch was denied with a model-policy reason.
---

# Model policy for subagents

The main conversation runs on the most capable model. Subagents should not, unless there is a reason. Always name the model on a dispatch: an omitted model is filled in by the hook (Explore and claude-code-guide get haiku, everything else sonnet), which is fine for reading but not a choice.

| Work | Model | Why |
|---|---|---|
| Reading, searching, looking things up, summarising files or docs | `haiku` | No judgement needed, output is facts |
| Implementing from a plan that contains the code, running tests, verifying against a spec | `sonnet` | The plan carries the judgement; the subagent transcribes and checks |
| Reviewing, debugging, fix rounds 4 and 5, planning a task, anything that needs to weigh options | `opus` | Judgement without the top-tier price |
| The one pass that brings several rounds of subagent work together, or verifies the whole against the original intent | `fable` | Only when the pieces have to be held in one head |

A top-tier dispatch (`fable`, `best`, a fable or mythos model id) is denied by the hook unless the prompt contains a line

```
Model policy: fable because <reason>
```

Write that line only for the integration or whole-verification pass. If a denial comes back for anything else, re-dispatch on `opus` or `sonnet`; do not add the line to get past the gate.

Code style rule that still applies: when a subagent authors code, the plan it works from contains the code verbatim, and the subagent lists any deviation the compiler forces. That is what makes `sonnet` safe for implementation.

Escalate one tier when a subagent reports it is stuck for lack of reasoning, not for lack of context. Lack of context is fixed by a better brief on the same model.
