<!-- agent-framework:managed -->
# AGENTS.md — Persistent multi-CLI agent protocol

This file is the **universal bootstrap** for any agentic CLI (Claude Code, Codex,
OpenCode, or others) working in this repository. It defines the protocol **once**.
Individual agent files in `.agents/agents/` only describe role-specific behavior and
point back here.

**The repo is the memory.** Work state lives in Markdown files on disk, never in a
CLI's internal memory. Any CLI reads those files, understands where the previous one
stopped, and continues. **Never rely on chat memory alone.**

Each task keeps exactly **two working files** in `.agents/tasks/<task-id>/`:

- `task.md` — the **living logical document**: brief, evolution, decisions, diagnosis,
  findings, review, release notes. What a human would re-read.
- `progress.md` — the **machine file**: state-machine frontmatter, the instruction for
  the next agent, transient commit coordination, a short rolling log.

`.agents/tasks/` is **gitignored** (local working state; a task is normally started
and finished by the same dev on the same machine). The **durable outputs** are
git-versioned under `docs/`: `docs/specs/` (feature specs), `docs/plans/` (feature
plans), `docs/tasks/` (one resume per closed task + `INDEX.md`). All three use the
same naming: `YYYY-MM-DD-<task-name>.md`.

Project-specific knowledge is NOT here. It lives in `.agents/project/` (see
`project.md` for the human guide and `config.yml` for parseable settings).

---

## Language

**Everything agents write to the repo is in English** — `task.md`, `progress.md`, the
durable docs under `docs/`, and any other `.md` an agent creates — regardless of the
language the human speaks. Conversation with the human may be in their language; the
repo artifacts are always English so any CLI or teammate can read them.

---

## Startup protocol (mandatory for every agent)

Before acting, every agent MUST:

0. Read `.agents/project/project.md` (repo-specific guide) and
   `.agents/project/config.yml` (repo settings, e.g. commit mode).
1. Resolve the task id: if the user says "current task", read `.agents/current-task`.
2. Read `.agents/tasks/<task-id>/progress.md` (state + Next) and `task.md` (at least
   frontmatter, Goal, and the sections your role needs).
3. Read the durable docs the `task.md` frontmatter links (`spec:`, `plan:`) when your
   role needs them, and `split-plan.md` if present.
4. Read the relevant git context: `git diff <base_commit>..HEAD --stat` first, then
   the full diff of relevant files only; `git log <base_commit>..HEAD --oneline`.
5. (Only when `commits.mode` is `human-gated`) If `progress.md` says
   `status: AWAITING_COMMIT`: compare HEAD against the last SHA in the Recent log.
   If there are new commits, log "human committed <sha>" in the Recent log, reset the
   `## Commit request` section to `None.`, set status back to `IN_PROGRESS`, and
   continue. If there are NO new commits, stop and tell the human a commit is pending.
6. If `progress.md` frontmatter `updated` is less than 15 minutes old and `owner` is
   not you, warn the human before proceeding (another CLI may be active).

Never rely on chat memory alone.

---

## Shutdown protocol (mandatory)

Before stopping, every agent MUST:

1. Write its output into the right `task.md` section (Diagnosis, Findings,
   Implementation notes, Review, ...) or durable doc (spec, plan, resume).
2. Update `progress.md`: frontmatter (phase, status, owner, updated), `## Next` for
   the next agent — in "Agent to use", name the agent AND resolve its model/effort
   from `.agents/project/config.yml` (see Agent model tiers below), e.g.
   `reviewer — model: opus, effort: high` — and append a compact entry to
   `## Recent log` (keep only the last ~5 entries).
3. Run `.agents/scripts/agent-task-check <task-id>` and fix anything it reports.

## Agent model tiers

The model tier and effort of each agent are NOT stored in the agent files. They live in
`.agents/project/config.yml` under `models.agents` (per-agent `tier` + `effort`) —
the single source of truth — with `models.mapping` translating each abstract tier
(`reasoning` | `standard` | `fast`) to a concrete model per CLI (`claude-code`,
`opencode`, `codex`). Editing `models.agents` in that file IS the per-repo override.

When an agent writes the `## Next` section of `progress.md`, it resolves the next
agent's tier from `models.agents`, the model from `models.mapping` (for the CLI in
use), and includes both in "Agent to use". This drives the manual flow and any CLI
without subagent dispatch.

