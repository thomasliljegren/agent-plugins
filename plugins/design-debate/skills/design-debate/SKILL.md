---
name: design-debate
description: "Run a multi-agent design debate. Several designers, each with its own lens and where possible its own model family, design a solution independently, critique each other over one or two rounds, and a judge picks one design. The result is an illustrated proposal at docs/working/proposals/YYYY-MM-DD-<slug>.md. Use when the user says 'design debate', 'have agents debate this', 'multi-agent design', 'compare designs from several models', or wants several independent designs argued out before deciding. Designers, rounds, lenses, models and effort are configurable at invoke time."
---

# Design debate

You are the orchestrator. You frame the problem, stop once for the user to approve the framing, then
run designers and a judge as subagents, and write one proposal. You never let a subagent write to
the repository, and you never commit.

References, all bundled:

- @./references/lenses.md — lens briefs and the optional menu
- @./references/models.md — model family per slot, fallbacks, judge rule, effort per harness
- @./references/prompts.md — every subagent prompt and its required headings
- @./references/proposal-template.md — the proposal skeleton

## Requires a subagent tool

The debate depends on designers working independently, in separate contexts. Check for a tool
that spawns a subagent with its own prompt (`task` in Copilot, `Task` in Claude Code, or the
equivalent in other clients). If there is none, stop and say this skill cannot run in this client.
Never simulate designers inside your own context: they would not be independent.

## Invocation and defaults

```
design-debate <problem> [designers=3] [rounds=2] [lenses=a,b,c] [models=A:x,B:y]
                 [effort=high] [judge-model=x] [judge-effort=x] [slug=x]
design-debate resume <slug>
design-debate status <slug>
```

Accept the same settings in plain words ("use 4 designers, low effort").

| Setting | Default | Allowed | When out of range |
|---|---|---|---|
| `designers` (N) | 3 | 2–5 | clamp to the nearest bound |
| `rounds` (R) | 2 | 1–2 | clamp to the nearest bound |
| `lenses` | `pragmatist`, `domain-architecture`, `operations-runtime` | names from lenses.md, or free text; a lens may repeat | use free text as the brief; fewer lenses than N: fill from the defaults, then the menu |
| `models` | family preference per slot (models.md) | per-slot id or family | apply the models.md fallback |
| `effort` | `high` | `low`, `medium`, `high`, `xhigh`; global or per slot | harness can't set it: "not applied" |
| `judge-model` | strongest model from a family no designer used | model id | models.md fallback |
| `judge-effort` | same as `effort` | as `effort` | as `effort` |
| `slug` | kebab-case from the problem, at most 6 words | kebab-case | slugify it |

List every clamp, fallback and "not applied" at the checkpoint. Never drop a setting silently.

Planned calls are `N + N×R + 1` (designs, debate rounds, judge), plus up to N repair calls (only
for final designs with gaps, see Completeness) and 1 shared retry: 10 planned at the defaults (13
with every repair), 16 at most (21 with every repair).

## Run state

Keep state outside the working tree, in
`$(git rev-parse --absolute-git-dir)/design-debate/<slug>/`. It survives new sessions, never
shows in `git status`, and is per worktree.

```
run.md            settings table, approval line, dispatch log, retry line, status
framing.md
drafts/<slot>.md  slots are A..E
round-1/<slot>.md
round-2/<slot>.md
completeness.md   written by the orchestrator, no subagent
repair/<slot>.md  only for slots that needed a repair
judge.md
```

`run.md` lines, appended as they happen:

- `approval: <hash>|N=<n>|R=<r>|<slot:lens:model:effort,...>|judge=<model:effort>`, where `<hash>` is
  `git hash-object framing.md`
- `dispatch: <stage>/<slot> <ISO time>`, written before every subagent spawn
- `labels: <stage>/<reader> P=<slot>,Q=<slot>,...`, written before each round or judge spawn (see
  Peer labels)
