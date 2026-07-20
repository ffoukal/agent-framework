# Changelog

All notable changes to the framework are documented here. Versions are semver and
match `.agents/VERSION` and the GitHub release tags (`vX.Y.Z`).

## Unreleased

### Spec-driven flow
- Features now start with a **`spec` phase**: the new **`specifier`** agent (renamed from
  `brainstormer`) runs discovery interactively and writes an approved **`spec.md`**
  (durable, in `docs/specs/`, linked from the task). Feature pipeline is now
  `spec → plan → implement → test → review → release/split` with **two gates** (spec, then
  plan). `brainstorming.md` is removed (discovery is the activity; `spec.md` is the
  deliverable).
- The `planner` builds the plan from the approved spec; the `reviewer` gains a **spec
  compliance** lens that verifies each acceptance criterion (unmet required → CHANGES_REQUESTED).
- The `intake` can **ingest a human-provided spec** (path or pasted) and route it through
  the spec gate. `fix`/`debug`/`chore`/`spike` are unchanged (a fix's `diagnosis.md` is
  its spec-equivalent). Phase `brainstorm` → `spec` (config, checks, orchestration).

### Git-rule enforcement (Claude Code)
- New `.agents/scripts/agent-git-guard` PreToolUse hook: blocks `git push`/`rebase`/
  `reset --hard`/`commit --amend`/`filter-branch`/branch deletion anywhere in a compound
  command, and blocks `git commit` when `commits.mode` is `human-gated` (reads
  `config.yml` live). install/update wire it into `.claude/settings.json` together with
  static `permissions.deny` rules, merging with (never clobbering) existing settings via
  jq. On CLIs without hooks the AGENTS.md prose remains the enforcement.

### Slash commands
- `agent-models-sync` now also generates thin slash commands wrapping the canonical
  prompts — `/task-new`, `/task-continue`, `/task-status`, `/orchestrate` — for Claude
  Code (`.claude/commands/`) and OpenCode (`.opencode/command/`), and prints a Codex
  per-user prompts recipe. Generated (marker + prune), never hand-edited.

### Step mode (human-chosen granularity)
- The orchestrator gains **step mode**: `Run only the next phase of the current task,
  then stop.` (`/task-step`) dispatches exactly ONE phase as a subagent — adapter-resolved
  model, no manual model/effort picking — then hands back. `/orchestrate` keeps running
  until the next human gate (or `stop after <phase>`). The granularity is a per-invocation
  human decision; gates and protocol are identical in both modes.
- Default `orchestrator` tier changed `standard/medium` → **`fast/low`** in the config
  template: coordination is mechanical and each dispatched subagent carries its own model,
  so orchestration overhead now runs on cheap tokens.

### Token economy
- `AGENTS.md` gains a mandatory **Context budget** subsection (read only listed files,
  `--stat` before full diffs, grep over full reads, no ad-hoc subagent dispatch, compact
  artifacts) and documents the **economy mode**: manual flow (fresh session per phase)
  over orchestration when quota is tight, plus tier downgrades in `config.yml`.
  `.agents/README.md` documents both for humans ("Modo ahorro").

### Added / Changed (from production feedback)
- `agent-models-sync` script: regenerates the subagent adapters (`.claude/agents/`,
  `.opencode/agent/`) from `config.yml` locally and prints the Codex recipe. Run it after
  editing `config.yml` tiers/mapping — no re-install needed. It is now the single
  generator (install/update call it); `lib/generate-adapters.sh` removed. `agent-task-check`
  warns when `config.yml` is newer than the adapters (drift → run the sync).
- `agent-task-check`: scans `task.md`/`state.md`/`next.md` for unreplaced template
  placeholders (fail); warns on a zeroed `updated` timestamp; warns if the agent named in
  `next.md` is not in `config.yml` `models.agents`; fails if `split-plan.md` has
  `approved_by_human: false` while status ≠ `NEEDS_HUMAN`; fails if a resolved
  `commit-request.md` was not archived. Removed the unreliable `run-log` vs `state.md`
  mtime warning (false positives).
- `agent-task-status --all` (alias `--list`): one-line overview of every task
  (id · type · status · phase · updated), marking the current one.
- `intake.md`: `agent-task-new` is now the only prescribed task-creation path (no manual
  template copy); the human-confirmation gate before creation is explicitly
  mode-independent (holds even under automatic/orchestrated dispatch).
- `debugger.md`: clarified that handing a `fix`-type task to the implementer is the normal
  `fix` pipeline, not a `debug → fix` escalation (no human-confirmation gate there).
