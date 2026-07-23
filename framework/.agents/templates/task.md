---
task: TASK-000
type: feature            # feature | fix | debug | chore | spike
created: <ISO-8601>
spec: null               # feature: docs/specs/YYYY-MM-DD-<task-name>.md
plan: null               # feature: docs/plans/YYYY-MM-DD-<task-name>.md
---

# Task <TASK_ID>

<!-- The LIVING LOGICAL DOCUMENT of the task: the brief plus how the work actually
     evolved — decisions, diagnosis, findings, reviews. At close, the terminal agent
     distills THIS file into docs/tasks/YYYY-MM-DD-<task-name>.md (the durable
     resume). Keep it factual and compact.
     Sections marked for a type apply only to that type: the intake deletes the ones
     that do not apply when creating the task. -->

## Goal

## Background

## Constraints

## Out of scope

## Links
<!-- Related resumes from docs/tasks/ (intake recall step), a spike's findings this
     feature derives from, tickets, etc. Spec/plan go in the frontmatter. -->

## Evolution & human decisions
<!-- Append-only. Direction changes, scope fine-tuning, mid-task human requests,
     type escalations. One dated entry per change: what changed and why. -->

## Diagnosis
<!-- fix/debug only. Symptom · Reproduction · Root cause · Evidence ·
     Proposed change · Tests to add/run · Risk. -->

## Findings
<!-- spike only. Question · Options explored · Evidence · Trade-offs ·
     Recommendation · Open questions. Exploratory code is disposable and
     non-productive — it never ships. -->

## Implementation notes
<!-- Non-trivial decisions made while implementing, plus test results (commands run
     and outcomes). NOT a list of what changed — the diff already shows that. -->

## Review
<!-- Written by the reviewer (structure and severity scale in reviewer.md). Findings
     by severity ([file:line] · why it matters · suggested fix) and one verdict per
     round: APPROVED | CHANGES_REQUESTED | BLOCKED. A new round replaces findings
     already resolved (note "round N: X findings resolved") instead of accumulating
     verbatim. -->

## Security review
<!-- Only when the pipeline has a security-review phase. Same findings/verdict
     format as Review (structure in security-reviewer.md). -->

## Release notes
<!-- feature only. Summary · Problem · Solution · Tests · Risks · Rollout ·
     Rollback. Doubles as the PR summary. -->
