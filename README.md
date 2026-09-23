# agent-plugins

A collection of plugins for AI coding agents, built on the [Agent Skills open standard](https://agentskills.io) so the same content works across Claude Code, OpenAI Codex, GitHub Copilot, Cursor, OpenCode, Gemini CLI, and any other agent that reads `SKILL.md`.

## Layout

```
plugins/<plugin-name>/
├─ .claude-plugin/plugin.json   # Claude Code plugin manifest
├─ skills/<skill-name>/         # portable SKILL.md skills (the cross-agent part)
├─ commands/                    # Claude Code slash commands
├─ agents/                      # Claude Code subagents
├─ hooks/hooks.json             # Claude Code hooks (optional)
├─ .github/plugin/plugin.json   # Copilot CLI manifest (optional, when Copilot needs different hooks)
├─ .codex-plugin/plugin.json    # Codex CLI manifest (optional)
├─ .cursor-plugin/plugin.json   # Cursor manifest (optional)
└─ .mcp.json                    # MCP server config (optional)
```

Skills are the portable core; any standard-compliant agent can use them unchanged. Commands, subagents, hooks and MCP wiring are harness extras bundled in the same plugin. Most plugins ship them for Claude Code only. A plugin that needs hooks elsewhere adds that harness's manifest (see [model-policy](plugins/model-policy)).

## Install

### Claude Code (full plugin: skills + commands + agents + MCP)

```
/plugin marketplace add thomasliljegren/agent-plugins
/plugin install hotchocolate-graphql@agent-plugins
```

Or from a local checkout: `/plugin marketplace add /path/to/agent-plugins`

### Any other agent (skills only, via skills.sh)

```
npx skills add github:thomasliljegren/agent-plugins
```

This detects every `SKILL.md` in the repo and installs it into each agent's skills directory (Codex, Copilot, Cursor, OpenCode, Gemini CLI, …).

### Manual

Copy `plugins/<plugin>/skills/<skill>/` into your agent's skills directory. See [docs/INSTALL.md](docs/INSTALL.md) for per-agent paths.

## Plugins

| Plugin | Description |
|---|---|
| [hotchocolate-graphql](plugins/hotchocolate-graphql) | Architecture patterns and conventions for HotChocolate v16 GraphQL servers and Fusion v2 subgraphs. |
| [model-policy](plugins/model-policy) | Keeps subagents on the cheapest model tier that fits, gates frontier-tier subagents behind a written reason, logs every dispatch. Ships hooks for Claude Code, Copilot CLI, Codex CLI and Cursor. |

## Adding a plugin

1. Create `plugins/<name>/` with a `.claude-plugin/plugin.json` and at least one skill under `skills/<skill-name>/SKILL.md`.
2. Register it in `.claude-plugin/marketplace.json` under `plugins`.
3. Skill frontmatter needs `name` and `description`; the description decides when agents load the skill, so make it trigger-rich.