For **orchestration** (see below), the installer generates native per-CLI adapters
(`.claude/agents/`, `.opencode/agent/`) carrying the resolved `model:` per agent, plus a
Codex `config.toml` profile recipe (one per tier). Those adapters are what let each CLI
route the resolved model to a **dispatched subagent**. They are generated, not source:
do not edit them — edit `config.yml` (or `.agents/agents/`) and run
`.agents/scripts/agent-models-sync` to regenerate them (install/update run it too). If
`config.yml` is newer than the adapters, `agent-task-check` warns you to sync.

---

## Git rules

**Universal (both commit modes):**
- Agents NEVER run: `git push`, `git rebase`, `git reset --hard`,
  `git commit --amend`, branch deletion, or any history rewrite. Pushing is ALWAYS
  human.
- Agents MAY run any read-only git command, `git add` (staging only if asked),
  `git stash` of their own work-in-progress, and local branch creation ONLY when
  executing an approved split-plan (see PR splitting).
- Commit boundaries are defined by the plan (Commit/PR boundaries) or phase ends —
  never micro-commits. The commit mode changes WHO commits, never WHEN.
- **Bookkeeping never gates:** `.agents/tasks/` is gitignored, so task bookkeeping
  produces no git diff at all. The small durable-doc writes at close (the resume and
  its `INDEX.md` line) are likewise NOT their own commit boundary — leave them
  uncommitted for the human to fold into a future commit. Deliverable durable docs
  (the spec, the plan) still gate normally — they ARE the phase's deliverable.

**If `commits.mode` is `human-gated` (default):**
- Agents NEVER run `git commit`. To get changes committed, fill the
  `## Commit request` section of `progress.md` and set status `AWAITING_COMMIT`
  (see Commits below).

**If `commits.mode` is `agent`:**
- Agents MAY run `git commit` at commit boundaries, and MUST record each commit
  (message + SHA) in the `## Recent log` of `progress.md` immediately after. The
  `## Commit request` section is not used.

### Commit authorship (universal rule, both modes)

Commit messages MUST NOT include AI co-authorship trailers or attribution lines.
Forbidden in any commit message or commit-request proposal:
- `Co-Authored-By: Claude ...` or any agent/AI co-author trailer
- "Generated with Claude Code", "🤖 Generated with ...", or similar attribution

Authorship belongs to the human operating the session. Agent traceability lives in
the `progress.md` Recent log (agent, CLI, SHA per entry) while the task is open, and
in git history afterwards. This rule is enforced regardless of `coauthor_trailers`
unless the team explicitly sets it to `true` in `config.yml`.

### Commit message format (guidance)

Prefer Conventional Commits: `<type>(<optional scope>): <imperative subject>`, with
`type` ∈ `feat | fix | refactor | perf | test | docs | build | ci | chore`. Signal
breaking changes with `feat!:` or a `BREAKING CHANGE:` body line. This is guidance, not
enforced by the tooling; a repo may override the convention in `project.md` under
"Project-specific rules".

---

## Task types and pipelines

| Type | Pipeline | Logical content lives in | Ends in |
|---|---|---|---|
| `feature` | spec → plan → implement → test → review → release/split | `docs/specs/` + `docs/plans/` + `task.md` | merged PRs + resume |
| `fix` | diagnose → implement → review | `task.md` (Diagnosis, Review) | merged PR + resume |
| `debug` | diagnose | `task.md` (Diagnosis) | `NEEDS_HUMAN` |
| `chore` | implement → review | `task.md` (brief is the plan) | merged PR + resume |
| `spike` | explore | `task.md` (Findings) | `NEEDS_HUMAN` |

Valid escalation routes (always with explicit human confirmation, logged in `task.md`
"Evolution & human decisions" and in `project/memory/decisions.md` if relevant):

- `debug → fix`: cause found, fix is bounded, proceed (mutate `type` and `pipeline`
  in `progress.md` frontmatter).
- `fix → feature`: the fix requires design; add a formal plan phase.
- `chore → fix` / `chore → feature`: the "mechanical" change turned out not to be.
- `spike → feature`: does NOT mutate the task — the intake creates a NEW `feature`
  task that links the spike's resume (or its `task.md` Findings if still open).

### Spec-driven features

