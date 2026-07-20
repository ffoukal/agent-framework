# Design: Orchestration mode — main agent dispatches phase-agents as subagents

Date: 2026-07-17
Status: proposed (awaiting review)
Scope: extends `spec-agent-framework.md`; on approval its changes fold into that spec.

## 1. Goal

Make the pipeline **fluid within a single session**. Today the human opens a new CLI
session per phase and manually picks the model/effort (the model is only *advisory* via
`next.md`). We want a **main agent (orchestrator)** that, in one session, dispatches each
autonomous phase as a **subagent** with the model/effort resolved automatically from
`config.yml`, running the whole pipeline and pausing only where a human is genuinely
needed. The human can also cap how far it runs (`stop-at`).

This stays **CLI-agnostic**: the orchestration methodology lives in a framework skill and
in `AGENTS.md`; per-CLI model routing is enabled by generated native adapters. It is
verified on Claude Code now; OpenCode/Codex get the same skill + adapters and degrade to
the advisory manual flow where their dispatch differs.

## 2. What this reverses (and why it's now justified)

`spec §9 7.1` removed the native adapter folders (`.claude/agents/`, `.opencode/agent/`)
because model selection was purely advisory — repo files "cannot force a CLI's model", so
generating them had no purpose. Orchestration changes that: on Claude Code the model of a
dispatched subagent **is** taken from `.claude/agents/<name>.md` frontmatter. So the
adapters now have a concrete job — they are the mechanism that routes the resolved tier's
model to each subagent. **We reintroduce adapter generation**, this time purpose-driven.

`config.yml` remains the single source of truth (`models.agents` tier/effort +
`models.mapping` tier→model). Adapters are still *generated, not source*.

## 3. Components

### 3.1 `orchestrator.md` (new agent role)
The loop driver. Runs **in the main session** (it is not itself a subagent — it is what
the main session becomes when given the orchestrate prompt). Reads `state.md`/`next.md`,
resolves the current phase's agent, dispatches it as a subagent with the resolved model
and an isolated hand-crafted context, integrates the result from the updated `state.md`,
advances, and repeats until a stop condition.

### 3.2 `orchestrating-agents` skill (`.agents/skills/`, framework-managed)
The **agnostic dispatch methodology**, discovered by all CLIs (Codex/OpenCode scan
`.agents/skills/` natively; Claude Code via the `.claude/skills` symlink). It encodes:
how to construct an isolated subagent context (never pass the orchestrator's full
history), how to resolve the model from `config.yml`, when to pause (gates, interactive
phases, `stop-at`), and how to integrate each phase's result. On Claude Code it MAY lean
on `superpowers:subagent-driven-development` if installed (compatible-with, not
dependent-on — same pattern as `brainstormer.md` with `superpowers:brainstorming`).

### 3.3 Per-CLI adapters (regenerated at install/update)
`.claude/agents/<agent>.md` and `.opencode/agent/<agent>.md`, each with `name`,
`description` (so the CLI can route by subagent type), and `model:` resolved from
`config.yml` (`models.agents[agent].tier` → `models.mapping[tier][cli]`). Header marks
them GENERATED. Codex keeps the printed per-tier `config.toml` profile recipe (its config
is per-user). Generation returns as `lib/generate-adapters.sh`, called by install/update.

**Effort note:** Claude Code subagent frontmatter routes `model` only (no per-subagent
"effort" field). So `effort` stays advisory: the orchestrator folds it into the subagent
prompt (e.g. "think harder") and it drives Codex's `model_reasoning_effort`. `model` is
the hard-routed knob.

### 3.4 `config.yml`
Add `orchestrator` to `models.agents` (tier `reasoning`, effort `high`). No new required
structure; the orchestration behavior is documented, not flag-gated (YAGNI).

## 4. Interactive vs autonomous phases

- **Interactive (stay in the main session, never auto-dispatched):** `intake`,
  `brainstormer` — they interview the human. A one-shot subagent with isolated context
  cannot hold that back-and-forth.
- **Autonomous (dispatched as subagents):** `planner`, `debugger`, `explorer`,
  `implementer`, `reviewer`, `security-reviewer`, `pr-splitter`, `release-manager`.

## 5. The orchestration loop

```
1. Resolve task (current-task); read project config, state.md, next.md.
2. Determine the current phase and its agent (from next.md / pipeline / state).
3. STOP and hand back to the human if any of:
   - the phase is interactive (intake/brainstorm),
   - a hard gate is pending: status NEEDS_HUMAN | BLOCKED | AWAITING_COMMIT,
     or a plan awaiting approval,
   - the stop-at boundary is reached.
4. Otherwise DISPATCH the phase agent as a subagent:
   - model = resolve from config.yml (models.agents[agent].tier -> models.mapping[tier][cli]);
   - context = task id, phase, "read first", "do", "stop when", "expected writes"
     (from next.md) — a crafted, isolated brief, NOT the orchestrator's history;
   - instruction: follow the normal shutdown protocol (write artifact, update state.md,
     append run-log, write next.md, run agent-task-check).
5. INTEGRATE: re-read state.md.
   - verdict CHANGES_REQUESTED -> next is implementer (loop);
   - status BLOCKED | NEEDS_HUMAN -> stop, surface to human;
   - status APPROVED/DONE for the task -> stop (done);
   - else advance to the next phase.
6. Repeat from 2.
```

