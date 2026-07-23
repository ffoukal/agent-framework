---
task: TASK-001
type: chore
date: 2026-07-21
tags: [documentation, project-memory, dogfood]
touched: [.agents/project/]
related: []
outcome: merged
spec: null
plan: null
---

# fill-project-docs

## Problem

`.agents/project/` (project.md and memory/) still contained the installer's template
TODOs — agents working in this repo had no accurate repo-specific guide.

## Solution

Rewrote `project.md` (stack, navigation map, build/test, project-specific rules,
CI & branching, gotchas) and filled all six `memory/*.md` files with factual content
sourced from README.md, CHANGELOG.md, AGENTS.md and the directory layout. Seeded
`decisions.md` with the three existing decisions (agent-git-guard hook, step mode,
orchestrator fast tier). Committed as 35d0a60; review verdict APPROVED, no findings.

## Pending review items

None.

## Unresolved / follow-ups

- Merge strategy in "CI & branching" was left as TBD (team decision).

## Notes

- `framework/` is the source of truth; the root `.agents/` is a dogfood copy synced
  via `./install.sh .` — the dual-copy drift risk is documented in project.md Gotchas.
- Generated adapters (`.claude/agents/`, `.opencode/*`) carry no visual marker; never
  hand-edit them.
