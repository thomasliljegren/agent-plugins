#!/usr/bin/env bash
# roadmap claim and roadmap release for GitHub, against a stand-in gh and a temporary repository with a local origin.
. "$(dirname "$0")/lib.sh"

# A project with three slices (#172 closed) and one pull request by someone else, which claims #177.
DATA_OPEN="$SCRATCH/open.raw.json"
jq '.subIssues = {"12": [{number: 170, title: "Link an insurer: tenant & scope", state: "open"}, {number: 171, title: "Tier overrides", state: "open"},
                         {number: 172, title: "Done already", state: "closed"}, {number: 177, title: "Failed readings", state: "open"}]}
    | .branchPrs = []
    | .openPrs = [{number: 204, draft: false, head: {ref: "feat/177-x"}, base: {ref: "main"}, updated_at: "2026-09-21T09:00:00Z", body: "Closes #177"}]' \
  "$DATA/leftover.raw.json" >"$DATA_OPEN"

# fresh NAME BRANCH: a new opted-in checkout on BRANCH, and a stand-in gh that knows no pull request for it yet
fresh() {
  P="$SCRATCH/$1"
  checkout "$P" "$2"
  opt_in "$P"
  stub_gh "$DATA_OPEN"
  export GH_STUB_BRANCH_PR="$SCRATCH/$1.pr.json"
}
claim() { (cd "$P" && bash "$ROADMAP" claim "$@" 2>&1); }
release() { (cd "$P" && bash "$ROADMAP" release "$@" 2>&1); }
T='feat(accounts): link an insurer'

fresh happy claude/some-session-1a2b3c
out=$(claim '#170' 171 --type feat --title "$T")
contains "claim says what it made" "Claimed #170, #171: PR #300 (draft) on feat/170-link-an-insurer-tenant-scope." "$out"
check "the branch is named after the first id and its title" feat/170-link-an-insurer-tenant-scope "$(git -C "$P" branch --show-current)"
check "the claim commit is empty and says what it claims" "chore: claim #170, #171" "$(git -C "$P" log -1 --format=%s)"
check "…and is pushed" "$(git -C "$P" rev-parse HEAD)" "$(git -C "$P.origin.git" rev-parse refs/heads/feat/170-link-an-insurer-tenant-scope)"
calls=$(cat "$GH_STUB_LOG")
contains "a draft pull request" "-F draft=true" "$calls"
contains "into the default branch" "-f base=main" "$calls"
check "one closing keyword per issue" "Closes #170
Closes #171" "$(jq -r .body "$GH_STUB_BRANCH_PR")"
check "one pull request is opened" 1 "$(grep -c 'api -X POST' <<<"$calls")"
check "…and read back last" "gh api -X GET repos/example/enzure/pulls/300" "$(tail -n 1 <<<"$calls")"
check "repeating a finished claim changes nothing and succeeds" "Already claimed: PR #300 on feat/170-link-an-insurer-tenant-scope closes #170, #171." "$(claim 171 170 --type feat --title "$T")"
check "…with no second commit" 1 "$(git -C "$P" log --format=%s main..HEAD | grep -c 'chore: claim')"
contains "the same branch cannot claim something else" "this branch already has PR #300, which closes 170 171" "$(claim 12 --type feat --title "$T")"

fresh named feat/170-link-insurer
claim 170 --type feat --title "$T" >/dev/null
check "a branch that already has the right name keeps it" feat/170-link-insurer "$(git -C "$P" branch --show-current)"
fresh described claude/x
claim 170 --type feat --title "$T" --description 'Link insurer' >/dev/null
check "--description names the branch" feat/170-link-insurer "$(git -C "$P" branch --show-current)"

# A claim that stopped after each step is finished by the same command.
fresh resumed claude/y
contains "a failed push names the step" "pushing feat/170-link-insurer failed" "$(git -C "$P" remote set-url --push origin /nonexistent; claim 170 --type feat --title "$T" --description 'link insurer')"
git -C "$P" remote set-url --push origin "$P.origin.git"
contains "…and the same command finishes the claim" "Claimed #170: PR #300" "$(claim 170 --type feat --title "$T" --description 'link insurer')"
check "…without a second claim commit" 1 "$(git -C "$P" log --format=%s main..HEAD | grep -c 'chore: claim')"
fresh resumed2 claude/z
contains "a failed pull request names the step" "opening the draft pull request failed" "$(GH_STUB_FAIL_ON='-X POST' claim 170 --type feat --title "$T")"
contains "…and the same command finishes the claim" "Claimed #170: PR #300" "$(claim 170 --type feat --title "$T")"

