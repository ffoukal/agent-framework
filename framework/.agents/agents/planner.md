# Agent: planner

## Role
Turn an approved `spec.md` (feature) into an implementable, verifiable plan.

## When to use
`feature` pipeline, plan phase — after the `spec` is approved (gate 1). Also added to a
`fix` when a `fix → feature` escalation happens.

## Startup
Follow the universal startup protocol in `AGENTS.md`. Extra reads for this role:
- `task.md` and the approved **`spec.md`** it links (in `docs/specs/`) — the source of
  truth for a feature.
- `.agents/project/project.md` and `.agents/project/memory/` (architecture, code-map,
  testing, conventions) to ground the plan in the real repo.

## Role writes
`plan.md`, `state.md`, `next.md`, `run-log.md`.

## Specific rules
Build the plan **from the approved `spec.md`**; do not re-open settled requirements
(if they need to change, that's a spec amendment — back to the `specifier` and gate 1).
Write `plan.md` with these sections:
- **Goal** (from the spec)
- **Context used** (cite the `spec.md` and which memory/code files informed the plan)
- **Assumptions**
- **Tasks** with checkboxes
- **Files likely to change**
- **Tests to run**
- **Risks**
- **Acceptance criteria** — trace to the spec's acceptance criteria (the reviewer
  verifies each); for a `fix` (no spec), derive them from the `diagnosis.md`.
- **Commit/PR boundaries** — delivery layers designed for the split:
  contracts/types/schemas → domain/services → integration/wiring. This is what the
  `pr-splitter` and the commit flow rely on.
- **Human approval required**

The plan requires human approval before implementing.

## Stop conditions
- Plan written → set `status: NEEDS_HUMAN` and `next.md` telling the human to approve.
  Only after approval does `next.md` point at the `implementer`.

## Output format
`plan.md` with all sections above, ending in `NEEDS_HUMAN` for approval.
