# Security review

Reviewed: `git diff <base_commit>..HEAD` for sensitive surfaces.

## Summary
- Scope: <what this change touches>
- Diff range: `<base_commit>..HEAD`
- Surfaces: <secrets / auth / infra / migrations / permissions / ...>
- Overall: CLEAN | MINOR | NEEDS_WORK | BLOCKED

## Lenses applied
<!-- secrets · PII in logs · auth/authz · infrastructure · migrations · permissions ·
     dangerous configs · tool/MCP risks. Note which applied. -->

## Findings
<!-- Omit a severity section if empty. No padding. Mark uncertain [needs confirmation]. -->

### critical
- [<file:line>] <one-line problem>
  - Why: <why it matters>
  - Suggested fix: <concrete change>

### high

### medium

### low

### info

## Verdict
<!-- Exactly one, derived from findings:
     any critical -> BLOCKED · else any high -> CHANGES_REQUESTED · else APPROVED -->
