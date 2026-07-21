# Code map

<!-- Where things live. The updater NEVER touches this file.
     The detectors pre-fill a module/entry-point draft (marked TODO). Verify it. -->

## Modules
- `framework/` — canonical, distributable framework content (`AGENTS.md`,
  `CLAUDE.md`, `.agents/agents|scripts|templates|skills|README.md|VERSION`).
- `project-template/` — blank `.agents/project/` skeleton seeded into new installs.
- `detectors/` — `kotlin.sh`, `go.sh`, `node.sh`: stack-specific draft generators.
- `.agents/` (this repo's own dogfooded install) — mirrors `framework/.agents/` plus
  this repo's own `project/` and `tasks/`.
- `.claude/`, `.opencode/` — generated per-CLI adapters and slash commands (build
  output, not source).
- `docs/` — supporting documentation.

## Entry points
- `install.sh` — installs the framework into a target repo (or `.` for dogfooding).
- `update.sh` — refreshes framework files in an already-installed target repo.
- `.agents/scripts/agent-task-new` — starts a new task (intake entry point).
- `.agents/scripts/agent-task-status` — status of current task / `--all` overview.
- `.agents/scripts/agent-task-next` / `agent-task-current` — resolve next phase /
  current task id.
- `.agents/scripts/agent-task-check <task-id>` — validates a task's artifacts.
- `.agents/scripts/agent-models-sync` — regenerates CLI adapters from `config.yml`.
- `.agents/scripts/agent-git-guard` — Claude Code `PreToolUse` hook enforcing git
  rules from `AGENTS.md`.

## Key files
- `AGENTS.md` (root and `framework/`) — the entire protocol; read by every agent at
  startup. Changing behavior almost always means editing this file (in `framework/`)
  plus the relevant `.agents/agents/<role>.md`.
- `.agents/agents/<role>.md` — one file per agent role (intake, planner, implementer,
  reviewer, security-reviewer, debugger, explorer, pr-splitter, release-manager,
  specifier, orchestrator); role-specific behavior, points back to `AGENTS.md`.
- `.agents/project/config.yml` — commit mode + per-agent model tier/effort mapping;
  the single source of truth for model routing.
- `.agents/templates/*.md` — canonical templates for every phase artifact
  (task, state, next, run-log, plan, diagnosis, review, commit-request, ...).

## Where to add X
- New agent role → add `.agents/agents/<role>.md` in `framework/.agents/agents/`
  (source), add its tier/effort to `config.yml`'s `models.agents` template in
  `project-template/config.yml`, then run `agent-models-sync` to regenerate adapters.
- New template → `.agents/templates/` in `framework/.agents/templates/`.
- New stack detector → `detectors/<stack>.sh`, wired into `install.sh`.
- New shared skill → `.agents/skills/` in `framework/.agents/skills/` (framework-owned,
  carries the `agent-framework:managed` marker).
- Repo-specific knowledge for an installed target repo → `.agents/project/` (never
  `framework/`).
