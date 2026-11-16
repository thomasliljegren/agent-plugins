# Prompts

Fill the `{{placeholders}}` and send each prompt as the whole subagent task. Every prompt ends with
its required headings. A reply missing any required heading is invalid: use the shared retry once,
then stop (see SKILL.md, Failure policy).

Every subagent prompt includes this safety block verbatim as `{{safety_block}}`:

> You are read-only. Do not create, edit, move or delete any file. Do not commit, push, open PRs or
> create tickets. Return your answer as your final message only.

## Framer

The orchestrator writes the framing itself; this is its checklist, not a subagent prompt.

1. Restate the problem in plain words.
2. Requirements: only what the user stated. Mark anything inferred as "assumed".
3. Non-goals.
4. Success criteria: numbered, each one checkable.
5. Grounding brief, about 300 words: the facts every designer needs, each cited as `path:line`.
   Read the repo's agent instructions (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`),
   the nearest `README.md`, and the decision records that apply. End the brief with an
   `Invariants:` line listing the repo's architecture rules: the judge gates on them.
6. Open questions the designs must answer.

Required headings: `## Problem`, `## Requirements`, `## Non-goals`, `## Success criteria`,
`## Grounding brief`, `## Open questions`.

## Designer

```
You are designer {{slot}} in a design debate. Other designers are working on the same problem
independently. Argue from this lens:

{{lens_brief}}

## Approved framing
{{framing}}

{{safety_block}}

Make about 5 targeted read-only lookups in the repository and cite each finding as `path:line`.
Write a complete design of about 1,500 words: components, flow, and an answer to every open question
in the framing. Include at least one mermaid diagram. Be opinionated: pick, do not list options.

Use exactly these headings:
## Summary
## Key decisions      (short, concrete, comparable statements, one per bullet)
## Risks
## Design
```

## Round 1

Peers are shown under shuffled peer labels (`P`, `Q`, …), never slot letters. See SKILL.md, Peer labels.

```
You are designer {{slot}} (lens: {{lens_name}}) in round 1 of a design debate.

## Approved framing
{{framing}}

## Your design
{{own_design}}

## Competing designs
{{peers_anonymised_shuffled}}

{{safety_block}}

1. For each competing design, give the single strongest specific objection, with evidence.
   No generic praise.
2. List what you adopt from the others, and why.
3. Return your full revised design.

Use exactly these headings:
## Critiques         (one bullet per peer: "**Design P:** objection")
## Adopted
## Summary
## Key decisions
## Risks
## Design
```

## Round 2

Only when R=2. The designer sees the critiques aimed at it.

```
You are designer {{slot}} (lens: {{lens_name}}) in round 2, the rebuttal round.

## Approved framing
{{framing}}

## Your round 1 design
{{own_round1}}

## Critiques aimed at your design
{{incoming_critiques}}

## Competing round 1 designs
{{peers_anonymised_shuffled}}

{{safety_block}}

For every incoming critique, give one disposition: accepted (and what you changed), rebutted (with
evidence), or unresolved (and what would settle it). Then critique the competing designs again,
and return your final design.

Use exactly these headings:
## Dispositions
## Critiques
## Adopted
## Summary
## Key decisions
## Risks
## Design
```

## Judge

The judge sees designs under shuffled peer labels, never slot letters, lens or model names.

```
You are the judge of a design debate. Pick a winner; do not average the designs.

## Approved framing
{{framing}}

## Final designs
{{finals_anonymised_shuffled}}

## Critiques and dispositions from the debate
{{critiques_and_dispositions}}

{{safety_block}}

1. Gates (pass/fail per design): every mandatory requirement and non-goal in the framing, plus
   the `Invariants:` and decided ADRs named in the grounding brief, and no committed credentials.
   A design failing any gate is ineligible.
2. Scorecard: each success criterion scored 1-5 per eligible design, each score with one cited
   line of evidence. No weights, and no totals: the orchestrator adds them up.
3. Winner: one eligible design. If none is eligible, say UNRESOLVED and why.
4. Grafts: at most 3 decisions from other designs, each citing the critique that justifies it.
   Label any detail you add that no critique supports as `unreviewed`.
5. Rejected alternatives: per losing design, what lost and why.

Use exactly these headings:
## Gates
## Scorecard
## Winner
## Grafts
## Rejected alternatives
## Risks
## Open questions
```
