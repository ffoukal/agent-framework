---
name: conventional-commits
description: Conventional Commits message format for a consistent, machine-parseable git history. Use when writing a commit message or a commit-request proposal.
# agent-framework:managed  — do NOT remove this marker; update.sh uses it to know this
# skill is framework-owned (replaceable). Team-owned skills omit the marker.
---

# Conventional Commits

Write commit messages as:

```
<type>(<optional scope>): <imperative subject>

<optional body>

<optional footer>
```

## Types

`feat` · `fix` · `refactor` · `perf` · `test` · `docs` · `build` · `ci` · `chore`

## Rules

- Subject in the imperative mood ("add", not "added"/"adds"), ≤ ~72 chars, no trailing period.
- `scope` is optional and names the area touched, e.g. `feat(auth): ...`.
- Breaking change: append `!` after type/scope (`feat!:`) OR add a `BREAKING CHANGE:`
  footer line describing the break.
- One logical change per commit; the boundary is the plan's Commit/PR boundaries or the
  phase end — never micro-commits.
- **No AI co-authorship trailers or attribution lines** (see `AGENTS.md` §4.3.1).

## Examples

```
feat(import): accept CSV uploads for bulk user creation
fix(auth): reject expired tokens before hitting the DB
refactor(payments)!: split PaymentService into charge/refund

BREAKING CHANGE: PaymentService.process() is removed; use charge()/refund().
```

This is guidance, not enforced by tooling. A repo may override the convention in
`project.md` under "Project-specific rules".
