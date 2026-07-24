---
name: orchestrating-agents
description: Methodology for advancing a task's pipeline by dispatching each autonomous phase as a subagent with the model resolved from config.yml. Used by the orchestrator (nested dispatch) and by the /task command routing. Use when orchestrating the persistent agent system.
# agent-framework:managed  — do NOT remove this marker; update.sh uses it to know this
# skill is framework-owned (replaceable). Team-owned skills omit the marker.
---

# Orchestrating agents

Dispatch a fresh subagent per pipeline phase, integrate its result from the repo state,
and advance — returning to the human only where they are genuinely needed. This is
CLI-agnostic: it describes the method; each CLI executes it with its own subagent
primitive.

## Topology (who runs where)

The human's entry point is **`/task`** in the main session. Three layers:

- **Main session** (any model — it pays almost nothing): routes `/task`, holds the
  interactive phases (`intake`, `specifier`) and `/task change`, dispatches the
  orchestrator, relays its report.
- **Orchestrator** (layer-1 subagent, cheap model fixed by its generated adapter):
  runs the loop below. It cannot talk to the human — a gate means *write state to
  disk and return*. Each `/task` gets a fresh orchestrator that resumes from disk.
- **Phase agents** (layer-2 nested subagents, models from their adapters): do the
  actual work, write everything to `task.md`/`progress.md`/durable docs, reply with
  ≤10 lines.

This keeps coordination context short (a gate ends the orchestrator) and cheap (its
model never inherits from the session). The spawn depth is capped at 2 by the
installer (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`), and phase-agent adapters deny the
Agent tool — the topology is enforced, not advisory.

## Core principles

- **Fresh subagent per phase.** Never let a subagent inherit session history — hand
  it exactly the context it needs and nothing more.
- **The repo is the memory.** Every dispatched subagent runs the full shutdown protocol
  (writes its output into `task.md` or the durable doc, updates `progress.md` —
  frontmatter, `## Next`, Recent log — runs `agent-task-check`). So any death —
  orchestrator returning at a gate, a session closing — resumes cleanly from disk.
- **Reports are ≤10 lines.** The dispatcher integrates from `progress.md`, not from
  the report; a long report is duplicated cost.
- **English only.** All files written to the repo are in English (see `AGENTS.md`).

## The loop (orchestrator)

1. Read `.agents/project/config.yml` and `progress.md`. Note `commits.mode` and any
   `stop_at`.
2. Identify the current phase and its agent.
3. **Return to the caller** if:
   - the phase is **interactive** (`intake`, `specifier`) — they need a live
     conversation a subagent cannot hold;
   - a **hard gate** is pending: `NEEDS_HUMAN` | `BLOCKED` | `AWAITING_COMMIT`, or a plan
     awaiting approval;
   - the **`stop-at`** boundary is reached.
   Update `progress.md` first; the report says exactly what the human must do and that
   `/task` resumes.
4. Otherwise **dispatch the phase agent as a nested subagent**:
   - **Model:** resolve `models.agents[<agent>].tier`, then
     `models.mapping[tier][<your-cli>]`. On Claude Code, dispatch by the agent's subagent
     type so its `.claude/agents/<agent>.md` model applies; on OpenCode, its
     `.opencode/agent/<agent>.md` model applies.
   - **Effort** is advisory: fold `models.agents[<agent>].effort` into the brief
     (e.g. "think harder for a high-effort review"). `model` is the routed knob.
   - **Brief (isolated):** task id, phase, and the "Read first / Do / Stop when /
     Expected writes" from the `## Next` section of `progress.md`. Do not paste your
     history. Require a ≤10-line reply.
   - **Instruction:** follow the normal shutdown protocol before returning.
5. **Integrate:** re-read `progress.md`.
   - verdict `CHANGES_REQUESTED` → next agent is `implementer` (loop);
   - `BLOCKED` | `NEEDS_HUMAN` → return, surfacing what is needed;
   - task `APPROVED` | `DONE` → return;
   - else advance to the next phase.
6. **Context gate check:** if your own context usage has reached
   `context.compact_gate` (config.yml, default 40% of the window), return now instead
   of dispatching another phase — report progress and that `/task` continues fresh
   from disk. Returning early is lossless; a bloated coordinator is not.
7. Repeat from step 2 — honoring the granularity in the brief (see below).

## Granularity (human control point)

The human decides per invocation, and the main session passes it in the brief:

- **`/task`** → loop until a gate, an interactive phase, or `DONE`.
- **`/task step`** → ONE iteration of the loop (steps 1–5), then return reporting what
  ran and what the next phase would be. Never chain a second phase, even gate-free.
- **`/task stop after <phase>`** → loop until that phase completes, then return.

Everything else (briefs, model resolution, gates, commit modes) is identical.

## Mid-task definition changes (`/task change`)

Definition changes run in the **main session**, never inside the orchestrator:
log the decision in task.md "Evolution & human decisions"; update the spec (feature)
or Diagnosis (fix) if affected — re-run the approval gate if acceptance criteria
moved; check the plan against the updated spec and re-plan only the affected parts;
rewind `progress.md` (phase + `## Next`) to the earliest affected phase, confirming
the rewind with the human first. Work already done that remains valid is kept — the
updated plan marks it done. An orchestrator that *detects* a scope change returns
`NEEDS_HUMAN` instead of deciding.

## Commit modes

- `human-gated` (default): the orchestrator returns at each commit boundary
  (`AWAITING_COMMIT`); the human commits, then `/task` continues. Note this returns
  once per boundary — for multi-boundary plans, `agent` mode keeps the flow unbroken.
- `agent` (recommended when orchestrating): the `implementer` subagent commits at
  boundaries and the loop continues. Push is always human.

## Manual fallback (no subagent dispatch, or no nesting)

If the CLI cannot dispatch subagents at all: do not dispatch. For each phase, resolve
the agent's model/effort as above, write it into the "Agent to use" of `progress.md`
`## Next`, and tell the human to run that phase (ideally in a fresh session with that
model). If the CLI dispatches subagents but cannot nest them, run the loop in the main
session and dispatch phase agents directly (layer 1) — and keep that session on a
cheap model, because coordination context accumulates there. Either way the pipeline
advances through the repo state.

## Never

Override the git rules, the plan-approval gate, or the commit mode; auto-resolve
`NEEDS_HUMAN`/`BLOCKED`; absorb a scope/definition change silently; push; or run
interactive phases as subagents.
