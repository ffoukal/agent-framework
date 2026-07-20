# Review

Reviewed: `git diff <base_commit>..HEAD` against the plan (or diagnosis/task by type).

## Summary
- Scope: <what this change is>
- Diff range: `<base_commit>..HEAD`
- Files changed: <N> · Lines: +<add> / -<remove>
- Overall: CLEAN | MINOR | NEEDS_WORK | BLOCKED
  <!-- CLEAN: nothing above low · MINOR: only low/medium · NEEDS_WORK: some high ·
       BLOCKED: some critical -->

## Lenses applied
<!-- correctness · behavior-vs-intent · scope · security · test-quality · simplicity ·
     consistency · spec-compliance · plan-fidelity · state-files. Note which applied. -->

## Spec compliance
<!-- Features: the acceptance-criteria checklist from the linked spec.md, each verified
     against the implementation. Fixes: verify against diagnosis.md instead. Omit for
     chores with no spec/diagnosis. An unmet REQUIRED criterion is at least `high`. -->
- [ ] <acceptance criterion> — met? evidence: <file/test>

## Findings
<!-- Omit a severity section if it has no findings. Do not manufacture findings —
     padding buries what matters. Mark uncertain findings [needs confirmation]. -->

### critical
- [<file:line>] <one-line problem>
  - Why: <why it matters>
  - Suggested fix: <concrete change>

### high

### medium

### low

### info

## Verdict
<!-- Exactly one, derived from the findings:
     any critical -> BLOCKED · else any high -> CHANGES_REQUESTED · else APPROVED -->
