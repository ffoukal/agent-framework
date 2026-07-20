# Design: Spec-driven flow (spec.md as a first-class, gated artifact)

Date: 2026-07-19
Status: proposed (awaiting review)
Scope: extends `spec-agent-framework.md`; on approval its changes fold into that spec.

## 1. Goal

Formalize spec-driven development in the framework. Today the `feature` pipeline is
`brainstorm (optional) → plan → …` with one approval gate (the plan); the human's real
workflow is **discovery → spec (accept) → plan (accept) → implement**. We make the
**spec a first-class, human-approved artifact** that drives the plan and against which
the implementation is verified — mirroring how the team already works (superpowers:
brainstorming → design doc → writing-plans → implement).

## 2. Decisions (locked with the human)

1. **`spec.md` replaces `brainstorming.md`.** One phase does discovery **and** produces
   the spec; there is no separate persisted brainstorming artifact (discovery is the
   activity, `spec.md` is the deliverable).
2. **Two approval gates:** the human approves `spec.md` (gate 1), then the planner builds
   `plan.md` from it, then the human approves the plan (gate 2), then implement.
3. **Fixes are unchanged:** `diagnose → implement → review`; `diagnosis.md` is the fix's
   spec-equivalent. `spec.md` is **feature-only**. `debug`/`chore`/`spike` unchanged.
4. **Role/phase:** the interactive `spec` phase is owned by a new **`specifier`** role
   (renamed from `brainstormer`). It runs discovery interactively (leaning on
   `superpowers:brainstorming` when present) and writes `spec.md`.
5. **Location:** `spec.md` lives in **`docs/specs/`** (durable, git-versioned) and is
   **linked from the task** (`task.md` Links + `state.md`). Default dir `docs/specs/`,
   overridable in `project.md` "Project-specific rules".
6. **Traceability (gap C):** acceptance criteria live in `spec.md` as a checklist; the
   **reviewer gains a "spec compliance" lens** that verifies each criterion with
   evidence, in addition to plan fidelity.
7. **External-spec ingestion (gap B):** the `intake` may adopt a human-provided spec
   (path or pasted) as the task's `spec.md` — still gated for confirmation.
8. **Amendment protocol (gap D):** if requirements change mid-task, update `spec.md`; if
   acceptance criteria change, **re-approve** (gate) and log it.

## 3. Pipeline changes

| Type | Before | After |
|---|---|---|
| `feature` | brainstorm (opt) → plan → implement → test → review → release/split | **spec → plan → implement → test → review → release/split** |
| `fix` | diagnose → implement → review | unchanged |
| `debug` / `chore` / `spike` | — | unchanged |

`spec` is the standard first phase of a `feature`. For a trivial feature the human may
skip it (start at `plan`); for a feature whose spec the human already wrote, the intake
ingests it (see §5). Phase name `brainstorm` → `spec` everywhere.

Gates: `spec` ends `NEEDS_HUMAN` (gate 1); after approval the `planner` runs and ends
`NEEDS_HUMAN` (gate 2, unchanged).

## 4. `specifier` role (was `brainstormer`)

- Interactive; runs in the main session (never auto-dispatched by the orchestrator).
- Process: **discovery** — explore intent, requirements, options, trade-offs
  (compatible with `superpowers:brainstorming` if available, without depending on it).
- Deliverable: writes **`spec.md`** to `docs/specs/<task-id>-<slug>.md`, links it from
  `task.md` (Links) and `state.md`, and ends `NEEDS_HUMAN` (gate 1).
- Amendment: if the spec changes later and acceptance criteria move, bump the spec and
  re-enter the gate.

## 5. Artifacts

### `spec.md` template (replaces `brainstorming.md`)
Sections: **Problem / Context · Goals · Requirements · Acceptance criteria (checklist)
· Non-goals / Out of scope · Approach & design decisions · Risks · Open questions ·
Human approval required.** Written in English (per `AGENTS.md` Language rule).

