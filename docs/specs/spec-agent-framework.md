# Spec: `agent-framework` — Sistema persistente de agentes multi-CLI

Implementá en este repositorio (nuevo, llamado `agent-framework`) un framework instalable de agentes especializados que funcione con cualquier CLI agentic (Claude Code, Codex, OpenCode u otras). El framework se instala en repos destino (Kotlin/Gradle, Go, Node/TS) y permite que múltiples CLIs colaboren sobre una misma tarea sin compartir memoria interna.

## 1. Principios de diseño

1. **El repo es la memoria.** La sesión y el estado de trabajo viven en archivos Markdown versionables, no en la memoria de una CLI. Cualquier CLI lee esos archivos, entiende dónde terminó la anterior y continúa.
2. **Archivos antes que orquestación.** Base simple, legible y robusta. Nada de daemons, colas ni tooling complejo.
3. **Separación framework/proyecto.** Lo genérico (protocolo, agentes, templates, scripts) es idéntico en todos los repos y actualizable. Lo específico del repo vive en `.agents/project/` y el updater nunca lo toca.
4. **Git es del humano.** Los agentes nunca ejecutan `git commit`, `git push`, ni comandos que reescriban historia. Piden intervención vía `commit-request.md` y el sistema se resincroniza solo leyendo el historial.
5. **No duplicar información.** Cada dato vive en un solo archivo. `state.md` es descriptivo (qué pasó, incluye el handoff), `next.md` es prescriptivo (qué hacer). No existe `handoff.md` como archivo separado.
6. **Protocolo en un solo lugar.** `AGENTS.md` define el protocolo universal una sola vez. Los archivos de agentes solo definen lo específico del rol y referencian el protocolo.

## 2. Estructura del repo `agent-framework`

```text
agent-framework/
  framework/                 # se copia tal cual a cada repo destino
    AGENTS.md
    CLAUDE.md                # contiene solo: @AGENTS.md
    .agents/
      README.md
      VERSION
      agents/
        orchestrator.md
        intake.md
        specifier.md
        planner.md
        debugger.md
        explorer.md
        implementer.md
        reviewer.md
        security-reviewer.md
        pr-splitter.md
        release-manager.md
      templates/
        task.md
        state.md
        next.md
        run-log.md
        spec.md
        plan.md
        diagnosis.md
        findings.md
        implementation-log.md
        review.md
        security-review.md
        commit-request.md
        split-plan.md
        release-notes.md
      skills/                # skills generales del equipo (formato SKILL.md),
                             # cada una con marcador agent-framework:managed
                             # (incluye orchestrating-agents)
      scripts/
        agent-task-new
        agent-task-status
        agent-task-next
        agent-task-current
        agent-task-check
        agent-models-sync      # regenera los adaptadores por CLI desde config.yml (§9 7.1)
  project-template/          # esqueleto de la parte específica por repo
    project.md
    memory/
      architecture.md
      domain.md
      code-map.md
      testing.md
      conventions.md
      decisions.md
  detectors/
    kotlin.sh
    go.sh
    node.sh
  install.sh
  update.sh
  README.md
  CHANGELOG.md
```

Dogfooding: al finalizar, correr `install.sh` sobre el propio repo `agent-framework` para que se desarrolle a sí mismo con el sistema.

## 3. Estructura instalada en un repo destino

```text
AGENTS.md                    # framework — bootstrap universal (Codex y OpenCode lo leen nativo)
CLAUDE.md                    # framework — solo "@AGENTS.md" (import nativo de Claude Code)
.agents/
  VERSION                    # ej: 1.0.0
  README.md                  # framework
  agents/                    # framework — NO editar localmente
  templates/                 # framework — NO editar localmente
  scripts/                   # framework — NO editar localmente
  skills/                    # territorio COMPARTIDO: skills del framework (con marcador
                             # agent-framework:managed en su SKILL.md) + skills propias
                             # del repo (sin marcador). Codex y OpenCode escanean este
                             # path nativamente; Claude Code lo alcanza vía symlink
                             # .claude/skills -> ../.agents/skills
  project/                   # ★ específico del repo — el updater NUNCA lo toca
    project.md
    config.yml               # settings parseables del repo (ver §10.1)
    memory/
  tasks/                     # datos de trabajo — el updater NUNCA los toca
    <TASK-ID>/
      task.md
      state.md
      next.md
      run-log.md
      <artifacts de fase según pipeline>
      archive/               # artifacts de fases cerradas
  current-task               # contiene el task id activo (o vacío)
```

Regla de update, brutal de simple: `update.sh` reemplaza todo excepto `project/`, `tasks/` y `current-task`. La frontera es por directorio, sin merges ni heurísticas.

## 4. `AGENTS.md`

Es el bootstrap universal. No debe contener nada específico de un proyecto (para eso remite a `.agents/project/`). Su primera línea es el marcador `<!-- agent-framework:managed -->`, que `install.sh`/`update.sh` usan para distinguir "archivo del framework, reemplazable" de "archivo propio del repo, requiere migración" (§9). Debe incluir:

### 4.1 Startup protocol (obligatorio para todo agente)

