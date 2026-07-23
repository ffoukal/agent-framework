# Conventions

<!-- Coding and process conventions. The updater NEVER touches this file. -->

## Code style
Shell scripts target POSIX/bash portability (`#!/bin/sh` or `#!/usr/bin/env bash`
depending on script — check the shebang before assuming features). No linter is
configured; `bash -n <script>` (syntax check) is the baseline verification. Markdown
files use `##`/`###` headers consistently and HTML comments (`<!-- ... -->`) for
in-template guidance that should not appear in the rendered/filled version.

## Commit / PR conventions
- Conventional Commits format (`type(scope): subject`), per `AGENTS.md` and the
  `conventional-commits` skill. `type` ∈ `feat|fix|refactor|perf|test|docs|build|
  ci|chore`.
- **No AI co-authorship trailers or attribution lines** in any commit message
  (`coauthor_trailers: false` in `config.yml`, enforced by the `agent-git-guard`
  hook and by `AGENTS.md` prose on CLIs without hooks).
- `commits.mode: human-gated` in this repo's own `config.yml`: agents never run
  `git commit`; they fill the `## Commit request` section of `progress.md` and set
  `status: AWAITING_COMMIT` for the human to commit.

## Error handling & logging
Shell scripts should fail fast and surface actionable errors (no silent swallowing).
There is no application logging — the only "log" is the rolling `## Recent log` in
each task's `progress.md`, prose written by agents, not a runtime log.

## Patterns to follow / avoid
- Follow: keep `framework/` and the per-repo `.agents/project/` strictly separate;
  never write repo-specific content into `framework/`, never write generic protocol
  content into `.agents/project/`.
- Follow: templates use `<!-- TODO: ... -->` HTML comments for guidance text that
  must be removed/replaced once real content is written — never leave a TODO comment
  in a "finished" file (checked by `agent-task-check`).
- Avoid: hand-editing generated adapters (`.claude/agents|commands/`,
  `.opencode/agent|command/`) — edit the source (`.agents/agents/*.md`,
  `config.yml`) and rerun `agent-models-sync`.
- Avoid: micro-commits — commit boundaries are plan/phase boundaries, not one commit
  per file edit.
