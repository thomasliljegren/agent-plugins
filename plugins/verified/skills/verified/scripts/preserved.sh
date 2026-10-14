#!/usr/bin/env bash
# Prints each token of OLD that none of the rewritten files carries and the deleted list does not name; exits 1 if
# any, 2 when it cannot check. A token is what tokens.awk prints; missing.awk says when the rewrite carries one.
# Matching is literal: a token is never a pattern. AWK names another awk.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
AWK=${AWK:-awk}

usage() {
  echo "usage: preserved.sh OLD NEW... [--moved FILE...] [--deleted LIST]" >&2
  echo "       preserved.sh --tokens FILE" >&2
  exit 2
}
readable() { [ -f "$1" ] && [ -r "$1" ] || { echo "preserved.sh: cannot read $1" >&2; exit 2; }; }
WORK=$(mktemp -d -t preserved.XXXXXX)
trap 'rm -rf "$WORK"' EXIT
tokens() {
  "$AWK" -f "$HERE/tokens.awk" "$1" >"$WORK/raw" || { echo "preserved.sh: $AWK failed on $1" >&2; exit 2; }
  LC_ALL=C sort -u "$WORK/raw"
}

if [ "${1:-}" = "--tokens" ]; then
  [ $# -eq 2 ] || usage
  readable "$2"
  tokens "$2"
  exit 0
fi

[ $# -ge 2 ] || usage
old=$1
shift
readable "$old"
new=0 moving=no deleted=/dev/null
targets=()
while [ $# -gt 0 ]; do
  case $1 in
    --moved) moving=yes ;;
    --deleted) [ $# -ge 2 ] || usage; deleted=$2; readable "$deleted"; shift ;;
    -*) usage ;;
    *) readable "$1"; targets+=("$1"); [ $moving = yes ] || new=$((new + 1)) ;;
  esac
  shift
done
[ $new -gt 0 ] || usage

tokens "$old" >"$WORK/tokens"
"$AWK" -v deletedfile="$deleted" -v tokenfile="$WORK/tokens" -f "$HERE/missing.awk" "$deleted" "$WORK/tokens" "${targets[@]}"
status=$?
[ $status -le 1 ] || { echo "preserved.sh: $AWK failed" >&2; exit 2; }
exit $status
