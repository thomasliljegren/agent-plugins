#!/usr/bin/env bash
# The GitHub adapter's state command against a stand-in gh, and the whole path through bin/roadmap. Nothing here asks GitHub.
. "$(dirname "$0")/lib.sh"

P="$SCRATCH/project"
checkout "$P" claude/explainable-dropoff-1a2b3c
opt_in "$P" '{"backend": "github", "rules": "CLAUDE.md", "practices": []}'
stub_gh "$DATA/busy.raw.json"
run() { (cd "$P" && bash "$ROADMAP" "$@" 2>&1); }

check "the state is the normalized fixture" "$(jq -S . "$DATA/busy.state.json")" "$(run --state | jq -S .)"
check "end to end: the snapshot" "$(cat "$DATA/busy.expected.txt")" "$(run)"
check "end to end: the report" "$(cat "$DATA/busy.report.expected.md")" "$(run --report)"
check "the hook prints the snapshot" "$(cat "$DATA/busy.expected.txt")" "$(printf '{"cwd": "%s"}' "$P" | bash "$ROADMAP" --hook)"

calls=$(cat "$GH_STUB_LOG")
check "every call is a REST GET: no GraphQL, which a cloud session's proxy refuses" "" "$(grep -v '^gh api -X GET repos/example/enzure' <<<"$calls" | grep -v '^gh auth')"
check "sub-issues are asked only of initiatives that have some" "12 25 43" "$(grep -o 'issues/[0-9]*/sub_issues' <<<"$calls" | grep -o '[0-9]*' | sort -nu | paste -sd' ' -)"
check "blockers are asked only of open issues whose summary counts one" "17 18 22 27" "$(grep -o 'issues/[0-9]*/dependencies/blocked_by' <<<"$calls" | grep -o '[0-9]*' | sort -nu | paste -sd' ' -)"
check "what a decision blocks is asked only where it blocks something" "28" "$(grep -o 'issues/[0-9]*/dependencies/blocking' <<<"$calls" | grep -o '[0-9]*' | sort -nu | paste -sd' ' -)"
contains "the two new kinds are asked by label" "labels=decision" "$calls"
contains "…" "labels=enhancement" "$calls"
contains "the branch's pull request is asked by owner and branch" "head=example:claude/explainable-dropoff-1a2b3c" "$calls"

stub_gh "$DATA/leftover.raw.json"
git -C "$P" checkout -q -b claude/pr-title-format-ci-eea340
opt_in "$P" '{"backend": "github", "practices": []}'
check "end to end: a leftover worktree" "$(cat "$DATA/leftover.expected.txt")" "$(run)"

opt_in "$P" '{"backend": "github", "github": {"labels": {"bug": "defect"}}}'
: >"$GH_STUB_LOG"; run >/dev/null
contains "a configured label is what GitHub is asked for" "labels=defect" "$(cat "$GH_STUB_LOG")"
opt_in "$P"

unavailable() { check "$1" "ROADMAP UNAVAILABLE: $2. Do not assume project status." "$3"; }
unavailable "GitHub refuses" "gh api failed: Bad credentials (HTTP 401)" "$(GH_STUB_FAIL='Bad credentials (HTTP 401)' run)"
stub_gh "$DATA/busy.raw.json"
unavailable "one failing call among the sub-issues fails the whole answer" "gh api failed: Server Error (HTTP 502)" "$(GH_STUB_FAIL_ON=/sub_issues run)"
unavailable "one failing call among the blockers fails the whole answer" "gh api failed: Server Error (HTTP 502)" "$(GH_STUB_FAIL_ON=/dependencies/blocked_by run)"
start=$(date +%s)
unavailable "GitHub does not answer in time" "the github adapter did not answer within 1 seconds" "$(GH_STUB_SLEEP=20 ROADMAP_TIMEOUT=1 run)"
check "…and no gh call is left running" "" "$(sleep 1; pgrep -f "$TESTS/stub/gh" || true)"
git -C "$P" remote set-url origin https://gitlab.com/example/enzure.git
unavailable "an origin that is not GitHub" "origin (https://gitlab.com/example/enzure.git) is not a GitHub repository" "$(run)"
git -C "$P" remote remove origin
unavailable "a checkout without an origin" "this checkout has no origin remote" "$(run)"

