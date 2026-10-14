#!/usr/bin/env bash
# Prints each token of OLD that none of the rewritten files carries and the deleted list does not name; exits 1 if
# any. A token is what tokens.awk prints. Matching is literal: a token is never a pattern. AWK names another awk.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)

usage() {
  echo "usage: preserved.sh OLD NEW... [--moved FILE...] [--deleted LIST]" >&2
  echo "       preserved.sh --tokens FILE" >&2
  exit 2
}
readable() { [ -r "$1" ] || { echo "preserved.sh: cannot read $1" >&2; exit 2; }; }
tokens() { "${AWK:-awk}" -f "$HERE/tokens.awk" "$1" | LC_ALL=C sort -u; }

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
new=0 moving=no deleted=""
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

haystack=$(cat "${targets[@]}")
missing=0
while IFS= read -r token; do
  if [ -n "$deleted" ] && grep -qxF -- "$token" "$deleted"; then continue; fi
  case $haystack in
    *"$token"*) ;;
    *) printf '%s\n' "$token"; missing=1 ;;
  esac
done < <(tokens "$old")
exit $missing
