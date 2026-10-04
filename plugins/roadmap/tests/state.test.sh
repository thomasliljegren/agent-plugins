#!/usr/bin/env bash
# The GitHub adapter's state command against a stand-in gh, and the whole path through bin/roadmap. Nothing here asks GitHub.
. "$(dirname "$0")/lib.sh"

P="$SCRATCH/project"
checkout "$P" claude/explainable-dropoff-1a2b3c
opt_in "$P" '{"backend": "github", "rules": "CLAUDE.md"}'
stub_gh "$DATA/busy.raw.json"
run() { (cd "$P" && bash "$ROADMAP" "$@" 2>&1); }

check "the state is the normalized fixture" "$(jq -S . "$DATA/busy.state.json")" "$(run --state | jq -S .)"
check "end to end: the snapshot" "$(cat "$DATA/busy.expected.txt")" "$(run)"
check "end to end: the report" "$(cat "$DATA/busy.report.expected.md")" "$(run --report)"
check "the hook prints the snapshot" "$(cat "$DATA/busy.expected.txt")" "$(printf '{"cwd": "%s"}' "$P" | bash "$ROADMAP" --hook)"

calls=$(cat "$GH_STUB_LOG")
check "every call is a REST GET: no GraphQL, which a cloud session's proxy refuses" "" "$(grep -v '^gh api -X GET repos/example/enzure' <<<"$calls" | grep -v '^gh auth')"
check "sub-issues are asked only of initiatives that have some" "12 25" "$(grep -o 'issues/[0-9]*/sub_issues' <<<"$calls" | grep -o '[0-9]*' | sort -nu | paste -sd' ' -)"
contains "the branch's pull request is asked by owner and branch" "head=example:claude/explainable-dropoff-1a2b3c" "$calls"

stub_gh "$DATA/leftover.raw.json"
git -C "$P" checkout -q -b claude/pr-title-format-ci-eea340
opt_in "$P"
check "end to end: a leftover worktree" "$(cat "$DATA/leftover.expected.txt")" "$(run)"

opt_in "$P" '{"backend": "github", "github": {"labels": {"bug": "defect"}}}'
: >"$GH_STUB_LOG"; run >/dev/null
contains "a configured label is what GitHub is asked for" "labels=defect" "$(cat "$GH_STUB_LOG")"
opt_in "$P"

unavailable() { check "$1" "ROADMAP UNAVAILABLE: $2. Do not assume project status." "$3"; }
unavailable "GitHub refuses" "gh api failed: Bad credentials (HTTP 401)" "$(GH_STUB_FAIL='Bad credentials (HTTP 401)' run)"
stub_gh "$DATA/busy.raw.json"
unavailable "one failing call among the sub-issues fails the whole answer" "gh api failed: Server Error (HTTP 502)" "$(GH_STUB_FAIL_ON=/sub_issues run)"
start=$(date +%s)
unavailable "GitHub does not answer in time" "the github adapter did not answer within 1 seconds" "$(GH_STUB_SLEEP=20 ROADMAP_TIMEOUT=1 run)"
check "…and no gh call is left running" "" "$(sleep 1; pgrep -f "$TESTS/stub/gh" || true)"
git -C "$P" remote set-url origin https://gitlab.com/example/enzure.git
unavailable "an origin that is not GitHub" "origin (https://gitlab.com/example/enzure.git) is not a GitHub repository" "$(run)"
git -C "$P" remote remove origin
unavailable "a checkout without an origin" "this checkout has no origin remote" "$(run)"
finish