A `feature` starts with the `spec` phase: the `specifier` runs discovery and writes an
approved spec (durable, `docs/specs/YYYY-MM-DD-<task-name>.md`, linked from the
`task.md` frontmatter `spec:`) — **gate 1**. The `planner` then builds the plan
(`docs/plans/YYYY-MM-DD-<task-name>.md`, frontmatter `plan:`) from that spec —
**gate 2** — and the `reviewer` verifies the spec's acceptance criteria against the
implementation. If requirements change mid-task, update the spec; if the acceptance
criteria move, re-approve (gate 1 again), logging it. `fix` tasks have no spec — their
`task.md` Diagnosis section is the spec-equivalent.

---

## Task close, resumes and recall

When a task reaches its terminal phase, the **terminal agent** closes it:

- `fix` / `chore`: the `reviewer`, right after emitting `APPROVED`.
- `feature`: the `release-manager`, after writing the release notes.
- `debug` / `spike`: end at `NEEDS_HUMAN` — no resume unless the human asks for one.

Closing means distilling `task.md` into the durable resume
`docs/tasks/YYYY-MM-DD-<task-name>.md` (template: `templates/resume.md` — Problem,
Solution, pending review items, unresolved follow-ups, notes; frontmatter with `tags`,
`touched` ≤5, `related`, `outcome`, and the spec/plan links) and appending **one
line** to `docs/tasks/INDEX.md`:

```
- YYYY-MM-DD TASK-ID type [tag, tag] touched/paths — one-line summary
```

The task directory is NOT deleted — it is gitignored and stays until the dev discards
it. `status: DONE` in `progress.md` marks the close.

**Recall (intake step):** when creating a new task, the intake reads
`docs/tasks/INDEX.md` (one line per past task — never the whole resumes), matches the
new task against tags and `touched` paths, reads ONLY the matching resumes, and links
them in the new `task.md` "Links" section. This is how past work reaches new pipelines
without exploratory reading.

---

## Phases, statuses and verdicts

```text
Phases:   intake | spec | diagnose | explore | plan | implement | test |
          review | security-review | split | release
Statuses: READY | IN_PROGRESS | AWAITING_COMMIT | NEEDS_HUMAN | BLOCKED |
          CHANGES_REQUESTED | APPROVED | DONE
Verdicts: APPROVED | CHANGES_REQUESTED | BLOCKED
```

---

## Classification & ambiguity (intake)

The `intake` classifies each task as `feature | fix | debug | chore | spike`, **citing
the triggering signal**, and follows a mandatory ambiguity protocol when the type is
unclear (present options, do not guess, record the decision). The full signals,
discriminants, and ambiguity protocol live in `.agents/agents/intake.md` — only the
intake needs them, so they are not carried in every session's context.

---

## Team skills

`.agents/skills/` is a shared library of reusable skills (each a folder with a
`SKILL.md`). Any agent may consult a relevant skill and apply it. It is **shared
territory**:

- Framework-owned skills carry the `agent-framework:managed` marker in their `SKILL.md`;
  `update.sh` replaces or removes only those. Do not edit them locally — they are
  overwritten on update.
- Repo-owned skills omit the marker; the updater never touches them. Add project skills
  here freely (without the marker).

All CLIs discover this path: Codex and OpenCode scan `.agents/skills/` natively; Claude
Code reaches it via the `.claude/skills -> ../.agents/skills` symlink created at install.

## Orchestration (`/task` — the main flow)

The human's entry point is **one command: `/task`**. It reads the persisted state and
does the right thing: no active task → run the **intake** in the main session; current
phase interactive (`intake`, `specifier`) → hold it in the main session; otherwise →
dispatch the **orchestrator** as a subagent, which runs the pipeline and returns at
gates.

**Nested topology (enforced, not advisory):** the orchestrator is a layer-1 subagent
on the cheap model its generated adapter fixes — it never inherits the main session's
model. It dispatches each autonomous phase as a layer-2 subagent (adapter model,
isolated brief — never its own history; ≤10-line replies). Phase-agent adapters deny
the Agent tool and the installer caps spawn depth at 2
(`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` in `.claude/settings.json`), so the topology
cannot silently degrade. The main session pays only a dispatch and a short report.

**Gate = return.** At hard gates (`NEEDS_HUMAN` | `BLOCKED` | `AWAITING_COMMIT`, plan
approval), interactive phases, and the human's stop boundary, the orchestrator writes
state to disk and returns — it never waits. Resuming is always from disk: the next
`/task` dispatches a fresh orchestrator that reconstructs everything from
`progress.md`/`task.md`, in any session, any CLI, any day. `commits.mode: agent` is
recommended when orchestrating; `human-gated` returns once per commit boundary.