### `plan.md`
"Context used" cites the `spec.md`; tasks trace to the spec's acceptance criteria. No
structural change beyond the citation/trace note.

### `review.md`
Add a **`## Spec compliance`** section: the acceptance-criteria checklist from `spec.md`,
each marked met/unmet with evidence (file/test). The reviewer's existing severity model
applies; an unmet required criterion is at least `high` (→ CHANGES_REQUESTED).

### `task.md`
`Links` points to the durable `spec.md` in `docs/specs/`.

## 6. Intake changes

- For a `feature`, after the summary is confirmed, the next phase is `spec` (specifier) —
  unless the human supplies an existing spec.
- **Ingest:** if the human provides a spec (path in the repo or pasted text), the intake
  adopts it as the task's `spec.md` (placing/normalizing it under `docs/specs/` and
  linking it), and still routes through the spec-approval gate before planning.
- The confirmation gate before task creation remains mandatory and mode-independent.

## 7. Orchestration

- Interactive phases (never auto-dispatched): `intake`, **`specifier`** (was
  `brainstormer`).
- The orchestrator pauses at the two gates (spec approval, plan approval) like any hard
  gate. No other change; autonomous phases dispatch as before.

## 8. Config, checks, tooling

- `config.yml` `models.agents`: rename `brainstormer` → `specifier` (tier `reasoning`,
  effort `high`).
- `agent-task-check`: phase enum `brainstorm` → `spec`. (Every framework agent still
  needs a `models.agents` entry — `specifier` replaces `brainstormer`.)
- No change to `agent-models-sync` beyond the agent rename flowing through.

## 9. Files to change

**Rename**
- `framework/.agents/agents/brainstormer.md` → `specifier.md` (rewrite role body).
- `framework/.agents/templates/brainstorming.md` → `spec.md` (new structure).

**Edit**
- `framework/AGENTS.md`: task-types table (feature pipeline), phases list
  (`brainstorm`→`spec`), orchestration interactive list, a short "Spec-driven features"
  note + amendment rule.
- `framework/.agents/agents/planner.md`: consume `spec.md` (cite + trace).
- `framework/.agents/agents/reviewer.md`: add the "spec compliance" lens.
- `framework/.agents/agents/intake.md`: feature → spec phase; external-spec ingestion.
- `framework/.agents/templates/review.md`: `## Spec compliance` section.
- `framework/.agents/templates/task.md`: Links → spec.
- `project-template/config.yml`: `brainstormer` → `specifier`.
- `framework/.agents/scripts/agent-task-check`: phase enum.
- `framework/.agents/skills/orchestrating-agents/SKILL.md`: interactive phases mention.
- `framework/.agents/README.md`, top `README.md`, `CHANGELOG.md`.
- `project-template/project.md`: note the specs dir default (`docs/specs/`), overridable.

**Spec** (`spec-agent-framework.md`, after approval): update §4.4 pipelines, §4.5 phases,
§5 (specifier replaces brainstormer, planner/reviewer/intake notes), §6 templates
(spec.md, review.md), §4.9 orchestration interactive list, §10.1 config.

## 10. Non-goals (YAGNI)

- No separate `spec` task **type** — `feature` with a `spec` phase covers it.
- No separate persisted discovery/brainstorming artifact — discovery is the activity of
  the spec phase.
- No new tooling to parse/verify acceptance criteria mechanically — the reviewer verifies
  them (human-readable checklist), consistent with the rest of the framework.

## 11. Verification

- A `feature` task routes `spec → plan → …`; the specifier writes `spec.md` to
  `docs/specs/`, links it, and pauses at gate 1; after approval the planner cites it and
  pauses at gate 2.
- `agent-task-check` accepts phase `spec` and still validates the `specifier` config
  entry; rejects the old `brainstorm` phase.
- Reviewer output includes the spec-compliance checklist; an unmet required criterion
  yields CHANGES_REQUESTED.
- Intake ingestion: a pasted/linked spec becomes the task's `spec.md` and still hits the
  gate.
- Orchestration pauses at both gates and never auto-dispatches the specifier.
