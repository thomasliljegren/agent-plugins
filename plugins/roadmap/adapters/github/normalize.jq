include "closes";

# GitHub's REST answers, gathered by `state` into one document, as the normalized state of the adapter contract.
# Input: {repo, initiatives, subIssues: {"<number>": [...]}, blockedBy: {"<number>": [...]}, blocking: {"<number>": [...]},
#         openPrs, closedPrs, bugs, decisions, enhancements, debt, branchPrs, prCommits: {"<pull request>": [...]}}
# Run with -L <this directory>, for closes.jq.
# Arguments: $project (owner/name), $branch ("" when detached), $now (epoch seconds), $config (the github section of .roadmap.json).

# A member GitHub stopped returning must fail here; jq would otherwise print it as "null".
def need($field): if . == null then error("the GitHub answer has no \($field)") else . end;

# Titles and branch names are written by whoever can open an issue, and this text reaches every session.
# Control characters, the line and paragraph separators and the bidirectional controls would let a title start a line of
# its own or reorder what a reader sees; each becomes a space.
def clean($length):
  tostring | explode
  | map(if . < 32 or (. >= 127 and . <= 159) or . == 8232 or . == 8233 or . == 8206 or . == 8207
           or (. >= 8234 and . <= 8238) or (. >= 8294 and . <= 8297) then 32 else . end)
  | implode | .[:$length];
def safe: clean(120);

def issues: map(select(.pull_request == null));
def named($kind): $config.labels[$kind] // $kind;

