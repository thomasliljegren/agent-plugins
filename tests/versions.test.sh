#!/usr/bin/env bash
# A plugin whose shipped files changed since the base carries a higher version, in every manifest it has.
. "$(dirname "$0")/lib.sh"
SCRIPT="$REPO/scripts/check-versions.sh"

g() { git -C "$R" "$@" >/dev/null 2>&1; }

manifest() { # PLUGIN VERSION [DIR]
  mkdir -p "$R/plugins/$1/${3:-.claude-plugin}"
  printf '{ "name": "%s", "version": "%s" }\n' "$1" "$2" >"$R/plugins/$1/${3:-.claude-plugin}/plugin.json"
}

fresh() { # a repository whose main has plugins a and b at 0.1.0, on a branch off it
  R="$SCRATCH/repo$((n = ${n:-0} + 1))"
  mkdir -p "$R"
  g init -q -b main
  g config user.email t@example.com
  g config user.name t
  for p in a b; do
    manifest "$p" 0.1.0
    mkdir -p "$R/plugins/$p/skills/s" "$R/plugins/$p/tests"
    echo one >"$R/plugins/$p/skills/s/SKILL.md"
    echo one >"$R/plugins/$p/tests/run.sh"
  done
  g add -A
  g commit -qm base
  g checkout -qb work
}

commit() { g add -A; g commit -qm change; }

run() { # [BASE]: sets code and out
  out=$(cd "$R" && bash "$SCRIPT" "${1:-main}" 2>&1)
  code=$?
}

fresh
run
check "nothing changed passes" 0 "$code"

fresh
echo two >"$R/plugins/a/skills/s/SKILL.md"
commit
run
check "a changed skill without a bump fails" 1 "$code"
contains "the failure names the plugin and its version" "a: changed since main, but still at 0.1.0" "$out"
check "an unchanged plugin is not named" 0 "$(grep -c '^b:' <<<"$out")"

fresh
echo two >"$R/plugins/a/skills/s/SKILL.md"
manifest a 0.1.1
commit
run
check "a changed skill with a bump passes" 0 "$code"

fresh
echo two >"$R/plugins/a/tests/run.sh"
commit
run
check "a change to tests only needs no bump" 0 "$code"

fresh
manifest c 0.1.0
commit
run
check "a plugin new on the branch passes" 0 "$code"

fresh
echo two >"$R/plugins/a/skills/s/SKILL.md"
manifest a 0.0.9
commit
run
check "a lowered version fails" 1 "$code"
contains "the failure says the version went down" "0.0.9 is not above 0.1.0" "$out"

fresh
manifest a 0.9.0
commit
g checkout -q main
g merge -q work
g checkout -q work
echo two >"$R/plugins/a/skills/s/SKILL.md"
manifest a 0.10.0
commit
run
check "versions compare by number, not by text" 0 "$code"

fresh
echo two >"$R/plugins/a/skills/s/SKILL.md"
run
check "an uncommitted change without a bump fails" 1 "$code"

fresh
echo new >"$R/plugins/a/skills/s/extra.md"
run
check "an untracked new file without a bump fails" 1 "$code"

fresh
echo two >"$R/plugins/a/skills/s/SKILL.md"
manifest a 0.2.0
manifest a 0.1.0 .codex-plugin
commit
run
check "manifests that disagree fail" 1 "$code"
contains "the failure names the manifest" "a: .codex-plugin/plugin.json is at 0.1.0, .claude-plugin/plugin.json at 0.2.0" "$out"

fresh
g checkout -q main
echo two >"$R/plugins/a/skills/s/SKILL.md"
commit
g checkout -q work
run
check "a change on the base alone needs no bump on the branch" 0 "$code"

fresh
run nowhere
check "a base that does not exist is an error, not a pass" 2 "$code"

check "this repository passes against its own HEAD" 0 "$(cd "$REPO" && bash "$SCRIPT" HEAD >/dev/null 2>&1; echo $?)"

finish
