# Checks a state document against the adapter contract (skills/roadmap/references/adapter-contract.md).
# Prints nothing when it holds; otherwise one line per member that is missing or has the wrong type.
#   jq -r -f scripts/contract.jq state.json
def is($type): type == $type;
def str: is("string");
def strs: is("array") and all(.[]; str);
def want($path; check): if (try check catch false) then empty else "\($path) is missing or has the wrong type" end;

def slice($p):
  want("\($p).id"; .id | str), want("\($p).title"; .title | str),
  want("\($p).state"; .state | IN("open", "done", "dropped")),
  want("\($p).claims"; .claims | strs),
  want("\($p).notes"; .notes | is("array") and all(.[]; (.text | str) and (.fix == null or (.fix | str))));

def initiative($p):
  want("\($p).id"; .id | str), want("\($p).title"; .title | str),
  want("\($p).total"; .total | is("number")), want("\($p).read"; .read | is("number")),
  want("\($p).claims"; .claims | strs), want("\($p).slices"; .slices | is("array")),
  (.slices // [] | if is("array") then to_entries[] | .key as $i | .value | slice("\($p).slices[\($i)]") else empty end);

def other($p):
  want("\($p).kind"; .kind | str), want("\($p).heading"; .heading | str), want("\($p).open"; .open | is("number")),
  want("\($p).list"; .list | str),
  want("\($p).items"; .items | is("array") and all(.[]; (.id | str) and (.title | str) and (.claims | strs)));

def claim($p):
  want("\($p).id"; .id | str), want("\($p).ref"; .ref | str), want("\($p).tentative"; .tentative | is("boolean")),
  want("\($p).idleDays"; .idleDays | is("number")), want("\($p).items"; .items | strs),
  want("\($p).note"; .note == null or (.note | str));

want("project"; .project | str), want("backend"; .backend | str), want("defaultBranch"; .defaultBranch | str),
want("initiatives"; .initiatives | is("array")),
(.initiatives // [] | if is("array") then to_entries[] | .key as $i | .value | initiative("initiatives[\($i)]") else empty end),
want("moreInitiatives"; .moreInitiatives | is("number")),
want("other"; .other | is("array")),
(.other // [] | if is("array") then to_entries[] | .key as $i | .value | other("other[\($i)]") else empty end),
want("claimsHeading"; .claimsHeading | str),
want("claims"; .claims | is("array")),
(.claims // [] | if is("array") then to_entries[] | .key as $i | .value | claim("claims[\($i)]") else empty end),
want("here.branch"; .here.branch | str),
want("here.state"; .here.state | IN("default-branch", "detached", "unclaimed", "claimed", "merged", "closed", "unlinked", "unknown")),
want("here.claim"; .here.claim == null or (.here.claim | str)),
want("here.tentative"; .here.tentative | is("boolean")),
want("here.items"; .here.items | is("array") and all(.[]; (.id | str) and (.title | str) and (.show | str))),
want("here.hint"; .here.hint | str)
