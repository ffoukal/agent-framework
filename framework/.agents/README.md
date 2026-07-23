# Persistent agent system (`.agents/`)

Este directorio es un **sistema de agentes persistentes multi-CLI**. La idea central:
**el repo es la memoria**. El estado de cada tarea vive en archivos Markdown en disco,
no en la memoria interna de una CLI. Cualquier CLI (Claude Code, Codex, OpenCode)
puede abrir el repo, leer el estado y continuar donde otra dejó.

Cada tarea usa **dos archivos de trabajo** en `.agents/tasks/<TASK-ID>/`:

- `task.md` — el **documento lógico vivo**: brief, evolución, decisiones, diagnosis,
  findings, review, release notes. Lo que un humano releería.
- `progress.md` — el **archivo de máquina**: frontmatter de la máquina de estados,
  instrucción para el próximo agente, coordinación de commits, log corto rodante.

`.agents/tasks/` está **gitignoreado** (estado de trabajo local). Lo durable vive
versionado en `docs/`: `docs/specs/` (specs), `docs/plans/` (planes) y `docs/tasks/`
(un resumen por tarea cerrada + `INDEX.md`), todos con el nombre
`YYYY-MM-DD-<task-name>.md`.

## Qué hay acá

```text
.agents/
  VERSION            # versión del framework instalado
  README.md          # este archivo
  agents/            # framework — roles de agentes. NO editar localmente
  templates/         # framework — plantillas de artifacts. NO editar localmente
  scripts/           # framework — utilidades de tarea. NO editar localmente
  project/           # ★ específico de ESTE repo — el updater NUNCA lo toca
    project.md       # guía del repo para agentes
    config.yml       # settings parseables (modo de commit, etc.)
    memory/          # arquitectura, dominio, code-map, testing, convenciones, decisiones
  tasks/             # estado de trabajo LOCAL (gitignoreado) — el updater NUNCA lo toca
    <TASK-ID>/       # una carpeta por tarea: task.md + progress.md (+ split-plan.md)
  current-task       # id de la tarea activa (o vacío)
```

El **protocolo universal** vive en `AGENTS.md` (raíz del repo). `CLAUDE.md` solo
importa `@AGENTS.md`. Codex y OpenCode leen `AGENTS.md` nativamente.

## Cómo crear una tarea

No crees archivos a mano. Usá el **intake** (agente conversacional):

```text
Start a new task using the persistent agent system.
```

El intake entrevista, clasifica el tipo (feature / fix / debug / chore / spike),
propone un resumen, y recién con tu confirmación crea la tarea, setea `current-task`
y deja el `## Next` de `progress.md` listo para el primer agente del pipeline.

(La primitiva de bajo nivel es `.agents/scripts/agent-task-new`, pero la puerta de
entrada documentada es el intake.)

## Cómo continuar desde cualquier CLI

Abrí cualquier CLI en el repo y decí:

```text
Continue the current task using the persistent agent system.
```

El agente lee `current-task`, `progress.md` (estado + próximo paso) y `task.md`, y
sigue. Podés ser explícito con el rol:

```text
Continue TASK-123 as implementer. Read `.agents/tasks/TASK-123/progress.md` and follow the persistent agent protocol.
Continue the current task as reviewer. Read the persistent task state and review the diff against base_commit.
```

## Orquestación (todo en una sesión)

En vez de abrir una sesión por fase, podés pedirle al **orquestador** que corra el
pipeline solo, despachando cada fase autónoma como **subagente** con el modelo resuelto
de `config.yml`. Frena solo donde hace falta un humano (fases interactivas, gates,
`stop-at`).

**Vos elegís la granularidad en cada invocación** — hasta el próximo gate, o de a una
fase:

```text
Orchestrate the current task using the persistent agent system.   # hasta el próximo gate
Orchestrate the current task; stop after review.                  # hasta una fase dada
Run only the next phase of the current task, then stop.           # step mode: UNA fase
Continue orchestrating the current task using the persistent agent system.
```

O directamente `/orchestrate` y `/task-step`.

- Interactivas (quedan con vos): `intake`, `specifier`.
- Autónomas (se despachan): planner, debugger, explorer, implementer, reviewer,
  security-reviewer, pr-splitter, release-manager.
- Para full fluidez sin frenar por commit, usá `commits.mode: agent` en `config.yml`
  (en `human-gated` frena en cada boundary para que commitees vos). El push siempre es
  humano.

Detalle completo en `AGENTS.md` (§ Orchestration) y en la skill `orchestrating-agents`.

## Slash commands

El install genera comandos delgados que envuelven los prompts canónicos (mismo
generador que los adaptadores: `agent-models-sync`):