```text
Before acting, every agent MUST:
0. Read `.agents/project/project.md` (repo-specific guide) and
   `.agents/project/config.yml` (repo settings, e.g. commit mode).
1. Resolve the task id: if the user says "current task", read `.agents/current-task`.
2. Read `.agents/tasks/<task-id>/task.md`, `state.md`, `next.md`.
3. Read the phase artifacts referenced by `state.md` (plan.md, diagnosis.md, review.md, ...).
4. Read the relevant git context: `git diff <base_commit>..HEAD`, `git log <base_commit>..HEAD --oneline`.
5. (Only when commits.mode is human-gated) If `state.md` says `status: AWAITING_COMMIT`:
   compare HEAD against the last SHA
   recorded in `run-log.md`. If there are new commits, log "human committed <sha>",
   archive the resolved `commit-request.md`, set status back to IN_PROGRESS, continue.
   If there are NO new commits, stop and tell the human a commit is pending.
6. If `state.md` frontmatter `updated` is less than 15 minutes old and `owner` is not
   you, warn the human before proceeding (another CLI may be active).
Never rely on chat memory alone.
```

### 4.2 Shutdown protocol (obligatorio)

```text
Before stopping, every agent MUST:
1. Update `state.md` (including the Handoff section).
2. Append its actions to `run-log.md`.
3. Write or update its phase artifact.
4. Write `next.md` for the next agent.
5. Run `.agents/scripts/agent-task-check <task-id>` and fix anything it reports.
```

### 4.3 Reglas de git

```text
Universal (both commit modes):
- Agents NEVER run: git push, git rebase, git reset --hard, git commit --amend,
  branch deletion, or any history rewrite. Pushing is ALWAYS human.
- Agents MAY run any read-only git command, git add (staging only if asked), git stash
  of their own work-in-progress, and local branch creation ONLY when executing an
  approved split-plan (see PR splitting).
- Commit boundaries are defined by the plan (Commit/PR boundaries) or phase ends —
  never micro-commits. The commit mode changes WHO commits, never WHEN.

If commits.mode is `human-gated` (default):
- Agents NEVER run git commit. To get changes committed, write `commit-request.md`
  and set status AWAITING_COMMIT (see §7).

If commits.mode is `agent`:
- Agents MAY run git commit at commit boundaries, and MUST record each commit
  (message + SHA) in `run-log.md` immediately after. `commit-request.md` is not used.
```

### 4.3.1 Autoría de commits (regla universal, ambos modos)

```text
Commit messages MUST NOT include AI co-authorship trailers or attribution lines.
Forbidden in any commit message or commit-request proposal:
- "Co-Authored-By: Claude ..." or any agent/AI co-author trailer
- "Generated with Claude Code", "🤖 Generated with ...", or similar attribution
Authorship belongs to the human operating the session. Agent traceability lives
in `run-log.md` (agent, CLI, SHA per entry), not in git history.
This rule is enforced regardless of `coauthor_trailers` unless the team explicitly
sets it to true in config.yml.
```

### 4.3.2 Formato de mensaje de commit (guía, no forzado)

```text
Prefer Conventional Commits: <type>(<optional scope>): <imperative subject>
with type in: feat | fix | refactor | perf | test | docs | build | ci | chore.
Signal breaking changes with feat!: or a "BREAKING CHANGE:" body line.
This is guidance, not enforced by tooling; a repo may override the convention in
project.md under "Project-specific rules". The authorship rule in §4.3.1 still applies.
```

### 4.4 Tipos de tarea y pipelines

| Tipo | Pipeline | Artifact central | Termina en |
|---|---|---|---|
| `feature` | spec → plan → implement → test → review → release/split | `spec.md` → `plan.md` | PRs mergeados |
| `fix` | diagnose → implement → review | `diagnosis.md` | PR mergeado |
| `debug` | diagnose | `diagnosis.md` | `NEEDS_HUMAN` |
| `chore` | implement → review | `task.md` (es el plan) | PR mergeado |
| `spike` | explore | `findings.md` | `NEEDS_HUMAN` |

Rutas de escalamiento válidas (siempre con confirmación humana explícita, registradas en `run-log.md` y en `project/memory/decisions.md` si son relevantes al proyecto):

- `debug → fix`: causa encontrada, arreglo acotado, se sigue de largo (mutar `type` y `pipeline` en frontmatter).
- `fix → feature`: el arreglo requiere diseño; se agrega fase de plan formal.
- `chore → fix` / `chore → feature`: el cambio "mecánico" resultó no serlo.
- `spike → feature`: NO muta la tarea — el intake crea una tarea `feature` nueva que linkea el `findings.md` del spike.

### 4.5 Fases, estados y verdicts estándar

```text
Phases:   intake | spec | diagnose | explore | plan | implement | test |
          review | security-review | split | release
Statuses: READY | IN_PROGRESS | AWAITING_COMMIT | NEEDS_HUMAN | BLOCKED |
          CHANGES_REQUESTED | APPROVED | DONE
Verdicts: APPROVED | CHANGES_REQUESTED | BLOCKED
```

### 4.6 Reglas de clasificación (para el intake)

Estas reglas viven en `intake.md` (solo el intake las necesita); `AGENTS.md` deja un puntero corto para no cargarlas en el contexto de cada sesión. Contenido:

