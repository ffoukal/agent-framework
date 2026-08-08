---
task: TASK-000
base_branch: develop
merge_strategy: <squash | merge-commit>   # determines the plain rebase recipe
stack_tool: <gh-stack | plain>            # gh-stack if the repo has the extension
approved_by_human: false
chunks:
  - id: 1
    branch: feat/<task>-1-contracts
    base: develop            # gh-stack: base of chunk N>1 is chunk N-1's branch
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
- `stack_tool: gh-stack` — human runs `gh stack submit` to open/update all PRs and
  `gh stack sync --prune` after each merge (fast-forwards trunk, rebases the rest,
  deletes merged branches); mid-stack review fixes go through `gh stack checkout
  <branch>` + commit + `gh stack rebase --upstack && gh stack push`; if `base_branch`
  moves without any chunk merging (e.g. an unrelated PR lands on it), that's
  `gh stack rebase && gh stack push` (whole stack, no `--upstack`) instead of a sync.
- `stack_tool: plain` — after merging chunk N, human rebases chunk N+1:
  `git rebase --onto <base_branch> <old-base-branch> <chunk-branch>`
  (the --onto form is mandatory if merge_strategy is squash — naive rebase produces
  phantom conflicts).
- CI runs on every pushed branch: push each chunk and wait for green BEFORE opening its
  PR. Reviewers only ever see green chunks.