Every dispatched subagent still runs the shutdown protocol, so **the repo stays the
memory**: if the orchestration session dies mid-pipeline, re-invoking "continue
orchestrating the current task" resumes cleanly from `state.md`/`next.md`.

## 6. `stop-at`

The human caps autonomy at invocation, e.g. *"orchestrate the current task, stop after
review"* or *"run until the plan is ready"*. The orchestrator records `stop_at: <phase>`
in `state.md` and halts when the pipeline is about to advance past it. Default (no
`stop-at`): run the full pipeline, pausing only at hard gates and interactive phases.

## 7. Gates and commit modes

Hard gates always pause the loop: plan approval (`planner` ends `NEEDS_HUMAN`),
`AWAITING_COMMIT` (human-gated), any `NEEDS_HUMAN`/`BLOCKED`, interactive phases, and
`stop-at`.

- **`commits.mode: human-gated` (default):** the orchestrator pauses at each commit
  boundary (`AWAITING_COMMIT`); the human commits, then re-invokes to continue. Fluid but
  with commit checkpoints.
- **`commits.mode: agent` (recommended for full end-to-end fluidity):** the `implementer`
  subagent commits at boundaries and the loop continues without pausing. Push is still
  always human.

We keep `human-gated` as the default and **document `agent` as the recommended mode for
orchestration**. No default change.

## 8. Agnostic strategy per CLI

- **Claude Code (verified now):** orchestrator = main session; dispatch via the `Task`
  tool with `subagent_type=<agent>`; model routed from `.claude/agents/<agent>.md`.
  Optionally leans on `superpowers:subagent-driven-development` if present.
- **OpenCode:** native subagents read `.opencode/agent/<agent>.md` (`model`); same skill
  drives the loop.
- **Codex:** per-user profiles from the printed recipe; where its dispatch differs, the
  orchestrating-agents skill instructs falling back to the advisory manual flow (surface
  `next.md` with the resolved model/effort, human runs the phase).

The skill states this fallback explicitly, so a CLI without subagent dispatch never
breaks — it just runs the current manual flow.

## 9. Non-goals (YAGNI)

- No parallel dispatch of phases (pipelines are sequential; parallelism only ever made
  sense for independent tasks, not phases of one task).
- The orchestrator never auto-resolves `NEEDS_HUMAN`/`BLOCKED`, never pushes, never
  overrides the git rules or plan-approval gate.
- No new daemon/queue — still files + one session.

## 10. Files to change

**New**
- `framework/.agents/agents/orchestrator.md`
- `framework/.agents/skills/orchestrating-agents/SKILL.md` (managed)
- `lib/generate-adapters.sh` (reinstated; now includes `description` + orchestrator)

**Edit**
- `framework/AGENTS.md` — new "Orchestration" section (loop, gates, stop-at, interactive
  split, agnostic fallback); update the "Agent model tiers" note (adapters are back, and
  now route models for subagent dispatch).
- `framework/.agents/agents/*.md` — no frontmatter change; add a one-line "Dispatched by
  the orchestrator as a subagent" note to the autonomous ones; note intake/brainstorm run
  interactively.
- `project-template/config.yml` — add `orchestrator` to `models.agents`.
- `framework/.agents/scripts/agent-task-check` — `state.md` may carry `stop_at`; ensure
  `orchestrator` is validated in `models.agents` (it is, since it enumerates agent files).
- `install.sh` / `update.sh` — regenerate `.claude/agents/` + `.opencode/agent/` via
  `lib/generate-adapters.sh` (install step 7.1 restored alongside the Codex recipe;
  update regenerates them). Adapters are generated artifacts.
- `framework/.agents/templates/state.md` — optional `stop_at` frontmatter field.
- `framework/.agents/README.md`, top `README.md`, `CHANGELOG.md` — document orchestration
  and the universal prompts.

**Spec** (`spec-agent-framework.md`, after approval): reverse §9 7.1 (adapters return with
purpose), add an orchestration section (new §), add `orchestrator` to §5 and §10.1,
document the commit-mode recommendation.

## 11. Universal prompts (added)

```
Orchestrate the current task using the persistent agent system.
Orchestrate the current task; stop after <phase>.
Continue orchestrating the current task using the persistent agent system.
```

## 12. Verification

- Adapter generation: `.claude/agents/<agent>.md` carry the resolved model per tier
  (e.g. reviewer→opus, implementer→sonnet); regenerated on update; unmarked/repo files
  untouched.
- A dry dispatch on Claude Code: orchestrator reads a task at `plan` phase, dispatches the
  planner subagent, the plan lands, and the loop pauses at the approval gate.
- Resumability: kill mid-loop, re-invoke, resume from `state.md`.
- `stop-at`: orchestrate with `stop after review` halts before release/split.
- Agnostic fallback: with no subagent dispatch, the skill instructs the manual flow.
