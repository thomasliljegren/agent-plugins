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
2. Requirements, numbered `R1`, `R2`, …: only what the user stated. Mark anything inferred as
   "assumed".
3. Non-goals.
4. Success criteria, numbered `SC1`, `SC2`, …, each one checkable. Always include one scope/cost
   criterion, marked `(scope/cost)`, even if the user did not ask for one, for example: modules
   touched, new tables, services or components, and increments before the first visible fix. Without
   it the scorecard rewards thoroughness only, and the leanest design cannot win on its strength.
5. Grounding brief, about 300 words: the facts every designer needs, each cited as `path:line`.
   Read the repo's agent instructions (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`),
   the nearest `README.md`, and the decision records that apply. End the brief with an
   `Invariants:` line listing the repo's architecture rules: the judge gates on them.
6. Open questions the designs must answer, numbered `Q1`, `Q2`, ….

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
## Framing answers    (one entry per R and Q item in the framing: "**R1:** answer in 1-2 sentences")
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
3. Return your full revised design. Keep a `## Key decisions` bullet word for word unless you
   changed that decision.
{{final_round_note}}

Use exactly these headings:
## Critiques         (one bullet per peer: "**Design P:** objection")
## Adopted
## Summary
## Key decisions
## Risks
## Framing answers
## Design
```

`{{final_round_note}}` is the Final-design note below in the last round (here: R=1) and in every
round with `rounds=auto`, and empty otherwise. The orchestrator compares `## Key decisions` between
rounds to detect convergence (SKILL.md, Auto rounds), so the word-for-word rule applies in every
round.

Final-design note:

> This is your final design. It replaces your earlier ones: the judge reads only this text. Restate
> every answer to the framing in full, including answers that have not changed since your draft. Do
> not write "unchanged", "as before" or "see round 1".

## Rebuttal

Rounds 2 and later. In round `{{round}}` the designer sees its own design from round `{{prev}}`
(`{{round}}` − 1), the critiques aimed at it in that round, and its peers' designs from that round.

```
You are designer {{slot}} (lens: {{lens_name}}) in round {{round}}, a rebuttal round.

## Approved framing
{{framing}}

## Your round {{prev}} design
{{own_previous}}

## Critiques aimed at your design
{{incoming_critiques}}

## Competing round {{prev}} designs
{{peers_anonymised_shuffled}}

{{safety_block}}

For every incoming critique, give one disposition: accepted (and what you changed), rebutted (with
evidence), or unresolved (and what would settle it). Then critique the competing designs again,
and return your full revised design. Keep a `## Key decisions` bullet word for word unless you
changed that decision.
{{final_round_note}}

Use exactly these headings:
## Dispositions
## Critiques
## Adopted
## Summary
## Key decisions
## Risks
## Framing answers
## Design
```

## Repair

Only for a slot whose final design misses framing items (see SKILL.md, Completeness). Same model
and effort as the slot. No peer designs.

```
You are designer {{slot}} (lens: {{lens_name}}). Your final design below leaves some items in the
framing unanswered. Answer them; do not redesign.

## Approved framing
{{framing}}

## Your final design
{{final_design}}

## Unanswered items
{{missing_items}}

{{safety_block}}

Return your full final design with the missing answers added. Keep every existing `## Key
decisions` bullet word for word; add new bullets only if an answer needs one. Restate every answer
in `## Framing answers`, not only the new ones.

Use exactly these headings:
## Repairs           (one bullet per unanswered item: what you added, and where)
## Summary
## Key decisions
## Risks
## Framing answers
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

## Gaps the orchestrator found
{{open_gaps}}

{{safety_block}}

1. Gates (pass/fail per design). A gate fails only when a design breaks a rule: it contradicts a
   mandatory requirement, breaches a non-goal, or violates the `Invariants:` or decided ADRs named
   in the grounding brief, or commits credentials. A design failing any gate is ineligible. A
   design that is silent on an item, or answers it only partly, passes the gate: score the gap in
   step 2 instead.
2. Scorecard: score every success criterion 1-5 for every design, ineligible ones included, each
   score with one cited line of evidence. Where a design leaves an item unanswered, the criterion
   covering it scores at most 2, with "not answered: <item>" as the evidence. No weights, and no
   totals: the orchestrator adds them up.
3. Winner: one eligible design. If none is eligible, say UNRESOLVED and why.
4. Leanest viable: the eligible design with the best score on the `(scope/cost)` criterion (ties:
   fewest new components). Name it, what it costs, and the risk it leaves compared with the winner.
   If the winner is the leanest, say so.
5. Grafts: at most 3 decisions from other designs, each citing the critique that justifies it.
   Label any detail you add that no critique supports as `unreviewed`.
6. Rejected alternatives: per losing design, what lost and why.

Use exactly these headings:
## Gates
## Scorecard
## Winner
## Leanest viable
## Grafts
## Rejected alternatives
## Risks
## Open questions
```

`{{open_gaps}}` lists, per design under the judge's peer labels, the `missing` cells left in
`completeness.md` after repairs, or "none".
