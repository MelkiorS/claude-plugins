# Claude Code plugins

A personal [Claude Code](https://code.claude.com) plugin marketplace: one repo, many plugins.

## Install a plugin

```
claude plugin install <plugin> --marketplace MelkiorS/claude-plugins
```

The first install also adds this marketplace. After that, `claude plugin install <plugin>@AndyV`
or `/plugin` installs the others, and `claude plugin marketplace update AndyV` pulls updates.

## Install a JetBrains plugin

This repo is also a JetBrains plugin repository. Add it once, in any JetBrains IDE: Settings →
Plugins → ⚙ → *Manage Plugin Repositories…* → **+** →

```
https://raw.githubusercontent.com/MelkiorS/claude-plugins/main/jetbrains/updatePlugins.xml
```

Then find the plugin in the **Marketplace** tab and install it; new versions arrive as normal
plugin updates.

## Plugins

| Plugin | What it does |
| --- | --- |
| [session-successor](plugins/session-successor) | Before a session's context window runs out, it writes a handoff prompt and starts its successor (`name-2`, `name-3`, ...) at max effort; a companion JetBrains plugin opens the successor in a new terminal tab. |
| [statusline](plugins/statusline) | A compact status line: model, project, git branch with a dirty/clean dot, colour-coded context left and an hourly phrase. Run `/statusline:setup` once after installing. |

Every plugin here is plain bash with no extra tools to install (no `jq`).

## Layout

```
.claude-plugin/marketplace.json   the Claude Code catalogue: one entry per plugin
plugins/<name>/                   a Claude Code plugin; this folder is what an install copies
jetbrains/updatePlugins.xml       the JetBrains catalogue: one entry per plugin
jetbrains/dist/                   built JetBrains plugin zips the catalogue points to
jetbrains/<name>/                 a JetBrains plugin's source
```

## Adding a plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json` plus its `hooks/`, `commands/`, `skills/`,
   `agents/` and a `README.md`.
2. Add an entry to `.claude-plugin/marketplace.json`:
   `{"name": "<name>", "source": "./plugins/<name>", "description": "..."}`.
3. Check both manifests: `claude plugin validate .` and `claude plugin validate plugins/<name>`.
4. Try it without installing: `claude --plugin-dir plugins/<name>`.

## Releasing a JetBrains plugin

1. Bump `version` in `jetbrains/<name>/build.gradle.kts` and run `./gradlew buildPlugin`.
2. Copy `build/distributions/<name>-…-<version>.zip` into `jetbrains/dist/` (delete the old zip).
3. Update the plugin's entry in `jetbrains/updatePlugins.xml`: `url` and `version`.
4. Run `jetbrains/check-index.py`: the IDE skips an entry whose `id`, `version` or
   `idea-version` differ from the `plugin.xml` inside its zip.
