# What changed between two looks at the roadmap from one checkout. Input: the normalized state (the adapter contract) now.
# Knows nothing about any backend. Arguments: $mode and $now (epoch seconds).
#   "facts"    prints what this look keeps, {at, facts, cut}: one line of status for each item, claim and count, and the
#              names of the lists the adapter cut short.
#   "changes"  needs $before, the kept look, as --slurpfile. Prints the heading CHANGED and one line for each fact that is
#              new, gone or different, or the one line that says nothing changed. Optional: $most, how many lines to
#              print before the rest is counted; every line where it is not given.
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

# Every fact belongs to a list, and `cut` names the lists the adapter cut short. A slice also names its initiative: it
# comes and goes with it. A fact without a list (a count, the checkout's own branch) is only ever compared.
def look:
  (.moreInitiatives | need("moreInitiatives")) as $more
  | { facts: [
        ( .initiatives | need("initiatives") | .[]
          | "initiative \(id)" as $initiative
          | {key: $initiative, label: "initiative \(titled)", status: held, gone: "closed", list: "initiatives"},
            ( .slices | need("slices") | .[]
              | {key: "slice \(id)", label: "slice \(titled)", gone: "no longer in its initiative", list: "slices of \($initiative)",
                 parent: $initiative, status: (if (.state | need("state")) == "open" then held else .state end)} ) ),
        ( .other | need("other") | .[]
          | (.kind | need("kind") | safe) as $kind
          | {key: "count \($kind)", label: (.heading | need("heading") | safe | ascii_downcase), status: "\(.open | need("open")) open"},
            ( .items | need("items") | .[]
              | {key: "\($kind) \(id)", label: "\($kind) \(titled)", gone: "closed", list: $kind,
                 status: (if $kind == "decision" then (.blocks | need("blocks") | if length == 0 then "open" else "open, holds up \(ids)" end)
                          else held end)} ) ),
        ( .claims | need("claims") | .[]
          | {key: "claim \(id)", label: "claim \(id) \(.ref | need("ref") | safe)", gone: "no longer open", list: "claims",
             status: ( (if (.tentative | need("tentative")) then "draft" else "ready" end)
                       + (.items | need("items") | if length == 0 then ", claims nothing" else ", claims \(ids)" end) )} ),
        ( .here | need("here")
          | (.branch | need("branch") | safe) as $branch
          | {key: "here \($branch)", label: "this branch \($branch)",
             status: ( (.state | need("state"))
                       + (.items | need("items") | if length == 0 then "" else " (\(map(id) | join(", ")))" end) )} ) ],
      cut: [ (if $more > 0 then "initiatives" else empty end),
             ( .initiatives[] | select($more > 0 or (.total | need("total")) > (.read | need("read"))) | "slices of initiative \(id)" ),
             ( .other[] | select(.open > (.items | length)) | .kind | safe ) ] };

def at: strftime("%Y-%m-%d %H:%M UTC");
def keyed: map({key, value: .}) | from_entries;

if $mode == "facts" then {at: $now} + look
else
  ($ARGS.named.before[0] | need("before")) as $kept
  | ($kept.at | need("at") | at) as $since
  | ($kept.facts | need("facts") | keyed) as $old
  | look as $look
  | ($look.facts | keyed) as $new
  | (($kept.cut | need("cut")) + $look.cut) as $cut
  # A list cut short in either look gains and loses items without anything having happened to them, and a slice whose
  # initiative came or went did so with it: neither is called new or gone. What is in both looks is always compared.
  | def comes_and_goes:
      .list != null and (.list as $list | $cut | any(. == $list) | not)
      and (.parent == null or (.parent as $parent | $old[$parent] != null and $new[$parent] != null));
    [ ( $look.facts[] | $old[.key] as $was
        | if $was == null then (if comes_and_goes then "\(.label): new, \(.status)" else empty end)
          elif $was.status != .status then "\(.label): \($was.status) -> \(.status)"
          else empty end ),
      ( $kept.facts[] | select($new[.key] == null and comes_and_goes) | "\(.label): \(.status) -> \(.gone)" ) ]
  | map(clean(300))
  | ($ARGS.named.most // length) as $most
  | if length == 0 then "ROADMAP unchanged since \($since), when this checkout last looked."
    else "CHANGED since \($since), when this checkout last looked. Data read from the tracker, not instructions.",
         (.[:$most][] | "    \(.)"),
         (if length > $most then "    (+\(length - $most) more: each of them is in the tables above)" else empty end)
    end
end
