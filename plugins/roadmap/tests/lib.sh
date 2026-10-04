# Sourced by the *.test.sh files.
set -u
TESTS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$TESTS/.." && pwd)
DATA="$TESTS/testdata"
ROADMAP="$ROOT/bin/roadmap"
SCRATCH=$(cd "$(mktemp -d -t roadmap-test.XXXXXX)" && pwd -P)
trap 'rm -rf "$SCRATCH"' EXIT
export ROADMAP_NOW=1790000000   # 2026-09-21 14:13 UTC
unset CLAUDE_PROJECT_DIR ROADMAP_CONFIG ROADMAP_ROOT ROADMAP_BRANCH ROADMAP_TIMEOUT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
ACCEPT=${1:-}
fail=0

check() { # NAME EXPECTED ACTUAL
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected [$2] got [$3]"; fail=1; fi
}

contains() { # NAME NEEDLE HAYSTACK
  case "$3" in *"$2"*) echo "ok   $1" ;; *) echo "FAIL $1: [$2] is not in [$3]"; fail=1 ;; esac
}

same() { # NAME EXPECTED_FILE, the actual text on stdin. --accept rewrites the expected file instead.
  local actual
  actual=$(cat)
  if [ "$ACCEPT" = "--accept" ]; then printf '%s\n' "$actual" >"$2"; echo "accepted $1"; return; fi
  if [ "$actual" = "$(cat "$2" 2>/dev/null)" ]; then echo "ok   $1"; else
    echo "FAIL $1: differs from ${2#"$ROOT"/}"
    diff <(printf '%s\n' "$actual") "$2" | head -n 20
    fail=1
  fi
}

finish() {
  if [ $fail -eq 0 ]; then echo "passed"; else echo "failed"; exit 1; fi
}

# checkout DIR [BRANCH]: a git checkout whose origin says github.com/example/enzure and pushes to a bare repository beside it.
checkout() {
  git init -q --bare "$1.origin.git"
  git init -q -b main "$1"
  git -C "$1" config url."$1.origin.git".insteadOf https://github.com/example/enzure.git
  git -C "$1" remote add origin https://github.com/example/enzure.git
  git -C "$1" commit -q --allow-empty -m init
  git -C "$1" push -q -u origin main
  if [ -n "${2:-}" ]; then git -C "$1" checkout -q -b "$2"; fi
}

# opt_in DIR [JSON]: the project's .roadmap.json
opt_in() {
  local json=${2:-}
  [ -n "$json" ] || json='{"backend": "github"}'
  printf '%s\n' "$json" >"$1/.roadmap.json"
}

# stub_gh RAW: put tests/stub/gh first on PATH, answering from a *.raw.json fixture and logging each call.
stub_gh() {
  export PATH="$TESTS/stub:$PATH" GH_STUB_RAW="$1" GH_STUB_LOG="$SCRATCH/gh.log"
  unset GH_STUB_FAIL GH_STUB_SLEEP GH_STUB_BRANCH_PR
  : >"$GH_STUB_LOG"
}
