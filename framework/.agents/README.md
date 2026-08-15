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
    agent-test.sh     # implementación del runner compacto de tests
    agent-verify.sh   # implementación del gate de verificación (quick|full|e2e|clean)
    checks.sh         # reglas promovidas: hallazgos de review vueltos check ejecutable
    memory/          # arquitectura, dominio, code-map, testing, convenciones, decisiones
  tasks/             # estado de trabajo LOCAL (gitignoreado) — el updater NUNCA lo toca
    <TASK-ID>/       # una carpeta por tarea: task.md + progress.md (+ split-plan.md)
  current-task       # id de la tarea activa (o vacío)
```

El **protocolo universal** vive en `AGENTS.md` (raíz del repo). `CLAUDE.md` solo
importa `@AGENTS.md`. Codex y OpenCode leen `AGENTS.md` nativamente.

## Cómo usarlo: un solo comando

Todo el ciclo de vida pasa por **`/task`**. Mira el estado persistido y hace lo
correcto:

- **No hay tarea activa** → arranca el **intake** en tu sesión: entrevista, clasifica
  (feature / fix / debug / chore / spike), propone un resumen y recién con tu
  confirmación crea la tarea. (La primitiva de bajo nivel es
  `.agents/scripts/agent-task-new`; la puerta de entrada es el intake.)
- **Fase interactiva** (`intake`, `specifier`) → la conversación queda en tu sesión.
- **Fase autónoma** → despacha el **orquestador** como subagente (modelo barato,
  fijado por su adapter), que corre el pipeline y **retorna en cada gate** diciéndote
  exactamente qué necesita. Resolvés el gate (commit, aprobación) cuando quieras y
  volvés a tipear `/task` — en esta sesión o en una fresca: el estado vive en disco,
  nada depende de la sesión vieja.

```text
/task                        # avanza hasta el próximo gate (default)
/task step                   # UNA fase y para (control total entre pasos)
/task stop after review      # corre hasta terminar esa fase
/task status                 # solo lectura: estado, gate pendiente, qué sigue
/task change <descripción>   # cambio de definición a mitad de tarea
```

Tus únicas responsabilidades: responder al intake/specifier, aprobar spec/plan/split,
commitear en los gates (modo `human-gated`), pushear, y relanzar `/task`.

**Cambios de definición** (`/task change` o decirlo en prosa): se registran en
`task.md` "Evolution & human decisions", se actualiza spec/plan si corresponde
(re-aprobación si se movieron los criterios), y la máquina de estados rebobina hasta
la fase afectada — confirmándolo con vos antes. El orquestador nunca absorbe un cambio
de alcance en silencio.

En cualquier CLI sin slash commands sirve el prompt equivalente:
`Advance the current task using the persistent agent system.`; para forzar un rol:
`Continue TASK-123 as implementer. Read .agents/tasks/TASK-123/progress.md and follow the persistent agent protocol.`

## Cómo funciona la orquestación (anidada)

```text
tu sesión (cualquier modelo)          paga solo dispatch + reportes cortos
 └── orchestrator (subagente, modelo fast por adapter)
      ├── despacha cada fase como subagente anidado (modelo por adapter)
      │     planner · debugger · explorer · implementer · reviewer ·
      │     security-reviewer · pr-splitter · release-manager
      └── gate → escribe estado en disco y RETORNA (nunca espera)
```

- Cada agente de fase lee todo de `task.md`/`progress.md` — nunca hereda historia de
  chat — y responde con ≤10 líneas: el detalle queda en disco.
- La topología es regla dura: el installer setea
  `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=2` (Claude Code ≥ 2.1.217) y los adapters de
  los agentes de fase niegan la tool `Agent`, así que ni la coordinación puede correr
  en tu modelo caro ni un agente de fase puede despachar por su cuenta.
- Para full fluidez sin frenar por commit, usá `commits.mode: agent` en `config.yml`
  (en `human-gated` retorna en cada boundary para que commitees vos). El push siempre
  es humano.
- CLIs sin subagentes o sin anidamiento: fallback de la skill `orchestrating-agents`
  (coordinación en sesión — usala con un modelo barato — o flujo manual por fase).

Detalle completo en `AGENTS.md` (§ Orchestration) y en la skill `orchestrating-agents`.
`/task` es generado por `agent-models-sync` (Claude Code: `.claude/commands/`;
OpenCode: `.opencode/command/`; Codex: receta per-user impresa por el sync). No lo
edites — se regenera.

## Modo ahorro (cuota / tokens)

La orquestación anidada ya es el camino barato: la coordinación corre en modelo `fast`
y muere en cada gate, así que no se acumula contexto caro. Si la cuota aprieta más:

1. **`/task step`**: de a una fase, cero coordinación multi-fase acumulada.
2. **Gate de contexto** (`context.compact_gate` en `config.yml`, default 40%): al
   alcanzarlo, el agente no arranca otra fase — cierra protocolo y corta; retomar de
   disco es gratis. Subilo o bajalo por repo.
3. **Bajá tiers en `config.yml`** (`models.agents`): p. ej. review de un `chore` en
   `fast`, implementer de cambios mecánicos en `standard` con effort `low`. Después
   corré `agent-models-sync`.
4. **Respetá el Context budget** de `AGENTS.md` (§ Context growth control): leer solo
   lo listado, `git diff --stat` primero, grep antes que lecturas completas.
5. **No saltees el gate de plan**: rehacer una implementación desviada es el mayor
   gasto de tokens posible.
6. **Un script en vez de una lectura.** `agent-plan next` en vez de leer el plan
   entero, `agent-task-next` en vez de leer `progress.md`, `agent-verify` en vez de
   pegar salida de build. Devuelven un puñado de líneas donde la lectura costaría
   cientos — y a diferencia de la lectura, no quedan ocupando contexto el resto de la
   sesión. Misma lógica que `agent-test`: la salida completa vive en disco.

## Verificación: `agent-test` vs `agent-verify`

`agent-test` prueba que **los tests pasan**. `agent-verify` prueba que **el cambio
está hecho**: `quick` (build+lint+typecheck+`checks.sh`), `full` (+ suite), `e2e`
(+ la app arranca y el camino crítico corre de verdad), `clean` (gate de handoff: sin
restos de debug, sin artefactos sueltos). El plan fija el nivel; `e2e` es obligatorio
cuando el diff cruza una capa, que es justo donde los mocks son ciegos. Sin evidencia
de nivel ejecutado, un `APPROVED` es una opinión sobre un diff.

## Lista de features: el plan es una máquina de estados

Para un `feature`, la sección `## Tasks` del plan **es** el scheduler de la fase
implement: cada `### Tn` lleva `verify` (comando ejecutable), `state`
(`todo|active|blocked|done`) y `evidence`. Se maneja con `agent-plan` (`next`, `set`,
`status`, `check`), nunca a mano. El script impone dos reglas que si no, nadie
recuerda: **WIP=1** (una sola Task `active`) y **nada pasa a `done` sin evidencia** —
y el implementer nunca promueve su propia Task, la cierra el orchestrator.