```md
Classify as `debug` when the user wants to understand WHY something happens, not (yet)
change it. Signals: "investigar", "entender por qué", "no sabemos qué pasa".

Classify as `fix` when there is a known-broken behavior with a clear expected behavior.
Signals: error message, failing test, bug report, "arreglar", "se rompe cuando".

Classify as `feature` when the desired outcome is new or changed behavior.
Signals: "agregar", "queremos que", new endpoint/field/flow, multi-module changes.

Classify as `chore` when the change is mechanical with zero design decisions.
Signals: "bump/actualizar dependencia", "renombrar", "mover archivos", "código muerto",
mechanical migration with no behavior change.

Classify as `spike` when nothing is broken and there is a question about the future.
Signals: "evaluar", "conviene", "proof of concept", "comparar opciones", "¿es viable?".

Discriminant for spike vs debug: is something misbehaving TODAY (debug), or is this a
question about the future (spike)?
Discriminant for fix vs debug: does the agent have permission to go from diagnosis to
implementation without stopping? fix = yes, debug = no.

## Ambiguity protocol (mandatory)
If the request matches more than one type, or none clearly:
1. Do NOT guess.
2. Present the matching options to the human with a one-line rationale each.
3. Wait for the decision. Record it in `task.md` under "Human decisions".
Confidence rule: if you cannot cite WHICH signal in the user's request triggered your
classification, treat it as ambiguous and ask.
```

### 4.7 Control de crecimiento de contexto

```text
- `state.md` stays short: max ~30 lines of body. It is overwritten, not appended.
- `run-log.md` is append-only and unbounded — read the `state.md` Handoff and the last few entries (via `agent-task-status`), NOT the whole file.
- When a phase closes (e.g. plan approved), move its superseded artifacts
  (e.g. a resolved commit-request.md) into `archive/`. Agents do not read `archive/` by
  default. The `spec.md` is durable (lives in `docs/specs/`), not archived.
```

### 4.8 Idioma

```text
Everything agents write to the repo is in English — task files, state.md, next.md,
run-log.md, every phase artifact, and any other .md an agent creates — regardless of the
language the human speaks. Conversation with the human may be in their language; the repo
artifacts are always English so any CLI or teammate can read them.
```

### 4.9 Orquestación (pipelines en una sola sesión)

El **orquestador** corre el pipeline en una sesión despachando cada fase autónoma como
**subagente**, en vez de que el humano abra una sesión por fase. Lee `state.md`/`next.md`,
despacha el agente de la fase con el modelo resuelto de `config.yml`, integra el resultado
y avanza — frenando solo donde hace falta un humano. La metodología agnóstica vive en la
skill `orchestrating-agents` (en `.agents/skills/`); el detalle del rol en
`orchestrator.md` (§5).

```text
- Interactive phases stay in the main session (never auto-dispatched): intake, specifier.
- Autonomous phases are dispatched as subagents: planner, debugger, explorer, implementer,
  reviewer, security-reviewer, pr-splitter, release-manager.
- Each subagent gets an isolated, hand-crafted context (never the orchestrator's history)
  and still runs the full shutdown protocol, so the repo stays the memory and a dead
  session resumes cleanly.
- The loop pauses and hands back to the human at: interactive phases, any hard gate
  (NEEDS_HUMAN | BLOCKED | AWAITING_COMMIT, or a plan awaiting approval), and the stop-at
  boundary (recorded as stop_at in state.md; default is the full pipeline).
- Commit modes: human-gated (default) pauses at each commit boundary; commits.mode: agent
  is recommended for full end-to-end fluidity (implementer subagent commits; push is human).
- Agnostic fallback: on a CLI without subagent dispatch, the skill instructs the manual
  flow (surface next.md with the resolved model/effort; the human runs the phase).
  Orchestration never overrides the git rules or gates.
```

Model routing: los adaptadores generados en el install (§9 7.1) son lo que hace que cada
CLI aplique el modelo del tier al subagente despachado. En Claude Code, la skill puede
apoyarse en `superpowers:subagent-driven-development` si está instalado (compatible con,
sin depender).

## 5. Archivos de agentes (`.agents/agents/`)

Formato común de cada archivo: Rol · Cuándo usarlo · Startup (referencia al protocolo universal + lecturas extra del rol) · Escrituras del rol · Reglas específicas · Stop conditions · Formato de salida. No repetir el protocolo universal: una línea que remita a `AGENTS.md`.

El tier de modelo y el esfuerzo de cada agente NO viven acá: viven en `models.agents` de `config.yml` (§10.1), única fuente de verdad. Todo agente que escribe `next.md` resuelve desde ahí el tier/effort/modelo del próximo agente y lo incluye en "Agent to use" (p. ej. `reviewer — model: opus, effort: high`) — esto maneja el flujo manual. Para la **orquestación** (§4.9), el install genera adaptadores nativos por CLI (`.claude/agents/`, `.opencode/agent/`) con el `model:` resuelto por rol: eso es lo que hace que el modelo del subagente despachado sea el correcto (los archivos del repo sí rutean el modelo del subagente en cada CLI, aunque no puedan forzar el modelo de la sesión principal).

### `orchestrator.md`
- Corre el pipeline de una tarea en **una sola sesión** despachando cada fase autónoma como subagente (§4.9). Vive en la sesión principal (no es él mismo un subagente). Prompts: `Orchestrate the current task using the persistent agent system.` / `Orchestrate the current task; stop after <phase>.`
- Aplica la skill `orchestrating-agents`. Frena en fases interactivas (`intake`, `specifier`), gates duros (`NEEDS_HUMAN`/`BLOCKED`/`AWAITING_COMMIT`, plan sin aprobar) y el `stop-at`.
- Escribe `state.md` (incluye `stop_at`) y `run-log.md` (una entrada por dispatch, con subagente + modelo). Los artifacts de fase los escriben los subagentes.

