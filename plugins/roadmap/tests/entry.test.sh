#!/usr/bin/env bash
# bin/roadmap: finding the project, dispatching to the adapter, the time limit, and the one line for every failure.
. "$(dirname "$0")/lib.sh"

P="$SCRATCH/project"
checkout "$P" feat/170-link-insurer

# fake NAME: an adapter of the project's own under adapters/NAME, whose state command is the script on stdin
fake() { mkdir -p "$P/adapters/$1"; cat >"$P/adapters/$1/state"; chmod +x "$P/adapters/$1/state"; opt_in "$P" "{\"backend\": \"adapters/$1\", \"$1\": {\"labels\": {\"slice\": \"s\"}}}"; }
run() { (cd "$P" && bash "$ROADMAP" "$@" 2>&1); }
hook() { printf '{"cwd": "%s"}' "${1:-$P}" | bash "$ROADMAP" --hook 2>&1; }

check "a project without .roadmap.json: the hook is silent" "" "$(hook)"
check "…and exits 0" 0 "$(hook >/dev/null; echo $?)"
contains "…and by hand it says how to opt in" "roadmap setup" "$(run)"
check "outside a git checkout the hook is silent" "" "$(hook "$SCRATCH")"
check "a hook without input is silent" "" "$(cd "$SCRATCH" && bash "$ROADMAP" --hook </dev/null 2>&1)"

fake good <<EOF2
#!/usr/bin/env bash
cat "$DATA/busy.state.json"
EOF2
check "the snapshot" "$(cat "$DATA/busy.expected.txt" | sed 's/ and in CLAUDE.md//')" "$(run)"
check "the hook prints the same" "$(run)" "$(hook)"
check "a subdirectory finds the project" "$(run)" "$(mkdir -p "$P/src/deep" && cd "$P/src/deep" && bash "$ROADMAP")"
check "--state prints the state" '"example/enzure"' "$(run --state | jq -c .project)"
contains "--report prints the report" "# Roadmap" "$(run --report)"
opt_in "$P" '{"backend": "adapters/good", "rules": "docs/WORKING.md"}'
contains "the rules file is named" "The rules are in the roadmap skill and in docs/WORKING.md." "$(run)"
check "an unknown option is a usage error" 2 "$(run --nope >/dev/null; echo $?)"

fake env <<'EOF2'
#!/usr/bin/env bash
echo "ROADMAP UNAVAILABLE: root=$ROADMAP_ROOT branch=$ROADMAP_BRANCH config=$ROADMAP_CONFIG now=$ROADMAP_NOW. Do not assume project status."
EOF2
check "the adapter gets the root, the branch, its config and the time" \
  "ROADMAP UNAVAILABLE: root=$P branch=feat/170-link-insurer config={\"labels\":{\"slice\":\"s\"}} now=$ROADMAP_NOW. Do not assume project status." "$(run)"

unavailable() { # NAME REASON OUTPUT: exactly the one line
  check "$1" "ROADMAP UNAVAILABLE: $2. Do not assume project status." "$3"
}
opt_in "$P" '{"backend": "nowhere"}'
unavailable "a missing adapter" "the nowhere adapter has no state command ($ROOT/adapters/nowhere)" "$(run)"
check "…exits 0" 0 "$(run >/dev/null; echo $?)"
fake failing <<'EOF2'
#!/usr/bin/env bash
echo "boom" >&2; exit 3
EOF2
unavailable "a failing adapter" "the adapters/failing adapter failed: boom" "$(run)"
fake garbage <<'EOF2'
#!/usr/bin/env bash
echo "<html>"
EOF2
contains "unreadable output" "ROADMAP UNAVAILABLE: the answer of the adapters/garbage adapter could not be read" "$(run)"
fake partial <<'EOF2'
#!/usr/bin/env bash
echo '{"project": "p"}'
EOF2
contains "a state that lacks a member" "could not be read (jq: error" "$(run)"
fake slow <<'EOF2'
#!/usr/bin/env bash
sleep 20
EOF2
start=$(date +%s)
unavailable "an adapter that outlasts the time limit" "the adapters/slow adapter did not answer within 1 seconds" "$(ROADMAP_TIMEOUT=1 run)"
check "…and the session waits no longer than that" yes "$([ $(( $(date +%s) - start )) -le 4 ] && echo yes)"
printf 'not json' >"$P/.roadmap.json"
unavailable "a config file that is not JSON" ".roadmap.json is not valid JSON" "$(run)"
opt_in "$P" '{}'
unavailable "a config file without a backend" ".roadmap.json names no backend" "$(run)"

# claim and release go to the adapter with their arguments; they fail when they cannot.
mkdir -p "$P/adapters/good"
printf '#!/usr/bin/env bash\necho "claim $* in $ROADMAP_ROOT"\n' >"$P/adapters/good/claim"; chmod +x "$P/adapters/good/claim"
opt_in "$P" '{"backend": "adapters/good"}'
check "claim reaches the adapter" "claim 170 --type feat in $P" "$(run claim 170 --type feat)"
check "release without the command fails" 1 "$(run release 170 >/dev/null 2>&1; echo $?)"

# The hook file: one SessionStart command, with a limit above the entry point's own.
H="$ROOT/hooks/hooks.json"
check "hooks.json registers SessionStart" 'bash "${CLAUDE_PLUGIN_ROOT}/bin/roadmap" --hook' "$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$H")"
check "the hook's limit is 10 seconds" 10 "$(jq -r '.hooks.SessionStart[0].hooks[0].timeout' "$H")"
check "the hook command runs" "$(run)" "$(printf '{"cwd": "%s"}' "$P" | CLAUDE_PLUGIN_ROOT="$ROOT" bash -c "$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$H")")"
check "bin/roadmap is executable" yes "$([ -x "$ROADMAP" ] && echo yes)"
finish
