# verified

Keeps what a project checked against the frameworks, libraries and tools it depends on in `VERIFIED.md`, by topic, each fact with its evidence and every fallback taken. A file grown a section per slice, per task or per date is reorganised into that shape without losing an identifier.

## Install

```
/plugin marketplace add thomasliljegren/agent-plugins
/plugin install verified@agent-plugins
```

Any other agent: `npx skills add github:thomasliljegren/agent-plugins` installs the skill, with its references and scripts.

The preservation check needs `bash` and `awk`.

## What it gives a project

- **The `verified` skill**: what belongs in `VERIFIED.md` and where everything else goes, the file's topic layout, the entry's shape (claim, what to do, evidence, source), how a fact is corrected, and the split into `verified/<topic>.md` past 400 lines.
- **`/verified:reorganize [path]`** (Claude Code): brings an existing file into that shape. It proposes every move, merge and deletion and waits for a yes before it writes. Other agents follow the skill's `references/reorganize.md`.
- **`scripts/preserved.sh`**, in the skill: proves a rewrite kept every line of fenced code, backticked span, commit hash, version and measurement of the original, or that the approved proposal moved or deleted it.

```
preserved.sh OLD NEW... [--moved FILE...] [--deleted LIST]
preserved.sh --tokens FILE
```

## Adopting it

Put one line in the project's `CLAUDE.md`: record what was checked against a framework in `VERIFIED.md`, by the `verified` skill. Keep there what only the project knows: the documentation to query before writing an API, what publishes the file, and destinations of its own. Then run `/verified:reorganize` once.

## Tests

```
bash plugins/verified/tests/run.sh
```