### `intake.md`
- Puerta de entrada conversacional. Prompt: `Start a new task using the persistent agent system.`
- Entrevista corta guiada por checklist (no guion rígido; si el usuario ya dio la info, no re-preguntar): objetivo, situación actual, error/reproducción si aplica, restricciones, out of scope.
- Clasifica el tipo según 4.6, citando la señal. Ambigüedad → protocolo de ambigüedad.
- Propone resumen: task id sugerido, tipo, goal en una frase, pipeline. El humano confirma.
- Recién entonces crea la tarea **usando `agent-task-new`** (única vía prescrita: estampa `updated`/`base_commit`, reemplaza todos los placeholders y crea `archive/`; NO crear los archivos a mano desde templates — arriesga timestamps en cero, placeholders sin reemplazar y `archive/` faltante). Luego setea `current-task` y escribe `next.md` apuntando al primer agente del pipeline (para `feature`, el `specifier`). El gate de confirmación humana previo a crear la tarea es **mode-independent**: aun despachado automáticamente (orquestador), el intake FRENA y emite el resumen antes de crear nada.
- **Ingesta de spec (feature):** si el humano ya tiene un spec (path o pegado), el intake lo adopta como `spec.md` del task bajo `docs/specs/`, lo linkea, e igual pasa por el gate 1 (el specifier lo refina).
- También maneja escalamientos de tipo y la creación de la feature derivada de un spike.

### `specifier.md`
- Fase `spec` (interactiva, en la sesión principal). Hace **discovery** para features y la cristaliza en un `spec.md` aprobado. Compatible con `superpowers:brainstorming` si está, sin depender. La discovery es la actividad; `spec.md` es el deliverable (no hay `brainstorming.md` separado).
- Escribe `spec.md` en `docs/specs/<task-id>-<slug>.md` (durable) con: Problem/Context · Goals · Requirements · **Acceptance criteria (checklist)** · Non-goals · Approach & design decisions · Risks · Open questions · Human approval. Lo linkea desde `task.md` (Links) y `state.md`.
- Termina en `NEEDS_HUMAN` (**gate 1**); recién aprobado, `next.md` apunta al `planner`. **Amendment:** si cambian los acceptance criteria mid-task, se re-aprueba (gate 1) y se loguea.

### `planner.md`
- Para features, **construye el plan desde el `spec.md` aprobado** (lo cita en Context used; no re-abre requisitos ya settleados — si cambian, es un amendment del spec, vuelve al `specifier` y gate 1).
- Crea un plan implementable y verificable en `plan.md` con: Goal · Context used · Assumptions · Tasks con checkboxes · Files likely to change · Tests to run · Risks · Acceptance criteria (trazan a los del spec; en `fix` derivan del `diagnosis.md`) · **Commit/PR boundaries** (capas de entrega pensadas para el split: contratos → dominio/servicios → integración/wiring) · Human approval required.
- El plan requiere aprobación humana antes de implementar (`NEEDS_HUMAN`, **gate 2**).

### `debugger.md`
- Diagnostica usando el repo y el contexto de `.agents/project/memory/` (infra/IDP si está documentado).
- Escribe `diagnosis.md`: Symptom · Reproduction · Root cause · Evidence · Proposed change · Tests to add/run · Risk.
- En tareas `debug`, termina en `NEEDS_HUMAN`. En `fix`, si la causa y el cambio son acotados, handoff directo al implementer — esto es el pipeline normal de `fix` (la tarea ya es tipo `fix`), NO la escalación `debug → fix`, así que no hay mutación de tipo ni gate de confirmación.

### `explorer.md`
- Para spikes. Responde una pregunta, no arregla nada.
- Escribe `findings.md`: Question · Options explored · Evidence · Trade-offs · Recommendation · Open questions.
- **Regla dura:** el código exploratorio es descartable — va en un directorio sandbox o rama efímera claramente marcada; `findings.md` lo declara no-productivo. Un spike NUNCA emite `commit-request.md` sobre código de aplicación, solo sobre archivos de `.agents/`.
- Termina siempre en `NEEDS_HUMAN`.

### `implementer.md`
- Implementa el plan o los cambios pedidos por review.
- Reglas: leer `plan.md` si existe; **si no existe, `diagnosis.md` es el plan** (fix) **o `task.md` es el plan** (chore). Si `review.md` tiene `CHANGES_REQUESTED`, priorizar esos cambios. Cambios mínimos, no rediseñar salvo que el plan lo pida.
- En chores: si aparecen decisiones de diseño, frenar y proponer escalamiento de tipo.
- Actualiza `implementation-log.md` (incluye sección **Test results** — no hay archivo separado de test-results).
- Al cerrar cada unidad commiteable (definida por los Commit/PR boundaries del plan, o fin de fase), emite `commit-request.md` (ver §7).

### `reviewer.md`
- Revisa `git diff <base_commit>..HEAD` contra el plan (o diagnosis/task según tipo), hunk por hunk.
- Aplica **lentes de revisión** (saltea la que no aplique): correctness · behavior-vs-intent (¿hace lo que dice el plan/commit?, edge cases de los acceptance criteria, errores silenciados) · scope (nada fuera del scope declarado — crítico en chores) · security/privacy básico · test-quality (el test fallaría sin el cambio; asserts sobre comportamiento, no implementación) · simplicity · consistency con el codebase · **spec compliance** (features: verifica cada acceptance criterion del `spec.md` linkeado con evidencia; un criterio requerido no cumplido es al menos `high` → CHANGES_REQUESTED; en `fix` verifica contra `diagnosis.md`) · fidelidad al plan · **que los archivos de estado estén actualizados**.
- Cada hallazgo lleva **severidad** (`critical` | `high` | `medium` | `low` | `info`) y es accionable: `[file:line]` · por qué importa · fix sugerido. Regla anti-padding: no inventar hallazgos para parecer exhaustivo (el padding entierra los reales); lo incierto se marca `[needs confirmation]` en vez de bajarle la severidad.
- Escribe `review.md` y **deriva el verdict de la severidad** (verdict exacto): cualquier `critical` → `BLOCKED`; si no, cualquier `high` → `CHANGES_REQUESTED`; si no (solo `medium`/`low`/`info`) → `APPROVED`.
- `CHANGES_REQUESTED` → status de la tarea `CHANGES_REQUESTED`, `next.md` apunta al implementer. `BLOCKED` → `NEEDS_HUMAN`.

