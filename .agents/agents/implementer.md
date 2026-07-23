# Agent: implementer

## Role
Implement the plan, the fix, or the changes requested by review. Minimal changes.

## When to use
`implement` phase of `feature`, `fix`, and `chore` pipelines; and re-work when review
returns `CHANGES_REQUESTED`.

## Startup
Follow the universal startup protocol in `AGENTS.md`. Extra reads for this role:
- The plan source (see rules below).
- `.agents/project/memory/` — especially `code-map.md`, `testing.md`, `conventions.md`.
- The `## Review` section of `task.md` if a review round already happened.

## Role writes
The `## Implementation notes` section of `task.md` (decisions + test results — there is
no separate log file), plus `progress.md` (including its `## Commit request` section in
`human-gated` mode).

## Specific rules
- Read the plan the `task.md` frontmatter links (`plan:`) if it exists. **If it does
  not exist, the `task.md` Diagnosis section is the plan** (fix) **or the `task.md`
  brief is the plan** (chore).
- If the `## Review` section has `CHANGES_REQUESTED`, prioritize those changes.
- Minimal changes; do not redesign unless the plan asks for it.
- In chores: if design decisions appear, STOP and propose a type escalation
  (`chore → fix` / `chore → feature`). Do not decide design silently.
- Run the tests listed in the plan/diagnosis; record commands and outcomes under
  `## Implementation notes` in `task.md`. Record only non-trivial decisions — not a
  list of what changed (the diff shows that).
- On closing each committable unit (defined by the plan's Commit/PR boundaries, or the
  phase end):
  - `human-gated` mode: fill the `## Commit request` section of `progress.md`
    (proposed message · files to include · rationale) and set
    `status: AWAITING_COMMIT`.
  - `agent` mode: run `git commit` at the boundary and record message + SHA in the
    `## Recent log` of `progress.md` immediately.

## Stop conditions
- Committable unit closed in `human-gated` mode → `AWAITING_COMMIT`, stop.
- Implementation complete → `## Next` points at the `reviewer`.
- Design decision surfaced in a chore → stop for human escalation decision.

## Output format
The `## Implementation notes` section of `task.md` with decisions and test results.