**The granularity is a human decision, chosen per invocation:**

```
/task                        # run until the next human gate (default)
/task step                   # exactly ONE phase, then stop
/task stop after <phase>     # run until <phase> completes
/task status                 # read-only: state, pending gate, next command
/task change <description>   # mid-task definition change (see below)
```

(Equivalent prose prompts — "Advance the current task using the persistent agent
system", etc. — work on any CLI; on CLIs without subagent dispatch or nesting, the
`orchestrating-agents` skill's manual fallback applies.)

**Mid-task definition changes (`/task change`)** run in the main session, never inside
the orchestrator: log the decision in task.md "Evolution & human decisions"; update
the spec/plan if affected (re-run the approval gate if acceptance criteria moved);
rewind `progress.md` to the earliest affected phase, confirming with the human first.
An orchestrator that detects a scope change returns `NEEDS_HUMAN` — it never absorbs
one. Full methodology in `orchestrator.md` and the `orchestrating-agents` skill.

## Context growth control

- `progress.md` stays short: `## Next` and `## Commit request` are overwritten in
  place, and `## Recent log` keeps only the last ~5 entries (drop the oldest when
  adding).
- `task.md` grows only in its append-oriented sections (Evolution, Implementation
  notes, Review rounds); a new review round replaces resolved findings instead of
  accumulating them verbatim.
- Durable docs (`docs/specs/`, `docs/plans/`, `docs/tasks/`) are reached via the
  `task.md` frontmatter links or `docs/tasks/INDEX.md` — never by listing or reading
  those directories wholesale.

### Context budget (token economy — mandatory)

Sessions run on limited quota. Every agent MUST:

- Read ONLY the files its startup protocol and the `## Next` "Read first" list name —
  no exploratory reading of the task directory or `project/memory/` beyond the role's
  listed extras.
- Take git context in two steps: `git diff <base_commit>..HEAD --stat` first, then the
  full diff of relevant files only.
- Prefer search (grep/glob) and partial reads over reading whole source files; never
  re-read a file already read in this session.
- **Never dump raw test-runner output into the session** — it is re-read on every
  later turn. Run tests through `.agents/scripts/agent-test` when the repo implements
  it (`all` = full suite with compact summary, `one <pattern>` = targeted run,
  `show <test>` = failure detail on demand; full logs stay on disk). Typical cycle:
  `all` for a baseline, iterate with `one`/`show` on the failures, `all` again before
  closing the phase. If the repo has no implementation, run the narrowest target the
  toolchain allows and filter the output (e.g. `| tail -40`).
- Not dispatch subagents outside orchestration — each dispatch re-reads the protocol.
- Keep artifacts factual and compact: no restating the protocol, no summarizing files
  that are already on disk (link them instead).
- **Honor the context compact gate** (`context.compact_gate` in `config.yml`, default
  40): when your context usage reaches that share of the window — harness warnings,
  or your own read that the session has grown well past its starting size — do NOT
  start a new phase or major work unit. Finish the current unit, run the shutdown
  protocol, and hand off to a fresh context: the orchestrator returns (the next
  `/task` resumes from disk at zero cost); a phase agent wraps up and reports; the
  main session suggests the human `/clear` and re-run `/task`. Never compact by
  summarizing into chat — the handoff IS the compaction, because the repo is the
  memory.

Nested orchestration is already the cheap path: coordination runs on the
orchestrator's own cheap model and dies at every gate, so the main session never
accumulates it. When quota is tight, the levers are: `/task step` (no multi-phase
coordination at all), lowering tiers in `config.yml` `models.agents` (e.g. review of
a `chore` on `fast`), and — on CLIs stuck with in-session coordination (no nesting) —
the manual flow (one fresh session per phase).

---

## Commits (operational summary)

See **Git rules** above for who commits in each mode. In both modes the committable unit
is the plan boundary or phase end (no micro-commits) and the working tree must be left
"ready" (tests passing, nothing half-done). `human-gated`: the agent fills the
`## Commit request` section of `progress.md`, sets `AWAITING_COMMIT`, stops; the human
commits; the next agent resyncs (startup step 5). `agent`: the agent commits at the
boundary and records message + SHA in the Recent log. Reviewer and pr-splitter operate
on `git diff <base_commit>..HEAD` the same in both modes, so a repo can switch modes
without breaking in-flight tasks. Task bookkeeping never needs a commit at all —
`.agents/tasks/` is gitignored (see Git rules).
