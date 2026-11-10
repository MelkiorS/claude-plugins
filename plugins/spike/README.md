# spike

Claude guesses less and asks less when it settles unknowns with evidence. **spike** puts one set of
rules into every session and every subagent, and adds `/spike <question>` for the full method:

1. **A fork during agreed work** (a contradiction, an unclear point, two plausible ways forward):
   Claude settles it with a spike and keeps going, then says in its reply which fork it was, what it
   chose and the evidence. It stops and asks only when no spike can settle it, when it's a product
   or scope call (or a big departure from the agreed plan), or when it's irreversible and ambiguous,
   such as deleting user files.
2. **Before writing a helper or a workaround:** Claude looks for an existing solution first: the
   project's own util, then the language, framework or platform, then a package that's already
   installed. A config that hides a native API gets fixed, not worked around, and any new
   dependency is named in the reply.
3. **While you're designing** (brainstorming, a design review, deciding forks one by one), you
   decide every fork; Claude briefs, spikes and recommends.

A spike reads every doc source that applies, never just one: the official docs, Context7, and the
installed source, which is the authority for the version that actually runs. Then it proves the
answer on the live system. When the sources disagree about behaviour, the installed source and the
live run win.

## /spike

```
/spike does tiny-flags 2.x support negated flags like --no-color?
```

runs the full method on one question and reports it:

> **Fork / question:** … **Chose / answer:** … **Evidence:** one line per source …
> **Skipped:** the sources it couldn't use, and why

With no question, `/spike` takes the open fork in the conversation, or asks what to spike. If
another skill is also named `spike` (from a plugin, or your own user or project skill), type
`/spike:spike`.

## Works best with Firecrawl and Context7

Firecrawl reads official docs and searches the web; Context7 serves version-matched library docs.
Without them a spike still runs (WebFetch or WebSearch for the docs, the installed source, a live
run), its report names what it skipped, and Claude suggests installing the missing tool once per
session:

```
claude plugin install context7@claude-plugins-official
claude plugin install firecrawl@claude-plugins-official   # then /mcp to connect your account
```

A server that is installed but not signed in counts as missing: finish signing in with `/mcp`. If
the official marketplace isn't registered yet: `claude plugin marketplace add
anthropics/claude-plugins-official`.

## Install

```
claude plugin install spike --marketplace MelkiorS/claude-plugins
```

Start new sessions after installing; restart sessions that were already running so they load it.
Settings (via `/plugin` → spike → configure, or at install time with `--config suggest_tools=off`):

| Setting | Default | Meaning |
| --- | --- | --- |
| `suggest_tools` | on | `on`: when a spike runs without Firecrawl or Context7, Claude suggests installing them, once per session. `off`: it only says which source it skipped. |

## How it works

| Part | What it does |
| --- | --- |
| `hooks/hooks.json` → `scripts/rules.sh` | puts `scripts/rules.md` (and `scripts/hint.md`, unless `suggest_tools` is off) into every session at start, again after `/clear`, resume and compaction, and into every subagent when it starts |
| `skills/spike/SKILL.md` | the full method; runs on `/spike` or when Claude starts a spike |

Your own instructions and your CLAUDE.md files (user or project) win where they differ, so a repo
can add its own specifics, such as which commands prove things and where spike results get written.
The rules never relax the project's git rules.

**Cost:** about 850 tokens per session: about 100 for the skill's line in the skill listing, the rest
for the rules; a subagent pays for the rules only. Measured on Claude Code 2.1.321 by sending the
same one-line prompt with and without the plugin: 747–941 tokens across runs, because the rest of
the context varies by about 100 tokens from run to run.

## Tested

Claude Code 2.1.321 on Linux. `scripts/rules.sh` under bash 5 and bash 3.2.57 (macOS's version, in
Docker); `bash plugins/spike/tests/test-rules.sh` checks its output (it needs `python3`). Live
checks: the rules reach the session and a subagent, also from a plugin path with a space; a project
CLAUDE.md that says "always ask first" wins; `/spike` works with and without the prefix, with no
question, and next to another plugin's `spike` skill.

Evals (`claude plugin eval`, Sonnet, one run per arm, with and without the plugin):

| Case | With | Without |
| --- | --- | --- |
| brake-product-call: the next step needs a product decision | 1.0 | 0.0 |
| spike-by-hand: `/spike` on a package whose README contradicts its code | 1.0 | 0.67 |
| fork-during-agreed-work: two utils, and only the plan's example shows which is right | 1.0 | 1.0 |
| helper-temptation: a stale tsconfig `lib` hides `.at()` | 1.0 | 1.0 |
| brake-routine-lookup: a plain API question stays a quick answer | 1.0 | 1.0 |

Without the plugin, Claude chose a delete strategy itself where it should have asked; with it, it
stopped and asked. Sonnet already reports simple forks and fixes the tsconfig on its own, so those
two cases show no difference. To run them yourself:
`claude plugin eval plugins/spike --scaffold --allow-tools Write Edit --no-publish`.

Design notes: [docs/design.md](docs/design.md).