# Review fixes: every open pull request is read, not the first page.
checkout "$SCRATCH/paged" feat/x; opt_in "$SCRATCH/paged"; stub_gh "$DATA/busy.raw.json"
(cd "$SCRATCH/paged" && bash "$ROADMAP" >/dev/null)
contains "open pull requests are read to the end" "state=open -f sort=updated -f direction=desc -f per_page=100 --paginate" "$(cat "$GH_STUB_LOG")"
jq 'del(.decisions, .enhancements, .blockedBy, .blocking)' "$DATA/leftover.raw.json" >"$SCRATCH/plain.raw.json"
checkout "$SCRATCH/plain" feat/x; opt_in "$SCRATCH/plain"; stub_gh "$SCRATCH/plain.raw.json"
plain=$(cd "$SCRATCH/plain" && bash "$ROADMAP" 2>&1)
contains "a project that uses none of the new labels" "DECISIONS FOR THE OWNER: none open" "$plain"
check "…makes no request for dependencies" "" "$(grep dependencies "$GH_STUB_LOG" || true)"
paged() { (cd "$SCRATCH/paged" && bash "$ROADMAP" "$@" 2>&1); }
stub_gh "$DATA/busy.raw.json"
unavailable "a blocker list that cannot be read fails the whole answer" "GitHub's blockers could not be read" "$(GH_STUB_GARBAGE_ON=/dependencies/blocked_by paged)"
unavailable "…and one that is no list" "GitHub's blockers could not be read" "$(GH_STUB_GARBAGE_ON=/dependencies/blocked_by GH_STUB_GARBAGE='{}' paged)"
unavailable "…and what a decision blocks" "GitHub's answer on what the decisions block could not be read" "$(GH_STUB_GARBAGE_ON=/dependencies/blocking paged)"

# Twenty-five open slices that each wait for another: the third round stays small, and none of them turns into next.
jq '.subIssues["43"] = [range(1; 26) | {number: (400 + .), title: "s\(.)", state: "open", state_reason: null, closed_at: null,
                                         labels: [{name: "slice"}], issue_dependencies_summary: {blocked_by: 1, blocking: 0}}]
    | .initiatives[5].sub_issues_summary.total = 25
    | .blockedBy += ([range(1; 26) | {key: "\(400 + .)", value: [{number: 15, state: "open"}]}] | from_entries)' "$DATA/busy.raw.json" >"$SCRATCH/chained.raw.json"
stub_gh "$SCRATCH/chained.raw.json"
chained=$(paged --state)
check "the blockers of at most twenty sub-issues are asked for" "17 18 401-418" \
  "$(grep -o 'issues/[0-9]*/dependencies/blocked_by' "$GH_STUB_LOG" | grep -o '[0-9]*' | sort -nu | grep -v -e '^22$' -e '^27$' | awk 'NR <= 2 {printf "%s ", $0; next} NR == 3 {first = $0} {last = $0} END {print first "-" last}')"
check "…a slice whose blockers were read names them" '[{"id":"#15","claims":["PR #31"]}]' "$(jq -c '.initiatives[5].slices[0].blockedBy' <<<"$chained")"
check "…and the rest are still blocked, their blockers not read" '[{"id":"1 not read","claims":[]}]' "$(jq -c '.initiatives[5].slices[24].blockedBy' <<<"$chained")"
check "…so none of them is next" "" "$(paged | grep -E '#4[0-9][0-9] .* next$')"
# All the sub-issues together are passed on in a file: as an argument they stop at the size a command line carries.
jq '.subIssues["43"] |= map(. + {body: ("x" * 400000)})' "$DATA/busy.raw.json" >"$SCRATCH/large.raw.json"
stub_gh "$SCRATCH/large.raw.json"
check "sub-issues larger than a command line carries are still read" '"#47"' "$(paged --state | jq -c '.initiatives[5].slices[3].id' 2>&1)"
finish
