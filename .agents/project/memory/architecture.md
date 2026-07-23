# Architecture

<!-- How the system is put together. The updater NEVER touches this file. -->

## Overview
No runtime architecture — this is a file-generation and file-sync system, not a
running service. The "system" is: author framework content once in `framework/`,
distribute it to target repos as files (`install.sh`/`update.sh`), and let any
agentic CLI operate on those files following the protocol in `AGENTS.md`. State lives
entirely in versioned Markdown, not in a process or database.

## Components
- **Framework payload** (`framework/`): protocol doc (`AGENTS.md`), per-role agent
  briefs (`.agents/agents/*.md`), templates (`.agents/templates/*.md`), shell tooling
  (`.agents/scripts/agent-task-*`, `agent-git-guard`, `agent-models-sync`), shared
  skills (`.agents/skills/`).
- **Installer** (`install.sh`): one-shot setup in a target repo — copies the
  framework, seeds `.agents/project/` from `project-template/` if absent, runs
  detectors, generates CLI-specific adapters and slash commands, wires the
  `agent-git-guard` hook into `.claude/settings.json`.
- **Updater** (`update.sh`): refreshes framework files in a target repo in place,
  respecting the directory boundary (never touches `.agents/project/`,
  `.agents/tasks/`, `.agents/current-task`).
- **Detectors** (`detectors/*.sh`): stack-specific scripts (kotlin/go/node) that
  pre-fill `project.md`/`memory/` drafts with TODO markers for a human/agent to
  verify. No detector exists for shell/Markdown repos.
- **Project layer** (`.agents/project/` in an installed repo): everything specific to
  that repo — `project.md`, `config.yml`, `memory/*.md`. Owned by the repo, never
  touched by the updater.
- **Generated adapters** (`.claude/agents|commands/`, `.opencode/agent|command/`):
  per-CLI subagent definitions and slash commands, produced by
  `agent-models-sync` from `.agents/agents/*.md` + `config.yml`; not source.

## Data flow
A task's lifecycle: `intake` creates `.agents/tasks/<id>/{task.md,progress.md}`
(gitignored, local) → each subsequent phase agent reads `progress.md` (state + Next)
and the `task.md` sections it needs, does its work, writes into its `task.md` section
(or durable doc in `docs/specs|plans/`), updates `progress.md` → repeats until a
terminal status (`DONE`, `NEEDS_HUMAN`) or a gate (`AWAITING_COMMIT`) is hit. At
close, the terminal agent distills `task.md` into `docs/tasks/YYYY-MM-DD-<name>.md`
plus an `INDEX.md` line. No component calls another at runtime; hand-off is entirely
through files a human or the next CLI session reads.

## External dependencies
None at runtime. Build-time/distribution dependency: GitHub Releases (semver tags)
as the distribution channel for the framework tarball; `gh` CLI or
`git clone --depth 1` as the fetch mechanism in `install.sh`. `jq` is used by the
installer to merge `.claude/settings.json` without clobbering existing content.

## Diagrams / references
None yet. `docs/` holds supporting documentation; feature specs for installed repos
land under `docs/specs/`.