- `retry-used: <stage>/<slot>`
- `proposal: <repo-relative path>`, written as soon as the proposal file exists
- `status: <framing|approved|design|round-1|round-2|completeness|judge|written|validated|written-unvalidated|stopped:<reason>>`

## Peer labels

Designers and the judge never see slot letters for other designs. Show designs under the peer
labels `P`, `Q`, `R`, `S`, `T`, shuffled per reader, so a label can never be mistaken for a slot.

- Before each round-1, round-2 or judge spawn, append that reader's mapping to `run.md`, for example
  `labels: round-1/A P=C,Q=B` or `labels: judge P=B,Q=A,R=C`.
- Map every critique back to its slot with that line before storing or forwarding it. Round 2 gets
  each designer the critiques aimed at its own slot, relabelled into that designer's new mapping.
  The judge's critiques and dispositions are relabelled into the judge's mapping.
- Map the judge's winner and grafts back to slots with the judge's `labels:` line before filling
  the proposal. On resume, always use the recorded lines; never reshuffle a completed stage.

A stage file is valid only if it has every heading prompts.md requires for that stage.

## Stages

0. **Preflight.**
   1. Resolve the repo root.
   2. Record the baseline signature (see Mutation check in Safety) in `run.md`.
   3. Detect the harness and read the subagent tool's live model list.
   4. Parse the settings.
   5. If a state folder exists for the slug, do not start a new run over it. Say so in plain text,
      with its status and the `resume <slug>` command, and end your turn. Never offer it through an
      ask-user or question tool.
   6. Note whether `docs/working/proposals/` exists.
1. **Frame.** You write `framing.md` yourself, with no subagent, following the Framer checklist in
   prompts.md. Write `run.md` with the resolved settings and `status: framing`.
2. **Checkpoint.** See below. This is the only human stop.
3. **Design.** Spawn N designers in parallel with the Designer prompt, each with its slot's lens,
   model and effort. Log each dispatch first. Save each valid reply to `drafts/<slot>.md`. Run the
   mutation check.
4. **Debate.**
   1. Round 1: every designer gets its own draft and every peer under shuffled peer labels.
      Save to `round-1/`. Run the mutation check.
   2. Round 2, only if R=2: add the critiques aimed at each designer. Save to `round-2/`. Run the
      mutation check.
5. **Completeness.** See Completeness below. Write `completeness.md`, run any repairs, and run the
   mutation check if a repair was spawned.
6. **Judge.** Spawn the judge with the Judge prompt: final designs under shuffled peer labels, plus all
   critiques and dispositions, plus the gaps still open in `completeness.md`, relabelled into the
   judge's mapping. Save to `judge.md`. Run the mutation check.
7. **Write.**
   1. Fill proposal-template.md into `docs/working/proposals/YYYY-MM-DD-<slug>.md`, creating the
      folder if needed. Compute the scorecard totals yourself from the judge's per-criterion scores,
      for every design, ineligible ones included and marked.
      Never overwrite: if the path exists, use `-2`, `-3`, and so on. Append `proposal: <path>`
      and `status: written` to `run.md` straight away. If `run.md` already has a `proposal:` line,
      do not write a new file: re-validate and repair that file in place.
   2. Validate:
      - Run `python3 .github/scripts/docs/check_integrity.py` if it exists.
      - Check that every relative link and every `path:line` citation in the proposal resolves.
        The integrity checker skips `docs/working/`.
      - Check that there are at least 2 mermaid blocks.
   3. Set `status: validated`, or `status: written-unvalidated` with the failures listed.
   4. Run the final mutation check, which allows the one proposal file.
8. **Report.** See Report.

## Completeness

The judge reads only each designer's final design: `round-<R>/<slot>.md`. A design that answered an
item in an earlier draft but dropped it from the final text has not answered it. Check before the
judge, so a gap gets fixed instead of deciding the result.

1. For each slot, read the final design's `## Framing answers` and check it has an entry for every
   requirement (`R1`, `R2`, …) and open question (`Q1`, `Q2`, …) in `framing.md`, and that each entry
   says something, not "see above" or "unchanged".
