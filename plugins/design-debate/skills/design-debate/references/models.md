# Models and effort

Different models disagree more usefully than one model wearing different lenses. Mix model families
where the harness allows it. Never hardcode version strings: resolve each preference against the
models the harness's subagent tool lists right now.

## Slot preferences

Designers are slots `A`..`E`. Each slot has a family preference, picked as the strongest available
model of that family.

| Slot | Copilot (`task` tool) | Claude Code (`Task` tool) | Other harnesses |
|---|---|---|---|
| A | Claude | opus | session default |
| B | GPT | sonnet | session default |
| C | Gemini | opus | session default |
| D | Claude (a different tier from A) | sonnet | session default |
| E | GPT (a different tier from B) | haiku | session default |

An explicit `models=A:<id>,B:<family>` at invoke time or at the checkpoint overrides a slot.

## Fallback

1. The requested model or family is not in the live list: take the next family in the slot order
   above (A → B → C → …, wrapping round).
2. Still nothing: the session default model.
3. Show every fallback at the checkpoint and record requested vs. actual model per slot in `run.md`
   and in the proposal header. A requested model is not proof of the model used: record what the
   tool reports, or "unverified" if it reports nothing.

## Judge

- The strongest available model from a family no designer used.
- If every family is in use (always true in Claude Code), take the strongest model and declare the
  shared family in the proposal header.
- Override with `judge-model=<id>`.

## Effort

| Harness | How effort is applied |
|---|---|
| Copilot | `reasoning_effort` on each `task` call (`low`, `medium`, `high`, `xhigh`) |
| Claude Code | Not settable per subagent. Show "effort: not applied" at the checkpoint |
| Other | Apply it if the subagent tool has an effort parameter; otherwise "not applied" |

Default effort is `high` for designers and the judge. `effort=` sets all slots, `effort=A:low,B:high`
sets per slot, and `judge-effort=` sets the judge.
