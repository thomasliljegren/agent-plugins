# The GitHub backend

Read with `SKILL.md`. This is what is true only of GitHub.

## How the vocabulary maps

| Roadmap | GitHub |
| --- | --- |
| Initiative | an open issue labelled `initiative`; its body names its design |
| Slice | a sub-issue of an initiative, labelled `slice`, in the order set on the parent |
| Dropped | closed as not planned, or as a duplicate |
| Other work | issues labelled `bug` or `debt` |
| Claim | an open pull request into the default branch whose body closes the item; a draft is a tentative claim |
| Release | the closing keyword removed from the body, or the draft closed |

The label names are the defaults; `.roadmap.json` can rename them under `github.labels`.

## Claiming

```
roadmap claim 170 171 --type feat --title "feat(accounts): link an insurer"
```

- `--type` is one of the project's types (`feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `build`, `ci`, `chore` unless `.roadmap.json` says otherwise). `--title` is the pull request's title, `type(scope): title`, the scope a lowercase module or area.
- The command renames the branch to `<type>/<first id>-<description>` (the description from the first issue's title, or `--description`), makes the empty commit `chore: claim #N`, pushes, opens a draft pull request with one `Closes #N` per id and reads it back. Run it from a branch off the default branch, in its own worktree.
- It refuses on the default branch, when another open pull request closes one of the ids, when an id is not an open issue, and when there are staged changes.
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

## What the snapshot can and cannot see

The adapter asks GitHub's REST API only, because a cloud session's GitHub proxy refuses GraphQL queries of its own. Two consequences:

- A claim is read from the closing keywords in the pull request's body, for issues of the same repository. An issue linked by hand in the pull request's sidebar, or one in another repository, is not seen.
- "Closed by hand, not by a merged PR" is judged against the 100 most recently updated closed pull requests. A slice closed before the oldest of them is not judged.

In a cloud session the proxy also refuses `reprioritizeSubIssue` and other GraphQL of your own: ask the owner to move a slice, or do it from a local session. `gh issue list` and `gh pr view --json` are GraphQL too; `gh api repos/{owner}/{repo}/...` is the REST route.
