# Sourced by the *.test.sh files.
set -u
TESTS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$TESTS/.." && pwd)
HOOK="$ROOT/scripts/model-policy.sh"
SCRATCH=$(mktemp -d -t model-policy-test.XXXXXX)
trap 'rm -rf "$SCRATCH"' EXIT
export MODEL_POLICY_LOG="$SCRATCH/state/dispatches.tsv"
export MODEL_POLICY_CONFIG="$SCRATCH/no-override.json"
unset COPILOT_CLI CURSOR_VERSION CURSOR_PLUGIN_ROOT MODEL_POLICY_DEBUG
fail=0

check() { # NAME EXPECTED ACTUAL
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected [$2] got [$3]"; fail=1; fi
}

finish() {
  if [ $fail -eq 0 ]; then echo "passed"; else echo "failed"; exit 1; fi
}
