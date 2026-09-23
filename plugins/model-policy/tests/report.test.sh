#!/usr/bin/env bash
# scripts/report.sh on the 0.2 log.
. "$(dirname "$0")/lib.sh"
REPORT="$ROOT/scripts/report.sh"

case "$(bash "$REPORT")" in "No dispatches logged yet"*) r=empty ;; *) r=other ;; esac
check "no log yet" empty "$r"

hook copilot explore "" x >/dev/null
hook copilot general-purpose gpt-6-astra "bring it together" >/dev/null
hook codex explorer "" x >/dev/null
printf '2000-01-01T00:00:00Z\tsess0000\tclaude-code\tproj\tExplore\t-\thaiku\tfast\tfilled\t1\told\n' >>"$MODEL_POLICY_LOG"

out=$(bash "$REPORT" 14)
check "total in the window" yes "$(grep -qx 'Total dispatches: 3' <<<"$out" && echo yes)"
check "by harness" yes "$(grep -qx '      2  copilot' <<<"$out" && echo yes)"
check "by tier" yes "$(grep -qx '      2  fast' <<<"$out" && echo yes)"
check "by action" yes "$(grep -qx '      1  denied' <<<"$out" && echo yes)"
check "by harness, agent type and model" yes "$(grep -qx '      1  codex explorer -> gpt-6-luna' <<<"$out" && echo yes)"
check "frontier section lists the denial" yes "$(grep -q 'denied.*gpt-6-astra' <<<"$out" && echo yes)"
out=$(bash "$REPORT" 14 copilot)
check "harness filter" yes "$(grep -qx 'Total dispatches: 2' <<<"$out" && echo yes)"
out=$(bash "$REPORT" 36500)
check "a wider window includes old rows" yes "$(grep -qx 'Total dispatches: 4' <<<"$out" && echo yes)"

bash "$REPORT" abc >/dev/null 2>&1
check "non-numeric days is rejected" 2 "$?"

printf 'time\tsession\tproject\tagent_type\trequested\teffective\taction\tprompt_chars\tdescription\n' >"$MODEL_POLICY_LOG"
out=$(bash "$REPORT" 14); status=$?
check "an 0.1 log exits 0" 0 "$status"
case "$out" in *"not a model-policy 0.2 log"*) r=explained ;; *) r=other ;; esac
check "an 0.1 log is explained" explained "$r"
check "an 0.1 log prints no tables" no "$(grep -q 'Total dispatches' <<<"$out" && echo yes || echo no)"

finish
