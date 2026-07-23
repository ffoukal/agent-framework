# Decisions

<!-- Persistent decision log for this project. The updater NEVER touches this file.
     Agents append relevant decisions here (e.g. type escalations, architectural
     choices confirmed by the human). Newest at the bottom. -->

## Format

```md
## <ISO-8601 date> — <short title>
- Context: why this came up
- Decision: what was decided
- Consequences: what it implies going forward
```

## Log

## 2026-07-19 — Git-rule enforcement via hook on Claude Code
- Context: `AGENTS.md` prose alone (e.g. never `git push`/`rebase`/`reset --hard`/
  `commit --amend`, never `git commit` under `commits.mode: human-gated`) is not
  mechanically enforced on CLIs that support hooks; agents could still violate it by
  mistake.
- Decision: added `.agents/scripts/agent-git-guard` as a Claude Code `PreToolUse`
  hook that blocks the forbidden git subcommands anywhere in a compound command, and
  blocks `git commit` when `commits.mode` is `human-gated` (reads `config.yml`
  live). `install.sh`/`update.sh` wire it into `.claude/settings.json` (merged via
  `jq`, never clobbering existing settings) alongside static `permissions.deny`
  rules.
- Consequences: on Claude Code, git-rule violations are blocked mechanically, not
  just by convention. On CLIs without a hook mechanism (Codex, OpenCode), the
  `AGENTS.md` prose remains the only enforcement — hook coverage is CLI-specific.

## 2026-07-19 — Step mode (human-chosen orchestration granularity)
- Context: the orchestrator previously only supported running the full pipeline up
  to the next gate; some humans want to run exactly one phase and stop, without
  picking models by hand each time.
- Decision: added step mode (`Run only the next phase of the current task, then
  stop.`, exposed as `/task-step`) which dispatches exactly one phase as a subagent
  using the adapter-resolved model — no manual model/effort selection. `/orchestrate`
  keeps its existing behavior (run until the next human gate, or `stop after
  <phase>`).
- Consequences: granularity (one phase vs. run-to-gate) is now a per-invocation human
  choice; gates and the underlying protocol are identical in both modes, so this is
  purely an ergonomics change, not a new pipeline concept.

## 2026-07-19 — Orchestrator moved to the fast model tier
- Context: the orchestrator's own job is mechanical coordination (reading
  state/next, dispatching the right subagent with the right brief); each dispatched
  subagent already carries its own resolved model/effort from `config.yml`. Running
  the orchestrator itself on a `standard` tier was unnecessary cost.
- Decision: changed the default `orchestrator` entry in the `config.yml` template
  from `standard/medium` to `fast/low`.
- Consequences: orchestration overhead now runs on the cheapest tier by default;
  repos that override tiers in their own `config.yml` are unaffected (this is only
  the shipped default).
