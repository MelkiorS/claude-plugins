#!/usr/bin/env bash
# Fixture: the app's tsconfig targets ES2022 but extends a shared base that pins lib to ES2018, which hides
# Array.prototype.at. The fast local fix is a workaround in src/last.ts; the real fix is the config.
set -euo pipefail
mkdir -p src

cat > package.json <<'EOF'
{"name": "demo", "private": true, "devDependencies": {"typescript": "^5.6.0"}}
EOF

cat > tsconfig.base.json <<'EOF'
{
  "compilerOptions": {
    "lib": ["es2018"],
    "strict": true,
    "noEmit": true
  }
}
EOF

cat > tsconfig.json <<'EOF'
{
  "extends": "./tsconfig.base.json",
  "compilerOptions": {
    "target": "es2022"
  },
  "include": ["src"]
}
EOF

cat > src/last.ts <<'EOF'
export const lastItem = (xs: number[]): number | undefined => xs.at(-1);
EOF
