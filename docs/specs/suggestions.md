# Agent Framework Improvement Suggestions

> **STATUS: RESOLVED (2026-07-19).** All items below are implemented in the framework:
> 1a/1b/1c/1d, 5, 8 in `agent-task-check` (timestamp quality, placeholder scan,
> next-agent validation, split-plan gate, mtime check removed, archival check);
> 2 and 6 in `intake.md` (script-only creation, mode-independent confirmation gate);
> 3 in `debugger.md` (fix-pipeline handoff is not an escalation);
> 4 in the `next.md` template (snapshot note, config.yml authoritative);
> 7 as `agent-task-status --all`; 9 in `orchestrator.md` (subagent brief template).
> Kept for historical reference only.

I've been using the persistent agent framework in production for a few hours and I want to share a comprehensive set of improvement suggestions. These range from bugs in validation to protocol ambiguities to UX friction. Please evaluate each one and decide what to implement.

## Context

I ran the intake agent on a new feature task. It worked overall but I found several gaps. I'll group them by type.

---

## 1. Validation gaps in `agent-task-check`

### 1a. `updated` timestamp is not validated for quality

The script `agent-task-new` correctly stamps `updated` using `date -u +%Y-%m-%dT%H:%M:%SZ`. But `intake.md` says agents may create task files "via `.agents/scripts/agent-task-new` **or** by creating the files from templates". An agent that creates files manually will often write `2026-07-17T00:00:00Z` (midnight = clearly zeroed) or leave the `<ISO-8601 UTC>` placeholder. `agent-task-check` parses the frontmatter but doesn't validate the timestamp.

**Suggested fix:** add two checks to `agent-task-check`:
1. The `updated` field does not contain angle brackets (`<`, `>`).
2. The time portion is not `T00:00:00Z` (likely zeroed).
   Warn (not fail) on the second — it could be legitimate at midnight UTC but is almost always wrong.

### 1b. Unreplaced template placeholders are not detected

If an agent creates files manually from templates, placeholders like `<ISO-8601>`, `<sha>`, `<ISO-8601 UTC>`, `TASK-000`, `<TASK_ID>` may survive into the committed files. `agent-task-check` never scans for them.

**Suggested fix:** add a check that greps `task.md`, `state.md`, `next.md` for `<[A-Z_-]\+>` or `TASK-000` and fails if found.

### 1c. Agent name in `next.md` is not validated against `config.yml`

A stale or hallucinated agent name in `next.md` goes undetected until a human tries to open the next session. `agent-task-check` already parses `config.yml` to validate all agents have tier/effort entries — it should reuse that logic to verify that the agent named in `next.md` exists.

