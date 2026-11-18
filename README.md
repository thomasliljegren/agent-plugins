# agent-plugins

A collection of plugins for AI coding agents, built on the [Agent Skills open standard](https://agentskills.io) so the same content works across Claude Code, OpenAI Codex, GitHub Copilot, Cursor, OpenCode, Gemini CLI, and any other agent that reads `SKILL.md`.

## Plugins

| Plugin | Description | Ships | Runs on |
|---|---|---|---|
| [design-debate](plugins/design-debate) | Several agents, each with its own lens and where the client allows its own model family, design a solution independently, critique each other over a set number of rounds or until their designs stop changing, and a judge picks one. One hard-stop checkpoint after framing; ends in a run folder in `docs/working/design-debates/` with the framing and an illustrated proposal. Experimental. | skill | any client with a subagent tool; tested in Copilot and Claude Code |
| [hotchocolate-graphql](plugins/hotchocolate-graphql) | Architecture patterns and conventions for HotChocolate v16 GraphQL servers, plus Fusion subgraphs, composition and gateway deployment. | skill | any agent |
| [model-policy](plugins/model-policy) | Keeps subagents on the best-value model tier that fits: fills a missing model by agent type, moves superseded models to their stronger and cheaper successor, gates frontier-tier subagents behind a written reason, logs every dispatch. | skill, hooks, `/model-policy:report` | hooks on Claude Code, Copilot CLI, Codex CLI and Cursor; the skill anywhere |
| [roadmap](plugins/roadmap) | Agents sharing work through the team's own tracker: a live snapshot of what is done, claimed and next at every session start, and claims the others can see. GitHub issues and pull requests today. | skill, hook, `roadmap` CLI, `/roadmap:setup`, `/roadmap:report` | Claude Code only, in a local checkout |
| [verified](plugins/verified) | Keeps what a project checked against its frameworks in `VERIFIED.md` by topic, with the evidence, and reorganises an existing file into that shape without losing an identifier. | skill, `/verified:reorganize` | the skill anywhere; the command on Claude Code |

Each plugin's own README has its install notes, requirements and usage.

## Install

### Claude Code (full plugin: skills, commands, hooks)

```
/plugin marketplace add thomasliljegren/agent-plugins
/plugin install <plugin>@agent-plugins
```

For example `/plugin install roadmap@agent-plugins`. From a local checkout: `/plugin marketplace add /path/to/agent-plugins`.

### Copilot CLI

```
copilot plugin marketplace add thomasliljegren/agent-plugins
copilot plugin install <plugin>@agent-plugins
```

### Codex CLI and Cursor

Install the plugin directory (for example `plugins/model-policy`) as described in [Codex plugins](https://developers.openai.com/plugins/build/plugins) or [Cursor plugins](https://cursor.com/docs/plugins). Only plugins with a `.codex-plugin/` or `.cursor-plugin/` manifest ship hooks there; today that is model-policy.

### Any other agent (skills only, via skills.sh)

```
npx skills add github:thomasliljegren/agent-plugins
```

This detects every `SKILL.md` in the repo and installs it, with its references and scripts, into each agent's skills directory (Codex, Copilot, Cursor, OpenCode, Gemini CLI, …). Hooks, slash commands and roadmap's `roadmap` CLI only come with a plugin install, so model-policy and roadmap work as guidance only this way.

### Manual

Copy `plugins/<plugin>/skills/<skill>/` into your agent's skills directory. See [docs/INSTALL.md](docs/INSTALL.md) for per-agent paths.

## Layout

```
.claude-plugin/marketplace.json     # the marketplace: every plugin, and its version in metadata.version
scripts/check-versions.sh           # every changed plugin has a higher version (tests in tests/)
plugins/<plugin-name>/
├─ README.md                        # what it does, install, use
├─ .claude-plugin/plugin.json       # Claude Code plugin manifest
├─ skills/<skill-name>/SKILL.md     # portable skills (the cross-agent part), with references/ and scripts/
├─ commands/                        # Claude Code slash commands
├─ agents/                          # Claude Code subagents
├─ hooks/hooks.json                 # Claude Code hooks; hooks-<harness>.json for the others (optional)
├─ bin/, scripts/, config/          # executables, helper scripts and data the hooks or commands use (optional)
├─ tests/run.sh                     # the plugin's tests (optional)
├─ .github/plugin/plugin.json       # Copilot CLI manifest (optional, when Copilot needs different hooks)
├─ .codex-plugin/plugin.json        # Codex CLI manifest (optional)
├─ .cursor-plugin/plugin.json       # Cursor manifest (optional)
└─ .mcp.json                        # MCP server config (optional)
```

Skills are the portable core; any standard-compliant agent can use them unchanged. Commands, subagents, hooks and MCP wiring are harness extras bundled in the same plugin. Most plugins ship them for Claude Code only. A plugin that needs hooks elsewhere adds that harness's manifest (see [model-policy](plugins/model-policy)).

## Tests

Plugins with a `tests/` directory run offline:

```
bash plugins/model-policy/tests/run.sh
bash plugins/roadmap/tests/run.sh
bash plugins/verified/tests/run.sh
```

They need `bash` and `jq`. Their docs tests also check this README and the marketplace entry.

Before a pull request, check that every plugin you changed has a higher version:

```
bash scripts/check-versions.sh [base]    # base defaults to origin/main
```

It compares each plugin with the merge base, counting commits and uncommitted and untracked files. A change under a plugin's `tests/` needs no bump. It also fails when one plugin's manifests (`.claude-plugin`, `.github/plugin`, `.codex-plugin`, `.cursor-plugin`) carry different versions. Its own tests are `bash tests/run.sh`.

## Adding a plugin

1. Create `plugins/<name>/` with a `README.md`, a `.claude-plugin/plugin.json` and at least one skill under `skills/<skill-name>/SKILL.md`.
2. Register it in `.claude-plugin/marketplace.json` under `plugins`, with the same description as its manifest, and add it to the table above.
3. Skill frontmatter needs `name` and `description`; the description decides when agents load the skill, so make it trigger-rich.
4. On any change outside `tests/`, raise the plugin's `version` in every manifest it has, and `metadata.version` in the marketplace, so an installed plugin picks it up. `scripts/check-versions.sh` checks the plugin's part.