- `orchestrator.md`: added a reference subagent-brief template. `next.md` template notes
  that the shown model is a write-time snapshot and `config.yml` is authoritative.

## [1.0.0] - 2026-07-15

Initial release.

### Added
- Universal bootstrap protocol (`AGENTS.md`): startup/shutdown protocols, git rules,
  commit authorship rule (no AI co-authorship trailers), task types & pipelines,
  phases/statuses/verdicts, classification & ambiguity protocol, context-growth control.
- `CLAUDE.md` importing `@AGENTS.md`.
- Agent roles: intake, brainstormer, planner, debugger, explorer, implementer,
  reviewer, security-reviewer, pr-splitter, release-manager.
- Templates: task, state, next, run-log, brainstorming, plan, diagnosis, findings,
  implementation-log, review, security-review, commit-request, split-plan,
  release-notes.
- Scripts: `agent-task-new`, `agent-task-status`, `agent-task-next`,
  `agent-task-current`, `agent-task-check`.
- Project template: `project.md`, `config.yml` (commit mode), and `memory/`
  (architecture, domain, code-map, testing, conventions, decisions).
- Detectors: `kotlin.sh`, `go.sh`, `node.sh`.
- `install.sh` and `update.sh` with a directory-boundary update rule (framework files
  replaced; `project/`, `tasks/`, `current-task` never touched).
- Two commit modes: `human-gated` (default) and `agent`.
- Per-agent model **tier** (`reasoning` | `standard` | `fast`) and **effort**
  (`high` | `medium` | `low`) declared in `config.yml` under `models.agents` (single
  source of truth), with `models.mapping` translating each tier to a concrete model per
  CLI. Model selection is advisory via `next.md`; install prints a Codex `config.toml`
  profile recipe (one per tier) and writes no mirror agent folders.
- Legacy migration: preexisting `AGENTS.md`/`CLAUDE.md` content is moved to
  `.agents/project/legacy-agents-instructions.md` on install for redistribution;
  `AGENTS.md` is always framework-owned, `CLAUDE.md` stays repo-owned (import ensured).
- Reviewer & security-reviewer use **severity-scored findings** (critical/high/medium/
  low/info) via explicit review lenses, an anti-padding rule, and a
  `[needs confirmation]` marker; severity maps to the verdict
  (critical→BLOCKED, high→CHANGES_REQUESTED, else APPROVED). `review.md` /
  `security-review.md` templates restructured accordingly.
- Task-id **input validation** in `agent-task-new`/`-status`/`-next`/`-check`: rejects
  slashes, leading dots, and shell metacharacters — closes a path-traversal / broken-sed
  footgun.
- Conventional Commits **guidance** in `AGENTS.md` and the `commit-request.md` template
  (guidance only, not enforced; overridable in `project.md`).
- **Orchestration mode**: an `orchestrator` agent runs a task's pipeline in one session
  by dispatching each autonomous phase as a subagent (model resolved from `config.yml`),
  pausing at interactive phases (`intake`/`brainstormer`), hard gates, and a human-set
  `stop-at`. Adds the `orchestrating-agents` managed skill (the CLI-agnostic dispatch
  methodology, optionally leaning on `superpowers:subagent-driven-development` on Claude
  Code) and an optional `stop_at` field in `state.md`. `commits.mode: agent` recommended
  for full fluidity; `human-gated` pauses per commit boundary.
- **Native subagent adapters reinstated** (`lib/generate-adapters.sh`): install/update
  generate `.claude/agents/` and `.opencode/agent/` with the resolved `model:` (and a
  `description`) per agent, so each CLI routes the tier's model to a dispatched subagent.
  Codex still gets a printed per-tier profile recipe. Reverses the earlier advisory-only
  removal, now that adapters have a concrete orchestration purpose.
- **English-only rule**: everything agents write to the repo (tasks and all `.md`
  artifacts) is in English regardless of the human's language (see `AGENTS.md`).
- **Team skills subsystem** (`.agents/skills/`): shared territory of reusable skills.
  Framework skills carry an `agent-framework:managed` marker (also the first line of
  `AGENTS.md`); install/update replace or remove only marked skills and never touch
  unmarked repo-owned ones. Install links `.claude/skills -> ../.agents/skills` (Codex/
  OpenCode scan the path natively) and detects legacy `AGENTS.md` by marker absence.
  Ships `conventional-commits` and `test-driven-development` skills.