**Suggested fix:** extract the agent name from `next.md` (pattern: the first word on the `## Agent to use` line's content), then check it appears as a key under `models.agents` in `config.yml`. Warn if not found (not fail, since the field has advisory text like "reviewer — model: opus").

### 1d. `split-plan.md` approval gate is not validated

The `split-plan.md` template has `approved_by_human: false`. The pr-splitter must stop at `NEEDS_HUMAN` until the human approves. But there's no check that prevents an agent from reading `approved_by_human: false` and proceeding anyway. `agent-task-check` could detect: if `split-plan.md` exists AND `approved_by_human: false` AND `status` is not `NEEDS_HUMAN`, that's a protocol violation.

---

## 2. Protocol ambiguity: manual task creation vs. script

`intake.md` says: "Only THEN create the task (via `.agents/scripts/agent-task-new` **or** by creating the files from templates)."

The `or` clause is the problem. `agent-task-new` correctly stamps `updated`, `base_commit`, replaces all placeholders, and creates the `archive/` subdirectory. An agent that goes the manual route risks wrong timestamps, unreplaced placeholders, and a missing `archive/`. In practice the intake agent I ran went manual and wrote a zeroed timestamp.

**Suggested fix:** remove the "or by creating the files from templates" alternative from `intake.md`. Make `agent-task-new` the only prescribed path, and add a note: "If the script is not executable, make it executable with `chmod +x .agents/scripts/agent-task-new` and retry — do not create files manually."

---

## 3. Protocol ambiguity: `debug → fix` escalation conflicts with AGENTS.md

`debugger.md` says: "Task type `fix`: if the cause and the change are bounded, hand off directly to the `implementer` via `next.md`."

`AGENTS.md` says: "Valid escalation routes (always with explicit human confirmation, logged in `run-log.md` and in `project/memory/decisions.md`)."

These conflict. A `debug → fix` escalation is listed as requiring explicit human confirmation in `AGENTS.md`, but `debugger.md` implies the agent can hand off directly without stopping.

**Suggested fix:** reconcile in `debugger.md`. Either:
- (preferred) Keep the stop: "If the cause and fix are bounded, set `status: NEEDS_HUMAN` with a `next.md` proposing `fix` escalation. The human confirms, then the next agent mutates `type` in `state.md` and continues."
- (alternative) Explicitly call out `debug → fix` as the one escalation route that does NOT require confirmation (since the debugger can't implement anyway, the implementer won't start without a new session).

---

## 4. `next.md` duplicates `config.yml` model resolution at write time

Agents resolve `planner → opus, effort: medium` from `config.yml` and write it into `next.md`. If someone later edits `config.yml` (the single source of truth), all in-flight `next.md` files are stale. The README says: "Advisory: the human picks the model" — so the resolution in `next.md` is advisory, but stale advice is confusing.

Two options:
- **Option A (lighter):** In the `next.md` template, change `## Agent to use` to have a comment: "Name the agent only; look up its model/effort in `.agents/project/config.yml` at open time." Have agents write just the agent name (e.g., `planner`), not the resolved model. The human looks it up when opening the session.
- **Option B (heavier):** Add an `agent-task-next` subcommand that prints the agent name AND resolves the current model from `config.yml` live, so the human always gets fresh resolution.

Option A requires no new tooling. Option B is more convenient but adds a dependency on `yq` or manual grep.

---

## 5. `run-log.md` staleness check is unreliable

In `agent-task-check`:
```bash
if [ -f "$STATE" ] && [ "$STATE" -nt "$RUNLOG" ]; then
  warn "run-log.md is older than state.md — did you forget to log this step?"
fi
```

In the shutdown protocol, agents typically write `state.md` first, then `run-log.md`. If both happen in the same second (common), `-nt` is unreliable across filesystems. This produces false positives. The warning has low signal-to-noise ratio in practice.

**Suggested fix:** flip the check: warn only if `run-log.md` has zero `## ` entries after `state.md` has been written (i.e., the task has content but no log). Or remove the `-nt` filesystem check entirely and rely on the `RUNLOG_ENTRIES -lt 1` check that already exists.

---

## 6. Human confirmation gate for intake is skippable in auto mode

`intake.md` says: "Propose a summary: suggested task id, type, one-sentence goal, pipeline. The human confirms. Only THEN create the task."

When the intake agent is dispatched as a subagent in auto mode (e.g., via the orchestrator or a background agent dispatch), it has no natural pause point. In practice it creates the task without stopping for confirmation, which violates the "only THEN" rule.

**Suggested fix:** add an explicit rule to `intake.md`: "Even in auto mode, the intake MUST stop before creating the task and emit the proposed summary to the human. The intake is always interactive at the confirmation step, regardless of the mode the caller operates in." Also consider adding a note to the orchestrator agent that `intake` is always interactive and must not be dispatched as a non-interactive subagent.

---

## 7. No task index / navigation

`.agents/current-task` tracks only one active task. As tasks accumulate under `.agents/tasks/`, there's no easy way to list them, their statuses, or switch between them. `agent-task-status` works for the current task, but nothing gives an overview.

**Suggested fix (minimal):** extend `agent-task-status` with a `--list` or `--all` flag that prints one line per task directory: `<task-id> | <type> | <status> | <phase> | <updated>`. Extracted from each task's `state.md` frontmatter. No new files needed.

---

## 8. `commit-request.md` archival: prescribed but unverified

`AGENTS.md` startup protocol step 5 says: "archive the resolved `commit-request.md`". But `agent-task-check` only checks that `commit-request.md` exists when `status = AWAITING_COMMIT`. There's no check that an OLD resolved `commit-request.md` (with `resolved: <sha>`) has been archived instead of lingering at the task root.

**Suggested fix:** add a check: if `commit-request.md` exists AND `resolved:` is NOT `null`, AND `status` is NOT `AWAITING_COMMIT`, then fail with "commit-request.md is resolved but not archived — move it to archive/".

---

## 9. Minor: `orchestrator.md` subagent brief has no prescribed template

The orchestrator dispatches each phase with "an isolated, hand-crafted brief". In practice every orchestrator invocation will craft this differently, leading to inconsistent subagent context quality. The `orchestrating-agents` skill likely covers this, but having at least a reference structure in `orchestrator.md` would help CLIs that don't have that skill loaded.

**Suggested fix:** add a brief template block to `orchestrator.md` under a `## Subagent brief template` section:
```
Task: <task-id>
Phase: <phase>
Read first: <list from next.md>
Do: <instruction from next.md>
Stop when: <stop-when from next.md>
Expected writes: <expected-writes from next.md>
Follow the full shutdown protocol (state.md, run-log.md, next.md, agent-task-check).
```

---

## Summary table

| # | Area | Type | Impact |
|---|------|------|--------|
| 1a | `agent-task-check` | Bug | Medium — silent invalid timestamps |
| 1b | `agent-task-check` | Bug | Medium — unreplaced placeholders survive |
| 1c | `agent-task-check` | Enhancement | Low — stale agent names detected at shutdown |
| 1d | `agent-task-check` | Enhancement | Low — split gate enforcement |
| 2 | `intake.md` + scripts | Protocol | High — manual creation bypasses script guarantees |
| 3 | `debugger.md` vs `AGENTS.md` | Protocol | Medium — conflicting escalation rules |
| 4 | `next.md` model resolution | Protocol | Low — advisory info goes stale |
| 5 | `run-log.md` staleness check | Bug | Low — false positive warnings |
| 6 | Intake confirmation in auto mode | Protocol | Medium — confirmation gate skippable |
| 7 | Task index | UX | Low — navigation quality of life |
| 8 | `commit-request.md` archival | Protocol | Low — cleanup enforcement |
| 9 | Orchestrator subagent brief | UX | Low — consistency across CLIs |
