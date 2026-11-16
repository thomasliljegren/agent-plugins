# Proposal template

The orchestrator fills this from `judge.md` and the stage files. Keep the section order. Inline all
diagrams as mermaid blocks, at least two. Replace every `{{placeholder}}`; delete a section only if
the run has nothing for it, and say so in one line instead.

````markdown
# Proposal: {{title}}

**Status:** working proposal, produced by a {{N}}-designer, {{R}}-round design debate on {{date}}
**Winner:** slot {{winner_slot}} ({{winner_lens}}), with {{graft_count}} grafts
**Run:** `{{slug}}` (state is local to the author's worktree and never committed; do not put absolute paths in this file)

| Slot | Lens | Requested model | Actual model | Effort |
|---|---|---|---|---|
{{config_table}}

Judge: {{judge_model}} (effort {{judge_effort}}). {{shared_family_note}}
Calls: {{planned_calls}} planned, {{actual_calls}} made, retry {{retry_state}}, repairs {{repaired_slots_or_none}}.

## 1. Recommendation

{{one decisive paragraph}}

## 2. Design

### 2.1 Components
{{components, with a mermaid diagram}}

### 2.2 Flow
{{flow or sequence, with a mermaid diagram}}

### 2.3 Answers to the framing's open questions
{{one entry per open question}}

## 3. Options considered

{{per design: final position, what the recommendation took from it, why the rest lost}}

### Gates and scorecard
{{gate table and scorecard from judge.md: every design, ineligible ones included and marked, with
your totals. An ineligible design's total is shown but cannot win.}}

## 4. Leanest viable option

{{from the judge's Leanest viable: the cheapest eligible design, what it costs on the (scope/cost)
criterion, and the risk it leaves compared with the recommendation. If the recommendation is the
leanest, say so in one line.}}

## 5. Where the debate changed minds

| Topic | Before (first draft) | After (final) | Who moved whom |
|---|---|---|---|
{{rows from Adopted and Dispositions}}

## 6. Risks and mitigations

| Risk | Mitigation | Residual |
|---|---|---|
{{rows}}

## 7. Open questions for the humans

{{numbered list}}

## 8. Proposed stories

{{one story by default: title, value statement, testable acceptance criteria. Text only.
Create tickets later, with a ticket-writing skill if one is installed.}}

## Appendix: debate summary

{{per designer: first-draft key decisions, final key decisions, the critiques cited by the judge,
and the dispositions. The full transcript stays in the state folder.}}
````
