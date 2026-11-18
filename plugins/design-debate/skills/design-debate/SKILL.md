---
name: design-debate
description: "Run a multi-agent design debate. Several designers, each with its own lens and where possible its own model family, design a solution independently, critique each other over a set number of rounds or until their designs stop changing, and a judge picks one design. The result is a run folder, docs/working/design-debates/YYYY-MM-DD-<slug>/, holding the framing and an illustrated proposal. Use when the user says 'design debate', 'have agents debate this', 'multi-agent design', 'compare designs from several models', or wants several independent designs argued out before deciding. Designers, rounds, lenses, models and effort are configurable at invoke time, and their defaults in a design-debate.json file."
---

# Design debate

You are the orchestrator. You frame the problem, stop once for the user to approve the framing, then
run designers and a judge as subagents, and write one proposal. The framing and the proposal go in
the run folder, `docs/working/design-debates/YYYY-MM-DD-<slug>/`, so both can be committed. You never let
a subagent write to the repository, and you never commit.

References, all bundled:

- @./references/lenses.md — lens briefs, the optional menu, and the lens-fit check
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

Accept the same settings in plain words ("use 4 designers, low effort", "debate until they agree").

| Setting | Default | Allowed | When out of range |
|---|---|---|---|
| `designers` (N) | 3 | 2–5 | clamp to the nearest bound |
| `rounds` (R) | 2 | a whole number from 1 up, with no upper bound, or `auto` (see Auto rounds) | below 1: use 1 |
| `lenses` | `pragmatist`, `domain-architecture`, `operations-runtime` | names from lenses.md, or free text; a lens may repeat | use free text as the brief; fewer lenses than N: fill from the defaults, then the menu |
| `models` | family preference per slot (models.md) | per-slot id or family | apply the models.md fallback |
| `effort` | `high` | `low`, `medium`, `high`, `xhigh`; global or per slot | harness can't set it: "not applied" |
| `judge-model` | strongest model from a family no designer used | model id | models.md fallback |
| `judge-effort` | same as `effort` | as `effort` | as `effort` |
| `slug` | kebab-case from the problem, at most 6 words | kebab-case | slugify it |

List every clamp, fallback and "not applied" at the checkpoint. Never drop a setting silently.

Planned calls are `N + N×R + 1` (designs, debate rounds, judge), plus up to N repair calls (only
for final designs with gaps, see Completeness) and 1 shared retry: 10 planned at the defaults (13
with every repair). There is no upper bound: the checkpoint shows the count, and approving the
checkpoint approves it. With `rounds=auto` the count is not known in advance: show the calls up to
the end of round 1 (`2N + 1`, judge included) and `N` per further round.

### Defaults files

Settings not given at invoke time come from, highest first:

1. the invocation;
2. `design-debate.json` at the repo root, for the project;
3. `${XDG_CONFIG_HOME:-~/.config}/design-debate/config.json`, for the user;
4. the defaults in the table above.

Each file is a JSON object whose keys are the setting names above. Both files are optional, and a
key in a higher file replaces the same key in a lower one, whole (a `models` object or `lenses`
list is not merged). `slug` is per run, so it is never read from a file.

```json
{
  "designers": 3,
  "rounds": "auto",
  "lenses": ["pragmatist", "domain-architecture", "operations-runtime"],
  "models": { "A": "opus", "B": "sonnet" },
  "effort": "high",
  "judge-model": "opus",
  "judge-effort": "xhigh"
}
```

A value from a file is checked like one given at invoke time, with the same out-of-range rules.
A file that is not a JSON object is ignored as a whole. An unknown key, or `slug`, is ignored. List
both at the checkpoint, so a typo never passes silently. Read the files only at preflight and on
resume: a file changed mid-run changes nothing until `resume`, which then goes back to the
checkpoint (the approval line differs).

### Auto rounds

With `rounds=auto`, run debate rounds until one changes no design:

- After each round, compare every designer's `## Key decisions` with its own previous design
  (the draft, for round 1), bullet by bullet, ignoring order and surrounding whitespace.
- **Converged:** every designer's bullets are the same as in its previous design. Append
  `converged: round-<k>` to `run.md`, and go to Completeness with round k as the final round.
- **Cycling:** not converged, but every designer's bullets match one of its own earlier designs.
  Another round would only repeat the debate. Append `cycled: round-<k>` and treat
  it as converged.
- Otherwise run another round.

Every auto round carries the Final-design note (prompts.md), since any round may be the last. A run
whose designers never settle keeps going; the user can stop it, and `resume` continues from the
next round. Report how many rounds ran and why they ended.

## Run state

The run folder in the repo holds what the user keeps:

