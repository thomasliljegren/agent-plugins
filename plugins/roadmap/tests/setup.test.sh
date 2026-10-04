#!/usr/bin/env bash
# roadmap setup for GitHub, against a stand-in gh and a temporary repository.
. "$(dirname "$0")/lib.sh"

P="$SCRATCH/project"
checkout "$P"
jq '. + {labels: ["bug"]}' "$DATA/leftover.raw.json" >"$SCRATCH/labels.raw.json"
stub_gh "$SCRATCH/labels.raw.json"
setup() { (cd "$P" && bash "$ROADMAP" setup "$@" 2>&1); }

out=$(setup github </dev/null)
check "without an answer nothing is written" "" "$(cd "$P" && ls -A | grep -v '^\.git$')"
check "…and nothing is created" "" "$(grep 'POST' "$GH_STUB_LOG")"
contains "…and each change was asked about" "Write .roadmap.json (backend: github)? [y/N]" "$out"

out=$(setup github --yes)
check ".roadmap.json opts the project in" github "$(jq -r .backend "$P/.roadmap.json")"
check "the missing labels are created, the present one is not" "initiative slice debt" "$(grep 'POST' "$GH_STUB_LOG" | grep -o 'name=[a-z]*' | sed 's/name=//' | paste -sd' ' -)"
W="$P/.github/workflows/pr-title.yml"
contains "the workflow carries the types" "pattern='^(feat|fix|refactor|perf|docs|test|build|ci|chore)\\([a-z0-9-]+\\): .*[^ ]\$'" "$(cat "$W")"
check "…and no placeholder is left" 0 "$(grep -c '__' "$W")"
check "the permissions are written" '["Bash(git add *)","Bash(git commit *)","Bash(git push *)","Bash(gh pr ready *)"]' "$(jq -c .permissions.allow "$P/.claude/settings.json")"
check "…with force pushes under ask" 6 "$(jq '.permissions.ask | length' "$P/.claude/settings.json")"
contains "the required check is printed, not run" "gh api -X POST repos/example/enzure/rulesets" "$out"
check "…" "" "$(grep rulesets "$GH_STUB_LOG")"

before=$(cat "$P/.roadmap.json" "$W" "$P/.claude/settings.json")
out=$(setup github --yes)
check "a second run changes nothing" "$before" "$(cat "$P/.roadmap.json" "$W" "$P/.claude/settings.json")"
contains "…and says so" ".claude/settings.json has the permissions already." "$out"

# What the project decided stays decided.
cat >"$P/.claude/settings.json" <<'JSON'
{
  "model": "sonnet",
  "permissions": {
    "allow": ["Bash(npm test)"],
    "ask": ["Bash(git commit *)"],
    "deny": ["Bash(git push *)"]
  },
  "hooks": {"Stop": []}
}
JSON
out=$(setup github --yes)
S="$P/.claude/settings.json"
check "an existing allow rule stays first" '"Bash(npm test)"' "$(jq -c '.permissions.allow[0]' "$S")"
check "a command under deny is not allowed" false "$(jq '.permissions.allow | any(. == "Bash(git push *)")' "$S")"
check "a command under ask is not allowed" false "$(jq '.permissions.allow | any(. == "Bash(git commit *)")' "$S")"
check "…and both stay where they were" '[["Bash(git commit *)"],["Bash(git push *)"]]' "$(jq -c '[.permissions.ask[:1], .permissions.deny]' "$S")"
contains "…and are reported" "Left under ask or deny, where the project put them: Bash(git commit *), Bash(git push *)." "$out"
check "the rest of the file is kept" '["sonnet",[]]' "$(jq -c '[.model, .hooks.Stop]' "$S")"
printf 'not json' >"$S"
contains "a settings file that is not JSON is left alone" ".claude/settings.json is not valid JSON; it is left as it is." "$(setup github --yes)"
check "…" "not json" "$(cat "$S")"
echo "# ours" >"$W"
contains "a workflow of the project's own is left alone" "differs from the template; it is left as it is" "$(setup github --yes)"
check "…" "# ours" "$(cat "$W")"

printf '{"backend": "github", "github": {"labels": {"slice": "work item"}, "types": ["feat", "fix"]}}\n' >"$P/.roadmap.json"
rm "$W"; : >"$GH_STUB_LOG"
setup github --yes >/dev/null
contains "a configured label is the one created" "name=work item" "$(cat "$GH_STUB_LOG")"
contains "configured types reach the workflow" "pattern='^(feat|fix)/" "$(cat "$W")"
finish