## Simplificación periódica del harness

Cada pieza de este framework existe porque algún modelo no podía hacer algo solo. Los
modelos mejoran; las piezas no se auto-borran. **Una vez por mes**: desactivá un
componente (una regla de rol, un check, una fase), corré una tarea representativa, y si
el resultado no empeora, borralo. Si empeora, restauralo o reemplazalo por algo más
liviano. Sin esta poda el harness solo crece, y cada línea que sobra se paga en tokens
en cada tarea, para siempre.

Para saber *qué* podar y qué reforzar, mirá el campo `harness_gap` de los resúmenes
(`none|spec|context|env|feedback|state`):

```sh
grep -h '^harness_gap:' docs/tasks/*.md | sort | uniq -c | sort -rn
```

La capa que más aparece es donde conviene invertir; las que nunca aparecen son
candidatas a poda. Es adivinar menos y medir un poco.

## Readiness del repo

`agent-env-check` responde "¿este repo puede realmente sostener el pipeline?":
`project.md` sin TODOs, `agent-test.sh` y `agent-verify.sh` presentes y ejecutables,
`docs/{specs,plans,tasks}` + INDEX, `.agents/tasks/` gitignoreado, adapters generados.
Corre solo al final de `install.sh`/`update.sh` y en cada `agent-task-check` (como
warning). Es el único subsistema que un agente no puede arreglarse a sí mismo.

## Reglas de git con enforcement mecánico (Claude Code)

Además de la prosa de `AGENTS.md`, el install deja en `.claude/settings.json`:

- `permissions.deny` para `git push` / `rebase` / `reset --hard` / `commit --amend` /
  `filter-branch`.
- Un hook `PreToolUse` (`.agents/scripts/agent-git-guard`) que atrapa comandos
  compuestos (`cd x && git push`) y bloquea `git commit` cuando `commits.mode` es
  `human-gated` (lee `config.yml` en vivo, así cambiar de modo no requiere tocar el
  hook).
- `env.CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=2` — habilita y a la vez limita la
  orquestación anidada (sesión → orquestador → agentes de fase, nada más profundo).

En OpenCode/Codex no existe un hook equivalente: ahí rigen las mismas reglas por prosa.

## Cambiar entre Claude Code / Codex / OpenCode

No hay nada especial que hacer: todas leen los mismos archivos. Cerrá una, abrí la
otra en el mismo repo, y usá `/task` (o el prompt "Advance the current task using the
persistent agent system."). El handoff está en `progress.md` (frontmatter + sección
`## Next`).

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
2. **`/task`** — no hay tarea activa: el intake entrevista, clasifica y crea la tarea;
   el orquestador arranca solo el pipeline.
3. **plan** — el `planner` escribe el plan en `docs/plans/` con Commit/PR boundaries;
   el orquestador retorna en `NEEDS_HUMAN`.
4. **gate** — vos aprobás el plan → `/task`.
5. **implement** — el `implementer` implementa por capas y emite un commit request en
   `progress.md` (o commitea, según modo) en cada boundary; en `human-gated`
   commiteás y relanzás `/task` por boundary.
6. **review** — el `reviewer` revisa el diff contra el plan y escribe la sección
   `## Review` de `task.md` con verdict.
7. **split** — si el diff es grande, el `pr-splitter` propone y (aprobado) ejecuta el
   split en capas; vos pusheás y abrís PRs.
8. **close** — el agente terminal escribe el resumen durable en `docs/tasks/` y su
   línea en `INDEX.md`.
9. **update** — cuando sale una versión nueva del framework, corrés `update.sh`; se
   actualiza todo menos `project/`, `tasks/` y `current-task`.

## Prompts universales (CLIs sin slash commands)

```text
Advance the current task using the persistent agent system.
Advance the current task; run only the next phase, then stop.
Continue TASK-123 as implementer. Read `.agents/tasks/TASK-123/progress.md` and follow the persistent agent protocol.
Continue the current task as reviewer. Read the persistent task state and review the diff against base_commit.
```

(Sin tarea activa, el primero arranca el intake — igual que `/task`.)
