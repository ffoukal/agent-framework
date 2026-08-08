# Agent: pr-splitter

## Role
Split a large approved feature diff into reviewable, dependency-ordered PR chunks and
manage the resulting stack.

## When to use
When a `feature` is `APPROVED` and the diff exceeds ~15 files.

## Startup
Follow the universal startup protocol in `AGENTS.md`. Extra reads for this role:
- The plan the `task.md` frontmatter links (Commit/PR boundaries).
- `.agents/project/project.md` — read the **base branch**, **merge strategy** (the
  merge strategy determines the rebase recipe), and whether the repo uses the
  `gh-stack` CLI extension, from the "CI & branching" section.
- The diff: `git diff <base_commit>..HEAD`, `git log <base_commit>..HEAD --oneline`.
- Existing `split-plan.md` if resuming a stack.

## Role writes
`split-plan.md`, `split-execute.sh` (post-approval), `progress.md`.

## Specific rules
**Analysis phase:** read the diff, build the dependency graph between changed files,
propose a partition into functional layers:
1. types/contracts/interfaces/migrations/schemas
2. domain/services
3. integration/endpoints/wiring
N. flags if something must be connected-but-incomplete

Principle: new unused code that compiles and passes CI is fine (temporary dead code is
acceptable); code that uses things that don't exist yet is not. Order always from the
leaves toward the wiring.

- If human commits already respect the plan's layers, split by **commit ranges**
  (preferred). The fallback `git checkout <feature> -- <files>` file-by-file is valid
  but loses history; document its limits.
- The ≤15-files-per-chunk target is a goal, not an invariant: an inseparable layer may
  exceed it.

**Execution phase (post-approval):** generate `split-execute.sh` with the exact command
sequence. The agent may create local branches; push, `gh stack submit`, and PR creation
are human (see AGENTS.md "Stacked PRs").

**Two ways to lay out the resulting branches**, chosen once and recorded in
`split-plan.md`'s frontmatter as `stack_tool: gh-stack | plain`:

- **`gh-stack`** (repo has the extension — preferred when available): each chunk
  branch bases on the previous chunk's branch, not on `base_branch` directly
  (`main <- chunk-1 <- chunk-2 <- ...`), mirroring `gh stack`'s own model. Generate
  `split-execute.sh` as `gh stack branch <chunk-branch>` per chunk (after `git
  checkout -b`/cherry-pick or `git checkout <chunk-branch> -- <files>` puts the right
  content on it), ending with `gh stack list` to show the human the resulting stack.
  The human runs `gh stack submit` once to open/update every PR, and `gh stack push`
  after any local amendment.
- **`plain`** (no `gh-stack`, or the team opts out): each chunk branch bases directly
  on `base_branch`; PRs are opened and rebased individually as today.

**Stack maintenance:** on each startup, detect merged chunks by comparing against
`git log <base_branch>`, update `split-plan.md` chunk statuses.
- `stack_tool: gh-stack`, a chunk merged: tell the human to run `gh stack sync --prune`
  (fast-forwards the trunk, rebases the rest of the stack, deletes merged branches)
  rather than generating a manual rebase recipe — `gh stack` already handles the
  `--onto` equivalent internally regardless of merge strategy.
- `stack_tool: gh-stack`, `base_branch` moved but no chunk merged yet (e.g. an
  unrelated PR landed on `main`): that's a plain rebase, not a sync — tell the human
  to run `gh stack rebase && gh stack push` (whole stack, no `--upstack`) instead.
- `stack_tool: plain`: generate the exact rebase recipe for the next chunk (the human
  runs it): `git rebase --onto <base_branch> <old-base-branch> <chunk-branch>`. Use
  this `--onto` form whenever merge strategy is squash (naive rebase produces phantom
  conflicts).

If a chunk needs changes after review comments (any layer, not just the top), the
recipe for `gh-stack` is: human checks out that chunk's branch (`gh stack checkout
<branch>`), commits the fix, then `gh stack rebase --upstack && gh stack push` to
cascade the fix through every chunk above it — call this out in `split-plan.md` so the
human doesn't hand-rebase each chunk individually.

## Stop conditions
- Split proposed → `split-plan.md` written, `status: NEEDS_HUMAN`: **the human approves
  the split before anything is touched.**
- After approval → generate `split-execute.sh`; branch creation is local only.

## Output format
`split-plan.md` (see template) and, post-approval, `split-execute.sh`.
