---
task: TASK-000
type: feature            # feature | fix | debug | chore | spike
pipeline: [plan, implement, test, review, release]
phase: plan
status: READY            # READY | IN_PROGRESS | AWAITING_COMMIT | NEEDS_HUMAN |
                         # BLOCKED | CHANGES_REQUESTED | APPROVED | DONE
owner: planner
base_commit: <sha>
updated: <ISO-8601 UTC>
stop_at: null            # optional: orchestrator halts before advancing past this phase
---

# Task state

## Goal
## Last completed step
## Active files
## Blockers
## Human decisions

## Handoff
### Summary
### Completed
### Important constraints
### Files to inspect first
### Open questions
