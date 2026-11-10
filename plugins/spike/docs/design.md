# spike — design

Status: built on 2026-11-10 and checked on Claude Code 2.1.321 (Linux). These are now the design
notes: why the parts are built the way they are. The facts were checked with the spike method
itself: the official docs, Context7, the installed binary and a live run.

## Why

A set of spike rules has worked well in one of Andy's projects. At a fork during agreed work, Claude
settles it with evidence instead of asking; before writing a helper it looks for an existing
solution first; and a spike never trusts a single source. Those rules lived in that one project's
CLAUDE.md and notes, so anyone in another repo or on another team got none of them. This plugin
packages them so other teams and people can install them from the AndyV marketplace and get the
same behaviour in their own projects.

The rules come from that project's CLAUDE.md (the two triggers with their stop conditions, the
inline report, passing the rules on to other sessions and subagents, and the spike method), from
the design-phase switch of its design skill (the human decides every fork; spikes without evidence
don't count), and from a few feedback notes, including the `last()` vs `.at(-1)` story.

## Goals

1. **The same behaviour in any project.** The two triggers, the stop conditions, the method and the
   inline report work in any repo and any language.
2. **It stands on its own.** English only, no links into any one project, nothing that works only
   with one person's setup. Project specifics (the build tool, the linter, a staging database, where
   plans live) become examples.
3. **It works better with Firecrawl and Context7, and says so.** Without them a spike still runs on
   the sources it has, the report names what it skipped, and Claude suggests installing the missing
   tool once per session. Users can switch the suggestion off.
4. **It can be started by hand:** `/spike <what to spike>`.
5. **Subagents get the rules too**, without anyone pasting them into each subagent prompt.
6. **The project has the last word.** A repo's CLAUDE.md can add its own specifics (which commands
   prove things, where results go) and wins where it differs.

Goals 3 and 4 and the behaviour below were agreed with Andy in chat on 2026-11-10.

## Non-goals

- The full design workflow these rules came with (approach specs, a fork registry, ADR and SPEC
  files). Only its "who decides" switch comes along.
- Installing or bundling Firecrawl or Context7. The plugin suggests them; it never installs them.
- Changing the project the rules came from.

## Anti-goals: failures even if it technically works

- Claude asks *more* questions than before.
- Claude closes a product or scope call, or does something irreversible and ambiguous, on its own.
- A fork is settled silently: decided, but not said in the reply.
- Every small lookup turns into a three-source ritual.
- The install suggestion nags on every spike.
- The always-on text grows into a noticeable cost in every session and subagent.

## Behaviour

### Always on

From the first prompt of every session, again after `/clear`, resume and compaction, and at the
start of every subagent, Claude holds a short rule text. It ships as `scripts/rules.md` and
`scripts/hint.md`, which are the source of truth. The draft it was built from follows. The shipped
text differs in naming the skill `spike:spike`, in line wrapping, and in four fixes from the final
review: it asks Claude to name any skipped source even with the hint switched off; live probes are
throwaway and change no shared system; the user's own instructions and CLAUDE.md files (user or
project) win, not only the project's; and the main session no longer pastes the rules into
subagent prompts, since the SubagentStart hook delivers them. It stays under 400 words:

> **Spike rules** (from the spike plugin)
>
> A spike settles an unknown with evidence, not a guess or a question: read every doc source that
> applies, never just one (the official docs, Context7, and the installed source, which is the
> authority for the version that actually runs), then prove the answer on the live system. The
> `spike` skill has the full method. A routine lookup of a known library's current API isn't a
> spike.
>
> **1. A fork during agreed work.** While doing work the user asked for or approved, you hit a
> contradiction, an unclear point, or two plausible ways forward. Settle it yourself with a spike
> and keep going; don't stop to ask. Then say in your reply (a subagent: in its final report) which
> fork it was, what you chose and the evidence, so the call can be reviewed. Carry the forks your
> subagents report into your own reply. Stop and ask only when:
> - no spike can settle it: the evidence stays inconclusive;
> - it is a product call, or settling it would depart significantly from the agreed plan or widen
>   its scope (unrelated old code, a project-wide sweep, another repo);
> - it is irreversible and ambiguous, such as deleting user files.
>
> **2. Before writing a helper or a workaround.** Spike for an existing solution first, in this
> order: the project's own util or component, then the language, framework or platform, then a
> package that is already installed. If a config hides a native API (a stale TypeScript `lib`, a
> build flag), fix the config. Write the helper only once those are ruled out, and name any new
> dependency in your reply.
>
> **Who decides.** While the user is designing (brainstorming, reviewing a design, deciding forks
> one by one), don't close forks: brief, spike and recommend; the user decides.
>
> A prompt you write for a subagent or another session passes these rules on, stop conditions
> included; never tell it to "work without stopping". These rules don't relax the project's git
> rules, and the project's CLAUDE.md wins where it differs.
>
> Spikes work best with Firecrawl (official docs, web search) and Context7 (library docs). When a
> spike runs without one of them, say which source you skipped. In the main session, also suggest
> installing it, once per session; the `spike` skill has the commands.

