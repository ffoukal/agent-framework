#!/usr/bin/env bash
# detector: Go (go.mod).
# Usage: go.sh <repo_root>
# Exit 0 and print draft sections if detected; exit 1 (no output) otherwise.
set -eu

ROOT="${1:-.}"

if [ ! -f "$ROOT/go.mod" ]; then
  exit 1
fi

MODULE=$(grep -E '^module ' "$ROOT/go.mod" 2>/dev/null | head -1 | awk '{print $2}')

# cmd/ entry points
CMDS=""
if [ -d "$ROOT/cmd" ]; then
  CMDS=$(find "$ROOT/cmd" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed "s|$ROOT/||" || true)
fi

echo "@@SECTION:PROJECT@@"
echo "- Stack draft: Go. Module: \`${MODULE:-TODO}\`  <!-- TODO verify -->"
echo "- Build draft: \`go build ./...\`  <!-- TODO verify -->"
echo "- Test draft: \`go test ./...\`  <!-- TODO verify -->"

echo "@@SECTION:TESTING@@"
echo "- Draft: run tests with \`go test ./...\`  <!-- TODO verify -->"

echo "@@SECTION:CODEMAP@@"
echo "- Module: \`${MODULE:-TODO}\`"
if [ -n "$CMDS" ]; then
  echo "- Entry points under cmd/ — TODO verify:"
  printf '%s\n' "$CMDS" | sed 's/^/  - /'
else
  echo "- TODO: no cmd/ entry points detected; confirm where main() lives."
fi
