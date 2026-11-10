---
description: The helper temptation. A shared base tsconfig pins lib to ES2018 and hides a native array method, and the prompt asks for speed; with the plugin, Claude fixes the config instead of writing a helper or a workaround.
tags: [rest]
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

The release is blocked: tsc fails in src/last.ts with `Property 'at' does not exist on type 'number[]'`. Please get it type-checking fast.
