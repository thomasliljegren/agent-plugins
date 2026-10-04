include "closes";

# GitHub's REST answers, gathered by `state` into one document, as the normalized state of the adapter contract.
# Input: {repo, initiatives, subIssues: {"<number>": [...]}, openPrs, closedPrs, bugs, debt, branchPrs}
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
| (.initiatives | need("initiatives") | issues) as $initiatives
| (.bugs | need("bugs") | issues) as $bugs
| (.debt | need("debt") | issues) as $debt
# GitHub links and closes issues only for pull requests into the default branch.
# A pull request from a fork is not a claim: anyone can open one.
| def linked:
    if (.base.ref | need("base")) == $default and (.head.repo.full_name // $project) == $project then (.body | closes) else [] end;
  ($open | map({id: "PR #\(.number | need("number"))", closes: linked})) as $links
| ([$closed[] | select(.merged_at != null) | linked[]]) as $merged
# Only the newest 100 closed pull requests are read. A slice closed before the oldest of them cannot be judged.
| (if ($closed | length) < 100 then null else ($closed | map(.updated_at) | min) end) as $horizon
| ([$initiatives[], $subs[][], $bugs[], $debt[]] | map({key: (.number | tostring), value: .title}) | from_entries) as $titles
| def claims_of: (.number | need("number")) as $n | [$links[] | select(.closes | any(. == $n)) | .id];
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
      notes: [ (if by_hand then {text: "closed by hand, not by a merged PR", fix: null} else empty end),
               (if unlabelled then {text: "unlabelled", fix: "gh issue edit N --add-label \(named("slice"))"} else empty end) ] };
  def initiative:
    ($subs[.number | tostring] // []) as $mine
    | { id: "#\(.number | need("number"))", title: (.title | need("title") | safe),
        total: (.sub_issues_summary.total | need("sub_issues_summary")), read: ($mine | length),
        claims: claims_of, slices: ($mine | map(slice)) };
  def item: {id: "#\(.number | need("number"))", title: (.title | need("title") | safe), claims: claims_of};
  def idle_days: (($now - (.updated_at | need("updated_at") | fromdateiso8601)) / 86400) | floor;
  def claim:
    linked as $closes
    | { id: "PR #\(.number | need("number"))", ref: (.head.ref | need("head") | safe), tentative: (.draft | need("draft")),
        idleDays: idle_days, items: ($closes | map("#\(.)")),
        note: (if ($closes | length) == 0 then "no closing link: it claims nothing" else null end) };
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
    other: [ {kind: "bug", heading: "Bugs", open: ($bugs | length), list: "gh issue list --label \(named("bug"))", items: ($bugs[:5] | map(item))},
             {kind: "debt", heading: "Debt", open: ($debt | length), list: "gh issue list --label \(named("debt"))", items: []} ],
    claimsHeading: "Open pull requests",
    claims: ($open | map(claim)),
    here: here }
