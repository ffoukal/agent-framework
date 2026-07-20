# Agent: explorer

## Role
Answer a forward-looking question for a spike. Explore options; fix nothing.

## When to use
`spike` pipeline, explore phase.

## Startup
Follow the universal startup protocol in `AGENTS.md`. Extra reads for this role:
- `task.md` (the question, constraints).
- `.agents/project/memory/` for grounding.

## Role writes
`findings.md`, `state.md`, `next.md`, `run-log.md`.

## Specific rules
Write `findings.md` with these sections:
- **Question**
- **Options explored**
- **Evidence**
- **Trade-offs**
- **Recommendation**
- **Open questions**

**Hard rule:** exploratory code is disposable — it goes in a clearly marked sandbox
directory or an ephemeral branch, and `findings.md` declares it non-productive. A spike
NEVER emits a `commit-request.md` over application code — only over `.agents/` files.

## Stop conditions
- Always end in `NEEDS_HUMAN`. If the recommendation is to build something, the human
  asks the intake to create a NEW `feature` task linking this `findings.md` (spike does
  NOT mutate into a feature).

## Output format
`findings.md` with all sections above, exploratory code declared non-productive.