```
docs/working/design-debates/YYYY-MM-DD-<slug>/
  framing.md        written at Frame; the user edits it here at the checkpoint
  proposal.md       written at Write (proposal-2.md, … if it already exists)
```

The date is the day the run starts. If the folder already exists (an earlier run with the same
slug that day, possibly committed), use `-2`, `-3`, and so on: never write into another run's
folder. The user may commit the folder at any time, mid-run included.

Keep everything else outside the working tree, in
`$(git rev-parse --absolute-git-dir)/design-debate/<slug>/`. It survives new sessions, never
shows in `git status`, and is per worktree.

```
run.md            settings table, run folder, approval line, dispatch log, retry line, status
drafts/<slot>.md  slots are A..E
round-<k>/<slot>.md  one folder per round, from round-1
completeness.md   written by the orchestrator, no subagent
repair/<slot>.md  only for slots that needed a repair
judge.md
```

`run.md` lines, appended as they happen:

- `run-dir: <repo-relative path>`, the run folder, written at preflight
- `approval: <hash>|N=<n>|R=<r or auto>|<slot:lens:model:effort,...>|judge=<model:effort>`, where `<hash>` is
  `git hash-object <run-dir>/framing.md`
- `dispatch: <stage>/<slot> <ISO time>`, written before every subagent spawn
- `labels: <stage>/<reader> P=<slot>,Q=<slot>,...`, written before each round or judge spawn (see
  Peer labels)
- `retry-used: <stage>/<slot>`
- `converged: round-<k>` or `cycled: round-<k>`, only with `rounds=auto` (see Auto rounds)
- `proposal: <repo-relative path>`, written as soon as the proposal file exists. A `proposal:` line
  above the latest `approval:` line belongs to a superseded run and does not count.
- `status: <framing|approved|design|round-<k>|completeness|judge|written|validated|written-unvalidated|stopped:<reason>>`

## Peer labels

Designers and the judge never see slot letters for other designs. Show designs under the peer
labels `P`, `Q`, `R`, `S`, `T`, shuffled per reader, so a label can never be mistaken for a slot.

- Before each round or judge spawn, append that reader's mapping to `run.md`, for example
  `labels: round-1/A P=C,Q=B` or `labels: judge P=B,Q=A,R=C`.
- Map every critique back to its slot with that line before storing or forwarding it. Each round
  after the first gets each designer the critiques aimed at its own slot in the round before,
  relabelled into that designer's new mapping.
  The judge's critiques and dispositions are relabelled into the judge's mapping.
- Map the judge's winner and grafts back to slots with the judge's `labels:` line before filling
  the proposal. On resume, always use the recorded lines; never reshuffle a completed stage.

A stage file is valid only if it has every heading prompts.md requires for that stage.

## Stages

0. **Preflight.**
   1. Resolve the repo root.
   2. Detect the harness and read the subagent tool's live model list.
   3. Resolve the settings from the invocation and the defaults files (see Defaults files).
   4. If a state folder exists for the slug, do not start a new run over it. Say so in plain text,
      with its status and the `resume <slug>` command, and end your turn. Never offer it through an
      ask-user or question tool.
   5. Pick the run folder (see Run state), note whether `docs/working/design-debates/` exists, and
      write `run-dir:` to `run.md`.
1. **Frame.** You write `<run-dir>/framing.md` yourself, creating the folders, with no subagent,
   following the Framer checklist in prompts.md. End every line without trailing whitespace and the
   file with one newline, so a formatting hook on commit does not change it. Append the resolved
   settings and `status: framing` to `run.md`.
2. **Checkpoint.** See below. This is the only human stop.
3. **Design.** Spawn N designers in parallel with the Designer prompt, each with its slot's lens,
   model and effort. Log each dispatch first. Save each valid reply to `drafts/<slot>.md`. Run the
   mutation check.
4. **Debate.** Run the rounds in order, one at a time. Save each to `round-<k>/` and run the
   mutation check after each.
   1. Round 1: every designer gets its own draft and every peer under shuffled peer labels.
   2. Rounds 2 to R, or with `rounds=auto` until they converge (see Auto rounds): the Rebuttal
      prompt, with each designer's round k−1 design, the round k−1 critiques aimed at it, and its
      peers' round k−1 designs.
   3. The last round carries the Final-design note (prompts.md); with `rounds=auto`, every round
      does.
5. **Completeness.** See Completeness below. Write `completeness.md`, run any repairs, and run the
   mutation check if a repair was spawned.
6. **Judge.** Spawn the judge with the Judge prompt: final designs under shuffled peer labels, plus all
   critiques and dispositions, plus the gaps still open in `completeness.md`, relabelled into the
   judge's mapping. Save to `judge.md`. Run the mutation check.
