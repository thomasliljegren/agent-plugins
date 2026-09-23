#!/usr/bin/env bash
# Summarises the model-policy log. Run: bash scripts/report.sh [days] [harness]
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$HERE/lib/config.sh"
LOG=$(model_policy_log_path)
DAYS=${1:-14}
HARNESS=${2:-}
case "$DAYS" in
  '' | *[!0-9]*) echo "usage: report.sh [days] [harness] (days is a whole number)" >&2; exit 2 ;;
esac
if [ ! -s "$LOG" ]; then
  echo "No dispatches logged yet ($LOG). The hook writes a line per subagent dispatch while the plugin is enabled."
  exit 0
fi
if [ "$(head -n 1 "$LOG")" != "$MODEL_POLICY_LOG_HEADER" ]; then
  echo "$LOG is not a model-policy 0.2 log (its header differs; 0.1 logs had 9 columns). Move it away or set MODEL_POLICY_LOG to a new file."
  exit 0
fi

SINCE=$(date -u -v-"${DAYS}"d +%Y-%m-%d 2>/dev/null || date -u -d "-${DAYS} days" +%Y-%m-%d)
ROWS=$(mktemp "${TMPDIR:-/tmp}/model-policy-report.XXXXXX") || exit 1
trap 'rm -f "$ROWS"' EXIT
# Columns: 1 time, 2 session, 3 harness, 4 project, 5 agent_type, 6 requested, 7 effective, 8 tier, 9 action, 10 prompt_chars, 11 description
awk -F'\t' -v since="$SINCE" -v h="$HARNESS" 'NR > 1 && substr($1, 1, 10) >= since && (h == "" || $3 == h)' "$LOG" >"$ROWS"

section() { # TITLE AWK_KEY [SORT_ARGS]
  echo
  echo "$1:"
  awk -F'\t' "{ c[$2]++ } END { for (k in c) printf \"  %5d  %s\\n\", c[k], k }" "$ROWS" | sort ${3:--rn}
}

echo "model-policy dispatches since $SINCE, ${HARNESS:-all harnesses} ($LOG)"
echo
echo "Total dispatches: $(wc -l <"$ROWS" | tr -d ' ')"
section "By harness" '$3'
section "By tier (fast, standard, strong, frontier; unknown = model not in the tier map)" '$8'
section "By effective model" '$7'
section "By action (kept = caller named the model, filled = hook chose it, denied = frontier without a reason, justified = frontier with a reason)" '$9'
section "By harness, agent type and effective model" '$3 " " $5 " -> " $7'
section "By day" 'substr($1, 1, 10)' '-k2'
echo
echo "Frontier dispatches and their reasons (justified or denied):"
awk -F'\t' '$8 == "frontier" { printf "  %s %-11s %-9s %-16s %s\n", substr($1, 1, 16), $3, $9, $6, $11 }' "$ROWS"
