#!/usr/bin/env bash
# Fixture for the spike-by-hand eval: a project on tiny-flags 2.3.0, whose README says negated flags
# aren't supported while its code and CHANGELOG say they are. Writes into the current directory.
set -euo pipefail
mkdir -p node_modules/tiny-flags

cat > package.json <<'EOF'
{"name": "demo", "private": true, "dependencies": {"tiny-flags": "^2.3.0"}}
EOF

cat > node_modules/tiny-flags/package.json <<'EOF'
{"name": "tiny-flags", "version": "2.3.0", "main": "index.js"}
EOF

cat > node_modules/tiny-flags/README.md <<'EOF'
# tiny-flags

A tiny command-line flag parser.

    const parse = require('tiny-flags');
    parse(['--color', '--size=3']); // { color: true, size: '3' }

Negated flags such as `--no-color` are not supported.
EOF

cat > node_modules/tiny-flags/CHANGELOG.md <<'EOF'
# Changelog

## 2.3.0
- Values after `=` keep any further `=` signs.

## 2.2.0
- Negated flags (`--no-<name>`) set the flag to `false`.

## 2.0.0
- First release of the 2.x line.
EOF

cat > node_modules/tiny-flags/index.js <<'EOF'
'use strict';
// Parses command-line flags into an object.
module.exports = function parse(argv) {
  const out = {};
  for (const arg of argv) {
    if (!arg.startsWith('--')) continue;
    const body = arg.slice(2);
    const eq = body.indexOf('=');
    if (eq !== -1) out[body.slice(0, eq)] = body.slice(eq + 1);
    else if (body.startsWith('no-')) out[body.slice(3)] = false;
    else out[body] = true;
  }
  return out;
};
EOF
