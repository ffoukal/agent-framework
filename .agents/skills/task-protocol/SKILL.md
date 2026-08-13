---
name: task-protocol
description: Full startup/shutdown protocol, task types & pipelines, phases/statuses/verdicts, commits, and task close/resume for the persistent multi-CLI agent system. Invoke before executing any pipeline role (orchestrator or a role in .agents/agents/) or before advancing /task.
# agent-framework:managed  — do NOT remove this marker; update.sh uses it to know this
# skill is framework-owned (replaceable). Team-owned skills omit the marker.
---

# Task protocol

This is the detailed protocol referenced by `AGENTS.md`. It only needs to be in
context while you are actually executing a task-pipeline role or advancing `/task` —
that's why it's a skill instead of always-loaded content. If you got here for any
other reason, you probably don't need it; go back to the actual request.

For **dispatch mechanics** (who dispatches whom, nested subagent topology, briefs,
granularity, mid-task changes), see the `orchestrating-agents` skill instead — this
skill does not duplicate that.

---

## Startup protocol (mandatory for every pipeline role)

Before acting, every agent MUST:

0. Read `.agents/project/project.md` (repo-specific guide) and
   `.agents/project/config.yml` (repo settings, e.g. commit mode) — **unless** you were
   dispatched with an isolated brief that already inlines `commits.mode` and your
   resolved model/effort (nested dispatch under the orchestrator does this). In that
   case, trust the brief; don't re-read these files.
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

## Shutdown protocol (mandatory)

Before stopping, every agent MUST:

1. Write its output into the right `task.md` section (Diagnosis, Findings,
   Implementation notes, Review, ...) or durable doc (spec, plan, resume).
2. Update `progress.md`: frontmatter (phase, status, owner, updated), `## Next` for
   the next agent — in "Agent to use", name the agent AND resolve its model/effort
   from `.agents/project/config.yml` (see Agent model tiers below) — and append a
   compact entry to `## Recent log` (keep only the last ~5 entries).
3. Run `.agents/scripts/agent-task-check <task-id>` and fix anything it reports.

## Agent model tiers

The model tier and effort of each agent are NOT stored in the agent files. They live
in `.agents/project/config.yml` under `models.agents` (per-agent `tier` + `effort`) —
the single source of truth — with `models.mapping` translating each abstract tier
(`reasoning` | `standard` | `fast`) to a concrete model per CLI (`claude-code`,
`opencode`, `codex`). Editing `models.agents` in that file IS the per-repo override.

When an agent writes the `## Next` section of `progress.md`, it resolves the next
agent's tier from `models.agents`, the model from `models.mapping` (for the CLI in
use), and includes both in "Agent to use". This drives the manual flow and any CLI
without subagent dispatch.

For orchestrated dispatch, the installer generates native Claude Code adapters
(`.claude/agents/`) carrying the resolved `model:` per agent — generated, not source:
edit `config.yml` (or `.agents/agents/`) and run `.agents/scripts/agent-models-sync`
to regenerate them. If `config.yml` is newer than the adapters, `agent-task-check`
warns you to sync.

Claude Code is the only actively maintained CLI target: `agent-models-sync` only
generates `.claude/agents/` and `.claude/commands/`. The `models.mapping` columns for
`opencode`/`codex` stay in `config.yml` (any CLI can still follow the manual flow by
reading `.agents/agents/*.md` + `config.yml` directly) but adapter generation for them
is paused.

## Git rules (detail — see AGENTS.md for the non-negotiable short list)

**Universal (both commit modes):**
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
  `## Commit request` section of `progress.md` and set status `AWAITING_COMMIT`.

**If `commits.mode` is `agent`:**
- Agents MAY run `git commit` at commit boundaries, and MUST record each commit
  (message + SHA) in the `## Recent log` of `progress.md` immediately after. The
  `## Commit request` section is not used.

### Stacked PRs (`gh stack`)

If a repo uses GitHub's stacked-PR workflow via the `gh-stack` CLI extension,
`gh stack rebase/push/submit/sync` all wrap `git push`/`git rebase` under the hood, so
they stay human-only in every commit mode. Agents MAY run read-only stack commands
(`gh stack list`, `gh stack checkout <branch>`) to inspect or navigate the stack. In a
stacked layout each layer branch bases on the layer below it, not on trunk directly —
see `pr-splitter.md` for how the `pr-splitter` builds and maintains such a stack.

### Commit message format (guidance)

Prefer Conventional Commits: `<type>(<optional scope>): <imperative subject>`, with
`type` ∈ `feat | fix | refactor | perf | test | docs | build | ci | chore`. Signal
breaking changes with `feat!:` or a `BREAKING CHANGE:` body line. This is guidance, not
enforced by the tooling; a repo may override the convention in `project.md`.

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

## Phases, statuses and verdicts

```text
Phases:   intake | spec | diagnose | explore | plan | implement | test |
          review | security-review | split | release
Statuses: READY | IN_PROGRESS | AWAITING_COMMIT | NEEDS_HUMAN | BLOCKED |
          CHANGES_REQUESTED | APPROVED | DONE
Verdicts: APPROVED | CHANGES_REQUESTED | BLOCKED
```

## Classification & ambiguity (intake)

The `intake` classifies each task as `feature | fix | debug | chore | spike`, **citing
the triggering signal**, and follows a mandatory ambiguity protocol when the type is
unclear (present options, do not guess, record the decision). The full signals,
discriminants, and ambiguity protocol live in `.agents/agents/intake.md` — only the
intake needs them.

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
- Not dispatch subagents outside orchestration — each dispatch re-reads this protocol.
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

## Commits (operational summary)

See **Git rules** above for who commits in each mode. In both modes the committable
unit is the plan boundary or phase end (no micro-commits) and the working tree must be
left "ready" (tests passing, nothing half-done). `human-gated`: the agent fills the
`## Commit request` section of `progress.md`, sets `AWAITING_COMMIT`, stops; the human
commits; the next agent resyncs (startup step 5). `agent`: the agent commits at the
boundary and records message + SHA in the Recent log. Reviewer and pr-splitter operate
on `git diff <base_commit>..HEAD` the same in both modes, so a repo can switch modes
without breaking in-flight tasks. Task bookkeeping never needs a commit at all —
`.agents/tasks/` is gitignored (see Git rules).
