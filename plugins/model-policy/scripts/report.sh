#!/usr/bin/env bash
# Summarises the model-policy log. Run: bash scripts/report.sh [days]
set -u
LOG=${MODEL_POLICY_LOG:-$HOME/.claude/logs/model-policy.tsv}
DAYS=${1:-14}
if [ ! -s "$LOG" ]; then
  echo "No dispatches logged yet ($LOG). The hook writes a line per Agent dispatch while the plugin is enabled."
  exit 0
fi
SINCE=$(date -u -v-"${DAYS}"d +%Y-%m-%d 2>/dev/null || date -u -d "-${DAYS} days" +%Y-%m-%d)
echo "model-policy dispatches since $SINCE ($LOG)"
echo
awk -F'\t' -v since="$SINCE" 'NR>1 && substr($1,1,10)>=since' "$LOG" > /tmp/model-policy-report.$$
TOTAL=$(wc -l </tmp/model-policy-report.$$ | tr -d ' ')
echo "Total dispatches: $TOTAL"
echo
echo "By effective model:"
awk -F'\t' '{c[$6]++} END {for (k in c) printf "  %-10s %5d\n", k, c[k]}' /tmp/model-policy-report.$$ | sort -k2 -rn
echo
echo "By action (kept = model named by the caller, filled = hook chose it, denied = top tier without a reason, justified = top tier with a reason):"
awk -F'\t' '{c[$7]++} END {for (k in c) printf "  %-10s %5d\n", k, c[k]}' /tmp/model-policy-report.$$ | sort -k2 -rn
echo
echo "By agent type and effective model:"
awk -F'\t' '{c[$4 " -> " $6]++} END {for (k in c) printf "  %-32s %5d\n", k, c[k]}' /tmp/model-policy-report.$$ | sort -k3 -rn
echo
echo "By day and effective model:"
awk -F'\t' '{c[substr($1,1,10) " " $6]++} END {for (k in c) printf "  %s %5d\n", k, c[k]}' /tmp/model-policy-report.$$ | sort
echo
echo "Top-tier dispatches and their reasons (justified or denied):"
awk -F'\t' '$7=="justified" || $7=="denied" {printf "  %s %-9s %-10s %s\n", substr($1,1,16), $7, $3, $9}' /tmp/model-policy-report.$$
rm -f /tmp/model-policy-report.$$
