# The GitHub backend

Read with `SKILL.md`. This is what is true only of GitHub.

## How the vocabulary maps

| Roadmap | GitHub |
| --- | --- |
| Initiative | an open issue labelled `initiative`; its body names its design |
| Slice | a sub-issue of an initiative, labelled `slice`, in the order set on the parent |
| Dropped | closed as not planned, or as a duplicate |
| Blocked | GitHub's blocked-by relation between issues, while the blocker is open |
| Other work | issues labelled `bug`, `decision`, `enhancement` or `debt` |
| Claim | an open pull request into the default branch whose body closes the item; a draft is a tentative claim |
| Release | the closing keyword removed from the body, or the draft closed |

The label names are the defaults; `.roadmap.json` can rename each of the six under `github.labels`.

## Claiming

```
roadmap claim 170 171 --type feat --title "feat(accounts): link an insurer"
```

- `--type` is one of the project's types (`feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `build`, `ci`, `chore` unless `.roadmap.json` says otherwise). `--title` is the pull request's title, `type(scope): title`, the scope a lowercase module or area.
- The command renames the branch to `<type>/<first id>-<description>` (the description from the first issue's title, or `--description`), makes the empty commit `chore: claim #N`, pushes, opens a draft pull request with one `Closes #N` per id and reads it back. Run it from a branch off the default branch, in its own worktree.
- It refuses on the default branch, when another open pull request closes one of the ids, when an id is not an open issue, and when there are staged changes.
- Two sessions that claim an id at the same moment both pass that check, so the command reads the open pull requests once more after it opened its own. The pull request opened first, the one with the lower number, keeps the id. The later one releases it, closes its draft when nothing is left, and fails with `lost #N to PR #M`: run `roadmap` and propose again. The earlier one is told that `PR #M claims #N as well`; if `roadmap` still shows both after that, tell the owner.
- A draft whose only commit is the claim's own is printed with `nothing pushed since the claim`. Stale and like that, it holds no work: the report says to close it, not to pick it up.
- CI skips drafts (the `PR title` check does not): `gh pr ready` starts it, so run the tests locally until then.

## Pitfalls

- **One closing keyword per issue.** `Closes #12, closes #13` closes both; `Closes #12, #13` closes only #12.
- **GitHub reads a keyword anywhere in the body.** Prose like "#9 now closes #17" closes #17 too. After writing a description, run `roadmap` and check the line for your branch shows exactly the issues you claimed.
- **Only pull requests into the default branch link and close issues.** A later pull request that builds on an earlier one branches from that branch and still targets the default branch, and says in its body which merges first. When the default branch moves, merge it into the lowest branch and each branch into the next. Never rebase a pushed branch.
- **Renaming a pushed branch closes its pull request.** `roadmap claim` renames before the first push. A wrong name after that costs a new pull request.
- **Never close an issue as completed by hand.** A pull request closes it. Close it as not planned to drop it.
- **Every pull request closes an issue.** If it cannot, split the issue.
- **The order of slices is the order on the parent.** A new slice is appended last: `gh issue create --parent <initiative> --label slice`. Move it to its place with the `reprioritizeSubIssue` GraphQL mutation (`gh api graphql`, inputs `issueId`, `subIssueId` and `afterId` or `beforeId`, node ids from `gh issue view N --json id`).
- **Releasing** removes the keyword and keeps the rest of the description. A draft that closes nothing more is closed; its branch is kept.

## Other work and blockers

- **File it with one label**: `gh issue create --label bug` (or `decision`, `enhancement`, `debt`). An enhancement an initiative takes becomes its sub-issue and swaps its label for `slice`.
- **An issue that waits for another says so with the relation**, never only in its body: `gh issue edit N --add-blocked-by M`. The roadmap then prints N as `blocked` and keeps it out of `next` until M closes. Where GraphQL is refused: `gh api -X POST repos/{owner}/{repo}/issues/N/dependencies/blocked_by -F issue_id=<id>`, the id from `gh api repos/{owner}/{repo}/issues/M --jq .id`.
- **A decision** is the question and its options in the issue's body, and blocks what waits for it (`gh issue edit <waiting> --add-blocked-by <decision>`). The roadmap lists the open ones with what each blocks. When the owner answers, write the answer as a comment and close the issue as completed; it is the one issue closed by hand.

## The `findings` practice

- Search before filing: `gh issue list --state open --search "<words>"`.
- A dropped finding is one line under a `Dropped` heading in the pull request's description.
- The rest of an issue your pull request could not finish is a new sub-issue of the same initiative: `gh issue create --parent <initiative> --label slice`, moved to its place as under Pitfalls.

## The `ready` practice

- `gh pr ready N` marks the pull request ready. Where CI skips drafts, that is what starts it, so the tests ran only locally until then.
- The line `THIS BRANCH` of `roadmap` shows what the pull request closes. Read it after writing the description: a keyword in prose closes an issue too.

## The `stacking` practice

- A pull request higher in a stack still targets the default branch, because only those link and close issues; it branches from the one below and says in its body which merges first.
- When the default branch moves: `git merge` it into the lowest branch, then each branch into the next. Never `git rebase` a pushed branch.
- A slice you will not start: `roadmap release <ids>`. It takes the keyword out of the description and closes a draft that closes nothing more.

## The `merge` practice

`roadmap setup` adds the permissions for `gh pr merge`, `gh pr checks`, `gh pr view` and `gh run rerun` when the project names `merge`.

1. After `gh pr ready N`, wait until `gh pr checks N --required --json bucket -q '.[].bucket'` prints no `skipping` line. A job that CI skips on a draft is recorded as a completed check, which a required check accepts: only the draft state held the merge. Auto-merge turned on before the new run registers merges at once.
2. A pull request in conflict with the default branch (`gh pr view N --json mergeable` answers `CONFLICTING`) gets no run at all: merge the default branch into it first. A run that has not appeared after five minutes is started again, once: `gh pr ready N --undo`, then `gh pr ready N`. If it has not appeared five minutes after that, tell the owner and stop.
3. `gh pr merge N --squash --auto`, then watch: `gh pr checks N --watch`.
4. Auto-merge that was turned off and on again has been seen to stay on and not merge. When the required checks have passed and, two minutes later, `gh pr view N --json state,mergeStateStatus,autoMergeRequest` still answers `OPEN`, `CLEAN` and an auto-merge request, merge with `gh pr merge N --squash`.
5. Before you change the pull request: `gh pr merge N --disable-auto`.
6. A cancelled run with no newer one is rerun once: `gh run rerun <run id>`. If that one is cancelled too, tell the owner and stop.
7. Never `git push --force`, and never `gh pr merge --admin`: those are the owner's.

## Overlap

```
roadmap overlap
roadmap overlap src/Accounts docs/accounts.md
```

- Without paths it compares what this checkout changes against `origin/<default branch>`, committed or not and untracked files too, with the files of every other open pull request, wherever that one is to merge. With paths it compares those instead, a directory standing for everything under it: that is the form for before the work starts.
- It prints the pull requests that share a file, what each claims and the files, `2 of 9` being two shared of the nine it changes. A renamed file counts under both its names.
- It reads the thirty most recently updated pull requests and the first hundred files of each, and says so where there were more (`+2 not read`, `100 of 100 or more`).
- A shared file is no conflict yet. It says who to read before you mark your work ready, and that the second of the two to merge takes the default branch in first.

## What the snapshot can and cannot see

The adapter asks GitHub's REST API only, because a cloud session's GitHub proxy refuses GraphQL queries of its own. What follows from that:

- A claim is read from the closing keywords in the pull request's body, written as `Closes #N`. An issue linked by hand in the pull request's sidebar, one named by its URL or as `owner/repo#N`, or one in another repository, is not seen: GitHub closes it all the same, but the roadmap shows the branch as having no closing link.
- A pull request from a fork is not a claim, since anyone can open one, and one into another branch than the default is not either, since GitHub links no issue for it. The roadmap says which of the two it is, and for the second how to retarget it.
- Blockers are read from GitHub's dependencies: the first twenty initiatives, the first ten bugs and, of the open sub-issues that wait for something, the first twenty. A blocked sub-issue beyond those is still printed as blocked, with `1 not read` where its blocker would be. A blocker in another repository is printed with that repository's name (`owner/name#N`), and no pull request of this repository counts as a claim on it.
- Every open issue labelled `bug`, `decision`, `enhancement` or `debt` is read to be counted, a hundred a request, one request after another. A label with many hundreds of open issues can take the snapshot past its five seconds; it then says `ROADMAP UNAVAILABLE` and why.
- A claim's idle time is counted from the pull request's `updated_at`, which a push, a comment and an edit of the description all move. It is stale after `staleAfterHours` of `.roadmap.json`, 168 where the file does not say.
- Whether anything was pushed since the claim is asked only of drafts that close something, the first twenty of them. Any other claim carries no such mark.
- What changed since the last look is worked out from one line for each item, kept in the checkout's git directory (`roadmap-seen.json`, never in the work tree). It is the checkout's last look, whoever looked: a subagent that runs `roadmap` there uses it up for the session. The tables are whole either way.
- "Closed by hand, not by a merged PR" is judged against the 100 most recently updated closed pull requests. A slice closed before the oldest of them is not judged.

In a cloud session the proxy also refuses `reprioritizeSubIssue` and other GraphQL of your own: ask the owner to move a slice, or do it from a local session. `gh issue list` and `gh pr view --json` are GraphQL too; `gh api repos/{owner}/{repo}/...` is the REST route.
