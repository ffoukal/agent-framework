#!/usr/bin/env bash
# update.sh — update the installed framework in a destination repo.
# Replaces framework-owned files only. NEVER touches project/, tasks/, current-task.
set -eu

REPO="${AGENT_FRAMEWORK_REPO:-your-org/agent-framework}"

usage() {
  cat <<'EOF'
Usage: update.sh [DEST_REPO]

Updates the framework in DEST_REPO (default: current dir):
  - Replaces AGENTS.md, .agents/README.md, agents/, templates/, scripts/, VERSION.
  - Does NOT touch .agents/project/, .agents/tasks/, .agents/current-task.
  - Shows a git diff and leaves changes uncommitted for the human to commit.

Framework source is resolved like install.sh (local checkout or GitHub release).
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

DEST=$(cd "${1:-.}" && pwd)
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

if [ ! -d "$DEST/.agents" ]; then
  echo "error: $DEST/.agents not found — run install.sh first" >&2
  exit 1
fi

# --- resolve framework source ---------------------------------------------
SRC=""
CLEANUP_SRC=""
if [ -d "$SCRIPT_DIR/framework" ] && [ -d "$SCRIPT_DIR/project-template" ]; then
  SRC="$SCRIPT_DIR"
else
  TMP=$(mktemp -d)
  CLEANUP_SRC="$TMP"
  echo "Downloading framework from $REPO ..."
  if command -v gh >/dev/null 2>&1; then
    ( cd "$TMP" && gh release download --repo "$REPO" --archive tar.gz )
    tar -xzf "$TMP"/*.tar.gz -C "$TMP"
  else
    git clone --depth 1 "https://github.com/$REPO.git" "$TMP/checkout"
  fi
  SRC=$(find "$TMP" -maxdepth 2 -type d -name framework 2>/dev/null | head -1 | xargs dirname)
  if [ -z "$SRC" ] || [ ! -d "$SRC/framework" ]; then
    echo "error: could not locate framework/ in downloaded archive" >&2
    exit 1
  fi
fi
cleanup() { [ -n "$CLEANUP_SRC" ] && rm -rf "$CLEANUP_SRC"; }
trap cleanup EXIT

# --- 1. version comparison -------------------------------------------------
LOCAL_V=$(cat "$DEST/.agents/VERSION" 2>/dev/null || echo "unknown")
NEW_V=$(cat "$SRC/framework/.agents/VERSION")
echo "Local version:  $LOCAL_V"
echo "Framework:      $NEW_V"
if [ "$LOCAL_V" = "$NEW_V" ]; then
  echo "Already up to date (re-applying framework files anyway)."
fi

# --- 2. replace framework-owned files --------------------------------------
# AGENTS.md is always replaced (framework-owned — nothing repo-specific lives there).
cp "$SRC/framework/AGENTS.md" "$DEST/AGENTS.md"
cp "$SRC/framework/.agents/README.md" "$DEST/.agents/README.md"
cp "$SRC/framework/.agents/VERSION" "$DEST/.agents/VERSION"
for d in agents templates scripts; do
  rm -rf "$DEST/.agents/$d"
  cp -R "$SRC/framework/.agents/$d" "$DEST/.agents/$d"
done
chmod +x "$DEST/.agents/scripts/"* 2>/dev/null || true

# .agents/skills/ is SHARED territory: replace/remove only framework-managed skills
# (SKILL.md with the agent-framework:managed marker); never touch unmarked repo skills.
src_skills="$SRC/framework/.agents/skills"
dest_skills="$DEST/.agents/skills"
if [ -d "$src_skills" ]; then
  mkdir -p "$dest_skills"
  for d in "$src_skills"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    existing="$dest_skills/$name"
    if [ -d "$existing" ] && [ -f "$existing/SKILL.md" ] \
       && ! grep -q 'agent-framework:managed' "$existing/SKILL.md"; then
      echo "WARN: skill '$name' exists unmanaged — framework skill not applied."
      continue
    fi
    rm -rf "$existing"
    cp -R "$d" "$existing"
  done
  for d in "$dest_skills"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [ -f "$d/SKILL.md" ] || continue
    if grep -q 'agent-framework:managed' "$d/SKILL.md" && [ ! -d "$src_skills/$name" ]; then
      rm -rf "$d"
    fi
  done
fi

# Ensure the Claude Code skills symlink still points at the shared skills dir.
CLAUDE_SKILLS="$DEST/.claude/skills"
if [ ! -e "$CLAUDE_SKILLS" ] && [ ! -L "$CLAUDE_SKILLS" ]; then
  mkdir -p "$DEST/.claude"
  ln -s ../.agents/skills "$CLAUDE_SKILLS"
  echo "Re-linked .claude/skills -> ../.agents/skills"
fi

# CLAUDE.md is repo-owned: do NOT replace it. Only ensure the @AGENTS.md import.
if [ ! -f "$DEST/CLAUDE.md" ]; then
  printf '@AGENTS.md\n' > "$DEST/CLAUDE.md"
  echo "CLAUDE.md was missing — created it (@AGENTS.md)."
elif ! grep -q '@AGENTS.md' "$DEST/CLAUDE.md"; then
  TMP=$(mktemp)
  { printf '@AGENTS.md\n\n'; cat "$DEST/CLAUDE.md"; } > "$TMP" && mv "$TMP" "$DEST/CLAUDE.md"
  echo "Re-added missing @AGENTS.md import to CLAUDE.md (existing content preserved)."
fi

echo "Updated framework files (incl. managed skills). NOT touched: project/, tasks/, current-task, unmarked skills."

# --- 2.1 .claude/settings.json: ensure git-rule enforcement (same as install) ---
SETTINGS="$DEST/.claude/settings.json"
mkdir -p "$DEST/.claude"
# JSON-escaped quotes: Claude Code expands $CLAUDE_PROJECT_DIR when running the hook.
GUARD_CMD='\"$CLAUDE_PROJECT_DIR\"/.agents/scripts/agent-git-guard'
FULL_SETTINGS=$(cat <<EOF
{
  "includeCoAuthoredBy": false,
  "permissions": {
    "deny": [
      "Bash(git push)",
      "Bash(git push:*)",
      "Bash(git rebase)",
      "Bash(git rebase:*)",
      "Bash(git reset --hard:*)",
      "Bash(git commit --amend:*)",
      "Bash(git filter-branch:*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "$GUARD_CMD" }]
      }
    ]
  }
}
EOF
)
if [ ! -f "$SETTINGS" ]; then
  printf '%s\n' "$FULL_SETTINGS" > "$SETTINGS"
  echo "Created .claude/settings.json (co-authorship off, git deny rules, git-guard hook)."
elif command -v jq >/dev/null 2>&1; then
  TMP=$(mktemp)
  if printf '%s\n' "$FULL_SETTINGS" | jq --slurpfile cur "$SETTINGS" '
    .permissions.deny as $deny | .hooks.PreToolUse[0] as $guard
    | $cur[0]
    | .includeCoAuthoredBy = false
    | .permissions.deny = (((.permissions.deny // []) + $deny) | unique)
    | .hooks.PreToolUse = (
        (.hooks.PreToolUse // []) as $pre
        | if ([$pre[] | .hooks[]?.command // ""] | any(test("agent-git-guard")))
          then $pre else $pre + [$guard] end
      )' > "$TMP"; then
    mv "$TMP" "$SETTINGS"
    echo "Ensured git deny rules + git-guard hook in .claude/settings.json."
  else
    rm -f "$TMP"
    echo "WARN: jq merge of $SETTINGS failed — merge the git deny rules and the"
    echo "      agent-git-guard PreToolUse hook manually (see framework README)."
  fi
else
  echo "WARN: jq not found; merge the git deny rules and the agent-git-guard PreToolUse"
  echo "      hook into $SETTINGS manually (see framework README)."
fi

# --- 2.2 gitignore .agents/tasks + seed docs/tasks/INDEX.md (same as install) ---
GITIGNORE="$DEST/.gitignore"
if [ ! -f "$GITIGNORE" ] || ! grep -qE '^\.agents/tasks/?$' "$GITIGNORE"; then
  { [ -f "$GITIGNORE" ] && [ -s "$GITIGNORE" ] && [ -n "$(tail -c 1 "$GITIGNORE")" ] && echo ""; \
    echo ".agents/tasks/"; } >> "$GITIGNORE"
  echo "Added .agents/tasks/ to .gitignore (local working state)."
  if git -C "$DEST" ls-files --error-unmatch .agents/tasks >/dev/null 2>&1; then
    echo "NOTE: .agents/tasks/ has tracked files from before this version. To untrack them:"
    echo "  git rm -r --cached .agents/tasks"
  fi
fi
if [ ! -f "$DEST/docs/tasks/INDEX.md" ]; then
  mkdir -p "$DEST/docs/tasks"
  cat > "$DEST/docs/tasks/INDEX.md" <<'EOF'
# Task index

<!-- One line per closed task, appended by the terminal agent at close. Format:
     - YYYY-MM-DD TASK-ID type [tag, tag] touched/paths — one-line summary
     The intake reads THIS file (never the whole resumes) to recall related work. -->
EOF
  echo "Seeded docs/tasks/INDEX.md."
fi

# --- 3. regenerate native subagent adapters from updated agents + config ----
echo ""
"$DEST/.agents/scripts/agent-models-sync"

# --- 4. show diff, let human commit ----------------------------------------
if git -C "$DEST" rev-parse --git-dir >/dev/null 2>&1; then
  echo ""
  echo "=== git diff (review before committing) ==="
  git -C "$DEST" --no-pager diff -- AGENTS.md CLAUDE.md .agents .claude .opencode || true
  git -C "$DEST" status --short || true
fi

echo ""
echo "Update complete. Review the diff and commit yourself."