# Refusals: nothing is renamed, committed or pushed.
refuses() { # NAME REASON ARGS...
  local name=$1 reason=$2 before; shift 2
  before=$(git -C "$P" rev-parse HEAD)$(git -C "$P" branch --show-current)
  contains "$name" "$reason" "$(claim "$@")"
  check "…and touches nothing" "$before" "$(git -C "$P" rev-parse HEAD)$(git -C "$P" branch --show-current)"
}
fresh refusing claude/w
refuses "an id someone else holds" "already claimed: PR #204 claims #177" 170 177 --type feat --title "$T"
refuses "a closed issue" "#172 is not an open issue" 172 --type feat --title "$T"
refuses "an issue that does not exist" "#999: gh api failed: Not Found (HTTP 404)" 999 --type feat --title "$T"
refuses "an id that is not a number" "an id is an issue number" abc --type feat --title "$T"
refuses "a type that is not configured" "--type is one of: feat fix" 170 --type feature --title "$T"
refuses "a title in another format" "--title must read 'feat(scope): title'" 170 --type feat --title "Link an insurer"
refuses "a title of another type" "--title must read 'fix(scope): title'" 170 --type fix --title "$T"
refuses "an option without its value" "--title needs a value" 170 --type feat --title
refuses "no ids" "usage: roadmap claim" --type feat --title "$T"
echo x >"$P/file" && git -C "$P" add file
refuses "staged changes, which the empty commit would take along" "there are staged changes" 170 --type feat --title "$T"
git -C "$P" reset -q
git -C "$P" checkout -q main
refuses "the default branch" "this is main" 170 --type feat --title "$T"
git -C "$P" checkout -q --detach
refuses "a detached HEAD" "detached HEAD" 170 --type feat --title "$T"
check "a refusal exits 1" 1 "$(claim 170 --type feat --title "$T" >/dev/null; echo $?)"

# release
body() { printf '%s' "$1" | jq -Rs '{number: 300, state: "open", draft: '"${2:-true}"', body: ., base: {ref: "main"}}' >"$GH_STUB_BRANCH_PR"; }
patched() { sed -n '/api -X PATCH/,$p' "$GH_STUB_LOG"; : >"$GH_STUB_LOG"; }   # the last change sent, bodies and all
fresh releasing feat/170-link-insurer
check "a branch without a pull request has nothing to release" "Nothing to release: feat/170-link-insurer has no open pull request, so it claims nothing." "$(release 170)"
body 'Closes #170, closes #171

Builds on #160.'
check "releasing one id keeps the others" "Released #171: PR #300 still closes #170." "$(release 171)"
contains "…and only its keyword leaves the body" "body=Closes #170

Builds on #160." "$(patched)"
check "the first of a list leaves no stray comma" "Released #170: PR #300 still closes #171." "$(release '#170')"
contains "…" "body=closes #171" "$(patched)"
check "releasing what the pull request does not close changes nothing" "Nothing to release: PR #300 does not close #999." "$(release 999)"
body 'Closes #17 and closes #170'
contains "#17 is not #170" "PR #300 still closes #170" "$(release 17)"
body 'Closes #170
Closes #171'
check "the last id closes a draft and keeps the branch" "Released #170, #171: draft PR #300 closed nothing more and is closed. The branch feat/170-link-insurer is kept." "$(release 170 171)"
contains "…by closing the pull request" "state=closed" "$(patched)"
check "…and the branch is still there" feat/170-link-insurer "$(git -C "$P" branch --show-current)"
body 'Closes #170' false
contains "a pull request up for review is not closed" "is up for review and now closes nothing" "$(release 170)"
check "…" "" "$(patched | grep state=closed)"

# Review fixes: a list anywhere in the body, and pull requests from forks.
fresh releasing2 feat/17-x
body 'Summary of the work.

Closes #17, closes #170'
release 17 >/dev/null
contains "a list in the middle of the body leaves no stray comma" "body=Summary of the work.

closes #170" "$(patched)"
body 'Closes #17 and closes #170'
release 17 >/dev/null
contains "…and no stray and" "body=closes #170" "$(patched)"
body 'Done:
- Closes #17
- Closes #170'
release 17 >/dev/null
contains "a bullet that held only the keyword goes with it" "body=Done:
- Closes #170" "$(patched)"
jq '.openPrs += [{number: 205, draft: false, head: {ref: "patch-1", repo: {full_name: "stranger/enzure"}}, base: {ref: "main"}, updated_at: "2026-09-21T09:00:00Z", body: "Closes #171"}]' \
  "$DATA_OPEN" >"$SCRATCH/fork.raw.json"
fresh forked claude/v
stub_gh "$SCRATCH/fork.raw.json"; export GH_STUB_BRANCH_PR="$SCRATCH/forked.pr.json"
contains "a pull request from a fork does not hold an issue" "Claimed #171: PR #300" "$(claim 171 --type feat --title "$T")"
contains "open pull requests are read to the end" "pulls -f state=open -f per_page=100 --paginate" "$(cat "$GH_STUB_LOG")"

# A clone that does not have origin/<default>, and a branch that was pushed under its old name.
fresh shallow claude/s
git -C "$P" update-ref -d refs/remotes/origin/main
GH_STUB_FAIL_ON='-X POST' claim 170 --type feat --title "$T" >/dev/null
claim 170 --type feat --title "$T" >/dev/null
check "a resumed claim without origin/main makes no second claim commit" 1 "$(git -C "$P" log --format=%s main..HEAD | grep -c 'chore: claim')"
fresh pushed claude/old-name
git -C "$P" push -q -u origin claude/old-name
out=$(claim 170 --type feat --title "$T" --description 'link insurer')
contains "a branch pushed under its old name: the old remote branch is named" "origin/claude/old-name is left as it is" "$out"
check "…and the branch now follows its new name" origin/feat/170-link-insurer "$(git -C "$P" rev-parse --abbrev-ref '@{upstream}')"
finish