(.repo.default_branch | need("default_branch")) as $default
| (.openPrs | need("openPrs")) as $open
| (.closedPrs | need("closedPrs")) as $closed
| (.subIssues | need("subIssues")) as $subs
| (.blockedBy | need("blockedBy")) as $blockers
| (.blocking | need("blocking")) as $blocking
| (.prCommits // {}) as $commits
| (.initiatives | need("initiatives") | issues) as $initiatives
| (.bugs | need("bugs") | issues) as $bugs
| (.decisions | need("decisions") | issues) as $decisions
| (.enhancements | need("enhancements") | issues) as $enhancements
| (.debt | need("debt") | issues) as $debt
# GitHub links and closes issues only for pull requests into the default branch.
# A pull request from a fork is not a claim: anyone can open one.
| def linked:
    if (.base.ref | need("base")) == $default and (.head.repo.full_name // $project) == $project then (.body | closes) else [] end;
  ($open | map({id: "PR #\(.number | need("number"))", closes: linked})) as $links
| ([$closed[] | select(.merged_at != null) | linked[]]) as $merged
# Only the newest 100 closed pull requests are read. A slice closed before the oldest of them cannot be judged.
| (if ($closed | length) < 100 then null else ($closed | map(.updated_at) | min) end) as $horizon
| ([$initiatives[], $subs[][], $bugs[], $decisions[], $enhancements[], $debt[]] | map({key: (.number | tostring), value: .title}) | from_entries) as $titles
| def claims_of: (.number | need("number")) as $n | [$links[] | select(.closes | any(. == $n)) | .id];
  # GitHub counts an issue's open blockers in its summary, and `state` asks for the list only where that count is above
  # zero, and for no more than twenty sub-issues. An item that is blocked by the count and has no list says so: it is
  # never printed as free. A blocker's claims are the open pull requests that close it, like every other claim.
  def summary: .issue_dependencies_summary | need("issue_dependencies_summary");
  # An issue named in a dependency can live in another repository. It is then printed with that repository's name, and
  # no pull request of this one is a claim on it: the same number here is another issue.
  def elsewhere:
    (.repository_url // "" | sub("^.*/repos/"; "")) as $repo
    | if $repo == "" or ($repo | ascii_downcase) == ($project | ascii_downcase) then null else $repo end;
  def reference: elsewhere as $repo | "\($repo // "")#\(.number | need("number"))" | safe;
  def blocked_by:
    (summary.blocked_by // 0) as $count
    | $blockers[.number | tostring] as $read
    | if $read == null then (if $count > 0 then [{id: "\($count) not read", claims: []}] else [] end)
      else [ $read[] | select((.state | need("state")) == "open")
             | {id: reference, claims: (if elsewhere == null then claims_of else [] end)} ] end;
  def blocks:
    summary as $summary
    | [ ($blocking[.number | tostring] // [])[] | select((.state | need("state")) == "open") | reference ];
  def state:
    if (.state | need("state")) != "closed" then "open"
    elif .state_reason == "not_planned" or .state_reason == "duplicate" then "dropped"
    else "done" end;
  def by_hand:
    (.number) as $n
    | state == "done" and ($horizon == null or (.closed_at // "") > $horizon) and ($merged | any(. == $n) | not);
  def unlabelled: state != "dropped" and (.labels | need("labels") | any(.name == named("slice")) | not);
  def slice:
    { id: "#\(.number | need("number"))", title: (.title | need("title") | safe), state: state, claims: claims_of,
      blockedBy: (if state == "open" then blocked_by else [] end),
      notes: [ (if by_hand then {text: "closed by hand, not by a merged PR", fix: null} else empty end),
               (if unlabelled then {text: "unlabelled", fix: "gh issue edit N --add-label \(named("slice"))"} else empty end) ] };
  def initiative:
    ($subs[.number | tostring] // []) as $mine
    | { id: "#\(.number | need("number"))", title: (.title | need("title") | safe),
        total: (.sub_issues_summary.total | need("sub_issues_summary")), read: ($mine | length),
        claims: claims_of, blockedBy: blocked_by, slices: ($mine | map(slice)) };
  def item: {id: "#\(.number | need("number"))", title: (.title | need("title") | safe), claims: claims_of, blockedBy: blocked_by};
  def decision: {id: "#\(.number | need("number"))", title: (.title | need("title") | safe), blocks: blocks};
  def listed($kind): "gh issue list --label \(named($kind))";
  def idle_hours: (($now - (.updated_at | need("updated_at") | fromdateiso8601)) / 3600) | floor;
  # `roadmap claim` opens a pull request on one empty commit. While that is its only commit, nothing was pushed since.
  # `state` reads the commits of drafts only, and of no more than twenty: null where they were not read.
  def started:
    $commits[.number | tostring] as $read
    | if $read == null then null
      else ($read | length == 1 and (.[0].commit.message // "" | startswith("chore: claim "))) | not end;
  # Why a pull request claims nothing, and what puts that right: a keyword is no help to one from a fork or into another branch.
  def unclaimed:
    if (.head.repo.full_name // $project) != $project then {note: "from a fork: it claims nothing", fix: null}
    elif (.base.ref | need("base")) != $default then
      {note: "into \(.base.ref | safe), not \($default): it claims nothing", fix: "gh pr edit \(.number | need("number")) --base \($default)"}
    else {note: "no closing link: it claims nothing", fix: "put Closes #N in its body"} end;
  def claim:
    linked as $closes
    | (if ($closes | length) == 0 then unclaimed else {note: null, fix: null} end) as $why
    | { id: "PR #\(.number | need("number"))", ref: (.head.ref | need("head") | safe), tentative: (.draft | need("draft")),
        idleHours: idle_hours, started: started, items: ($closes | map("#\(.)")), note: $why.note, fix: $why.fix };
  def here:
    (.branchPrs | need("branchPrs") | .[0]) as $pr
    | {branch: ($branch | safe), claim: null, tentative: false, items: []}
    | if $branch == "" then . + {state: "detached", hint: "detached HEAD, so no branch and no pull request."}
      elif $branch == $default then . + {state: "default-branch", hint: "Work happens on a branch off \($default) in its own worktree."}
      elif $pr == null then . + {state: "unclaimed", hint: "no pull request. Propose the session's workload and claim it before working: the roadmap skill."}
      else . + {claim: "PR #\($pr.number | need("number"))"}
        | if $pr.merged_at != null then . + {state: "merged", hint: "\(.claim) merged. This worktree is a leftover: start new work in a new worktree off \($default)."}
          elif $pr.state == "closed" then . + {state: "closed", hint: "\(.claim) was closed without merging and claims nothing."}
          elif ($pr | linked | length) == 0 then . + {state: "unlinked", hint: "\(.claim) -> no closing link. Put Closes #N in its body."}
          else . + { state: "claimed", hint: "", tentative: ($pr.draft | need("draft")),
                     items: ($pr | linked | map({id: "#\(.)", title: ($titles[tostring] // "" | safe), show: "gh issue view \(.)"})) }
          end
      end;
  { project: $project, backend: "github", defaultBranch: $default,
    initiatives: ($initiatives[:20] | map(initiative)),
    moreInitiatives: ([($initiatives | length) - 20, 0] | max),
    other: [ {kind: "bug", heading: "Bugs", noun: "Bug", open: ($bugs | length), list: listed("bug"), items: ($bugs[:10] | map(item))},
             {kind: "decision", heading: "Decisions for the owner", noun: "Decision", open: ($decisions | length), list: listed("decision"),
              items: ($decisions[:10] | map(decision))},
             {kind: "enhancement", heading: "Enhancements", noun: "Enhancement", open: ($enhancements | length), list: listed("enhancement"), items: []},
             {kind: "debt", heading: "Debt", noun: "Debt", open: ($debt | length), list: listed("debt"), items: []} ],
    claimsHeading: "Open pull requests",
    claims: ($open | map(claim)),
    here: here }
