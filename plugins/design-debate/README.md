# design-debate

Puts a design problem to several agents at once. Each designer works independently, with its own lens (pragmatist, domain and architecture fit, operations and runtime, or one you name) and, where the client allows it, its own model family. They critique each other over one or two rounds, and a judge gates the designs on the framing and the repo's invariants, scores them, and picks one. The result is one illustrated proposal at `docs/working/proposals/YYYY-MM-DD-<slug>.md`.

Experimental.

## Install

```
/plugin marketplace add thomasliljegren/agent-plugins
/plugin install design-debate@agent-plugins
```

Any other agent: `npx skills add github:thomasliljegren/agent-plugins` installs the skill with its references. It runs only in a client with a subagent tool: tested in Copilot (CLI and app) and Claude Code.

## Use

```
design-debate "<problem>" [designers=3] [rounds=2] [lenses=a,b,c] [models=A:x,B:y]
              [effort=high] [judge-model=x] [judge-effort=x] [slug=x]
design-debate resume <slug>
design-debate status <slug>
```

Every setting has a default. The run frames the problem, then stops once, at a checkpoint that ends the agent's turn: approval is a new message from you, so autopilot cannot approve it. The checkpoint shows the framing as a link, each slot's lens, model and effort, any setting it clamped or could not apply, and the planned calls (`N + N×R + 1`, plus one retry; 10 at the defaults).

## What a run touches

- Writes one file in the working tree: the proposal. Never commits, pushes or reverts anything.
- Keeps its state in `$(git rev-parse --absolute-git-dir)/design-debate/<slug>/`, so a run survives a new session and never shows in `git status`.
- Stops, listing the paths, if anything else in the repo changes while subagents run.

## Model mixing

| Client | Designers | Judge | Effort |
|---|---|---|---|
| Copilot | Claude, GPT and Gemini families by slot | a family no designer used | per call |
| Claude Code | opus and sonnet by slot | shares a family, declared in the proposal | not applied |