### `security-reviewer.md`
- Fase opcional (el planner o el humano la agregan al pipeline cuando la tarea toca superficies sensibles).
- Revisa: secrets · PII en logs · auth/authz · infraestructura · migraciones · permisos · configs peligrosas · riesgos de herramientas/MCP si aplica.
- Escribe `security-review.md` con el **mismo modelo de severidad y derivación de verdict** que el `reviewer` (misma regla anti-padding y marcador `[needs confirmation]`).

### `pr-splitter.md`
- Se invoca cuando la feature está `APPROVED` y el diff supera ~15 archivos.
- **Fase de análisis:** lee `git diff <base_commit>..HEAD`, construye el grafo de dependencias entre archivos cambiados, propone partición en capas funcionales (patrón: 1. tipos/contratos/interfaces/migraciones/schemas → 2. dominio/servicios → 3. integración/endpoints/wiring → N. flags si algo debe quedar conectado-pero-incompleto). Principio: código nuevo no usado compila y pasa CI (dead code temporal aceptable); código que usa cosas inexistentes, no. Orden siempre de las hojas hacia el wiring.
- Si los commits humanos ya respetan las capas del plan, el split es por **rangos de commits** (preferido). El fallback `git checkout <feature> -- <files>` archivo por archivo es válido pero pierde historia; documentar sus límites.
- El objetivo de ≤15 archivos por chunk es objetivo, no invariante: una capa inseparable puede excederlo.
- Escribe `split-plan.md` (ver template §6) y setea `NEEDS_HUMAN`: **el humano aprueba el split antes de tocar nada.**
- **Fase de ejecución (post-aprobación):** genera `split-execute.sh` con la secuencia exacta de comandos. El agente puede crear ramas locales; push y creación de PRs son humanos.
- Mantiene el estado del stack: en cada startup, detecta chunks mergeados comparando con `git log develop`, actualiza `split-plan.md` y genera la receta exacta de rebase para el siguiente chunk (el humano la ejecuta).

### `release-manager.md`
- Produce `release-notes.md` y el resumen para PR: Summary · Problem · Solution · Tests · Risks · Rollout · Rollback · Agent trace (qué agentes/CLIs participaron, extraído de `run-log.md`).
- En features con split, coordina el orden de merge del stack junto con `pr-splitter`.

## 6. Templates (`.agents/templates/`)

Todos con encabezados útiles y formato consistente. Los campos críticos van como frontmatter YAML parseable.

### `state.md`

```md
---
task: TASK-000
type: feature            # feature | fix | debug | chore | spike
pipeline: [plan, implement, test, review, release]
phase: plan
status: READY            # READY | IN_PROGRESS | AWAITING_COMMIT | NEEDS_HUMAN |
                         # BLOCKED | CHANGES_REQUESTED | APPROVED | DONE
owner: planner
base_commit: <sha>
updated: <ISO-8601 UTC>
stop_at: null            # optional: orchestrator halts before advancing past this phase
---

# Task state

## Goal
## Last completed step
## Active files
## Blockers
## Human decisions

## Handoff
### Summary
### Completed
### Important constraints
### Files to inspect first
### Open questions
```

### `next.md`

```md
# Next action

## Agent to use
## Instruction
## Read first
## Do
## Stop when
## Expected writes
```

### `task.md`

```md
---
task: TASK-000
type: feature
created: <ISO-8601>
---

# Task <TASK_ID>

## Goal
## Background
## Constraints
## Desired outcome
## Out of scope
## Human decisions
## Links
```

### `run-log.md`
Append-only, una entrada por bloque con formato fijo machine-parseable:

```md
## <ISO-8601 UTC> | <agent> | <cli> | <HEAD sha>
- <action>
- <action>
```

### `commit-request.md`

```md
---
task: TASK-000
requested: <ISO-8601>
resolved: null            # el próximo agente lo completa al detectar el commit
---

# Commit request

## Proposed message
<!-- Conventional Commits (§4.3.2); no AI co-authorship trailers (§4.3.1). -->
## Files to include
## Rationale
## Suggested commands
```

### `split-plan.md`

```md
---
task: TASK-000
base_branch: develop
merge_strategy: <squash | merge-commit>   # determina la receta de rebase
approved_by_human: false
chunks:
  - id: 1
    branch: feat/<task>-1-contracts
    base: develop
    depends_on: []
    files: []
    status: pending        # pending | building | in_review | merged
    ci_status: pending     # pending | passing | failing
    ci_url: null
    pr: null
---

# Split plan

## Layering rationale
## Merge order rules
- Chunks merge strictly in order; never merge N+1 before N.
- After merging chunk N, rebase chunk N+1:
  `git rebase --onto <base_branch> <old-base-branch> <chunk-branch>`
  (the --onto form is mandatory if merge_strategy is squash — naive rebase
  produces phantom conflicts).
- CI runs on every pushed branch: push each chunk and wait for green BEFORE
  opening its PR. Reviewers only ever see green chunks.
```

