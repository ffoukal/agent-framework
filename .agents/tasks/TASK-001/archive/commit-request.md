---
task: TASK-001
requested: 2026-07-20T02:50:00Z
resolved: null            # the next agent completes this when it detects the commit
---

# Commit request

## Proposed message
```
docs(project): fill in .agents/project/ for this repo

install.sh left project.md and memory/ as template TODOs since no detector
matches this repo's shell + Markdown stack. Replace them with accurate,
repo-specific content so future agent sessions get real context in startup
step 0, and seed memory/decisions.md with the 3 decisions already taken.
```

## Files to include
- `.agents/project/project.md`
- `.agents/project/memory/architecture.md`
- `.agents/project/memory/code-map.md`
- `.agents/project/memory/conventions.md`
- `.agents/project/memory/decisions.md`
- `.agents/project/memory/domain.md`
- `.agents/project/memory/testing.md`
- `.agents/tasks/TASK-001/*` (task.md, state.md, next.md, run-log.md,
  implementation-log.md — task bookkeeping)
- `.agents/current-task`

## Rationale
`install.sh` seeded `.agents/project/` from the blank template because no detector
matched this repo's stack (POSIX shell + Markdown), leaving every file as
unreplaced TODOs. Agents read `project.md` at the start of every session (startup
step 0), so leaving it empty costs context quality on every future task. This chore
is also the installer's own "suggested first task", used here to exercise the
end-to-end human-gated pipeline for the first time in this repo.

## Suggested commands
```
git add .agents/project/project.md .agents/project/memory/*.md \
  .agents/tasks/TASK-001 .agents/current-task
git commit -F - <<'EOF'
docs(project): fill in .agents/project/ for this repo

install.sh left project.md and memory/ as template TODOs since no detector
matches this repo's shell + Markdown stack. Replace them with accurate,
repo-specific content so future agent sessions get real context in startup
step 0, and seed memory/decisions.md with the 3 decisions already taken.
EOF
```
