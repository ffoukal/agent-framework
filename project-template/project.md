# Project guide

<!-- Repo-specific guide for agents. The updater NEVER touches this file.
     Agents read it in step 0 of the startup protocol. Keep it accurate.
     The detectors pre-fill drafts marked with TODO — never treat drafts as truth. -->

## What this is
<!-- TODO: one paragraph — what this repository/service is and who uses it. -->

## Stack
<!-- TODO: languages, frameworks, runtime, key libraries. -->

## How to navigate this repo
<!-- TODO: where the important code lives; module/directory map at a high level. -->

## Build & test
<!-- TODO: exact commands to build, test, lint. The detectors may have drafted these. -->

Agents run tests through `.agents/scripts/agent-test` (`all` | `one <pattern>` |
`show <test>`) — never by dumping the raw test-runner output into the session. The
repo implementation lives in `.agents/project/agent-test.sh` (repo-owned; the
installer seeds a reference for detected stacks — verify its TODOs).

Agents gate "done" through `.agents/scripts/agent-verify`
(`quick` | `full` | `e2e` | `clean`), implemented by `.agents/project/agent-verify.sh`
(repo-owned, seeded with TODOs). Fill its `build` / `lint` / `typecheck` / `boot`
functions — an unfilled level silently reports SKIP and proves nothing.
Recurring review findings become executable rules in `.agents/project/checks.sh`,
which `agent-verify quick` runs.

## Project-specific rules
<!-- TODO: any rule agents must obey that is NOT a config flag. There are no per-repo
     agent overrides in v1 — put such rules here; agents read them in startup step 0.
     Specs: feature `spec.md` files live in `docs/specs/` by default; override the
     location here if this repo keeps them elsewhere. -->

## CI & branching
<!-- TODO: base branch (e.g. develop) and merge strategy (squash | merge-commit).
     The pr-splitter READS the merge strategy from here to choose the rebase recipe. -->
- base branch: TODO
- merge strategy: TODO   <!-- squash | merge-commit -->

## Gotchas
<!-- TODO: surprising things, footguns, flaky areas. -->