### Resto de templates
`spec.md` (estructura de §5/specifier: Problem/Context · Goals · Requirements · Acceptance criteria · Non-goals · Approach · Risks · Open questions · Human approval), `plan.md` (estructura de §5/planner), `diagnosis.md` (estructura de §5/debugger), `findings.md` (estructura de §5/explorer), `implementation-log.md` (con sección `## Test results`), `review.md` (Summary + Overall + lentes aplicadas + **`## Spec compliance`** + hallazgos agrupados por severidad `### critical/high/medium/low/info` + `## Verdict` derivado), `security-review.md` (mismo esquema), `release-notes.md`. No crear templates de `handoff.md`, `test-results.md` ni `brainstorming.md`.

## 7. Commits (resumen operativo)

El comportamiento depende de `commits.mode` en `.agents/project/config.yml`. En ambos modos, la unidad commiteable la definen los boundaries del plan o el fin de fase (no micro-commits), el working tree debe quedar "listo" (tests pasando, nada a medias), y el mensaje respeta §4.3.1 (sin co-autoría de agentes) y §4.3.2 (formato Conventional Commits, guía).

**Modo `human-gated` (default):**
1. El agente escribe `commit-request.md`, setea `status: AWAITING_COMMIT` y se detiene.
2. El humano revisa, ajusta si quiere, y commitea. No edita archivos del sistema.
3. El próximo agente resincroniza solo (paso 5 del startup protocol).

**Modo `agent`:**
1. El agente ejecuta `git commit` en el boundary y registra mensaje + SHA en `run-log.md` inmediatamente.
2. El push sigue siendo humano, siempre.
3. No se usa `commit-request.md` ni el estado `AWAITING_COMMIT`.

El resto del sistema es agnóstico al modo: reviewer y pr-splitter operan sobre `git diff <base_commit>..HEAD` y rangos de commits igual en ambos casos. Un repo puede cambiar de modo sin romper tareas en curso.

## 8. Scripts (`.agents/scripts/`)

POSIX shell o Bash simple, ejecutables, con `--help` mínimo. Todos aceptan task id opcional; si falta, leen `.agents/current-task`.

**Validación de task id (obligatoria en todo script que lo use en un path o en `sed`):** antes de construir rutas o expresiones, validar el id contra un patrón estricto — permitido letras/dígitos/`.`/`_`/`-`, sin `/`, sin empezar con `.` (regex ilustrativa `^[A-Za-z0-9._-]+$` excluyendo `.`/`..` inicial). Si no matchea, error con mensaje claro y `exit ≠ 0`. Esto cierra el footgun de path traversal (`../../x`) y de `sed` roto (un `/` en el id). Aplica a `agent-task-new`, `-status`, `-next` y `-check`.

- `agent-task-new TASK-ID "Goal"` — crea `tasks/TASK-ID/` con `task.md`, `state.md`, `next.md`, `run-log.md` desde templates; registra `base_commit` = HEAD actual; setea `current-task`. Valida `TASK-ID` (ver arriba) antes de tocar el filesystem. Si la tarea existe, error y salir sin sobrescribir. (Primitiva de bajo nivel: la puerta de entrada documentada es el intake.)
- `agent-task-status [TASK-ID]` — imprime `state.md`, separador, `next.md`, separador, últimas 5 entradas de `run-log.md` (parseando el formato fijo). Con `--all` (o `--list`): una línea por tarea (`id · type · status · phase · updated`), marcando la actual.
- `agent-task-next [TASK-ID]` — imprime `next.md`.
- `agent-task-current` — imprime el task id actual.
- `agent-models-sync` — regenera los adaptadores de subagente (`.claude/agents/`, `.opencode/agent/`) desde `config.yml` e imprime la receta de perfiles de Codex. **Es el generador único**: `install.sh`/`update.sh` lo invocan, y el humano lo corre a mano después de editar `models` en `config.yml` (no toma task id).
- `agent-task-check [TASK-ID]` — valida el protocolo: `.agents/project/config.yml` existe y tiene valores válidos (`commits.mode` ∈ {human-gated, agent}; `models.agents` con tier/effort válidos para cada agente del framework; `models.mapping` con los tres tiers); frontmatter de `state.md` parseable y con status/type/phase válidos; `updated` sin placeholder y con warning si el horario está en cero (`T00:00:00Z`); `task.md`/`state.md`/`next.md` sin placeholders de template sin reemplazar (`TASK-000`, `<TASK_ID>`, `<ISO-8601[ UTC]>`, `<sha>`) → falla; `next.md` existe, no está vacío, y el agente nombrado en "Agent to use" existe en `models.agents` (warning si no); `run-log.md` tiene al menos una entrada; si `status: AWAITING_COMMIT` (solo válido en modo human-gated), existe `commit-request.md` sin resolver; si existe un `commit-request.md` resuelto con `status` ≠ AWAITING_COMMIT → falla (debe archivarse en `archive/`); si existe `split-plan.md` con `approved_by_human: false` y `status` ≠ NEEDS_HUMAN → falla; si `config.yml` es más nuevo que los adaptadores generados (`.claude/agents/`) → warning para correr `agent-models-sync`; en modo `agent`, los commits nuevos desde `base_commit` tienen su entrada correspondiente en `run-log.md` y ningún mensaje de commit del rango contiene trailers de co-autoría de IA. Exit code ≠ 0 con mensajes claros si algo falla. Es el paso final obligatorio del shutdown protocol.

## 9. `install.sh`, `update.sh` y detectores

