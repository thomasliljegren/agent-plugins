set -u
TESTS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$TESTS/.." && pwd)
DATA="$TESTS/testdata"
SCRATCH=$(cd "$(mktemp -d -t verified-test.XXXXXX)" && pwd -P)
trap 'rm -rf "$SCRATCH"' EXIT
fail=0

check() { # NAME EXPECTED ACTUAL
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected [$2] got [$3]"; fail=1; fi
}

contains() { # NAME NEEDLE HAYSTACK
  case "$3" in *"$2"*) echo "ok   $1" ;; *) echo "FAIL $1: [$2] is not in [$3]"; fail=1 ;; esac
}

finish() {
  if [ $fail -eq 0 ]; then echo "passed"; else echo "failed"; exit 1; fi
}
