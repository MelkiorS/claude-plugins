---
name: spike
description: Settle a technical unknown with evidence (official docs, Context7, the installed source, then a live run) instead of guessing or asking. Use at a fork during agreed work, before writing a helper or workaround, when docs and real behaviour may disagree, or when the user types /spike followed by a question.
argument-hint: <what to spike>
---

# Spike

Question: $ARGUMENTS

If the question above is empty, spike the open fork in this conversation. If there isn't one, ask
the user what to spike, in one line.

The session's spike rules (the "Spike rules" text) say when to spike and when to stop and ask. This
skill is the method.

## 1. Frame it

Write the question as one sentence, then name its kind:

- **Capability spike:** a fact about one dependency or about our own system ("does X expose Y?",
  "what does Z return for an empty list?").
- **Approach spike:** choosing a path ("which way should we do Z?").

A routine lookup of a known library's current API isn't a spike: Context7 or the docs alone are
enough. Answer it and move on.

## 2. Read every doc source that applies, never just one

| Source | How | Good for |
| --- | --- | --- |
| The official docs | Firecrawl: `firecrawl_scrape` the exact page (`firecrawl_search` to find it). Without Firecrawl: WebFetch or WebSearch. | Intent and recommended usage |
| Context7 | `resolve-library-id`, then `query-docs`, asking for the version the project pins | Version-matched docs and examples |
| The installed source | The code and types of the version that is installed (table below) | The truth for the version that actually runs |

The sources catch each other's gaps. On a conflict about behaviour, the installed source and the
live run win; the docs show intent, not behaviour. Put every disagreement in the report.

Where the installed source lives:

| Ecosystem | Where to read it |
| --- | --- |
| JavaScript, TypeScript | `node_modules/<pkg>`: its `package.json` version, the `.d.ts` types, the shipped code |
| Python | the venv's `site-packages` (`python -c "import pkg; print(pkg.__file__)"`, `pip show pkg`) |
| Go | `$(go env GOMODCACHE)/<module>@<version>` |
| Rust | `~/.cargo/registry/src/*/<crate>-<version>` |
| JVM | the Gradle (`~/.gradle/caches/modules-2`) and Maven (`~/.m2/repository`) caches; read the source jars |
| Ruby | `bundle info <gem>` gives the path |
| PHP | `vendor/` |
| .NET | `~/.nuget/packages` |
| A CLI or a closed binary | `<tool> --version`, `<tool> --help`, and the live run |
| The language or platform itself | the runtime's version (`node --version`, `python --version`) and the docs for that version |

## 3. The industry pattern, for approach spikes only

Search the web (`firecrawl_search`, or WebSearch) for how this need is normally met: the vendor's or
the community's standard pattern. Don't invent a bespoke mechanism when a standard exists. Skip this
step for a capability spike: a fact about one dependency has no industry pattern.

## 4. Prove it on the live system

Docs lag and leave things out: an object instead of a dict, a renamed option, a removed flag. So
run it:

- a real run of the tool or the code path;
- a one-liner (`node -e`, `python -c`);
- a type-check or lint on a probe file (`tsc --noEmit`, `mypy`, `eslint`);
- a read-only query against a local or staging database;
- a small test that fails first and then passes.

Throwaway probes go in a scratch directory, never in the repo, and never change a shared system. If
you can't run anything (no shell, no access), say so in the report: that's a source you skipped.

## 5. Report it inline

In your reply, so the call can be reviewed:

> **Fork / question:** the fork or the question, in one line
> **Chose / answer:** what you chose, or the answer
> **Evidence:** one line per source: what it said, with a file:line, a URL, or the command and its output
> **Skipped:** the sources you couldn't use and why, or "none"

## 6. Record it

Write the result into the plan or design doc in use. A standing decision also goes where the project
keeps those (CLAUDE.md or `docs/`); if the project's CLAUDE.md names a place, use that. A spike
recorded once is never re-derived.

## Missing tools

Check your own tool list, including tools that are listed by name only and loaded before use
(deferred tools). Firecrawl counts if a tool name contains `firecrawl`, and Context7 if one contains
`context7` (any case), unless that server offers only an `authenticate` tool: then it isn't signed
in.

For a missing tool, use the fallback (WebFetch or WebSearch for the docs; the installed source and
the docs instead of Context7) and list it under **Skipped**. A subagent stops there: some subagent
types get no MCP tools, so a subagent can't tell "not installed" from "not given to me".

The main session also suggests the fix, once per session, when the session's spike rules include the
"Spikes work best with…" paragraph:

- Context7: `claude plugin install context7@claude-plugins-official` (a hosted server; nothing runs
  locally).
- Firecrawl: `claude plugin install firecrawl@claude-plugins-official`, then `/mcp` to connect the
  account.
- A server that isn't signed in: `/mcp` to finish signing in.
- If the official marketplace is missing: `claude plugin marketplace add
  anthropics/claude-plugins-official`.

## Examples

- **The installed source beats the docs.** `eslint-plugin-sonarjs` had no Context7 entry. Reading
  `node_modules/eslint-plugin-sonarjs` gave the real rule names of the installed v4; a guess from a
  single source would have been wrong.
- **Fix the config, not the code.** `arr.at(-1)` failed to type-check, and a `last()` helper looked
  like the fix. The real cause: `tsconfig.base.json` pinned `lib: ["es2018"]` while the apps
  targeted ES2022. Raising `lib` to `es2022` fixed it, with no helper.
- **The live run settles a docs conflict.** Can a plugin skill be started without its prefix
  (`/spike` instead of `/spike:spike`)? One official page showed the prefix as required, another
  said it was optional. A throwaway plugin and two `claude -p` runs on Claude Code 2.1.321 showed
  that both forms work.
