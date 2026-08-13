<!-- agent-framework:managed -->
# AGENTS.md — bootstrap

This file is the minimal, **always-loaded** bootstrap for any agentic CLI (Claude
Code, Codex, OpenCode, or others) working in this repository. It stays short on
purpose — it is injected into every session and every dispatched subagent regardless
of relevance, so only what every single one of them truly needs unconditionally lives
here. The full task-pipeline protocol lives in the `task-protocol` skill
(`.agents/skills/task-protocol/`) and loads only when actually needed — invoke it,
don't assume its content is already in context.

## The repo is the memory

Work state lives in Markdown files on disk, never in a CLI's internal memory. Each
task keeps exactly **two working files** in `.agents/tasks/<task-id>/`: `task.md` (the
living logical document — brief, evolution, decisions, diagnosis, findings, review)
and `progress.md` (the machine file — state-machine frontmatter, instruction for the
next agent, rolling log). `.agents/tasks/` is **gitignored**; durable outputs are
git-versioned under `docs/specs/`, `docs/plans/`, `docs/tasks/` (naming:
`YYYY-MM-DD-<task-name>.md`). Project-specific knowledge lives in `.agents/project/`
(`project.md`, `config.yml`), not here.

## When to load the full protocol

If you are a dispatched pipeline role (the `orchestrator` or anything in
`.agents/agents/`), or the human is running `/task` (or an equivalent "advance the
current task" request): **invoke the `task-protocol` skill first**, then follow your
specific role file (`.agents/agents/<role>.md`) and, for dispatch mechanics, the
`orchestrating-agents` skill. Otherwise — ordinary requests, unrelated coding work,
questions — none of this applies; proceed normally, no protocol overhead.

## Language

Everything written to the repo (`task.md`, `progress.md`, durable docs under `docs/`,
any other `.md` an agent creates) is in English, regardless of the language the human
speaks. Conversation with the human may be in their language.

## Non-negotiable git rules

- Agents NEVER run: `git push`, `git rebase`, `git reset --hard`,
  `git commit --amend`, branch deletion, or any history rewrite — including the
  `gh stack` equivalents (`rebase`/`push`/`submit`/`sync`) where a repo uses stacked
  PRs. Pushing is **always human**.
- Commit messages and commit-request proposals NEVER carry AI co-authorship trailers
  (`Co-Authored-By: Claude ...`) or "Generated with ..." attribution. Authorship
  belongs to the human operating the session.
- Full detail (commit modes, the commit-request flow, message format, stacked PRs) is
  in the `task-protocol` skill.

## Team skills

`.agents/skills/` is a shared library of reusable skills. Framework-owned skills carry
the `agent-framework:managed` marker (`update.sh` replaces/removes only those — do not
edit them locally); repo-owned skills omit the marker and are never touched by the
updater.