2. Write `completeness.md`: one table, a row per framing item, a column per slot, each cell `ok` or
   `missing`. A slot's open gaps are its `missing` cells.
3. For each slot with gaps, log `dispatch: repair/<slot>` and spawn one Repair prompt (prompts.md),
   with that slot's model and effort, in parallel. No peer designs, so no `labels:` line.
4. A repair is accepted only if the reply has every required heading and keeps every earlier
   `## Key decisions` bullet word for word. Save an accepted reply to `repair/<slot>.md`; it becomes
   that slot's final design. Otherwise keep the `round-<R>` design and note `repair rejected:
   <reason>` under the table.
5. Re-check accepted repairs and update the table. Never send a second repair.

Repairs are best effort and outside the shared retry. A failed, invalid or rejected repair never
uses the retry and never stops the run: the judge scores the gap instead (prompts.md, Judge). On
resume, a `repair/<slot>` dispatch with no file is re-run once like any uncertain call.

## Checkpoint (hard stop)

Present the checkpoint, then **end your turn**.

- Approval is an explicit new message from the user: `approve`, or one or more `edit` replies
  followed by `approve`.
- Never ask for approval through an ask-user, question or confirmation tool. In autopilot or
  unattended modes those are answered automatically, which would skip the only human gate.
- Silence, a timeout, an automated reply or "continue on your own" instructions are not approval.
  In autopilot, stop at the checkpoint anyway and say why.

The checkpoint message contains:

1. `framing.md` and the state folder as clickable links (see Linking outputs), with a 3–5 line
   summary of the framing.
2. The slug and the proposal path. Say if `docs/working/proposals/` will be created.
3. A table of slots, with lens, requested model, resolved model, effort and fallback note for each,
   plus the judge.
4. N, R, the planned calls (`N + N×R + 1`), the up-to-N repair calls and the 1 retry.
5. Every clamp, fallback and "not applied" setting.
6. The reply forms: `approve`, `edit <setting>=<value>` (for example `edit rounds=1`), `edit
   framing` (the user edits the file, then replies `approve`), and `cancel`.

On approve, append the approval line to `run.md` and set `status: approved`. On any edit, re-show
the checkpoint. On `cancel`, append `status: stopped:cancelled` and end.

## Linking outputs

Every file you hand to the user is a link they can click, never a bare path to go and find:
`framing.md` at the checkpoint, the proposal in the report, and the state folder.

- If the client has a tool that publishes or attaches files to the chat, use it.
- Otherwise write a markdown link with the absolute path: `[proposal](file:///abs/path.md)`.

## Resume and status

`design-debate status <slug>` reads `run.md` and lists each stage as done, missing or uncertain.

`design-debate resume <slug>`:

1. Recompute the approval line from the current `framing.md` and settings. If it differs from the
   recorded one, or there is none, go back to the checkpoint and say why.
2. If the user re-approves a *changed* approval line, the earlier designs answered a different
   framing or panel. Move `drafts/`, `round-1/`, `round-2/`, `completeness.md`, `repair/` and
   `judge.md` into `superseded-<n>/` in
   the state folder, keep the retry line, and restart from Design.
3. If `run.md` has a `proposal:` line, go straight to Write step 2: validate and repair that file.
4. Otherwise skip every valid stage file.
5. List each `dispatch:` with no valid file as "uncertain, may already be billed", then run it
   again. These re-runs do not use the retry.
6. Keep the retry: a `retry-used:` line from an earlier session still counts.
7. Take a fresh baseline signature, and continue from the first incomplete stage.

## Safety

- Every subagent prompt carries the read-only safety block from prompts.md. Use read-only agent
  types where the harness offers them *and* they accept a model override; otherwise use a general
  agent and rely on the block plus the mutation check.
- **Mutation check:** the signature is these three values, recorded at preflight and compared after
  every subagent stage:
  - `git status --porcelain --untracked-files=all`
  - `git diff HEAD | git hash-object --stdin`
  - `git ls-files -o --exclude-standard -z | xargs -0 git hash-object | git hash-object --stdin`
    (contents of untracked files, which the first two miss)

  The final check after Write allows exactly the one `proposal:` file.
  - On any difference: set `status: stopped:mutation`, list the changed paths, and stop.
  - Never revert, reset, checkout or stash anything; the change may be the user's own work.
  - `resume` takes a new baseline.
- The only repository write is the proposal. Never commit, push, open a PR, edit
  documentation conventions or create tickets.

## Failure policy

| Failure | Response |
|---|---|
| Model unavailable | Use the fallback shown at the checkpoint; record the actual model |
| Reply missing a required heading | Use the shared retry for that call, then stop |
| Retry already used, including in an earlier session | Stop, keep state, report incomplete with the resume command. Never continue with fewer designers |
| Session dies mid-stage | `resume` lists uncertain calls and re-runs them |
| Framing or settings changed after approval | Back to the checkpoint; on re-approval, earlier designs move to `superseded-<n>/` and Design restarts |
| Mutation check fails | Stop, list paths, never revert |
| Final design misses a framing item | One repair call for that slot (see Completeness); if it fails, the judge scores the gap. Never uses the retry |
| Judge returns UNRESOLVED | Write the proposal with the gates table and the reasons; status `validated` if checks pass |
| Proposal fails validation | `written-unvalidated`, list the failures, keep state for repair |

## Report

End with:

1. The proposal and the state folder as clickable links, and the proposal's status (`validated` or
   `written-unvalidated`).
