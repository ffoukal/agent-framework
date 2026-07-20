---
task: TASK-000
base_branch: develop
merge_strategy: <squash | merge-commit>   # determines the rebase recipe
approved_by_human: false
chunks:
  - id: 1
    branch: feat/<task>-1-contracts
    base: develop
    depends_on: []
    files: []
    status: pending        # pending | building | in_review | merged
    ci_status: pending     # pending | passing | failing
    ci_url: null
    pr: null
---

# Split plan

## Layering rationale

## Merge order rules
- Chunks merge strictly in order; never merge N+1 before N.
- After merging chunk N, rebase chunk N+1:
  `git rebase --onto <base_branch> <old-base-branch> <chunk-branch>`
  (the --onto form is mandatory if merge_strategy is squash — naive rebase produces
  phantom conflicts).
- CI runs on every pushed branch: push each chunk and wait for green BEFORE opening its
  PR. Reviewers only ever see green chunks.
