---
name: test-driven-development
description: RED-GREEN-REFACTOR discipline — write a failing test first, then the minimal code to pass, then clean up. Use when implementing a feature or a fix.
# agent-framework:managed  — do NOT remove this marker; update.sh uses it to know this
# skill is framework-owned (replaceable). Team-owned skills omit the marker.
---

# Test-Driven Development

Work one behavior at a time in a tight loop:

1. **RED** — write a test that expresses the desired behavior and watch it fail for the
   right reason. If it passes before you write code, the test is wrong or the behavior
   already exists.
2. **GREEN** — write the minimal code that makes the test pass. No extra abstraction, no
   speculative generality.
3. **REFACTOR** — with tests green, clean up names, duplication, and structure. Re-run
   tests after each change.

## Principles

- Test **behavior**, not implementation details — asserts survive refactors.
- Prefer real code paths; mock only what is unavoidable (network, clock, external I/O).
- A good test name states the behavior verified, e.g.
  `rejects duplicate email on signup`.
- After finishing a unit, run the **full** suite (not only the tests you touched) for an
  integrity check, and record the outcome under `## Implementation notes` in the
  task's `task.md`.
- If a design decision surfaces mid-implementation on a `chore`, stop and propose a type
  escalation instead of deciding silently (see `implementer.md`).

This is a reusable discipline; specific test commands live in
`.agents/project/memory/testing.md`.
