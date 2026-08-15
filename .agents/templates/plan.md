# Plan

<!-- Durable plan for this feature. Lives at docs/plans/YYYY-MM-DD-<task-name>.md and is
     linked from the task.md frontmatter (plan:). Approved by the human before
     implementation (gate 2). -->

## Goal

## Context used
<!-- Which project.md / memory / code files informed this plan. -->

## Assumptions

## Tasks
<!-- The feature list: the scheduler, the gate and the handoff all read THIS.
     One `### Tn` block per Task, sized to finish in one dispatch. Three fields, all
     mandatory — a Task without a runnable `verify` is not a Task, it is a wish.

     Agents do not hand-edit this section: `agent-plan next` returns the Task to work
     on, `agent-plan set Tn <state> "<evidence>"` moves it. The script enforces WIP=1
     (one `active` Task) and refuses `done` without evidence, so nobody has to
     remember either rule. Nobody reads the whole plan to find the next Task. -->

### T1 — <observable behavior, one line>
- verify: `.agents/scripts/agent-test one <pattern>`
- state: todo          <!-- todo | active | blocked | done -->
- evidence: —          <!-- <sha> · <compact result>; written when it goes done -->

### T2 — <...>
- verify: `.agents/scripts/agent-verify e2e`
- state: todo
- evidence: —

## Files likely to change

## Verification level
<!-- The gate the whole plan must clear before review. quick | full | e2e.
     e2e is REQUIRED when the change crosses a layer boundary (UI↔service,
     service↔store, process↔process) — that is exactly where mocked tests are blind. -->
- level: full

## Risks

## Acceptance criteria

## Commit/PR boundaries
<!-- Delivery layers designed for the split, leaves toward wiring:
     1. contracts / types / interfaces / migrations / schemas
     2. domain / services
     3. integration / endpoints / wiring
     N. flags if something must stay connected-but-incomplete
     Reference Task ids (e.g. "boundary 1: T1-T3") so the orchestrator knows which
     Task closes each boundary. -->

## Human approval required
This plan must be approved by the human before implementation begins.
