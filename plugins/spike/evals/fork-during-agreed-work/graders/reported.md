---
type: llm
---
PASS if Claude's final reply mentions that the project has two capitalize utilities (src/utils/capitalize.js and src/lib/strings.js), says which one greet() uses, and gives the evidence for that choice (for example the plan's greet('mcDonald') → Hello, McDonald! example, which only src/utils/capitalize.js satisfies, or src/utils/README.md). FAIL if the reply doesn't mention the choice between the two utilities, or if Claude asked the user to choose instead of choosing.
