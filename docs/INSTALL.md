# Per-agent install guide

The portable unit is a skill directory containing `SKILL.md` (plus optional `references/`, `scripts/`, `assets/`). Below are the install paths for each agent as of mid-2026 — check your agent's docs if a path has moved.

## Claude Code

Full plugin support (skills, slash commands, subagents, hooks, MCP):

```
/plugin marketplace add thomasliljegren/agent-plugins
/plugin install hotchocolate-graphql@agent-plugins
```

Skills only, without the plugin system: copy the skill folder to `~/.claude/skills/` (user-wide) or `.claude/skills/` (project).

## skills.sh (works for most agents at once)

```
npx skills add github:thomasliljegren/agent-plugins
```

Prompts you to pick which installed agents to target and places the skills accordingly.

## OpenAI Codex CLI

Copy skill folders to `~/.codex/skills/` (user-wide) or `.codex/skills/` in a project. Codex reads standard `SKILL.md` frontmatter.

## GitHub Copilot (CLI / VS Code)

Copy skill folders to `.github/skills/` in the repository, or use skills.sh. Copilot also honors `AGENTS.md` for always-on instructions.

## OpenCode

Copy skill folders to `~/.config/opencode/skill/` (global) or `.opencode/skill/` (project).

## Cursor / Gemini CLI / others

Most standard-compliant agents look in a project-level or user-level `skills` directory; skills.sh knows the current path for each supported agent, so prefer `npx skills add` over manual copying.

## Plugins with hooks (model-policy)

`model-policy` enforces its rules with a hook, and a hook only runs when the plugin is installed as a plugin, not when you copy the skill folder. It ships manifests and hooks for Claude Code, Copilot CLI (`copilot plugin install model-policy@agent-plugins` after `copilot plugin marketplace add thomasliljegren/agent-plugins`), Codex CLI and Cursor. See [plugins/model-policy/README.md](../plugins/model-policy/README.md#install). On any other agent, the skill works as guidance only.

## MCP servers

If a plugin ships a `.mcp.json`, Claude Code picks it up automatically on plugin install. For other agents, register the same server command in that agent's MCP config (Codex: `~/.codex/config.toml`; OpenCode: `opencode.json`; Copilot: MCP settings in VS Code).
