# Domain

<!-- The business/domain model. The updater NEVER touches this file. -->

## Glossary
- **Framework repo**: this repo (`agent-framework`) — authors and distributes the
  protocol; not itself a consumer of the protocol for a product, except via
  dogfooding.
- **Target repo**: any repo (Kotlin/Gradle, Go, Node/TS, or other) that runs
  `install.sh` to adopt the framework.
- **Dogfooding**: running `./install.sh .` against `agent-framework` itself, so this
  repo's own task pipeline (`.agents/tasks/`) exercises the real protocol.
- **Agent role**: one of `intake, specifier, planner, implementer, debugger,
  explorer, reviewer, security-reviewer, pr-splitter, release-manager,
  orchestrator` — each has a brief in `.agents/agents/<role>.md`.
- **Phase**: one step of a task's pipeline (`intake, spec, diagnose, explore, plan,
  implement, test, review, security-review, split, release`).
- **Gate**: a point requiring explicit human confirmation before the pipeline
  proceeds (spec approval, plan approval, `AWAITING_COMMIT`, `NEEDS_HUMAN`).
- **Tier**: abstract model class (`reasoning|standard|fast`) assigned per agent role
  in `config.yml`, mapped to a concrete model per CLI via `models.mapping`.
- **Adapter**: a generated, CLI-specific subagent/command file
  (`.claude/agents/*.md`, `.opencode/agent/*.md`, etc.) carrying the resolved model.

## Core entities
- **Task** (`.agents/tasks/<id>/`, gitignored): the unit of work. Composed of
  `task.md` (living logical document: brief + Diagnosis/Findings/Implementation
  notes/Review/Release notes sections) and `progress.md` (machine file: state
  frontmatter, `## Next`, transient `## Commit request`, rolling `## Recent log`).
  Durable outputs live in `docs/specs|plans|tasks/` as `YYYY-MM-DD-<task-name>.md`.
- **Project layer** (`.agents/project/`): per-target-repo knowledge — `project.md` +
  `memory/*.md` + `config.yml`. This is what TASK-001 fills in for this repo.

## Business rules
- A task always has exactly one `type` (`feature|fix|debug|chore|spike`), fixing its
  pipeline; type can only change via a logged, human-confirmed escalation route.
- `framework/` content is never mixed with `.agents/project/` content — the updater
  enforces this boundary mechanically (never touches `project/` or
  `tasks/`, which holds `tasks/.current`).
- Generated adapters are always derived, never hand-authored; the source of truth is
  `.agents/agents/*.md` + `config.yml`.
- Commit authorship rule (no AI co-author trailers) is universal regardless of
  `commits.mode`.

## Edge cases
- A repo whose stack has no detector (like this one: shell + Markdown) gets a fully
  TODO-templated `.agents/project/`; someone must fill it by hand — that is exactly
  what TASK-001 does, and it is the installer's own "suggested first task".
- If `progress.md`'s `updated` timestamp is fresh (<15 min) and `owner` isn't the
  current agent, another CLI may be concurrently active — the startup protocol
  requires warning the human rather than proceeding silently.
