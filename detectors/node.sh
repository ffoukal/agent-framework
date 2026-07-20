#!/usr/bin/env bash
# detector: Node / TypeScript (package.json).
# Usage: node.sh <repo_root>
# Exit 0 and print draft sections if detected; exit 1 (no output) otherwise.
set -eu

ROOT="${1:-.}"

if [ ! -f "$ROOT/package.json" ]; then
  exit 1
fi

# package manager
PM="npm"
[ -f "$ROOT/pnpm-lock.yaml" ] && PM="pnpm"
[ -f "$ROOT/yarn.lock" ] && PM="yarn"

# scripts (best-effort, no jq dependency): pull test/build/lint if present
get_script() {
  grep -Eo "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$ROOT/package.json" 2>/dev/null \
    | head -1 | sed -E "s/\"$1\"[[:space:]]*:[[:space:]]*\"//" | sed 's/"$//'
}
TEST_S=$(get_script test)
BUILD_S=$(get_script build)
LINT_S=$(get_script lint)

TS=""
[ -f "$ROOT/tsconfig.json" ] && TS="yes"

# workspaces (best-effort)
WS=""
if grep -q '"workspaces"' "$ROOT/package.json" 2>/dev/null; then
  WS="yes"
fi

echo "@@SECTION:PROJECT@@"
echo "- Stack draft: Node ($PM)$([ -n "$TS" ] && echo ' + TypeScript').  <!-- TODO verify -->"
[ -n "$BUILD_S" ] && echo "- Build draft: \`$PM run build\`  (\"$BUILD_S\")  <!-- TODO verify -->"
[ -n "$LINT_S" ] && echo "- Lint draft: \`$PM run lint\`  (\"$LINT_S\")  <!-- TODO verify -->"
[ -n "$TEST_S" ] && echo "- Test draft: \`$PM test\`  (\"$TEST_S\")  <!-- TODO verify -->"

echo "@@SECTION:TESTING@@"
if [ -n "$TEST_S" ]; then
  echo "- Draft: run tests with \`$PM test\`  (\"$TEST_S\")  <!-- TODO verify -->"
else
  echo "- TODO: no \"test\" script found in package.json."
fi

echo "@@SECTION:CODEMAP@@"
[ -n "$TS" ] && echo "- TypeScript project (tsconfig.json present)."
if [ -n "$WS" ]; then
  echo "- Workspaces present in package.json — TODO: map each workspace as a module."
else
  echo "- TODO: single package or workspaces not detected."
fi
