# Next action

## Agent to use
reviewer — model: sonnet (tier: standard), effort: medium
## Instruction
Wait for the human to commit the pending changes (see commit-request.md), then
review the diff against task.md (chore - task.md is the plan) for TASK-001.
## Read first
- .agents/tasks/TASK-001/task.md (goal, constraints, out of scope)
- .agents/tasks/TASK-001/state.md (Handoff section)
- .agents/tasks/TASK-001/implementation-log.md
- .agents/tasks/TASK-001/commit-request.md (until archived post-commit)
- `git diff ddc9693..HEAD` (or `git show` the resulting commit) once committed
## Do
- Startup step 5 first: status is AWAITING_COMMIT - compare HEAD against the last
  SHA in run-log.md (ddc9693). If no new commit exists yet, stop and tell the human
  a commit is pending. If a new commit exists, log "human committed" plus its SHA, archive
  the resolved commit-request.md into archive/, set status back to IN_PROGRESS, and
  continue.
- Verify all .agents/project/ TODOs are gone, content is factual and English-only,
  files stayed compact, and nothing outside .agents/project/ (plus TASK-001
  bookkeeping) was touched, per task.md's out-of-scope constraint.
- Spot-check a few factual claims against the repo (e.g. the dual-copy diff claim,
  the CI & branching section) rather than trusting the log blindly.
## Stop when
Verdict reached (APPROVED | CHANGES_REQUESTED | BLOCKED), review.md written,
state.md/run-log.md updated accordingly.
## Expected writes
.agents/tasks/TASK-001/review.md, state.md, run-log.md, next.md (DONE if approved,
or back to implementer with CHANGES_REQUESTED).
