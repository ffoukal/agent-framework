#!/usr/bin/env bash
# agent-verify implementation — generic reference. Repo-owned: installed to
# .agents/project/agent-verify.sh; the updater never touches it. Fill the TODOs.
#
# Contract (see .agents/scripts/agent-verify): quick | full | e2e | clean
# Rule: tool output goes to $LOG, only the compact summary reaches stdout.
set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)   # .agents/project -> repo root
cd "$ROOT"

LEVEL=${1:-quick}
LOG_DIR=".agents/test-logs"
LOG="$LOG_DIR/verify-$LEVEL.log"
mkdir -p "$LOG_DIR"
: > "$LOG"

FAILED=0
UNCONFIGURED=0

# Exit code a step returns while it is still a TODO. An unconfigured step must NEVER
# read as PASS: a green result that proves nothing is worse than a red one.
NOT_CONFIGURED=77

# run <label> <fn> — runs quietly, prints one PASS/FAIL/TODO line.
run() {
  _label=$1; shift
  printf '\n===== %s =====\n' "$_label" >> "$LOG"
  if "$@" >> "$LOG" 2>&1; then
    printf '  PASS  %s\n' "$_label"
  else
    _rc=$?
    if [ "$_rc" -eq "$NOT_CONFIGURED" ]; then
      printf '  TODO  %s — not configured, proves nothing\n' "$_label"
      UNCONFIGURED=$((UNCONFIGURED + 1))
    else
      printf '  FAIL  %s  → see %s\n' "$_label" "$LOG"
      FAILED=1
    fi
  fi
}

# --- repo commands (TODO: replace each body with the real command) ----------
# Deleting a step you genuinely do not have (e.g. no typecheck in this stack) is fine
# and honest — leaving it as `return $NOT_CONFIGURED` keeps it visible as a gap.
build()     { return $NOT_CONFIGURED; }  # TODO e.g. npm run build    / ./gradlew assemble
lint()      { return $NOT_CONFIGURED; }  # TODO e.g. npm run lint     / ruff check src/
typecheck() { return $NOT_CONFIGURED; }  # TODO e.g. npx tsc --noEmit / mypy src/ --strict
boot()      { return $NOT_CONFIGURED; }  # TODO start the app, wait for ready, hit one
                                         #      real endpoint/flow, then shut down.
                                         #      This IS `e2e` — a mock cannot replace it.

# --- promoted checks: reviewer findings turned into enforcement -------------
promoted() {
  [ -x .agents/project/checks.sh ] || return $NOT_CONFIGURED
  .agents/project/checks.sh
}

# --- clean: handoff gate ---------------------------------------------------
# Debug leftovers in the diff since the task's base commit (not the whole repo).
clean_check() {
  _base=${AGENT_BASE_COMMIT:-}   # exported by the agent-verify dispatcher
  [ -n "$_base" ] || { echo "  SKIP  debug-leftovers (no base_commit)"; return 0; }

  # TODO tune the pattern to this stack's debug idioms.
  _pat='console\.log|debugger;|fdescribe\(|fit\(|it\.only\(|describe\.only\(|binding\.pry|breakpoint\(|dbg!\(|System\.out\.println|printStackTrace\(|TODO-REMOVE|XXX-DEBUG'
  _hits=$(git diff "$_base"..HEAD -U0 2>/dev/null \
          | grep -E '^\+' | grep -vE '^\+\+\+' | grep -nE "$_pat" || true)
  if [ -n "$_hits" ]; then
    _n=$(printf '%s\n' "$_hits" | grep -c .)
    printf '  FAIL  debug-leftovers (%d added line(s) match debug idioms)\n' "$_n"
    printf '%s\n' "$_hits" | head -8 | sed 's/^/          /'
    printf '        WHY: they ship to production and poison the next session'\''s diff.\n'
    printf '        FIX: remove them, or whitelist the pattern in agent-verify.sh.\n'
    FAILED=1
  else
    printf '  PASS  debug-leftovers\n'
  fi
}

echo "agent-verify $LEVEL"
case "$LEVEL" in
  clean)
    clean_check
    run promoted promoted
    run boot boot
    ;;
  quick)
    run build build
    run lint lint
    run typecheck typecheck
    run promoted promoted
    ;;
  full)
    "$0" quick || FAILED=1
    if [ -x .agents/scripts/agent-test ]; then
      echo "  --- tests (agent-test all) ---"
      .agents/scripts/agent-test all || FAILED=1
    else
      echo "  SKIP  tests (no agent-test)"
    fi
    ;;
  e2e)
    "$0" full || FAILED=1
    run boot boot
    ;;
esac

if [ "$FAILED" -ne 0 ]; then
  echo "RESULT: FAIL ($LEVEL) — detail in $LOG"
elif [ "$UNCONFIGURED" -gt 0 ]; then
  echo "RESULT: PARTIAL ($LEVEL) — $UNCONFIGURED step(s) still TODO in agent-verify.sh."
  echo "        Report this level as PARTIAL, never as passing."
else
  echo "RESULT: PASS ($LEVEL)"
fi
exit "$FAILED"
