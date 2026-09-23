# model-policy decision core. Input: one hook payload. Args: --arg harness H --argjson config CFG.
# Output: {"skip":true} for non-dispatch calls, else {"skip":false,"record":{...},"output":<object|null>}.

def tier_order: ["frontier", "strong", "standard", "fast"];
def dispatch_tools: {
  "claude-code": ["Agent", "Task"],
  "copilot": ["Agent", "Task", "task"],
  "codex": ["spawn_agent", "Agent"],
  "cursor": ["Task", "Agent"]
};

def str: if type == "string" then . else "" end;
def oneline: str | gsub("[\t\r\n]+"; " ");
def glob_re: "^" + (gsub("(?<c>[.+^${}()|\\[\\]\\\\])"; "\\\(.c)") | gsub("\\*"; ".*") | gsub("\\?"; ".")) + "$";
def glob_match($p): ascii_downcase | test($p | ascii_downcase | glob_re);
def base_model: sub("\\[[^\\]]*\\]$"; "");
def justified: test("(^|\n)[ \t]*model policy: *(frontier|fable) because [^\n]{3,}"; "i");

def h: ($config.harnesses[$harness] // {}) | if type == "object" then . else {} end;
def tier_default($t): h.tiers[$t].default // "" | str;
def classify($m):
  ($m | base_model) as $b
  | first(tier_order[] as $t
      | select(any((h.tiers[$t].match // [])[] | strings; . as $p | $b | glob_match($p)))
      | $t) // "unknown";
# The configured stronger, cheaper successor of a named model, keeping any bracket suffix, or "".
def successor($m):
  ($m | base_model) as $b
  | (h.supersededBy // {} | if type == "object" then . else {} end)
  | first(to_entries[] | select((.key | ascii_downcase) == ($b | ascii_downcase)) | .value | strings | select(. != "")) // ""
  | if . == "" then "" else . + $m[($b | length):] end;
def agent_tier($type): h.agentTypes[$type] // h.agentTypes["*"] // "standard" | str;

def tool_input:
  (.tool_input // .toolArgs // {})
  | if type == "string" then (try fromjson catch {}) else . end
  | if type == "object" then . else {} end;

def normalize:
  tool_input as $in
  | {
      tool: (.tool_name // .toolName // "" | str),
      in: $in,
      agent_type: ($in.subagent_type // $in.agent_type // $in.subagentType // "" | str),
      model: ($in.model // $in.subagent_model // "" | str),
      prompt: ($in.prompt // $in.message // $in.task // "" | str),
      description: ($in.description // $in.task_name // $in.name // "" | str),
      session: (.session_id // .sessionId // .conversation_id // "" | str | .[0:8]),
      project: (.cwd // (.workspace_roots // [])[0] // "" | str | sub("/+$"; "") | split("/") | last // "")
    };

def decide:
  normalize as $n
  | if ((dispatch_tools[$harness] // []) | index($n.tool)) == null then {skip: true}
    else
      ($n.model | if . == "inherit" then "" else . end) as $req
      | $n + {skip: false, requested: $n.model}
      + if $req == "" then
          agent_tier($n.agent_type) as $t
          | tier_default($t) as $d
          | if $d == "" then {effective: "", tier: "unknown", action: "kept"}
            else {effective: $d, tier: $t, action: "filled"} end
        else
          successor($req) as $s
          | classify($req) as $t
          | if $s != "" and classify($s) != "frontier" then {effective: $s, tier: classify($s), action: "upgraded"}
            elif $t != "frontier" then {effective: $req, tier: $t, action: "kept"}
            elif $n.prompt | justified then {effective: $req, tier: $t, action: "justified"}
            else {effective: "-", tier: $t, action: "denied"} end
        end
    end;

def fill_reason($d):
  "model-policy: no model named, \(if $d.agent_type == "" then "subagent" else $d.agent_type end) runs on \($d.effective) (\($d.tier) tier)";

def upgrade_reason($d):
  "model-policy: \($d.requested) is superseded by \($d.effective) (stronger and cheaper), running on \($d.effective)";

def deny_reason($d):
  "model-policy: subagents do not run on \($d.requested) (frontier tier) without a reason. "
  + "Re-dispatch on \(tier_default("strong")) (strong tier: judgement, review, fix rounds) "
  + "or \(tier_default("standard")) (standard tier: implementation from a plan, verification against a spec). "
  + "Use the frontier tier only for the pass that brings several rounds of subagent work together or verifies the whole, "
  + "and then add this line to the prompt: \"Model policy: frontier because <reason>\".";

def render($d):
  if $d.action == "filled" or $d.action == "upgraded" then
    ($d.in + {model: $d.effective}) as $u
    | (if $d.action == "filled" then fill_reason($d) else upgrade_reason($d) end) as $r
    | if $harness == "copilot" then {permissionDecision: "allow", permissionDecisionReason: $r, modifiedArgs: $u}
      elif $harness == "cursor" then {permission: "allow", updated_input: $u}
      elif $harness == "codex" then {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", updatedInput: $u}}
      else {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", permissionDecisionReason: $r, updatedInput: $u}}
      end
  elif $d.action == "denied" then
    deny_reason($d) as $r
    | if $harness == "copilot" then {permissionDecision: "deny", permissionDecisionReason: $r}
      elif $harness == "cursor" then {permission: "deny", user_message: $r, agent_message: $r}
      else {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}
      end
  else null
  end;

def record($d):
  $d
  | {session, project, agent_type, requested, effective, tier, action, description}
  | map_values(oneline | if . == "" then "-" else . end)
  | .prompt_chars = ($d.prompt | length);

decide as $d
| if $d.skip then {skip: true}
  else {skip: false, record: record($d), output: render($d)}
  end
