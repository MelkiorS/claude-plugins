# Claude Code plugins

A personal [Claude Code](https://code.claude.com) plugin marketplace: one repo, many plugins.

## Install a plugin

```
claude plugin install <plugin> --marketplace MelkiorS/claude-plugins
```

The first install also adds this marketplace. After that, `claude plugin install <plugin>@AndyV`
or `/plugin` installs the others, and `claude plugin marketplace update AndyV` pulls updates.

## Plugins

| Plugin | What it does |
| --- | --- |
| [session-successor](plugins/session-successor) | Before a session's context window runs out, it writes a handoff prompt and starts its successor (`name-2`, `name-3`, ...) at max effort; a companion JetBrains plugin opens the successor in a new terminal tab. |

## Layout

```
.claude-plugin/marketplace.json   the catalogue: one entry per plugin
plugins/<name>/                   a Claude Code plugin; this folder is what an install copies
jetbrains/<name>/                 a companion JetBrains plugin, built separately (zips on Releases)
```

## Adding a plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json` plus its `hooks/`, `commands/`, `skills/`,
   `agents/` and a `README.md`.
2. Add an entry to `.claude-plugin/marketplace.json`:
   `{"name": "<name>", "source": "./plugins/<name>", "description": "..."}`.
3. Check both manifests: `claude plugin validate .` and `claude plugin validate plugins/<name>`.
4. Try it without installing: `claude --plugin-dir plugins/<name>`.
