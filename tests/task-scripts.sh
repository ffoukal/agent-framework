#!/usr/bin/env bash
# tests/task-scripts.sh — regression tests for the installed task scripts
# (agent-task-new, agent-task-check, agent-plan) against a fresh install.
# Framework-dev only: not installed into consumer repos. Run from the repo root.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST=$(mktemp -d)
trap 'rm -rf "$DEST"' EXIT
FAILS=0

pass() { echo "ok    $1"; }
failt() { echo "FAIL  $1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /' >&2; FAILS=$((FAILS + 1)); }

git -C "$DEST" init -q
git -C "$DEST" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
"$ROOT/install.sh" "$DEST" >/dev/null 2>&1 || { echo "install.sh failed" >&2; exit 1; }
S="$DEST/.agents/scripts"

# 1. A feature task fresh from the template passes agent-task-check.
NEW_OUT=$("$S/agent-task-new" feat "goal" 2>&1)
if OUT=$("$S/agent-task-check" feat 2>&1); then
  pass "fresh feature task passes agent-task-check"
else
  failt "fresh feature task passes agent-task-check" "$OUT"
fi

# 2. agent-task-new points at the task-protocol skill, not AGENTS.md.
if printf '%s' "$NEW_OUT" | grep -q 'task-protocol'; then
  pass "agent-task-new points at the task-protocol skill"
else
  failt "agent-task-new points at the task-protocol skill" "$NEW_OUT"
fi

# 3. A fresh chore/fix task passes too.
for t in chore fix; do
  "$S/agent-task-new" "$t-task" "goal" >/dev/null 2>&1
  sed -i.bak -E "s/^type:[[:space:]]*feature/type: $t/" "$DEST/.agents/tasks/$t-task/progress.md"
  if OUT=$("$S/agent-task-check" "$t-task" 2>&1); then
    pass "fresh $t task passes agent-task-check"
  else
    failt "fresh $t task passes agent-task-check" "$OUT"
  fi
done

# 4. A linked-but-missing plan (with a trailing comment) is reported as a missing
#    plan, not as a feature-list invariant violation.
sed -i.bak -E 's|^plan:.*|plan: docs/plans/nope.md   # feature: docs/plans/...|' \
  "$DEST/.agents/tasks/feat/task.md"
OUT=$("$S/agent-task-check" feat 2>&1) && failt "missing plan file fails agent-task-check" "$OUT"
if printf '%s' "$OUT" | grep -q 'plan file not found' \
   && ! printf '%s' "$OUT" | grep -q 'violate the feature-list invariants'; then
  pass "missing plan file is reported as missing, not as an invariant violation"
else
  failt "missing plan file is reported as missing, not as an invariant violation" "$OUT"
fi

# 5. agent-plan resolves a commented plan: link to the file (not to "path # comment").
mkdir -p "$DEST/docs/plans"
printf '# Plan\n\n## Tasks\n' > "$DEST/docs/plans/nope.md"
OUT=$("$S/agent-plan" status feat 2>&1)
if printf '%s' "$OUT" | grep -q 'plan file not found\|no plan:'; then
  failt "agent-plan resolves a plan: link with a trailing comment" "$OUT"
else
  pass "agent-plan resolves a plan: link with a trailing comment"
fi

[ "$FAILS" -eq 0 ] && echo "All task-script tests passed." || echo "$FAILS test(s) failed." >&2
[ "$FAILS" -eq 0 ]
