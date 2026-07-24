#!/usr/bin/env bash
# install.sh — install the persistent agent framework into a destination repo.
# Run from the destination repo (or pass its path). Leaves changes uncommitted.
set -eu

REPO="${AGENT_FRAMEWORK_REPO:-your-org/agent-framework}"

usage() {
  cat <<'EOF'
Usage: install.sh [DEST_REPO]

Installs the persistent agent framework into DEST_REPO (default: current dir).
Framework source resolution:
  - If run from an agent-framework checkout (framework/ + project-template/ next to
    this script), that local copy is used (dev / dogfood mode).
  - Otherwise the framework is downloaded from the latest GitHub release of
    $AGENT_FRAMEWORK_REPO (default your-org/agent-framework) via `gh`, falling back to
    `git clone --depth 1`.

Never overwrites: .agents/project/, .agents/tasks/, .agents/current-task, and a
CLAUDE.md that already has its own content.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

DEST=$(cd "${1:-.}" && pwd)
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# --- resolve framework source ---------------------------------------------
SRC=""
CLEANUP_SRC=""
if [ -d "$SCRIPT_DIR/framework" ] && [ -d "$SCRIPT_DIR/project-template" ]; then
  SRC="$SCRIPT_DIR"
  echo "Using local framework source: $SRC"
else
  TMP=$(mktemp -d)
  CLEANUP_SRC="$TMP"
  echo "Downloading framework from $REPO ..."
  if command -v gh >/dev/null 2>&1; then
    ( cd "$TMP" && gh release download --repo "$REPO" --archive tar.gz )
    tar -xzf "$TMP"/*.tar.gz -C "$TMP"
  else
    echo "gh not found; falling back to git clone --depth 1"
    git clone --depth 1 "https://github.com/$REPO.git" "$TMP/checkout"
  fi
  SRC=$(find "$TMP" -maxdepth 2 -type d -name framework 2>/dev/null | head -1 | xargs dirname)
  if [ -z "$SRC" ] || [ ! -d "$SRC/framework" ]; then
    echo "error: could not locate framework/ in downloaded archive" >&2
    exit 1
  fi
fi

cleanup() { if [ -n "$CLEANUP_SRC" ]; then rm -rf "$CLEANUP_SRC"; fi; }
trap cleanup EXIT

echo "Installing into: $DEST"

# --- 2.1 migrate preexisting AGENTS.md / CLAUDE.md content -----------------
# Capture BEFORE step 1 overwrites AGENTS.md. AGENTS.md is framework-owned and fully
# replaced (update.sh replaces it too), so nothing repo-specific may live there.
LEGACY_TMP=$(mktemp)
MIGRATED=0
# Migration is a one-time onboarding step: only on a fresh install (no .agents/project/
# yet). On a re-install over an existing install, skip it so we never re-copy content.
if [ ! -d "$DEST/.agents/project" ]; then
  if [ -f "$DEST/AGENTS.md" ] && ! grep -q 'agent-framework:managed' "$DEST/AGENTS.md"; then
    {
      echo "## Migrated from a preexisting AGENTS.md ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
      echo ""
      cat "$DEST/AGENTS.md"
      echo ""
    } >> "$LEGACY_TMP"
    MIGRATED=1
    echo "Migrating existing AGENTS.md content -> project/legacy-agents-instructions.md."
  fi
  if [ -f "$DEST/CLAUDE.md" ]; then
    EXTRA=$(grep -vE '^[[:space:]]*@AGENTS\.md[[:space:]]*$' "$DEST/CLAUDE.md" \
      | grep -vE '^[[:space:]]*$' || true)
    if [ -n "$EXTRA" ]; then
      {
        echo "## Migrated from a preexisting CLAUDE.md ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
        echo ""
        cat "$DEST/CLAUDE.md"
        echo ""
      } >> "$LEGACY_TMP"
      MIGRATED=1
      echo "Migrating existing CLAUDE.md content -> project/legacy-agents-instructions.md."
    fi
  fi
fi

# Sync framework-managed skills into the SHARED .agents/skills/ territory:
# overwrite/add managed skills, delete managed skills gone upstream, never touch
# unmarked (repo-owned) skills.
sync_managed_skills() {
  src_skills="$SRC/framework/.agents/skills"
  dest_skills="$DEST/.agents/skills"
  [ -d "$src_skills" ] || return 0
  mkdir -p "$dest_skills"
  for d in "$src_skills"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    existing="$dest_skills/$name"
    if [ -d "$existing" ] && [ -f "$existing/SKILL.md" ] \
       && ! grep -q 'agent-framework:managed' "$existing/SKILL.md"; then
      echo "WARN: skill '$name' exists unmanaged — framework skill not applied (rename to resolve)."
      continue
    fi
    rm -rf "$existing"
    cp -R "$d" "$existing"
  done
  # remove managed skills that no longer exist upstream
  for d in "$dest_skills"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [ -f "$d/SKILL.md" ] || continue
    if grep -q 'agent-framework:managed' "$d/SKILL.md" && [ ! -d "$src_skills/$name" ]; then
      rm -rf "$d"
    fi
  done
}

# --- 1. copy framework (overwrite framework-owned paths) -------------------
mkdir -p "$DEST/.agents"
cp "$SRC/framework/AGENTS.md" "$DEST/AGENTS.md"
cp "$SRC/framework/.agents/VERSION" "$DEST/.agents/VERSION"
cp "$SRC/framework/.agents/README.md" "$DEST/.agents/README.md"
for d in agents templates scripts; do
  rm -rf "$DEST/.agents/$d"
  cp -R "$SRC/framework/.agents/$d" "$DEST/.agents/$d"
done
chmod +x "$DEST/.agents/scripts/"* 2>/dev/null || true
sync_managed_skills

# --- 2. project-template -> .agents/project (only if absent) ---------------
NEW_PROJECT=0
if [ ! -d "$DEST/.agents/project" ]; then
  cp -R "$SRC/project-template" "$DEST/.agents/project"
  NEW_PROJECT=1
  echo "Created .agents/project/ from template."
else
  echo ".agents/project/ already exists — left untouched."
fi

# --- 6. config.yml (only if absent) ----------------------------------------
if [ ! -f "$DEST/.agents/project/config.yml" ]; then
  cp "$SRC/project-template/config.yml" "$DEST/.agents/project/config.yml"
  echo "Created .agents/project/config.yml from template."
fi

# --- 2.1 (cont.) persist migrated legacy content now that project/ exists --
if [ "$MIGRATED" -eq 1 ]; then
  cat "$LEGACY_TMP" >> "$DEST/.agents/project/legacy-agents-instructions.md"
fi
rm -f "$LEGACY_TMP"

# --- 4. VERSION (already copied in step 1) ---------------------------------
echo "Framework version: $(cat "$DEST/.agents/VERSION")"

# --- 3. detectors: pre-fill drafts (only on a fresh project/) --------------
append_marked() {
  file_in="$1"; name="$2"; dest_file="$3"
  extracted=$(awk -v want="@@SECTION:$name@@" '
    /^@@SECTION:/ { cur=$0; next }
    { if (cur==want) print }
  ' "$file_in")
  [ -n "$extracted" ] || return 0
  {
    echo ""
    echo "## Detector drafts (review and resolve these TODOs)"
    printf '%s\n' "$extracted"
  } >> "$dest_file"
}

if [ "$NEW_PROJECT" -eq 1 ]; then
  DTMP=$(mktemp)
  for name in kotlin go node; do
    det="$SRC/detectors/$name.sh"
    [ -f "$det" ] || continue
    if out=$(sh "$det" "$DEST" 2>/dev/null) && [ -n "$out" ]; then
      printf '%s\n' "$out" >> "$DTMP"
      echo "  detector matched: $name"
    fi
  done
  if [ -s "$DTMP" ]; then
    append_marked "$DTMP" PROJECT "$DEST/.agents/project/project.md"
    append_marked "$DTMP" TESTING "$DEST/.agents/project/memory/testing.md"
    append_marked "$DTMP" CODEMAP "$DEST/.agents/project/memory/code-map.md"
  else
    echo "  no detector matched (unknown stack) — fill project.md manually."
  fi
  rm -f "$DTMP"
fi

# --- 5. CLAUDE.md ----------------------------------------------------------
# CLAUDE.md is repo-owned; keep any Claude-specific content, just ensure the import.
if [ ! -f "$DEST/CLAUDE.md" ]; then
  printf '@AGENTS.md\n' > "$DEST/CLAUDE.md"
  echo "Created CLAUDE.md (@AGENTS.md)."
elif ! grep -q '@AGENTS.md' "$DEST/CLAUDE.md"; then
  TMP=$(mktemp)
  { printf '@AGENTS.md\n\n'; cat "$DEST/CLAUDE.md"; } > "$TMP" && mv "$TMP" "$DEST/CLAUDE.md"
  echo "Prepended @AGENTS.md to existing CLAUDE.md (content preserved below; a copy was"
  echo "  migrated to project/legacy-agents-instructions.md for redistribution)."
fi

# --- 7. .claude/settings.json: co-authorship off + git-rule enforcement ----
# Mechanical enforcement of the AGENTS.md git rules on Claude Code:
#   - permissions.deny blocks push/rebase/hard-reset/amend/filter-branch outright;
#   - a PreToolUse hook (.agents/scripts/agent-git-guard) catches compound commands
#     and blocks `git commit` when commits.mode is human-gated.
#   - env CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=2 enables nested orchestration
#     (main session -> orchestrator -> phase agents) and caps it at that depth.
#     Requires Claude Code >= 2.1.217 (between 2.1.172 and 2.1.216 nesting was on
#     by default; earlier versions fall back to in-session coordination).
# On other CLIs the same rules stay prose-enforced (AGENTS.md).
SETTINGS="$DEST/.claude/settings.json"
mkdir -p "$DEST/.claude"
# JSON-escaped quotes: Claude Code expands $CLAUDE_PROJECT_DIR when running the hook.
GUARD_CMD='\"$CLAUDE_PROJECT_DIR\"/.agents/scripts/agent-git-guard'
FULL_SETTINGS=$(cat <<EOF
{
  "includeCoAuthoredBy": false,
  "env": {
    "CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH": "2"
  },
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
    | .env.CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH = "2"
    | .permissions.deny = (((.permissions.deny // []) + $deny) | unique)
    | .hooks.PreToolUse = (
        (.hooks.PreToolUse // []) as $pre
        | if ([$pre[] | .hooks[]?.command // ""] | any(test("agent-git-guard")))
          then $pre else $pre + [$guard] end
      )' > "$TMP"; then
    mv "$TMP" "$SETTINGS"
    echo "Merged git deny rules + git-guard hook into .claude/settings.json."
  else
    rm -f "$TMP"
    echo "WARN: jq merge of $SETTINGS failed — merge the git deny rules and the"
    echo "      agent-git-guard PreToolUse hook manually (see framework README)."
  fi
else
  echo "WARN: jq not found; merge the git deny rules and the agent-git-guard PreToolUse"
  echo "      hook into $SETTINGS manually (see framework README)."
fi

# --- 7.1 generate native subagent adapters (+ Codex recipe) ----------------
# The installed agent-models-sync script is the single generator; the human re-runs it
# after editing config.yml. It writes .claude/agents/ + .opencode/agent/ and prints the
# Codex per-user profile recipe.
echo ""
"$DEST/.agents/scripts/agent-models-sync"

# --- 7.15 gitignore .agents/tasks + seed docs/tasks/INDEX.md ---------------
# .agents/tasks/ is local working state (a task is started and finished by the same
# dev); the durable outputs live in docs/specs|plans|tasks.
GITIGNORE="$DEST/.gitignore"
if [ ! -f "$GITIGNORE" ] || ! grep -qE '^\.agents/tasks/?$' "$GITIGNORE"; then
  { [ -f "$GITIGNORE" ] && [ -s "$GITIGNORE" ] && [ -n "$(tail -c 1 "$GITIGNORE")" ] && echo ""; \
    echo ".agents/tasks/"; } >> "$GITIGNORE"
  echo "Added .agents/tasks/ to .gitignore (local working state)."
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

# --- 7.2 .claude/skills symlink so Claude Code discovers repo skills --------
# Codex and OpenCode scan .agents/skills/ natively; Claude Code needs this link.
CLAUDE_SKILLS="$DEST/.claude/skills"
mkdir -p "$DEST/.claude"
if [ -L "$CLAUDE_SKILLS" ]; then
  :  # already a symlink — leave it
elif [ -e "$CLAUDE_SKILLS" ]; then
  echo "WARN: $CLAUDE_SKILLS exists and is not a symlink — not overwriting."
  echo "      Move its skills into .agents/skills/ and remove it to let Claude Code see them."
else
  ln -s ../.agents/skills "$CLAUDE_SKILLS"
  echo "Linked .claude/skills -> ../.agents/skills"
fi

# --- 8 & 9. summary --------------------------------------------------------
cat <<EOF

Install complete (nothing committed — review and commit yourself).

Files touched:
  AGENTS.md, CLAUDE.md
  .agents/ (VERSION, README.md, agents/, templates/, scripts/)
  .agents/skills/ (framework-managed skills; repo skills preserved)
  .agents/project/ $([ "$NEW_PROJECT" -eq 1 ] && echo '(new, with detector drafts)' || echo '(preserved)')
  .claude/settings.json, .claude/skills -> ../.agents/skills
  .claude/agents/, .opencode/agent/ (generated subagent adapters for orchestration)
  .gitignore (.agents/tasks/ entry), docs/tasks/INDEX.md (task resume index)
EOF

if [ "$MIGRATED" -eq 1 ]; then
  cat <<EOF

Legacy migration: existing AGENTS.md/CLAUDE.md content was moved to
  .agents/project/legacy-agents-instructions.md
Review it and redistribute: build/test -> memory/testing.md, repo rules ->
project.md (Project-specific rules), conventions -> memory/conventions.md, then delete
the legacy file. Suggested task:
  "Continue as implementer: redistribute the content of
   .agents/project/legacy-agents-instructions.md into the appropriate project/ files,
   then delete it."
EOF
fi

cat <<EOF

Suggested first task (create it via the intake):
  "Start a new task using the persistent agent system."
  Goal: an agent walks the repo and completes/corrects .agents/project/.
EOF
