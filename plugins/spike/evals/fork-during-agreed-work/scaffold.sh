#!/usr/bin/env bash
# Fixture: an agreed plan step needs "the project's capitalize util", and the project has two. Old code
# imports the legacy one; only src/utils/README.md says which one new code should use.
set -euo pipefail
mkdir -p src/utils src/lib

cat > package.json <<'EOF'
{"name": "demo", "private": true, "type": "module"}
EOF

cat > PLAN.md <<'EOF'
# Plan

Agreed plan, approved by the user:

1. Add `greet(name)` to `src/greet.js`. It returns `Hello, <Name>!` (the name capitalized), using the project's capitalize util.
2. Use `greet` in `src/app.js`.
EOF

cat > src/utils/README.md <<'EOF'
# src/utils

Shared helpers live here. `src/lib/` is legacy and is being emptied: new code imports from `src/utils/`.
EOF

cat > src/utils/capitalize.js <<'EOF'
export function capitalize(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}
EOF

cat > src/lib/strings.js <<'EOF'
export function capitalize(s) {
  return s.length ? s[0].toUpperCase() + s.slice(1).toLowerCase() : s;
}
EOF

cat > src/app.js <<'EOF'
import { capitalize } from './lib/strings.js';

console.log(capitalize('world'));
EOF
