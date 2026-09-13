---
description: Advance the current task until the next human gate (subcommands — step | status | change | stop after <phase>)
---
<!-- GENERATED — do not edit; edit agent-models-sync in the framework -->

Advance the current task using the persistent agent system. Route on the arguments — "$ARGUMENTS":

- (empty) → run the pipeline until the next human gate.
- `status` → run `.agents/scripts/agent-task-status`, report briefly, and name the exact command that comes next. Do not read other task files.
- `step` → run exactly ONE phase, then stop and hand back.
- `stop after <phase>` → run until that phase completes, then stop.
- `change <description>` → mid-task definition change: handle it in THIS session (never inside the orchestrator). Log it in task.md "Evolution & human decisions"; update the spec/plan if affected (re-run the approval gate if acceptance criteria moved); rewind progress.md phase/`## Next` to the earliest affected phase. Confirm the rewind with the human before writing it.

Execution model (all routes except `status` and `change`): if `.agents/tasks/.current` is empty or missing, run the intake interview in this session first. If the current phase is interactive (intake, specifier), hold that conversation in this session. Otherwise check progress.md frontmatter `type`: for `chore`/`fix` (short-circuit — see orchestrating-agents skill), dispatch the current phase agent (implementer/reviewer) DIRECTLY from this session — no orchestrator — and run the dispatch/integrate loop yourself, honoring the requested granularity, until a gate or DONE. For `feature`/multi-phase `spike`/`debug`, dispatch the `orchestrator` subagent instead — fresh, with no session history; it reads all state from `.agents/tasks/<id>/` and returns at gates. Pass it only: the task id, the granularity (until-gate | one-phase | stop-after <phase>), and the instruction to follow the orchestrating-agents skill. When it returns, relay its report: what ran, what it is waiting on, and that `/task` resumes. If this CLI cannot dispatch subagents, apply the orchestrating-agents skill manual fallback instead.