- `/task-new` — arranca el intake de una tarea nueva.
- `/task-continue` — continúa la tarea actual desde el estado persistido.
- `/task-status` — muestra estado, próximo paso y últimas entradas del log.
- `/task-step` — corre **solo la próxima fase** como subagente y para (step mode).
- `/orchestrate` — corre el pipeline **hasta el próximo gate** (acepta args, ej.
  `stop after review`).

La granularidad es **decisión humana por invocación**: `/task-step` para avanzar de a
una fase con control total entre pasos; `/orchestrate` para dejarlo correr hasta que
haga falta un humano. En ambos el modelo/effort de cada fase lo resuelven los
adaptadores — nunca se elige a mano.

Claude Code los lee de `.claude/commands/`; OpenCode de `.opencode/command/`. Para
Codex, `agent-models-sync` imprime la receta de prompts per-user (`~/.codex/prompts/`).
Son generados — no los edites; se regeneran con el sync.

## Modo ahorro (cuota / tokens)

Cuando la cuota aprieta:

1. **Usá `/task-step` con la sesión principal en un modelo barato.** El orquestador es
   tier `fast` por default: la coordinación es mecánica y cada subagente corre con su
   propio modelo (adapter). De a un paso, el contexto de coordinación no se acumula
   (intercalá `/clear` si querés resetearlo), y no elegís modelo/effort a mano nunca.
   El flujo manual (sesión por fase) queda como fallback para CLIs sin subagentes.
2. **Bajá tiers en `config.yml`** (`models.agents`): p. ej. review de un `chore` en
   `fast`, implementer de cambios mecánicos en `standard` con effort `low`. Después
   corré `agent-models-sync`.
3. **Respetá el Context budget** de `AGENTS.md` (§ Context growth control): leer solo
   lo listado, `git diff --stat` primero, grep antes que lecturas completas.
4. **No saltees el gate de plan**: rehacer una implementación desviada es el mayor
   gasto de tokens posible.

## Reglas de git con enforcement mecánico (Claude Code)

Además de la prosa de `AGENTS.md`, el install deja en `.claude/settings.json`:

- `permissions.deny` para `git push` / `rebase` / `reset --hard` / `commit --amend` /
  `filter-branch`.
- Un hook `PreToolUse` (`.agents/scripts/agent-git-guard`) que atrapa comandos
  compuestos (`cd x && git push`) y bloquea `git commit` cuando `commits.mode` es
  `human-gated` (lee `config.yml` en vivo, así cambiar de modo no requiere tocar el
  hook).

En OpenCode/Codex no existe un hook equivalente: ahí rigen las mismas reglas por prosa.

## Cambiar entre Claude Code / Codex / OpenCode

No hay nada especial que hacer: todas leen los mismos archivos. Cerrá una, abrí la
otra en el mismo repo, y usá el prompt "Continue the current task...". El handoff está
en `progress.md` (frontmatter + sección `## Next`).

## Skills del equipo (`.agents/skills/`)

Librería compartida de skills reutilizables (cada una es una carpeta con un `SKILL.md`).
Cualquier agente puede consultar una skill relevante y aplicarla. Es **territorio
compartido**:

- Las skills del framework llevan el marcador `agent-framework:managed` en su `SKILL.md`;
  `update.sh` reemplaza/elimina **solo** esas. No las edites localmente.
- Las skills propias del repo **no** llevan el marcador; el updater nunca las toca.
  Agregá las tuyas acá libremente (sin marcador).

Todas las CLIs las descubren: Codex y OpenCode escanean `.agents/skills/` nativamente;
Claude Code llega vía el symlink `.claude/skills -> ../.agents/skills` que crea el install.

## Modelos por agente (tier / effort)

El tier y el effort de cada agente **no viven en los archivos de agente**: viven en
`project/config.yml` bajo `models.agents` (tier + effort por agente), que es la **única
fuente de verdad**. `models.mapping` traduce cada tier abstracto
(`reasoning` | `standard` | `fast`) al modelo concreto por CLI (`claude-code`,
`opencode`, `codex`). Ajustar tier/effort por repo = editar `models.agents` acá.

En el **flujo manual**, el `## Next` de `progress.md` incluye el modelo/effort resuelto del próximo agente
(p. ej. `reviewer — model: opus, effort: high`) y vos elegís el modelo al abrir la sesión.
Para la **orquestación**, el install genera los adaptadores de subagente por CLI
(`.claude/agents/`, `.opencode/agent/`) con ese `model:` por rol, e imprime la receta de
perfiles de Codex. Esos adaptadores (generados, no fuente) son los que hacen que cada CLI
rutee el modelo al subagente despachado.

## Qué archivos mirar primero

