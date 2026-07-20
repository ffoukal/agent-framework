# agent-framework

Un framework **instalable** de agentes especializados que funciona con **cualquier CLI
agentic** (Claude Code, Codex, OpenCode u otras). Se instala en repos destino
(Kotlin/Gradle, Go, Node/TS) y permite que múltiples CLIs colaboren sobre una misma
tarea **sin compartir memoria interna**.

## Idea central: el repo es la memoria

La sesión y el estado de trabajo viven en archivos Markdown versionables dentro de
`.agents/`, no en la memoria de una CLI. Cualquier CLI lee esos archivos, entiende
dónde terminó la anterior y continúa.

Principios:

1. **El repo es la memoria.**
2. **Archivos antes que orquestación** — sin daemons, colas ni tooling complejo.
3. **Separación framework/proyecto** — lo genérico es idéntico y actualizable; lo
   específico del repo vive en `.agents/project/` y el updater nunca lo toca.
4. **Git es del humano** — los agentes nunca `push`/`rebase`/reescriben historia.
5. **No duplicar información** — `state.md` es descriptivo, `next.md` es prescriptivo.
6. **Protocolo en un solo lugar** — `AGENTS.md`.

## Estructura de este repo

```text
framework/         # se copia tal cual a cada repo destino (AGENTS.md, CLAUDE.md, .agents/)
project-template/  # esqueleto de la parte específica por repo (.agents/project/)
detectors/         # kotlin.sh, go.sh, node.sh — pre-llenan borradores
install.sh         # instala en un repo destino
update.sh          # actualiza el framework en un repo destino
CHANGELOG.md
```

## Instalar en un repo destino

Desde la raíz del repo destino:

```bash
# en un repo Kotlin/Go/Node cualquiera
curl -sL <url>/install.sh | sh        # o:
./install.sh /ruta/al/repo/destino     # apuntando explícitamente
```

`install.sh`:
- Descarga el framework (GitHub Release vía `gh`, fallback `git clone --depth 1`) o usa
  la copia local si se corre desde un checkout de `agent-framework`.
- Copia `framework/` al repo destino.
- Copia `project-template/` a `.agents/project/` **solo si no existe**.
- Sincroniza las skills del framework en `.agents/skills/` (territorio compartido:
  respeta las skills propias del repo) y crea el symlink `.claude/skills`.
- Corre los detectores y pre-llena `project.md`, `memory/testing.md` y
  `memory/code-map.md` con borradores marcados con TODO.
- Crea `CLAUDE.md` (`@AGENTS.md`) y `.agents/project/config.yml` si no existen.
- Configura `.claude/settings.json`: `includeCoAuthoredBy: false`, reglas
  `permissions.deny` para git prohibido (push/rebase/reset --hard/amend) y el hook
  `PreToolUse` `agent-git-guard` que hace cumplir mecánicamente las reglas de git de
  `AGENTS.md` (incluye bloquear `git commit` en modo `human-gated`). Hace merge sin
  pisar settings existentes.
- Genera los **slash commands** `/task-new`, `/task-continue`, `/task-status` y
  `/orchestrate` (`.claude/commands/`, `.opencode/command/`; receta impresa para Codex).
- Genera los **adaptadores de subagente** por CLI (`.claude/agents/`, `.opencode/agent/`)
  con el `model:` resuelto por rol, e **imprime** la receta de perfiles para el
  `config.toml` de usuario de Codex. Los adaptadores permiten que la **orquestación**
  rutee el modelo al subagente despachado.
- Migra el contenido de un `AGENTS.md`/`CLAUDE.md` preexistente a
  `.agents/project/legacy-agents-instructions.md` para que lo redistribuyas.
- Deja todo **sin commitear** — el humano revisa y commitea.

## Primer prompt: crear una tarea

Abrí cualquier CLI en el repo destino y decí:

```text
Start a new task using the persistent agent system.
```

El **intake** entrevista, clasifica el tipo (feature / fix / debug / chore / spike) —o
pregunta si es ambiguo—, crea la tarea y deja `next.md` listo. Cualquier CLI posterior
que reciba `Continue the current task using the persistent agent system.` sabe qué
tarea está activa, qué fase corresponde, qué leer y qué escribir.

## Actualizar

```bash
./update.sh /ruta/al/repo/destino
```

Reemplaza los archivos del framework y **nunca** toca `project/`, `tasks/` ni
`current-task`. Muestra el diff y deja que el humano commitee.

## Distribución

Vía **GitHub Releases** con tags semver (`v1.0.0`, ...). No hay registry: el tarball que
GitHub genera por release es el artefacto. `update.sh` compara `.agents/VERSION` contra
el último release.

## Dogfooding

Este repo se desarrolla a sí mismo con el sistema: correr `./install.sh .` sobre el
propio `agent-framework` instala `.agents/` en la raíz.

Documentación para humanos del sistema instalado: `framework/.agents/README.md`.
