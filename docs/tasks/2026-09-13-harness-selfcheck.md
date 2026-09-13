---
task: harness-selfcheck
type: chore
date: 2026-09-13
tags: [ci, self-check, skills-linter, agent-models-sync, tooling]
touched: [.agents/scripts/agent-models-sync, .agents/scripts/agent-skill-check, .github/workflows/ci.yml]
related: []
outcome: done
harness_gap: none
spec: null
plan: null
---

# harness-selfcheck

## Problem

The framework generates and distributes tooling (`.claude/agents/` adapters, skills)
to N consumer repos via `install.sh`/`update.sh`, but had no way to catch drift or
malformed skills before they shipped: `agent-models-sync` had no dry-run mode (drift
was only caught per-task by `agent-task-check`'s warning, not CI-enforced), there was
no structural linter for skills, and no CI at all.

## Solution

Added three independently-committed pieces, all sourced in `framework/.agents/` and
synced into the repo-root dogfood copy via `install.sh`:

- `agent-models-sync --check`: generates adapters/commands into a scratch dir,
  diffs file-by-file against the real `.claude/agents/` + `.claude/commands/`
  (stale content, missing files, orphans, leftover OpenCode/Codex adapters), writes
  nothing, exits non-zero on any drift.
- `agent-skill-check`: lints every `.agents/skills/*/SKILL.md` for frontmatter
  `name:` matching its directory, non-empty `description:` (soft WARN, not FAIL,
  past 500 chars — no hard truncation threshold is documented anywhere in this repo),
  existence of any `references/`/`scripts/`/`templates/` path referenced in the body
  (only when the skill actually has such a local subdirectory, to avoid
  false-positiving on repo-relative shorthand like `` `scripts/agent-plan` ``), and
  correct presence/absence of the `agent-framework:managed` marker (checked only when
  `framework/.agents/skills/` exists alongside, i.e. this repo's own dogfood case).
  Deliberately does **not** enforce a fixed set of required section headings — this
  repo's own skills don't share one beyond the H1 title, so hardcoding
  writing-skills' aspirational structure would fail our own skills today.
- `.github/workflows/ci.yml`: runs both checks above plus an install.sh smoke test
  (fresh scratch dir, asserts key files land) and an update.sh smoke test (injects
  stale `AGENTS.md` content post-install, asserts `update.sh` overwrites it).

## Pending review items

None.

## Unresolved / follow-ups

- If the skill index's actual truncation point for `description:` is ever confirmed,
  tighten `agent-skill-check`'s soft 500-char WARN to a hard FAIL at the right number.
- CI workflow was reviewed by reading (no GitHub Actions runner in this sandbox) —
  not executed end-to-end; first real run happens on the next push/PR.

## Notes

- Source of truth is `framework/.agents/scripts/`; the repo-root `.agents/scripts/`
  copy is the dogfooded install and must be kept in sync via `./install.sh .`.
- `agent-skill-check`'s marker-correctness check only applies in this repo's own
  dogfood layout (where `framework/.agents/skills/` exists to compare against) — a
  plain consumer repo has nothing to compare a skill's origin to, so that specific
  check is silently skipped there, not guessed.