1. `.agents/current-task` — qué tarea está activa.
2. `.agents/tasks/<id>/progress.md` — la máquina de estados: status, fase, y la
   sección `## Next` (qué hacer ahora, qué agente usar, qué leer, cuándo parar).
3. `.agents/tasks/<id>/task.md` — el documento lógico: brief, evolución, decisiones,
   y las secciones de fase (Diagnosis, Findings, Review, ...).

`task.md` = **la historia lógica** (lo que un humano releería). `progress.md` = **la
coordinación** (lo que la máquina de estados necesita). No se duplican.

## Cierre de tarea, resúmenes y recall

Al cerrar una tarea (`APPROVED` de fix/chore, release de una feature), el agente
terminal destila `task.md` en `docs/tasks/YYYY-MM-DD-<task-name>.md` (problema,
solución, items de review pendientes, follow-ups, notas; frontmatter con `tags`,
`touched` ≤5, `related`, `outcome` y links a spec/plan) y agrega una línea a
`docs/tasks/INDEX.md`. La carpeta de la tarea queda local (gitignoreada) hasta que
quieras borrarla.

El **intake** de cada tarea nueva lee `INDEX.md` (una línea por tarea, nunca los
resúmenes enteros), detecta overlap por tags/paths y linkea solo los resúmenes que
matchean en el `task.md` nuevo — así el conocimiento pasado llega al pipeline sin
lecturas exploratorias.

## Flujo de commits

El comportamiento depende de `commits.mode` en `.agents/project/config.yml`:

- **`human-gated` (default):** el agente nunca commitea. Cuando cierra una unidad
  commiteable llena la sección `## Commit request` de `progress.md`, pone
  `status: AWAITING_COMMIT` y para. Vos revisás y commiteás. El próximo agente detecta
  el commit nuevo y resincroniza solo.
- **`agent`:** el agente commitea en los boundaries del plan y registra mensaje + SHA
  en el `## Recent log` de `progress.md`. La sección de commit request no se usa.

En **ambos modos el push es siempre humano**, y los commits **nunca** llevan co-autoría
de agentes. Para cambiar de modo, editá `commits.mode` en `config.yml`; el sistema es
agnóstico y no rompe tareas en curso.

## Por qué los commits no llevan co-autoría de agentes

La autoría pertenece al humano que opera la sesión. La trazabilidad de qué agente y
qué CLI hizo qué (con SHA) vive en el `## Recent log` de `progress.md` mientras la
tarea está abierta, no en el historial de git. El install
además setea `"includeCoAuthoredBy": false` en `.claude/settings.json` para
neutralizar mecánicamente el trailer que Claude Code agrega por defecto.

## Split de PRs

Cuando una feature queda `APPROVED` y el diff supera ~15 archivos, el `pr-splitter`
analiza el diff, arma el grafo de dependencias y propone una partición en capas
(contratos → dominio/servicios → integración/wiring). Escribe `split-plan.md` y para
en `NEEDS_HUMAN`: **vos aprobás el split antes de que se toque nada**. Post-aprobación
genera `split-execute.sh` con la secuencia exacta; el agente crea ramas locales, pero
push y creación de PRs son humanos. En cada startup detecta chunks ya mergeados y
genera la receta de rebase para el siguiente.

## Ejemplo de flujo real completo

1. **install** — corrés `install.sh` desde el repo destino; se copia el framework y se
   pre-llenan borradores con los detectores.
2. **intake** — "Start a new task..."; el intake entrevista, clasifica y crea la tarea.
3. **plan** — el `planner` escribe el plan en `docs/plans/` con Commit/PR boundaries
   y para en `NEEDS_HUMAN`.
4. **gate** — vos aprobás el plan.
5. **implement** — el `implementer` implementa por capas y emite un commit request en
   `progress.md` (o commitea, según modo) en cada boundary.
6. **review** — el `reviewer` revisa el diff contra el plan y escribe la sección
   `## Review` de `task.md` con verdict.
7. **split** — si el diff es grande, el `pr-splitter` propone y (aprobado) ejecuta el
   split en capas; vos pusheás y abrís PRs.
8. **close** — el agente terminal escribe el resumen durable en `docs/tasks/` y su
   línea en `INDEX.md`.
9. **update** — cuando sale una versión nueva del framework, corrés `update.sh`; se
   actualiza todo menos `project/`, `tasks/` y `current-task`.

## Prompts universales

```text
Start a new task using the persistent agent system.
Continue the current task using the persistent agent system.
Continue TASK-123 as implementer. Read `.agents/tasks/TASK-123/progress.md` and follow the persistent agent protocol.
Continue the current task as reviewer. Read the persistent task state and review the diff against base_commit.
```
