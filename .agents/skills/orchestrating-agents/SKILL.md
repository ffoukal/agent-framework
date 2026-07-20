---
name: orchestrating-agents
description: Methodology for running a task's pipeline in one session by dispatching each autonomous phase as a subagent with the model resolved from config.yml. Use when orchestrating the persistent agent system.
# agent-framework:managed  — do NOT remove this marker; update.sh uses it to know this
# skill is framework-owned (replaceable). Team-owned skills omit the marker.
---

# Orchestrating agents

Dispatch a fresh subagent per pipeline phase, integrate its result from the repo state,
and advance — all in one session, pausing only where a human is genuinely needed. This
is CLI-agnostic: it describes the method; each CLI executes it with its own subagent
primitive.

On Claude Code you MAY lean on `superpowers:subagent-driven-development` if it is
installed (compatible with, not dependent on). Otherwise use the native subagent/`Task`
mechanism directly. If your CLI has no subagent dispatch, use the manual fallback below.

## Core principles

- **Fresh subagent per phase.** Never let a subagent inherit your session history — hand
  it exactly the context it needs and nothing more. This keeps it focused and preserves
  your context for coordination.
- **The repo is the memory.** Every dispatched subagent runs the full shutdown protocol
  (writes its artifact, updates `state.md`, appends `run-log.md`, writes `next.md`, runs
  `agent-task-check`). So if the session dies, re-invoking resumes cleanly from disk.
- **English only.** All files written to the repo are in English (see `AGENTS.md`).

## The loop

1. Read `.agents/project/config.yml`, `state.md`, `next.md`. Note `commits.mode` and any
   `stop_at`.
2. Identify the current phase and its agent.
3. **Pause and return to the human** if:
   - the phase is **interactive** (`intake`, `specifier`) — they need a live
     conversation the subagent cannot hold;
   - a **hard gate** is pending: `NEEDS_HUMAN` | `BLOCKED` | `AWAITING_COMMIT`, or a plan
     awaiting approval;
   - the **`stop-at`** boundary is reached.
4. Otherwise **dispatch the phase agent as a subagent**:
   - **Model:** resolve `models.agents[<agent>].tier`, then
     `models.mapping[tier][<your-cli>]`. On Claude Code, dispatch by the agent's subagent
     type so its `.claude/agents/<agent>.md` model applies; on OpenCode, its
     `.opencode/agent/<agent>.md` model applies.
   - **Effort** is advisory: fold `models.agents[<agent>].effort` into the brief
     (e.g. "think harder for a high-effort review"). `model` is the routed knob.
   - **Brief (isolated):** task id, phase, and the "Read first / Do / Stop when /
     Expected writes" from `next.md`. Do not paste your history.
   - **Instruction:** follow the normal shutdown protocol before returning.
5. **Integrate:** re-read `state.md`.
   - verdict `CHANGES_REQUESTED` → next agent is `implementer` (loop);
   - `BLOCKED` | `NEEDS_HUMAN` → pause, surface to the human;
   - task `APPROVED` | `DONE` → stop;
   - else advance to the next phase.
6. Repeat from step 2 — **unless running in step mode** (see below).

## Step mode (single-phase dispatch)

The human decides the granularity per invocation — this is a human-control point,
not an optimization:

- **`Run only the next phase ...`** (or `/task-step`): execute ONE iteration of the
  loop — steps 1–5 — then STOP and hand back, reporting what ran and what the next
  phase would be. Never advance to the next phase, even if no gate is pending.
- **`Orchestrate ...`** (or `/orchestrate`): loop until a gate, an interactive phase,
  a `stop-at`, or `DONE`.

Everything else (briefs, model resolution, gates, commit modes) is identical in both
modes. Step mode pairs well with a cheap main-session model: the coordination work is
mechanical, and the dispatched subagent carries its own model from the adapters.

## Commit modes

- `human-gated` (default): pause at each commit boundary (`AWAITING_COMMIT`); the human
  commits, then re-invoke to continue.
- `agent` (recommended for full fluidity): the `implementer` subagent commits at
  boundaries and the loop continues. Push is always human.

## Manual fallback (no subagent dispatch)

Do not dispatch. For each phase, resolve the agent's model/effort as above, write it into
`next.md`'s "Agent to use", and tell the human to run that phase (optionally in a new
session with that model). The pipeline still advances through the repo state — just with
the human as the dispatcher.

## Never

Override the git rules, the plan-approval gate, or the commit mode; auto-resolve
`NEEDS_HUMAN`/`BLOCKED`; push; or run interactive phases as subagents.