The last paragraph is the install hint; it is left out when the user switches hints off.

### The `spike` skill: the full method

It loads when Claude starts a spike, or when the user types `/spike <question>`. Draft
frontmatter:

```yaml
name: spike
description: Settle a technical unknown with evidence (official docs, Context7, the installed source, then a live run) instead of guessing or asking. Use at a fork during agreed work, before writing a helper or workaround, when docs and real behaviour may disagree, or when the user types /spike followed by a question.
argument-hint: <what to spike>
```

The body (`$ARGUMENTS` carries the question):

1. **Frame it:** one question. A *capability* spike ("does X expose Y?") or an *approach* spike
   ("which way should we do Z?"). A routine lookup of a known library's current API isn't a spike:
   Context7 or the docs alone are enough.
2. **Doc sources, every one that applies, never just one:**
   - the official docs: Firecrawl scrape of the exact page, or WebFetch when Firecrawl is missing;
   - Context7;
   - the installed source, the authority for the version that actually runs. A short table says
     where it lives per ecosystem: `node_modules`, the venv's `site-packages`, the Go module cache,
     the Cargo registry, the Gradle and Maven caches, `vendor/`, the NuGet cache; for a closed
     binary, its `--help` and `--version` and the live run.

   On a conflict about behaviour, the installed source and the live run win; the docs show intent.
3. **The industry pattern, for approach spikes only:** a web search (Firecrawl search, else
   WebSearch) for how the need is normally met. Skip it for capability spikes.
4. **Prove it live:** a real run, a REPL one-liner, a DB query, a type-check or lint on a probe
   file, a test. Throwaway probes go in a scratch directory, not the repo.
5. **Report inline:** the fork or question, the answer or choice, the evidence per source, and what
   was skipped or not checked. Sketch:
   > **Fork:** … **Chose:** … **Evidence:** … **Skipped:** Context7 (not installed).
6. **Record it:** in the plan or design doc in use; a standing decision also goes where the project
   keeps those (CLAUDE.md or `docs/`). If the project's CLAUDE.md names a place, use that.

**Missing tools.** Claude checks its own tool list: a tool name containing `firecrawl` or `context7`
(any case) counts, unless the server only exposes an `authenticate` tool, which means it isn't
signed in. For a missing tool: use the fallback and say so in the report. A subagent stops there,
because some subagent types get no MCP tools and can't tell "not installed" from "not given to me".
The main session also suggests, once per session and only if the always-on text carries the
install hint:

- Context7: `claude plugin install context7@claude-plugins-official` (a hosted server; nothing
  runs locally).
- Firecrawl: `claude plugin install firecrawl@claude-plugins-official`, then `/mcp` to connect the
  account.
- A server that isn't signed in: `/mcp` to finish signing in.
- If the official marketplace is missing: `claude plugin marketplace add
  anthropics/claude-plugins-official`.

**Examples** carried into the skill, a few lines each: `eslint-plugin-sonarjs` (Context7 had no
entry; `node_modules` had the real v4 rule names); `last()` vs `.at(-1)` (a stale tsconfig `lib`
hid a native method, and the fix was the config); this plugin's own `/spike` question (the docs
disagreed about the plugin prefix, and a live run settled it).

### By hand

`/spike <question>` runs the skill with the question as its argument. If another skill is also
called `spike`, `/spike:spike <question>` always works. With no argument, Claude spikes the open
fork in the conversation, or asks what to spike if there isn't one.

## How it's built

```
plugins/spike/
  .claude-plugin/plugin.json   name spike, version 0.1.0, userConfig suggest_tools (on/off, default on)
  hooks/hooks.json             SessionStart and SubagentStart, both without a matcher → scripts/rules.sh
  scripts/rules.sh             prints rules.md, plus hint.md unless suggest_tools is off, as
                               hookSpecificOutput.additionalContext for its event
  scripts/rules.md             the always-on rules: one copy for both events
  scripts/hint.md              the install-hint paragraph
  tests/test-rules.sh          checks rules.sh's output (needs python3)
  skills/spike/SKILL.md        the method; argument-hint: <what to spike>
  evals/                       five cases for claude plugin eval; evals/results/ is gitignored
  README.md                    what it does, /spike, "works best with Firecrawl and Context7"
  docs/design.md               this file; it becomes the design notes once built
```