7. **Write.**
   1. Fill proposal-template.md into `<run-dir>/proposal.md`. Compute the scorecard totals yourself
      from the judge's per-criterion scores, for every design, ineligible ones included and marked.
      Never overwrite: if the file exists, use `proposal-2.md`, `proposal-3.md`, and so on. Append
      `proposal: <path>` and `status: written` to `run.md` straight away. If `run.md` already has a
      `proposal:` line that counts (see Run state), do not write a new file: re-validate and repair
      that file in place.
   2. Validate:
      - Run `python3 .github/scripts/docs/check_integrity.py` if it exists.
      - Check that every relative link and every `path:line` citation in the proposal resolves.
        The integrity checker skips `docs/working/`.
      - Check that there are at least 2 mermaid blocks.
   3. Set `status: validated`, or `status: written-unvalidated` with the failures listed.
   4. Run the final mutation check, which allows the one proposal file in the run folder.
8. **Report.** See Report.

## Completeness

The judge reads only each designer's final design: `round-<k>/<slot>.md` for the last round run. A design that answered an
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
   that slot's final design. Otherwise keep the last round's design and note `repair rejected:
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

Each time you present the checkpoint (after Frame, after any `edit`, and on resume), first rate
the lenses against the current `framing.md` and lenses (see Lens fit in lenses.md). The rating goes
in the checkpoint message only, never in `framing.md`.

The checkpoint message contains:

1. `framing.md` (in the run folder) and the state folder as clickable links (see Linking outputs),
   with a 3–5 line summary of the framing.
2. The slug and the run folder, and say that it was created for this run. The user may commit it.
3. A table of slots, with lens, requested model, resolved model, effort and fallback note for each,
   plus the judge.
4. Lens fit (lenses.md): each lens `fits` or `weak` with its slots and reason, 2–3 suggestions
   per weak lens, and the ready-to-paste `edit lenses=...` line; or one line saying every lens fits.
5. N, R, the planned calls (`N + N×R + 1`, or for `rounds=auto` the calls through round 1 and
   `N` per further round), the up-to-N repair calls and the 1 retry.
6. Every clamp, fallback and "not applied" setting, which defaults files were read, which settings
   came from them, and every ignored file or key.
7. The reply forms: `approve`, `edit <setting>=<value>` (for example `edit rounds=1`), `edit
   framing` (the user edits `<run-dir>/framing.md` in place, then replies `approve`), and `cancel`.

On approve, append the approval line to `run.md`, record the baseline signature (see Mutation check
in Safety), and set `status: approved`. The baseline comes after approval, so whatever the user did in
the repo while reviewing is not blamed on a subagent. If `framing.md` changed since the checkpoint
was shown (`edit framing`), rate the lenses again and show the result with the approval; it does not
reopen the checkpoint. On any other edit, re-show the checkpoint. On
`cancel`, append `status: stopped:cancelled` and end.

## Linking outputs

Every file you hand to the user is a link they can click, never a bare path to go and find:
`framing.md` at the checkpoint, the proposal and `framing.md` in the report, and the state folder.

- If the client has a tool that publishes or attaches files to the chat, use it.
- Otherwise write a markdown link with the absolute path: `[proposal](file:///abs/path.md)`.

## Resume and status

`design-debate status <slug>` reads `run.md` and lists each stage as done, missing or uncertain.

`design-debate resume <slug>`:

1. Read the run folder from the `run-dir:` line. If `<run-dir>/framing.md` is missing:
   - with no `approval:` line and `status:` absent or `framing`, the run died before or during
     Frame: run Frame again into the same run folder, then go to the checkpoint;
   - otherwise stop: say where it was, that the user can restore it (for example from a commit) or
     `cancel`, and end your turn.
2. Recompute the approval line from the current `framing.md` and settings, defaults files included. If it differs from the
   recorded one, or there is none, go back to the checkpoint and say why.
3. If the user re-approves a *changed* approval line, the earlier designs answered a different
   framing or panel. Move `drafts/`, every `round-<k>/`, `completeness.md`, `repair/` and
   `judge.md` into `superseded-<n>/` in
   the state folder, keep the retry line, and restart from Design. The framing stays in the run
   folder; an earlier proposal there stays too, and the new one gets the next free name.
4. If `run.md` has a `proposal:` line that counts (see Run state), go straight to Write step 2:
   validate and repair that file.
5. Otherwise skip every valid stage file.
6. List each `dispatch:` with no valid file as "uncertain, may already be billed", then run it
   again. These re-runs do not use the retry.
7. Keep the retry: a `retry-used:` line from an earlier session still counts.
8. Check the run folder's contents (see Mutation check) before spawning anything. If a stray file is
   still there, stop with `stopped:mutation` again and name it, at no cost.
9. Take a fresh baseline signature, and continue from the first incomplete stage.

## Safety

- Every subagent prompt carries the read-only safety block from prompts.md. Use read-only agent
  types where the harness offers them *and* they accept a model override; otherwise use a general
  agent and rely on the block plus the mutation check.
- **Mutation check:** the signature is these three values, recorded on approve and compared after
  every subagent stage. Run every git command in this check from the repo root (`git -C
  <repo-root> …`), since `<run-dir>` is repo-relative. Each command leaves out the run folder with
  the pathspec `-- . ':(exclude)<run-dir>'`, so the user can edit or commit the framing without
  tripping it:
  - `git status --porcelain --untracked-files=all -- . ':(exclude)<run-dir>'`
  - `git diff HEAD -- . ':(exclude)<run-dir>' | git hash-object --stdin`
  - `git ls-files -o --exclude-standard -z -- . ':(exclude)<run-dir>' | xargs -0 git hash-object | git hash-object --stdin`
    (contents of untracked files, which the first two miss)

  The run folder is checked on its own, from the approval onwards:
  - `git hash-object <run-dir>/framing.md` equals the approved hash. If not, set
    `status: stopped:framing-changed`, say the framing changed after approval (by the user, a
    tool, or a subagent) and that `resume <slug>` re-shows the checkpoint, and stop.
  - `git ls-files -co --exclude-standard -- <run-dir>`, ignoring names that start with a dot, lists
    only these: `framing.md`; any file named by a `proposal:` line above the latest `approval:`
    line, at any stage; and after Write, the current `proposal:` file. Anything else is a
    mutation: name the file and tell the user to move or delete it before `resume`.

  - On any other difference: set `status: stopped:mutation`, list the changed paths, and stop.
  - Never revert, reset, checkout or stash anything; the change may be the user's own work.
  - `resume` takes a new baseline.
- The only repository writes are the run folder's `framing.md` and proposal. Never commit, push,
  open a PR, edit documentation conventions or create tickets.

## Failure policy

| Failure | Response |
|---|---|
| Model unavailable | Use the fallback shown at the checkpoint; record the actual model |
| Reply missing a required heading | Use the shared retry for that call, then stop |
| Retry already used, including in an earlier session | Stop, keep state, report incomplete with the resume command. Never continue with fewer designers |
| Session dies mid-stage | `resume` lists uncertain calls and re-runs them |
| Framing or settings changed after approval | Back to the checkpoint; on re-approval, earlier designs move to `superseded-<n>/` and Design restarts |
| Framing edited mid-run | `stopped:framing-changed`; `resume` re-shows the checkpoint |
| Framing missing on resume | Stop; the user restores it or cancels |
| Mutation check fails | Stop, list paths, never revert |
| Final design misses a framing item | One repair call for that slot (see Completeness); if it fails, the judge scores the gap. Never uses the retry |
| Judge returns UNRESOLVED | Write the proposal with the gates table and the reasons; status `validated` if checks pass |
| Proposal fails validation | `written-unvalidated`, list the failures, keep state for repair |

## Report

End with:

1. The proposal, `framing.md` and the state folder as clickable links, and the proposal's status
   (`validated` or `written-unvalidated`). Say the run folder is ready to commit.
2. The winner and grafts, in 2–3 lines.
3. Planned vs. actual calls (repairs counted separately, with which slots were repaired), the
   rounds run (with `rounds=auto`: and whether they converged or cycled),
   requested vs. actual model per slot, and every setting not applied.
4. Uncertain re-runs, if any, and the resume command if the run is incomplete.
5. If the repo documents where working docs go (for example in `AGENTS.md`) and does not mention
   `docs/working/design-debates/`, suggest adding it in a separate change. Do not edit it.
6. Next step: turn section 8 into tickets, with the user's ticket-writing skill if one is
   installed. Default to one story. Cite the proposal by repo path; use a blob URL only if a pushed
   branch already contains the file.

## Harness notes

- **Copilot (CLI and app):** spawn with `task`, passing `model` and `reasoning_effort` per call.
  Prefer `general-purpose` agents: read-only types may not honour a model override. Launch the
  designers of one stage together, in parallel. The live model list is in the `task` tool's `model`
  parameter.
- **Claude Code:** spawn with `Task`, several in one message for parallelism, with
  `model: opus|sonnet|haiku|fable`. Only Claude models are available, so the judge always shares a family
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