2. The winner and grafts, in 2–3 lines.
3. Planned vs. actual calls (repairs counted separately, with which slots were repaired),
   requested vs. actual model per slot, and every setting not applied.
4. Uncertain re-runs, if any, and the resume command if the run is incomplete.
5. If the repo documents where working docs go (for example in `AGENTS.md`) and does not mention
   `docs/working/proposals/`, suggest adding it in a separate change. Do not edit it.
6. Next step: turn section 8 into tickets, with the user's ticket-writing skill if one is
   installed. Default to one story. Cite the proposal by repo path; use a blob URL only if a pushed
   branch already contains the file.

## Harness notes

- **Copilot (CLI and app):** spawn with `task`, passing `model` and `reasoning_effort` per call.
  Prefer `general-purpose` agents: read-only types may not honour a model override. Launch the
  designers of one stage together, in parallel. The live model list is in the `task` tool's `model`
  parameter.
- **Claude Code:** spawn with `Task`, several in one message for parallelism, with
  `model: opus|sonnet|haiku`. Only Claude models are available, so the judge always shares a family
  with a designer: declare it. Effort is not applied.
- **Other clients** (Codex, OpenCode, VS Code): untested. Run only if a subagent tool exists (see
  Requires a subagent tool). Use the models.md "Other harnesses" column, and say in the report that
  the client is untested so the user can share the result.

## Status

Experimental. It is worth keeping once a few real design problems, run in at least two clients,
produce proposals that reviewers rate, blind, as more defensible than a single-agent proposal from
the same framing.

Before then, check whether lenses earn their place. By default each slot mixes a model and a lens,
so a run cannot tell which one shaped a design. On one real framing, run two extra debates with
`rounds=1`, each with its own slug. At each checkpoint, reply `edit framing` and replace that run's
`framing.md` with the original run's, so all three answer the same framing:

1. Same lens, different models: `slug=<slug>-models lenses=pragmatist,pragmatist,pragmatist`, with
   the default model mix.
2. Same model, different lenses: `slug=<slug>-lenses models=A:<id>,B:<id>,C:<id>` (one model id),
   with the default lenses.

Compare the `## Key decisions` of the drafts within each run. If the lens run spreads decisions much
less than the model run, simplify the lenses (for example to one shared brief).
