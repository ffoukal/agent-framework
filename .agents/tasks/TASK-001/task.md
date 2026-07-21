---
task: TASK-001
type: chore
created: 2026-07-20T02:22:06Z
---

# Task TASK-001

## Goal
Complete .agents/project/ (project.md and memory/) with accurate repo-specific content, replacing the template TODOs.
## Background
This repo dogfoods the agent framework it develops. `install.sh` created
`.agents/project/` from the template, but `project.md` and the `memory/` files are
still template TODOs (no detector matched — the stack is shell + Markdown, not
kotlin/go/node). Agents read these files in startup step 0, so their emptiness costs
every future session context quality. This is also the "suggested first task" printed
by the installer, used here as the end-to-end test of the pipeline.
## Constraints
- English only, like every repo artifact.
- Describe only what is true in the repo today — no aspirational content.
- Keep each file short and factual; project.md is read every session (context budget).
- Do not touch framework-owned files (`.agents/agents|templates|scripts`, AGENTS.md).
## Desired outcome
`project.md` (what/stack/navigation/build-test/rules/CI/gotchas) and
`memory/architecture.md`, `code-map.md`, `conventions.md`, `testing.md`, `domain.md`
filled with accurate content; `memory/decisions.md` seeded with the decisions already
taken (git-rule enforcement via hook, step mode, orchestrator on fast tier).
## Out of scope
- Any change outside `.agents/project/`.
- New framework features or script changes.
## Human decisions
- 2026-07-20: classified as `chore` (signal: mechanical documentation fill, zero design
  decisions — "completar .agents/project/"). Confirmed by the human.
- 2026-07-20: human initialized git (ddc9693) so the full human-gated commit flow can
  be exercised.
## Links
- Installer suggestion: install.sh final output ("suggested first task").
