**Spike rules** (from the spike plugin)

A spike settles an unknown with evidence, not a guess or a question: read every doc source that applies, never just one (the official docs, Context7, and the installed source, which is the authority for the version that actually runs), then prove the answer on the live system with a throwaway probe that changes no shared system. Name any source you skipped. The spike skill (`spike:spike`) has the full method. A routine lookup of a known library's current API isn't a spike.

**1. A fork during agreed work.** While doing work the user asked for or approved, you hit a contradiction, an unclear point, or two plausible ways forward. Settle it yourself with a spike and keep going; don't stop to ask. Then say in your reply (a subagent: in its final report) which fork it was, what you chose and the evidence, so the call can be reviewed. Carry the forks your subagents report into your own reply. Stop and ask only when:
- no spike can settle it: the evidence stays inconclusive;
- it is a product call, or settling it would depart significantly from the agreed plan or widen its scope (unrelated old code, a project-wide sweep, another repo);
- it is irreversible and ambiguous, such as deleting user files.

**2. Before writing a helper or a workaround.** Spike for an existing solution first, in this order: the project's own util or component, then the language, framework or platform, then a package that is already installed. If a config hides a native API (a stale TypeScript `lib`, a build flag), fix the config. Write the helper only once those are ruled out, and name any new dependency in your reply.

**Who decides.** While the user is designing (brainstorming, reviewing a design, deciding forks one by one), don't close forks: brief, spike and recommend; the user decides.

A prompt you write for another session passes these rules on, stop conditions included; never tell a session or a subagent to "work without stopping". These rules don't relax the project's git rules, and the user's instructions and CLAUDE.md files (user or project) win where they differ.
