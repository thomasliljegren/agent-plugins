#!/usr/bin/env bash
# Every plugin whose shipped files changed since BASE carries a higher version than it had there,
# and all of a plugin's manifests carry the same version.
#
#   scripts/check-versions.sh [BASE]     BASE defaults to origin/main
#
# Compares the merge base of BASE and HEAD with the working tree, so commits, staged, unstaged and
# untracked files all count. A change under a plugin's tests/ is not shipped and needs no bump.
# Exit 0 when every plugin holds, 1 when one does not, 2 when the check cannot run.
set -u
base=${1:-origin/main}
root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not in a git repository" >&2; exit 2; }
cd "$root" || exit 2
command -v jq >/dev/null || { echo "jq is needed" >&2; exit 2; }
git rev-parse --verify -q "$base^{commit}" >/dev/null || { echo "no such base: $base" >&2; exit 2; }
mb=$(git merge-base "$base" HEAD) || { echo "no merge base between $base and HEAD" >&2; exit 2; }

above() { # A B: is version A above version B, compared number by number?
  awk -v a="$1" -v b="$2" 'BEGIN {
    na = split(a, x, "."); nb = split(b, y, "."); n = na > nb ? na : nb
    for (i = 1; i <= n; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 }
    exit 1 }'
}

status=0
for dir in plugins/*/; do
  dir=${dir%/}
  name=${dir#plugins/}
  main="$dir/.claude-plugin/plugin.json"
  [ -f "$main" ] || continue
  now=$(jq -r '.version // ""' "$main")

  for m in "$dir"/.*-plugin/plugin.json "$dir"/.github/plugin/plugin.json; do
    [ -f "$m" ] && [ "$m" != "$main" ] || continue
    v=$(jq -r '.version // ""' "$m")
    if [ "$v" != "$now" ]; then
      echo "$name: ${m#"$dir"/} is at ${v:-no version}, .claude-plugin/plugin.json at ${now:-no version}"
      status=1
    fi
  done

  git cat-file -e "$mb:$main" 2>/dev/null || continue # new on this branch
  changed=$( { git diff --name-only "$mb" -- "$dir" ":(exclude)$dir/tests"
               git ls-files --others --exclude-standard -- "$dir" ":(exclude)$dir/tests"; } | head -1)
  [ -n "$changed" ] || continue
  was=$(git show "$mb:$main" | jq -r '.version // ""')
  if [ "$now" = "$was" ]; then
    echo "$name: changed since $base, but still at $now; raise version in $main"
    status=1
  elif ! above "$now" "$was"; then
    echo "$name: changed since $base, but $now is not above $was"
    status=1
  fi
done
exit $status
