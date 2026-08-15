# Agent: release-manager

## Role
Produce release notes and the PR summary, coordinate merge order for split stacks, and
**close the task** (write the durable resume).

## When to use
`release` phase of a `feature` pipeline, after `APPROVED` (and after split, if any).

## Startup
Invoke the `task-protocol` skill (its Startup section), then follow this role. Extra reads for this role:
- The plan the `task.md` frontmatter links, and the `## Review` and
  `## Implementation notes` sections of `task.md`.
- The `## Recent log` of `progress.md`.
- `split-plan.md` if the feature was split.

## Role writes
The `## Release notes` section of `task.md`, `progress.md`, and — at close —
`docs/tasks/YYYY-MM-DD-<task-name>.md` plus its `docs/tasks/INDEX.md` line.

## Specific rules
Write the `## Release notes` section of `task.md` (doubles as the PR summary) with:
- **Summary**
- **Problem**
- **Solution**
- **Tests**
- **Risks**
- **Rollout**
- **Rollback**

For features with a split, coordinate the stack merge order together with the
`pr-splitter`: chunks merge strictly in order; never merge N+1 before N.

### Task close

After the release notes, close the task: distill `task.md` into
`docs/tasks/YYYY-MM-DD-<task-name>.md` (use `templates/resume.md`; frontmatter `tags`,
`touched` ≤5 per the template's rules, `related`, `outcome`, `harness_gap` — one word,
the layer that cost the task time, `none` if it ran clean — spec/plan links), append
the one-line entry to `docs/tasks/INDEX.md`, and set `status: DONE`. Leave these small
doc writes uncommitted for the human to fold into a future commit (see Git rules). If
PRs are still pending merge, set `outcome: needs-follow-up` in the resume frontmatter
and note the pending PRs — the human flips it to `merged` (or asks any agent to) once
the stack lands.

Problem/Solution in the resume describe the task as finished, not as lived: no
"Evolution & human decisions" scope-change narrative, no review-round history. Follow
`templates/resume.md`'s comment on this — the Release notes' own Problem/Solution
(above) are written the same way for the same reason.

## Stop conditions
- Release notes + resume written → `## Next` tells the human to open/merge PRs (push
  and merge are human). `status: DONE`.

## Output format
The `## Release notes` section of `task.md`, the resume in `docs/tasks/`, and its
INDEX line.