### `install.sh` (se ejecuta desde el repo destino)
1. Obtiene el framework: `gh release download --repo <org>/agent-framework --archive tar.gz` (resuelve auth en repos privados y versiona limpio); si `gh` no está disponible, fallback a `git clone --depth 1` del tag más reciente. Copia `framework/` al repo destino.
2. Copia `project-template/` a `.agents/project/` **solo si no existe**.
2.1. **Migración de archivos preexistentes:** si el repo ya tiene `AGENTS.md` con contenido propio, mover ese contenido a `.agents/project/legacy-agents-instructions.md` (preservado intacto) antes de escribir el `AGENTS.md` del framework, y avisar en el resumen final que debe revisarse y redistribuirse (build/test → `memory/testing.md`, reglas del repo → `project.md` § Project-specific rules, convenciones → `memory/conventions.md`) y luego borrarse. Ídem si existe `CLAUDE.md` con contenido propio: migrar el contenido a `legacy-agents-instructions.md` (al pasar a `project/` lo verán también Codex y OpenCode) y dejar `CLAUDE.md` con `@AGENTS.md`; si el equipo decide conservar contenido exclusivo de Claude Code en `CLAUDE.md`, puede coexistir debajo del import, pero entonces el archivo pasa a ser responsabilidad del repo. Invariante: nada específico del repo vive en `AGENTS.md`, porque `update.sh` lo reemplaza completo.
2.2. Sugerir como tarea de migración: "Continue as implementer: redistribute the content of `.agents/project/legacy-agents-instructions.md` into the appropriate `project/` files, then delete it."
3. Corre los detectores según lo que encuentre y pre-llena `project.md` y `memory/testing.md` / `memory/code-map.md` con borradores marcados con TODOs (nunca como verdad absoluta).
4. Escribe `.agents/VERSION`.
5. Crea `CLAUDE.md` con `@AGENTS.md` si no existe (si existía con contenido propio, ya fue migrado en 2.1).
6. Crea `.agents/project/config.yml` desde el template (defaults: `mode: human-gated`, `coauthor_trailers: false`) solo si no existe.
7. Escribe `"includeCoAuthoredBy": false` en `.claude/settings.json` del repo destino — mergeando la clave si el archivo existe, sin pisar el resto — para neutralizar mecánicamente el trailer que Claude Code agrega por defecto. Para Codex/OpenCode alcanza la regla de `AGENTS.md`.
7.1. **Genera los adaptadores de subagente por CLI** llamando a `.agents/scripts/agent-models-sync`: `.claude/agents/<agente>.md` y `.opencode/agent/<agente>.md`, cada uno con `name`/`description`/`model:` resueltos desde `config.yml` (`models.agents[agente].tier` → `models.mapping[tier][cli]`). Son lo que permite que la orquestación (§4.9) rutee el modelo al subagente despachado. El script además **imprime** la receta de perfiles para el `config.toml` de usuario de Codex (un perfil por tier), porque la config de Codex es por-usuario. Los adaptadores son **generados, no fuente** (encabezado "GENERATED — do not edit"). Como `config.yml` es repo-owned y el humano lo edita, el mismo `agent-models-sync` se corre a mano para regenerarlos sin re-instalar; `agent-task-check` avisa si `config.yml` quedó más nuevo que los adaptadores.
7.2. Crea el symlink `.claude/skills -> ../.agents/skills` para que Claude Code descubra las skills del repo (Codex y OpenCode escanean `.agents/skills/` nativamente). Si ya existe un `.claude/skills/` real con contenido, avisar y no pisar (el humano decide si migra esas skills a `.agents/skills/`).
8. Deja los cambios sin commitear e imprime el resumen — el humano revisa y commitea.
9. Sugiere como primera tarea: "un agente recorre el repo y completa/corrige `.agents/project/`".

### `update.sh`
1. Compara `.agents/VERSION` local contra la versión del framework.
2. Reemplaza `AGENTS.md` (siempre — es del framework), `.agents/README.md`, `agents/`, `templates/`, `scripts/`, `VERSION`. `CLAUDE.md` no se reemplaza: solo verifica que la línea `@AGENTS.md` siga presente y la re-agrega si falta. En `.agents/skills/` (territorio compartido): reemplaza/elimina únicamente las carpetas cuyo SKILL.md tiene el marcador `agent-framework:managed`; toda skill sin marcador es del proyecto y no se toca. **Regenera los adaptadores de subagente** (`.claude/agents/`, `.opencode/agent/`) desde los agentes + `config.yml` actualizados (§9 7.1).
3. **No toca** `.agents/project/`, `.agents/tasks/`, `.agents/current-task`.
4. Muestra el diff y deja que el humano commitee.

### Distribución
- El framework se distribuye vía GitHub Releases con tags semver (`v1.0.0`, ...). No hay registry ni empaquetado: el tarball que GitHub genera por release es el artefacto.
- `update.sh` compara `.agents/VERSION` contra el último release y usa el mismo mecanismo de descarga que `install.sh`.
- Roadmap no-bloqueante (post-estabilización, fuera del alcance de este spec): GitHub Action en `agent-framework` que, al publicar un release, abre PRs de actualización (checkout de cada repo destino → `update.sh` → `gh pr create`) sobre una lista de repos definida en el workflow. Opcional: publicar el mismo repo como marketplace de plugins de Claude Code/Codex (installer + hook de Stop que corra `agent-task-check`), manteniendo la estructura repo-resident como única fuente de verdad.

### Detectores (`detectors/*.sh`)

