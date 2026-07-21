# Implementation log

## Changes
- Rewrote `.agents/project/project.md`: what this is, stack (POSIX shell +
  Markdown), navigation map (framework/, project-template/, detectors/, install.sh,
  update.sh, docs/, dogfooded .agents/, generated adapters), build/test (bash -n,
  `./install.sh .` dogfood, `agent-task-check`), project-specific rules
  (`framework/` is source of truth, sync via `./install.sh .`, never hand-edit
  generated adapters), CI & branching (base: main, merge strategy: TBD by team),
  gotchas (dual-copy drift risk, generated files with no visual marker).
- Filled `.agents/project/memory/architecture.md`, `code-map.md`, `conventions.md`,
  `testing.md`, `domain.md` with short, factual, repo-specific content (no runtime
  architecture — this is a file-generation/sync system; module map; conventions
  around Conventional Commits + no AI co-author trailers + human-gated commits;
  bash -n / dogfood-run verification; glossary of framework-specific terms).
- Seeded `.agents/project/memory/decisions.md` with the three decisions listed in
  `task.md`: git-rule enforcement via the `agent-git-guard` hook, step mode
  (`/task-step`), and the orchestrator's default tier moving to `fast/low`. Sourced
  from the `Unreleased` section of `CHANGELOG.md`.

## Decisions
None beyond what task.md already specified — this is a mechanical documentation
chore, content sourced directly from README.md, CHANGELOG.md, AGENTS.md, the repo's
directory layout, and a `diff -rq` comparison confirming `framework/.agents/*` and
the dogfooded `.agents/*` are currently identical.

## Test results
- `bash -n install.sh`, `bash -n update.sh`, `bash -n detectors/*.sh`,
  `bash -n .agents/scripts/*` — all pass (syntax OK), confirming no shell script was
  broken by this doc-only change (none were touched, but this is the mandated
  verification per task instructions).
- `./install.sh .` (dogfood run) — completed successfully; output confirmed
  `.agents/project/ already exists — left untouched.` `git status --porcelain=v1
  -uall` before and after the run showed identical results (only the
  `.agents/project/` edits from this task plus the untracked TASK-001 files) —
  confirming the install is idempotent and this task made no changes outside
  `.agents/project/`, matching the out-of-scope constraint.
- `diff -rq .agents/agents framework/.agents/agents`,
  `diff -rq .agents/scripts framework/.agents/scripts`,
  `diff -rq .agents/templates framework/.agents/templates` — no output (identical),
  confirming the dual-copy claim made in the Gotchas section of `project.md`.