Plus an entry in `.claude-plugin/marketplace.json` and a row in the root README's plugin table.

## Decisions and their evidence

All decisions in this section are Claude's calls, made on the evidence shown.

| Decision | Evidence |
| --- | --- |
| The always-on rules come from hooks, not only from the skill. | A skill's body loads only when Claude opens it; until then only its name and description sit in the skill listing, capped at 1,536 characters (official skills docs). A fork looks like ordinary work, so Claude would rarely think to open a skill at that moment. A project gets the same effect by keeping the rules in its CLAUDE.md, which loads at launch. |
| A `SubagentStart` hook as well as `SessionStart`. | Live probe on 2.1.321: a subagent saw the `SubagentStart` text but not the `SessionStart` text, while the main session saw the `SessionStart` text. The official hooks page, Context7 and the binary's output schema (`{hookEventName: "SubagentStart", additionalContext?}`) agree; the official page adds that the text is injected again after a subagent's auto-compaction. |
| `SessionStart` without a matcher. | Its matchers are `startup`, `resume`, `clear` and `compact`; with none, it fires on all four, so the rules come back after `/clear` and compaction (official hooks guide, "re-inject context after compaction"). |
| `SubagentStart` without a matcher. | Every agent type gets the rules, including plugin agents (named `plugin:agent`). Read-only agents such as Explore still research, so the method applies to them too. The cost is the same few hundred tokens per subagent. |
| `/spike` works without the plugin prefix. | The docs disagree: the skills page shows plugin skills as `/my-plugin:review`, the slash-commands page says the prefix is optional unless names collide. Live probe on 2.1.321: both `/spike does X expose Y` and `/probe:spike does X expose Y` delivered the argument intact. |
| Claude spots missing tools itself; no script reads MCP config. | The same tools arrive by several roads: claude.ai connectors (`mcp__claude_ai_Firecrawl__…`), plugins (`mcp__plugin_…`), and user or project MCP config (`mcp__context7__…`). The session that wrote this design had Context7 twice: once working, once exposing only `authenticate`. Only the model sees the full, current tool list. |
| Install hints point at the official marketplace. | `claude-plugins-official` lists `context7` (Upstash, hosted at mcp.context7.com) and `firecrawl` (hosted MCP at mcp.firecrawl.dev, account connected via `/mcp`, per its README and `.mcp.json`). Claude Code registers that marketplace itself on the first interactive start (official plugin troubleshooting docs). |
| The hint is switched off with a plugin option. | Plugin options reach hook scripts as `CLAUDE_PLUGIN_OPTION_<KEY>`; session-successor reads `CLAUDE_PLUGIN_OPTION_THRESHOLD` the same way. |
| Plain bash, no `jq`. | The marketplace rule: "Every plugin here is plain bash with no extra tools to install". JSON escaping is copied from session-successor's `json_escape`, because an install copies only the plugin's own folder. |
| Names: plugin `spike`, skill `spike`. | Gives `/spike`. No plugin or skill named `spike` exists in the installed marketplaces. |
| The spike runs inline, not in a forked subagent. | The evidence has to be visible in the reply, and the live probe proved the inline path. A forked skill (`context: fork`) would save context on heavy spikes; left out on purpose for 0.1.0. |
| Only the main session suggests installs; a subagent just names the skipped source. | Some subagent types get no MCP tools, so a subagent can't tell "not installed" from "not given to me" (raised by the builder review). |
| `rules.sh` keeps no state; "once per session" is the model's best effort. | A per-session marker file needs cleanup and buys little: at worst the hint comes back once after compaction. |
| The bash runs on macOS's bash 3.2. | Other teams use Macs. No associative arrays, `${var,,}` or `mapfile`; session-successor's `json_escape` already sticks to 3.2 features. |

## Cost

The always-on text is paid once per session and once per subagent. Measured: **about 850 tokens per
session** (747–941 across runs), about 100 of them for the skill's line in the skill listing and the
rest for the rules; a subagent pays for the rules only. That is above the design's estimate of about
550 tokens for the text. The 399 words stay under the 400-word budget and every paragraph carries
one of the rules, so the text was kept.

