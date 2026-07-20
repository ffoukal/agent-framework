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
- `review.md` if it exists.

## Role writes
`implementation-log.md` (includes a `## Test results` section — there is no separate
test-results file), `state.md`, `next.md`, `run-log.md`, and — in `human-gated` mode —
`commit-request.md`.

## Specific rules
- Read `plan.md` if it exists. **If it does not exist, `diagnosis.md` is the plan**
  (fix) **or `task.md` is the plan** (chore).
- If `review.md` has `CHANGES_REQUESTED`, prioritize those changes.
- Minimal changes; do not redesign unless the plan asks for it.
- In chores: if design decisions appear, STOP and propose a type escalation
  (`chore → fix` / `chore → feature`). Do not decide design silently.
- Run the tests listed in the plan/diagnosis; record outcomes in the
  `## Test results` section of `implementation-log.md`.
- On closing each committable unit (defined by the plan's Commit/PR boundaries, or the
  phase end):
  - `human-gated` mode: emit `commit-request.md` and set `status: AWAITING_COMMIT`.
  - `agent` mode: run `git commit` at the boundary and record message + SHA in
    `run-log.md` immediately (no `commit-request.md`).

## Stop conditions
- Committable unit closed in `human-gated` mode → `AWAITING_COMMIT`, stop.
- Implementation complete → `next.md` points at the `reviewer`.
- Design decision surfaced in a chore → stop for human escalation decision.

## Output format
`implementation-log.md` with a description of changes and a `## Test results` section.