| Detecta | Infiere |
|---|---|
| `build.gradle.kts` / `pom.xml` | Kotlin/JVM: `./gradlew build`, `./gradlew test`; módulos de `settings.gradle.kts` volcados a `code-map.md`; entry point vía `@SpringBootApplication` si hay Spring |
| `go.mod` | módulo, `go build ./...`, `go test ./...`, `cmd/` como entry points |
| `package.json` | scripts npm/pnpm/yarn tal cual (`test`, `build`, `lint`); `tsconfig.json`; workspaces como mapa de módulos |

## 10. `project-template/project.md`

Estructura fija (los agentes deben poder confiar en ella):

```md
# Project guide

## What this is
## Stack
## How to navigate this repo
## Build & test
## Project-specific rules
## CI & branching
<!-- base branch (ej: develop), merge strategy (squash | merge-commit) — el
     pr-splitter LEE la merge strategy de acá para elegir la receta de rebase -->
## Gotchas
```

Los archivos de `memory/` (`architecture.md`, `domain.md`, `code-map.md`, `testing.md`, `conventions.md`, `decisions.md`) llevan las secciones ya acordadas en el diseño original, con contenido inicial útil y TODOs. `decisions.md` es el registro de decisiones persistentes del proyecto.

### 10.1 `project-template/config.yml`

Settings parseables del repo (prosa y conocimiento van en `project.md`; flags que agentes y scripts deben obedecer sin ambigüedad van acá):

```yaml
# .agents/project/config.yml — repo settings. The updater never touches this file.
commits:
  mode: human-gated        # human-gated | agent  (see AGENTS.md §git rules)
  coauthor_trailers: false # keep false: no AI co-author trailers in commit messages
models:
  agents:                  # tier/effort per agent — single source of truth.
    orchestrator:      { tier: reasoning, effort: high }    # editing this file IS
    planner:           { tier: reasoning, effort: high }    # the per-repo override
    reviewer:          { tier: reasoning, effort: high }
    security-reviewer: { tier: reasoning, effort: high }
    pr-splitter:       { tier: reasoning, effort: high }
    specifier:         { tier: reasoning, effort: high }
    implementer:       { tier: standard,  effort: medium }
    debugger:          { tier: standard,  effort: medium }
    explorer:          { tier: standard,  effort: medium }
    intake:            { tier: fast,      effort: low }
    release-manager:   { tier: fast,      effort: low }
  mapping:                 # tier -> concrete model per CLI; team fills real names
    reasoning: { claude-code: opus,   opencode: <provider/model>, codex: <model> }
    standard:  { claude-code: sonnet, opencode: <provider/model>, codex: <model> }
    fast:      { claude-code: haiku,  opencode: <provider/model>, codex: <model> }
```

Los agentes lo leen en el paso 0 del startup protocol. Campos futuros de configuración van acá, no en `project.md`.

No hay overrides de *comportamiento* de agentes por repo (reglas, protocolo): cualquier regla específica va en "Project-specific rules" de `project.md` (los agentes la leen en el paso 0 del startup). Tier/effort sí se ajustan por repo editando directamente `models.agents` en este archivo — el template trae los defaults del equipo pre-cargados.

## 11. `.agents/README.md`

Documentación breve para humanos: qué es el sistema, cómo crear una tarea (vía intake), cómo continuar desde cualquier CLI, cómo cambiar entre Claude Code/Codex/OpenCode, qué archivos mirar primero, qué significan `state.md` y `next.md`, cómo funciona el flujo de commits en cada modo y cómo cambiarlo en `config.yml`, cómo funciona el split de PRs, y por qué los commits nunca llevan co-autoría de agentes (la trazabilidad vive en `run-log.md`). Ejemplo de flujo real completo (el de 8 pasos: install → intake → plan → gate → implement → review → split → update).

Prompts universales a incluir:

```text
Start a new task using the persistent agent system.
Continue the current task using the persistent agent system.
Continue TASK-123 as implementer. Read `.agents/tasks/TASK-123/next.md` and follow the persistent agent protocol.
Continue the current task as reviewer. Read the persistent task state and review the diff against base_commit.
```

## 12. Calidad esperada

- Infraestructura de repo concreta, no documentación vaga: archivos completos, consistentes, con instrucciones que una CLI agentic pueda seguir literalmente.
- Textos orientados a agentes en inglés; el README para humanos puede estar en español. **Todo lo que los agentes escriben al repo (tareas y cualquier `.md`) es en inglés** (§4.8), sin importar el idioma del humano.
- Scripts probados manualmente contra un repo dummy (crear tarea, status, check con estado roto a propósito).
- No ejecutar herramientas destructivas. No modificar código de aplicación.

Al finalizar:
1. Mostrar árbol de archivos creados.
2. Explicar brevemente cómo instalar en un repo destino.
3. Indicar el primer comando/prompt para crear una tarea (vía intake).

## 13. Resultado esperado

```bash
# en un repo Kotlin cualquiera
curl -sL <url>/install.sh | sh    # o ./install.sh apuntando al repo destino
```

Luego abrir cualquier CLI y decir `Start a new task using the persistent agent system.` → el intake entrevista, clasifica (o pregunta si es ambiguo), crea la tarea y deja `next.md` listo. Cualquier CLI posterior que reciba `Continue the current task...` debe saber: qué tarea está activa, qué tipo y pipeline tiene, qué fase corresponde, qué archivos leer, qué agente usar, qué escribir, cuándo pedir un commit humano, y cómo dejar el próximo handoff.
