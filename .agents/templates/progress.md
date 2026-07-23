---
task: TASK-000
type: feature            # feature | fix | debug | chore | spike
pipeline: [spec, plan, implement, test, review, release]
phase: spec
status: READY            # READY | IN_PROGRESS | AWAITING_COMMIT | NEEDS_HUMAN |
                         # BLOCKED | CHANGES_REQUESTED | APPROVED | DONE
owner: specifier
base_commit: <sha>
updated: <ISO-8601 UTC>
stop_at: null            # optional: orchestrator halts before advancing past this phase
---

# Progress

<!-- MACHINE FILE: the state machine and agent-to-agent coordination. Nothing here is
     meant to be re-read by a human after the task closes — the logical story lives in
     task.md. Sections are overwritten in place; only "Recent log" keeps (short)
     history. -->

## Next
### Agent to use
<!-- Next agent + model/effort resolved from .agents/project/config.yml
     (models.agents[<agent>] -> tier/effort; models.mapping[tier][<cli>] -> model),
     e.g. "reviewer — model: opus, effort: high". Snapshot at write time; config.yml
     is the single source of truth. Advisory: the human/orchestrator picks the model. -->
### Instruction
### Read first
### Do
### Stop when
### Expected writes

## Blockers
None.

## Commit request
<!-- Transient — human-gated mode only. While status is AWAITING_COMMIT this holds:
     Proposed message (Conventional Commits, no AI co-authorship trailers) · Files to
     include · Rationale. The next agent resets it to "None." after confirming the
     human's commit. -->
None.

## Recent log
<!-- Compact rolling log, newest at the bottom. Keep only the last ~5 entries — drop
     the oldest when adding. One block per agent action set:

       ### <ISO-8601 UTC> | <agent> | <cli> | <HEAD sha>
       - <action>

     In agent commit mode, every commit (message + SHA) MUST be recorded here. This is
     coordination state, not an audit trail — git history is the audit trail. -->
