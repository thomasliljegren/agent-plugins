# Sourced by state, claim, release and setup.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"   # the desktop app's hooks do not always inherit the shell's PATH
export GH_NO_UPDATE_NOTIFIER=1 GH_PROMPT_DISABLED=1 NO_COLOR=1

adapter=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=${ROADMAP_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}
config=${ROADMAP_CONFIG:-}
[ -n "$config" ] || config='{}'

named() { jq -r --arg kind "$1" '.labels[$kind] // $kind' <<<"$config"; }   # named slice -> the label that means slice
types() { jq -r '.types // ["feat","fix","refactor","perf","docs","test","build","ci","chore"] | join("|")' <<<"$config"; }

# github_repo: prints owner/name of origin, or the reason it cannot and returns 1.
# The raw setting, not `git remote get-url`: that one applies insteadOf rewrites.
github_repo() {
  local origin
  origin=$(git -C "$root" config --get remote.origin.url 2>/dev/null) || { echo "this checkout has no origin remote"; return 1; }
  case "$origin" in
    *github.com[:/]*/*) ;;
    *) echo "origin ($origin) is not a GitHub repository"; return 1 ;;
  esac
  origin=${origin%.git}
  echo "${origin#*github.com[:/]}"
}

# gh_reason ERRFILE STATUS: why a gh call failed, in one line.
gh_reason() {
  if ! gh auth token >/dev/null 2>&1; then
    echo "gh is not signed in to GitHub in this environment; ask before assuming anything"
    return
  fi
  local reason
  reason=$(sed -n 's/^.*gh: //p' "$1" | tail -n 1)
  [ -n "$reason" ] || reason=$(tail -n 1 "$1" | cut -c 1-200)
  echo "gh api failed: ${reason:-exit status $2}"
}

# numbers IDS...: ids as printed (#170) or as typed (170), as bare numbers, one per line. Returns 1 on anything else.
numbers() {
  local id
  for id in "$@"; do
    id=${id#\#}
    case "$id" in ''|*[!0-9]*) return 1 ;; esac
    echo "$id"
  done
}

# closes: the issue numbers the body on stdin closes, one per line.
closes() { jq -L "$adapter" -Rrs 'include "closes"; closes[]'; }
