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

Gradle needs a JDK, and WebStorm's bundled one works:
`export JAVA_HOME=~/.local/share/JetBrains/Toolbox/apps/webstorm/jbr`. Add `-PlocalIde=<IDE folder>`
to build and verify against an installed IDE instead of downloading one.

1. Bump `version` in `jetbrains/<name>/build.gradle.kts`, add a line to `<change-notes>` in its
   `plugin.xml`, and run `./gradlew buildPlugin verifyPlugin`. JetBrains Marketplace runs the same
   Plugin Verifier on every upload; it must say "Compatible".
2. Copy `build/distributions/<name>-…-<version>.zip` into `jetbrains/dist/` (delete the old zip).
3. Update the plugin's entry in `jetbrains/updatePlugins.xml`: `url` and `version`.
4. Run `jetbrains/check-index.py`: the IDE skips an entry whose `id`, `version` or
   `idea-version` differ from the `plugin.xml` inside its zip.
5. JetBrains Marketplace: sign the zip, then upload it.
   - Once, outside the repo, make a signing key and certificate as in JetBrains'
     [Plugin Signing](https://plugins.jetbrains.com/docs/intellij/plugin-signing.html) guide, and
     keep both: every release needs them.
     ```
     openssl genpkey -aes-256-cbc -algorithm RSA -out private_encrypted.pem -pkeyopt rsa_keygen_bits:4096
     openssl rsa -in private_encrypted.pem -out private.pem
     openssl req -key private.pem -new -x509 -days 365 -out chain.crt
     ```
   - Each release: `export CERTIFICATE_CHAIN="$(cat chain.crt)" PRIVATE_KEY="$(cat private.pem)"
     PRIVATE_KEY_PASSWORD=<the passphrase>`, then `./gradlew signPlugin`. The signed zip is the
     `…-signed.zip` in `build/distributions/`.
   - The first version is uploaded by hand: plugins.jetbrains.com → *Upload plugin*. Later versions:
     `PUBLISH_TOKEN=<token> ./gradlew publishPlugin` (a token from your Marketplace profile; it signs
     first).
