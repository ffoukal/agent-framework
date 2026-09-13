# _frontmatter.sh — sourced helper (not a command) shared by the task scripts, so
# every script reads task.md/progress.md frontmatter the same way and they cannot
# diverge again (e.g. one tolerating a trailing "# comment" and another not).
#
#   . "$SCRIPT_DIR/_frontmatter.sh"
#   fm_get FILE KEY     print KEY's value from FILE's frontmatter: trailing "# comment"
#                       stripped, surrounding whitespace and quotes removed; empty if
#                       the key or the frontmatter is missing
#   fm_is_null VALUE    true for '' | null | ~

fm_get() {
  [ -f "$1" ] || return 0
  awk -v key="$2" '
    NR == 1 && $0 !~ /^---[[:space:]]*$/ { exit }
    /^---[[:space:]]*$/ { if (++c == 2) exit; next }
    c == 1 && match($0, "^[[:space:]]*" key ":") {
      v = substr($0, RLENGTH + 1)
      if (v ~ /^[[:space:]]*#/) v = ""; else sub(/[[:space:]]+#.*$/, "", v)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      if (v ~ /^".*"$/ || v ~ /^\047.*\047$/) v = substr(v, 2, length(v) - 2)
      print v
      exit
    }' "$1"
}

fm_is_null() {
  case "${1:-}" in ''|null|~) return 0 ;; *) return 1 ;; esac
}
