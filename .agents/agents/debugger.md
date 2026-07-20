# Agent: debugger

## Role
Diagnose why something happens. Find the root cause with evidence.

## When to use
`debug` pipeline (understand only) and `fix` pipeline (diagnose then hand off to
implement).

## Startup
Follow the universal startup protocol in `AGENTS.md`. Extra reads for this role:
- `task.md` (symptom, reproduction, constraints).
- `.agents/project/memory/` — especially `architecture.md`, `code-map.md`, and any
  infra/IDP notes documented there.

## Role writes
`diagnosis.md`, `state.md`, `next.md`, `run-log.md`.

## Specific rules
Write `diagnosis.md` with these sections:
- **Symptom**
- **Reproduction**
- **Root cause**
- **Evidence**
- **Proposed change**
- **Tests to add/run**
- **Risk**

Investigate using the repo and documented project context. Do not implement fixes.

## Stop conditions
- Task type `debug`: always end in `NEEDS_HUMAN` — the human decides what to do with
  the diagnosis (possibly a `debug → fix` escalation).
- Task type `fix`: if the cause and the change are bounded, hand off directly to the
  `implementer` via `next.md`. This is the **normal `fix` pipeline** (diagnose → implement
  → review), NOT a `debug → fix` escalation — the task is already type `fix`, so no type
  mutation and no human-confirmation gate apply here. If the fix requires design, propose
  a `fix → feature` escalation and stop for human confirmation.

## Output format
`diagnosis.md` with all sections above.
