# Changelog

All notable changes to the framework are documented here. Versions are semver and
match `.agents/VERSION` and the GitHub release tags (`vX.Y.Z`).

## Unreleased

### Cost guardrails (config drift warnings + compact test runner)
- **`agent-models-sync` warns on missing `models.agents` entries** instead of
  silently defaulting to `standard` — a silent default could put the orchestrator
  on an expensive model in repos installed before a new agent existed.
- **`update.sh` diffs config keys:** after updating, it compares the key paths of
  `project-template/config.yml` against the repo's `config.yml` (which the updater
  never edits) and lists any keys the template has that the repo lacks (e.g.
  `models.agents.orchestrator`, `context.compact_gate`).
- **`agent-test` compact test runner:** new framework-owned dispatcher
  `.agents/scripts/agent-test` (contract: `all` | `one <pattern>` | `show <test>`)
  delegating to a repo-owned `.agents/project/agent-test.sh`. Full runner output
  goes to `.agents/test-logs/` (gitignored); only a compact summary (counts +
  failing test ids) enters the agent's context. `install.sh` seeds a reference
  implementation for detected stacks (Gradle/Kotlin shipped); AGENTS.md Context
  budget now mandates using it — raw test-runner dumps in the session are the main
  cache-read cost driver during implement/debug loops.

### Single `/task` command + nested orchestration (breaking)
- **One entry point:** the five slash commands (`/task-new`, `/task-continue`,
  `/task-status`, `/task-step`, `/orchestrate`) are replaced by a single **`/task`**
  command that reads the persisted state and does the right thing: no active task →
  intake in the main session; interactive phase → stays in the main session;
  otherwise → dispatches the orchestrator. Subcommands: `step` (one phase),
  `status` (read-only), `stop after <phase>`, and `change <description>` (mid-task
  definition change). `agent-models-sync` generates `/task` and prunes the old
  generated commands.
- **Nested orchestration:** the orchestrator now runs as a **dispatched subagent**
  (layer 1) on the model its adapter fixes from `config.yml` — never the main
  session's model — and dispatches each phase agent as a layer-2 nested subagent.
  **Gate = return:** at `NEEDS_HUMAN` | `BLOCKED` | `AWAITING_COMMIT`, plan approval,
  interactive phases, or `stop-at`, it writes state to disk and returns instead of
  waiting; the next `/task` dispatches a fresh orchestrator that resumes from disk
  (any session, any CLI). This keeps coordination context short and cheap by
  construction.
- **Hard enforcement of the cheap topology:** install/update set
  `env.CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=2` in `.claude/settings.json`
  (Claude Code ≥ 2.1.217; 2.1.172–2.1.216 nested by default); phase-agent adapters
  now carry `disallowedTools: Agent` so only the orchestrator can dispatch; subagent
  briefs require ≤10-line replies (detail stays on disk); `agent-task-check` now
  FAILs on `progress.md` > 120 lines (warn > 90) and on a Recent log > 7 entries
  (warn > 5).
- **Mid-task definition changes** are now a first-class flow (`/task change`): logged
  in task.md "Evolution & human decisions", spec/plan updated (re-approval if
  acceptance criteria moved), `progress.md` rewound to the earliest affected phase
  with human confirmation. The orchestrator never absorbs a scope change — it
  returns `NEEDS_HUMAN`.
- **Context compact gate:** new `context.compact_gate` in `config.yml` (default 40,
  % of the context window). At/above it, an agent must not start a new phase or major
  unit: it finishes the shutdown protocol and hands off to a fresh context (the
  orchestrator returns early — lossless, since `/task` resumes from disk; the main
  session suggests `/clear` + `/task`). Advisory by nature (agents estimate usage
  from harness warnings and session growth); the disk-based handoff is what makes
  the cut cheap.
- Docs rewritten accordingly (`AGENTS.md` § Orchestration, `.agents/README.md`,
  `orchestrator.md`, `orchestrating-agents` skill), including the token-economy
  guidance: nested orchestration is now the default cheap path; the manual flow
  remains the fallback for CLIs without dispatch/nesting.

### Two-file task model + durable docs (breaking)
- Each task now keeps exactly **two working files**: `task.md` (the living logical
  document — brief, evolution & human decisions, Diagnosis, Findings, Implementation
  notes, Review, Security review, Release notes as sections) and `progress.md` (the
  machine file — state frontmatter, `## Next`, transient `## Commit request`, rolling
  `## Recent log` of ~5 entries). Removed as files: `state.md`, `next.md`,
  `run-log.md`, `implementation-log.md`, `commit-request.md`, `review.md`,
  `diagnosis.md`, `findings.md`, `security-review.md`, `release-notes.md`, `archive/`.
- **`.agents/tasks/` is now gitignored** (install/update add the entry and warn about
  previously tracked files): task state is local working state; a task is normally
  started and finished by the same dev. Cross-machine handoff via git no longer
  carries open-task state — the durable outputs do.
- **Durable docs**, all named `YYYY-MM-DD-<task-name>.md`: specs in `docs/specs/`,
  plans now written directly to `docs/plans/` (git-versioned, survive the task), and
  a per-task **resume** in `docs/tasks/` written by the terminal agent at close
  (reviewer for fix/chore on APPROVED; release-manager for features). The resume
  distills task.md: Problem, Solution, pending review items, unresolved follow-ups,
  notes; frontmatter `tags`, `touched` (≤5, "where would you look first", never
  mechanical ripples), `related`, `outcome`, spec/plan links.
- **Recall:** `docs/tasks/INDEX.md` (seeded by install/update) holds one line per
  closed task; the intake reads the INDEX (never the resumes wholesale), matches the
  new task by tags/paths, and links only the matching resumes in the new task.md.
- Scripts updated: `agent-task-new` creates the two files; `agent-task-next` prints
  `## Next`; `agent-task-status` prints progress + the task brief; `agent-task-check`
  validates the new invariants (Commit request section vs status, Recent log
  presence/trim, DONE ⇒ resume + INDEX line, tasks-gitignored warning).

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
