# Persistent agent system (`.agents/`)

Este directorio es un **sistema de agentes persistentes multi-CLI**. La idea central:
**el repo es la memoria**. El estado de cada tarea vive en archivos Markdown
versionables, no en la memoria interna de una CLI. Cualquier CLI (Claude Code, Codex,
OpenCode) puede abrir el repo, leer el estado y continuar donde otra dejó.

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
  tasks/             # datos de trabajo — el updater NUNCA los toca
    <TASK-ID>/       # una carpeta por tarea
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
y deja `next.md` listo para el primer agente del pipeline.

(La primitiva de bajo nivel es `.agents/scripts/agent-task-new`, pero la puerta de
entrada documentada es el intake.)

## Cómo continuar desde cualquier CLI

Abrí cualquier CLI en el repo y decí:

```text
Continue the current task using the persistent agent system.
```

El agente lee `current-task`, `state.md`, `next.md` y los artifacts de fase, y sigue.
Podés ser explícito con el rol:

```text
Continue TASK-123 as implementer. Read `.agents/tasks/TASK-123/next.md` and follow the persistent agent protocol.
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
en `state.md` (sección Handoff) y la instrucción concreta en `next.md`.

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

En el **flujo manual**, `next.md` incluye el modelo/effort resuelto del próximo agente
(p. ej. `reviewer — model: opus, effort: high`) y vos elegís el modelo al abrir la sesión.
Para la **orquestación**, el install genera los adaptadores de subagente por CLI
(`.claude/agents/`, `.opencode/agent/`) con ese `model:` por rol, e imprime la receta de
perfiles de Codex. Esos adaptadores (generados, no fuente) son los que hacen que cada CLI
rutee el modelo al subagente despachado.

## Qué archivos mirar primero

1. `.agents/current-task` — qué tarea está activa.
2. `.agents/tasks/<id>/state.md` — estado descriptivo: qué pasó, en qué fase estamos,
   y el **Handoff** para la próxima CLI.
3. `.agents/tasks/<id>/next.md` — estado prescriptivo: qué hacer ahora, qué agente
   usar, qué leer, cuándo parar.

`state.md` = **qué pasó** (descriptivo). `next.md` = **qué hacer** (prescriptivo).
No se duplican: no existe `handoff.md` separado; el handoff vive dentro de `state.md`.

## Flujo de commits

El comportamiento depende de `commits.mode` en `.agents/project/config.yml`:

- **`human-gated` (default):** el agente nunca commitea. Cuando cierra una unidad
  commiteable escribe `commit-request.md`, pone `status: AWAITING_COMMIT` y para. Vos
  revisás y commiteás. El próximo agente detecta el commit nuevo y resincroniza solo.
- **`agent`:** el agente commitea en los boundaries del plan y registra mensaje + SHA
  en `run-log.md`. No se usa `commit-request.md`.

En **ambos modos el push es siempre humano**, y los commits **nunca** llevan co-autoría
de agentes. Para cambiar de modo, editá `commits.mode` en `config.yml`; el sistema es
agnóstico y no rompe tareas en curso.

## Por qué los commits no llevan co-autoría de agentes

La autoría pertenece al humano que opera la sesión. La trazabilidad de qué agente y
qué CLI hizo qué (con SHA) vive en `run-log.md`, no en el historial de git. El install
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
3. **plan** — el `planner` escribe `plan.md` con Commit/PR boundaries y para en
   `NEEDS_HUMAN`.
4. **gate** — vos aprobás el plan.
5. **implement** — el `implementer` implementa por capas y emite `commit-request.md`
   (o commitea, según modo) en cada boundary.
6. **review** — el `reviewer` revisa el diff contra el plan y escribe `review.md` con
   verdict.
7. **split** — si el diff es grande, el `pr-splitter` propone y (aprobado) ejecuta el
   split en capas; vos pusheás y abrís PRs.
8. **update** — cuando sale una versión nueva del framework, corrés `update.sh`; se
   actualiza todo menos `project/`, `tasks/` y `current-task`.

## Prompts universales

```text
Start a new task using the persistent agent system.
Continue the current task using the persistent agent system.
Continue TASK-123 as implementer. Read `.agents/tasks/TASK-123/next.md` and follow the persistent agent protocol.
Continue the current task as reviewer. Read the persistent task state and review the diff against base_commit.
```
