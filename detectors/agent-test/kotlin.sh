#!/usr/bin/env bash
# agent-test implementation — Kotlin/JVM (Gradle + JUnit XML). Repo-owned: installed
# to .agents/project/agent-test.sh by install.sh when the kotlin detector matches;
# adapt the TODO-marked bits to this repo. The updater never touches this file.
#
# Contract (see .agents/scripts/agent-test):
#   all           full suite; compact summary only (counts + failing test ids)
#   one <pattern> targeted run (Gradle --tests pattern); same compact output
#   show <test>   failure message + trimmed stack for one test (from JUnit XML)
#
# Full Gradle output goes to $LOG, never to stdout — only the summary enters the
# agent's context.
set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)   # .agents/project -> repo root
cd "$ROOT"

LOG_DIR=".agents/test-logs"                 # inside .agents/, gitignored territory
LOG="$LOG_DIR/last-run.log"
MARKER="$LOG_DIR/.run-marker"
mkdir -p "$LOG_DIR"

GRADLE="./gradlew"                           # TODO verify (gradle wrapper? modules?)
TEST_TASK="test"                             # TODO verify (or a module task like :app:test)
RESULTS_GLOB="*/test-results"                # searched under build/ dirs, see results_files
STACK_LINES=30                               # lines of failure detail printed by `show`

usage() { echo "Usage: agent-test all | one <class-or-pattern> | show <Class[.method]>"; }

# JUnit XML files written by the run that just happened (newer than MARKER);
# falls back to all result files (e.g. Gradle said UP-TO-DATE and wrote nothing).
results_files() {
  files=$(find . -path '*/build/test-results/*' -name '*.xml' -newer "$MARKER" 2>/dev/null)
  if [ -z "$files" ]; then
    STALE=1
    files=$(find . -path '*/build/test-results/*' -name '*.xml' 2>/dev/null)
  fi
  printf '%s\n' "$files"
}

summarize() {
  files=$(results_files)
  if [ -z "$files" ]; then
    echo "no JUnit XML results found under build/test-results — check $LOG"
    return
  fi
  # shellcheck disable=SC2086
  totals=$(cat $files | awk '
    /<testsuite /  { for (i=1;i<=NF;i++) { if ($i ~ /^tests=/)    { gsub(/[^0-9]/,"",$i); t+=$i }
                                           if ($i ~ /^failures=/) { gsub(/[^0-9]/,"",$i); f+=$i }
                                           if ($i ~ /^errors=/)   { gsub(/[^0-9]/,"",$i); e+=$i }
                                           if ($i ~ /^skipped=/)  { gsub(/[^0-9]/,"",$i); s+=$i } } }
    END { printf "%d run, %d passed, %d failed, %d skipped", t, t-f-e-s, f+e, s }')
  echo "$totals${STALE:+  (stale: no tests re-executed this run — results are from a previous run)}"
  # shellcheck disable=SC2086
  grep -l -E '<(failure|error)[ >]' $files 2>/dev/null | while read -r xml; do
    awk '
      /<testcase / { cn=""; nm=""
        for (i=1;i<=NF;i++) { if ($i ~ /^classname=/) cn=$i; if ($i ~ /^name=/) nm=$i }
        gsub(/classname=|name=|"/ ,"",cn); gsub(/classname=|name=|"/ ,"",nm); open=1 }
      open && /<(failure|error)[ >]/ { print "  FAIL " cn "." nm; open=0 }
      /<\/testcase>/ { open=0 }
    ' "$xml"
  done
  echo "(details: agent-test show <Class.method> · full log: $LOG)"
}

run_gradle() {
  touch "$MARKER"
  STALE=""
  set +e
  "$GRADLE" "$@" --console=plain > "$LOG" 2>&1
  status=$?
  set -e
  if [ "$status" -ne 0 ] && ! grep -q "There were failing tests\|tests failed\|> Task .*test.* FAILED" "$LOG"; then
    echo "BUILD FAILED before tests ran — last lines of $LOG:"
    tail -20 "$LOG"
    exit "$status"
  fi
  summarize
}

cmd="${1:-}"
case "$cmd" in
  all)
    run_gradle $TEST_TASK ;;
  one)
    [ -n "${2:-}" ] || { usage >&2; exit 2; }
    run_gradle $TEST_TASK --tests "$2" ;;
  show)
    [ -n "${2:-}" ] || { usage >&2; exit 2; }
    klass="${2%%.*}"
    method="${2#*.}"; [ "$method" = "$2" ] && method=""
    xml=$(find . -path '*/build/test-results/*' -name "*${klass}*.xml" 2>/dev/null | head -1)
    [ -n "$xml" ] || { echo "no results XML found for '$klass' — run agent-test all/one first" >&2; exit 1; }
    awk -v m="$method" -v max="$STACK_LINES" '
      /<testcase / { nm=""; for (i=1;i<=NF;i++) if ($i ~ /^name=/) nm=$i
        gsub(/name=|"/,"",nm); intc = (m=="" || nm==m) }
      intc && /<(failure|error)[ >]/ { infail=1 }
      infail { n++; if (n<=max) print; }
      infail && /<\/(failure|error)>/ { if (n>max) print "  ... (" n-max " more lines in XML)"; exit }
    ' "$xml" \
      | sed -e 's/&quot;/"/g' -e 's/&apos;/'"'"'/g' -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&amp;/\&/g'
    ;;
  -h|--help|"") usage ;;
  *) usage >&2; exit 2 ;;
esac
