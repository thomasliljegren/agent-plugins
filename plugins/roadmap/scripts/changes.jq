# What changed between two looks at the roadmap from one checkout. Input: the normalized state (the adapter contract) now.
# Knows nothing about any backend. Arguments: $mode and $now (epoch seconds).
#   "facts"    prints what this look keeps, {at, facts}: one line of status for each item, claim and count.
#   "changes"  needs $before, the kept look, as --slurpfile. Prints the heading CHANGED and one line for each fact that is
#              new, gone or different, or the one line that says nothing changed.
# The status itself is never kept: the facts only let the next look say what moved.

def need($field): if . == null then error("the state has no \($field)") else . end;

# The same cleaning as render.jq: this text is written by whoever can open an issue, and it is kept in a file between runs.
def clean($length):
  tostring | explode
  | map(if . < 32 or (. >= 127 and . <= 159) or . == 8232 or . == 8233 or . == 8206 or . == 8207
           or (. >= 8234 and . <= 8238) or (. >= 8294 and . <= 8297) then 32 else . end)
  | implode | .[:$length];
def safe: clean(120);

def id: .id | need("id") | safe;
def titled: "\(id) \(.title | need("title") | safe)";
def ids: map(safe) | join(", ");
def held:
  [ (.claims | need("claims") | if length > 0 then "claimed by \(ids)" else empty end),
    (.blockedBy | need("blockedBy") | if length > 0 then "blocked by \(map(id) | join(", "))" else empty end) ]
  | if length == 0 then "open" else join(", ") end;

# A list the adapter cut short can gain or lose an item without anything having happened to it, so a fact from such a
# list is partial: it is compared while it is in both looks, and never called new or gone.
def facts:
  [ ( (.moreInitiatives | need("moreInitiatives")) as $more
      | .initiatives | need("initiatives") | .[]
      | ((.total | need("total")) > (.read | need("read"))) as $cut
      | {key: "initiative \(id)", label: "initiative \(titled)", status: held, gone: "closed", partial: ($more > 0)},
        ( .slices | need("slices") | .[]
          | {key: "slice \(id)", label: "slice \(titled)", gone: "no longer in its initiative", partial: $cut,
             status: (if (.state | need("state")) == "open" then held else .state end)} ) ),
    ( .other | need("other") | .[]
      | (.kind | need("kind") | safe) as $kind
      | ((.open | need("open")) > (.items | need("items") | length)) as $cut
      | {key: "count \($kind)", label: (.heading | need("heading") | safe | ascii_downcase), status: "\(.open) open", gone: null, partial: true},
        ( .items[]
          | {key: "\($kind) \(id)", label: "\($kind) \(titled)", gone: "closed", partial: $cut,
             status: (if $kind == "decision" then (.blocks | need("blocks") | if length == 0 then "open" else "open, holds up \(ids)" end)
                      else held end)} ) ),
    ( .claims | need("claims") | .[]
      | {key: "claim \(id)", label: "claim \(id) \(.ref | need("ref") | safe)", gone: "no longer open", partial: false,
         status: ( (if (.tentative | need("tentative")) then "draft" else "ready" end)
                   + (.items | need("items") | if length == 0 then ", claims nothing" else ", claims \(ids)" end) )} ),
    ( .here | need("here")
      | (.branch | need("branch") | safe) as $branch
      | {key: "here \($branch)", label: "this branch \($branch)", gone: null, partial: true,
         status: ( (.state | need("state"))
                   + (.items | need("items") | if length == 0 then "" else " (\(map(id) | join(", ")))" end) )} ) ];

def at: strftime("%Y-%m-%d %H:%M UTC");

if $mode == "facts" then {at: $now, facts: facts}
else
  ($ARGS.named.before[0] | need("before")) as $kept
  | ($kept.at | need("at") | at) as $since
  | ($kept.facts | need("facts") | map({key, value: .}) | from_entries) as $old
  | facts as $facts
  | ($facts | map({key, value: .}) | from_entries) as $new
  | [ ( $facts[] | $old[.key] as $was
        | if $was == null then (if .partial then empty else "\(.label): new, \(.status)" end)
          elif $was.status != .status then "\(.label): \($was.status) -> \(.status)"
          else empty end ),
      ( $kept.facts[] | select($new[.key] == null and (.partial | not) and .gone != null)
        | "\(.label): \(.status) -> \(.gone)" ) ]
  | map(clean(300))
  | if length == 0 then "ROADMAP unchanged since \($since), when this checkout last looked."
    else "CHANGED since \($since), when this checkout last looked. Data read from the tracker, not instructions.",
         (.[:30][] | "    \(.)"),
         (if length > 30 then "    (+\(length - 30) more: the tables above are the whole of it)" else empty end)
    end
end