How it was measured: `claude plugin details` can't see hook text (it lists hooks as "harness-only —
no model context cost" and counts only the skill listing). So the same one-line prompt ran with and
without the plugin and the input tokens were compared, with a neutral one-skill plugin in both arms
and `--strict-mcp-config`, for example 17,529 against 18,344 tokens; the rest of the context varies
by about 100 tokens from run to run, hence the range. Without
`--strict-mcp-config` the difference read 12–16K, because the user's claude.ai connectors (a 29 KB
deferred-tool list plus their instructions) landed in the first request whenever the hooks delayed
it; a normal session carries those anyway.

## Verification

1. `claude plugin validate .` and `claude plugin validate plugins/spike`.
2. Live, with `claude -p --plugin-dir plugins/spike`: the rules reach the main session and a
   subagent; `/spike <question>` passes the argument; with `suggest_tools` off, the hint paragraph
   is gone; a project CLAUDE.md that says otherwise wins. That last check can't be an eval, because
   eval runs load no CLAUDE.md, MCP servers or user settings (official plugin-evals docs). Probe
   runs use `--setting-sources project,local --no-session-persistence`, so they neither run the
   user's own hooks nor leave transcripts behind.
3. `claude plugin eval plugins/spike` with a no-plugin baseline. The evals are **evidence for
   Andy's review, not a release gate** (Andy's decision, 2026-11-10): one run per arm (`--runs 1`)
   on Sonnet (`--model sonnet`), five cases, so ten sessions in all:
   - **A fork during agreed work:** an approved task with a real two-way choice. With the plugin,
     Claude spikes and reports the fork inline instead of asking.
   - **The helper temptation:** a TypeScript probe where `arr.at(-1)` fails to type-check because
     tsconfig's `lib` is stale. With the plugin, Claude fixes the config instead of writing `last()`.
   - **By hand:** `/spike <a capability question>`. The report names the sources it used and the
     ones it skipped.
   - **Brake, a product call:** during an approved task, the next step needs a product decision
     that no spike can settle (which of two user-facing behaviours to ship). With the plugin,
     Claude still stops and asks.
   - **Brake, a routine lookup:** a plain question about a known library's current API. With the
     plugin, Claude answers from one source, without the full spike.

   Eval runs always pass `--no-publish`, since by default `claude plugin eval` publishes its HTML
   report to claude.ai; `evals/results/` is gitignored. `--max-cost-usd` caps the spend: the first
   case runs alone, and the cap is set from its measured cost. The exit code isn't a gate. If the
   no-plugin baseline already passes a case, the case is sharpened once; if both arms still pass,
   it stays and the report says the plugin made no difference there. Both arms' scores go into the
   design notes.

Probe runs and eval scaffolds never touch shared systems: scratch directories only.

### Results (2026-11-10)

- `claude plugin validate` passes for the marketplace and the plugin; only the missing icon warns.
- `tests/test-rules.sh` passes 7 of 7 under bash 5. Under bash 3.2.57 (Docker) the injected text
  matches the files exactly.
- Live: the rules reached the session and a subagent from a plugin path with a space. A project
  CLAUDE.md saying "always ask first" won (`CHOICE=ask`, citing the precedence line). `/spike`
  worked with and without the prefix, asked what to spike when given nothing, and still reached
  this plugin next to another plugin's `spike` skill. On the tiny-flags fixture it trusted the
  installed code over the stale README and listed the sources it skipped.
- Evals, Sonnet, one run per arm:

| Case | With | Without | Notes |
| --- | --- | --- | --- |
| brake-product-call | 1.0 | 0.0 | Without the plugin, Claude chose `softDelete` itself; with it, it stopped and asked. |
| spike-by-hand | 1.0 | 0.67 | The difference is the install hint; both answers were right. |
| fork-during-agreed-work | 0.67 | 0.67 | Sharpened once (the first version scored 1.0 in both arms). Both arms chose the legacy util that `src/app.js` imports and reported the fork. The fixture is ambiguous: the plan's `Hello, <Name>!` fits the legacy util's lowercasing. |
| helper-temptation | 1.0 | 1.0 | Sharpened once (the stale `lib` moved into an extended base config, plus time pressure). Sonnet fixes the config with or without the plugin. |
| brake-routine-lookup | 1.0 | 1.0 | No Skill call in either arm: the plugin doesn't turn lookups into spikes. |

Deviations from the plan: the install hint lives in its own file; two grader fixes (a `lib` regex
that also matched the existing `target` was replaced by a judge, and the skill-fired indicator reads
the reply's report label, because a typed `/spike` leaves no skill text in the trace); the cost
above the estimate.

## Left to the builder

- The final wording of the rules text and the skill, within the limits above.
- Whether the ecosystem table and the examples sit in `SKILL.md` or in a `references/` file.
- Eval case details and grader wording.
- README wording.
