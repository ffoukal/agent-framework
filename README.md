# agent-framework

An **installable** multi-agent framework for agentic CLIs. It turns a repo into a
place where specialized agents (intake, specifier, planner, implementer, reviewer,
debugger, …) run a disciplined task pipeline, hand work off to each other, and stop at
explicit human gates — with all state kept in Markdown files instead of a CLI's
internal memory.

Install it into any repo (Kotlin/Gradle, Go, Node/TS, or anything else) with
`install.sh`. Version `1.0.0`.

## Core idea: the repo is the memory

Session state lives in files under `.agents/`, not inside a CLI. Any CLI — or any
fresh session of the same CLI — reads those files, knows exactly where the previous
one stopped, and continues. Compaction is never needed: the handoff *is* the
compaction.

Principles:

1. **The repo is the memory.** No daemons, queues, or servers.
2. **Framework / project separation.** Generic parts are identical everywhere and
   updatable; repo-specific parts live in `.agents/project/` and the updater never
   touches them.
3. **Git belongs to the human.** Agents never push, rebase, amend, or rewrite history.
4. **No duplicated information.** `task.md` is the logical story, `progress.md` is the
   state machine, durable output lives once under `docs/`.
5. **Token economy is a feature.** Scripts return a handful of lines where a read
   would cost hundreds.
6. **One protocol, loaded on demand.** `AGENTS.md` is a slim always-loaded bootstrap;
   the full protocol lives in the `task-protocol` skill.

## Quick start

From the destination repo:

```bash
./install.sh /path/to/target/repo    # or, from a checkout: ./install.sh .
```

Then open any agentic CLI in that repo and run:

```text
/task                # Claude Code
```

or, on a CLI without slash commands, the equivalent prompt:

```text
Advance the current task using the persistent agent system.
```

With no active task this starts the **intake**: it interviews you, classifies the task
(`feature | fix | debug | chore | spike`), and creates it. From then on `/task` always
does the right next thing.

## What `install.sh` does

- Resolves the framework source: local checkout (dev/dogfood) or the latest GitHub
  release via `gh`, falling back to `git clone --depth 1`.
- Copies `AGENTS.md` and `.agents/{VERSION,README.md,agents,templates,scripts}`.
- Creates `.agents/project/` from `project-template/` **only if absent**, plus
  `config.yml` and `CLAUDE.md` (`@AGENTS.md`) if absent.
- Runs the **detectors** (`kotlin`, `go`, `node`) to pre-fill `project.md`,
  `memory/testing.md` and `memory/code-map.md` with TODO-marked drafts, and seeds
  `agent-test.sh` / `agent-verify.sh` from the matching stack reference
  (`agent-verify` also has a generic fallback, so no repo is left without the file).
- Syncs framework-managed skills into the shared `.agents/skills/` and links
  `.claude/skills -> ../.agents/skills`.
- Configures `.claude/settings.json` (merged with `jq`, never clobbered): co-authorship
  off, `permissions.deny` for forbidden git, the `agent-git-guard` PreToolUse hook, and
  `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=2`.
- Generates subagent adapters and the `/task` slash command via `agent-models-sync`.
- Gitignores `.agents/tasks/` and `.agents/test-logs/`, seeds `docs/{specs,plans,tasks}`
  and `docs/tasks/INDEX.md`.
- Migrates a preexisting `AGENTS.md`/`CLAUDE.md` into
  `.agents/project/legacy-agents-instructions.md` for you to redistribute.
- Ends with the **readiness report** (`agent-env-check`).

Nothing is committed — you review and commit.

## The one command: `/task`

```text
/task                        # advance until the next human gate (default)
/task step                   # exactly ONE phase, then stop
/task stop after review      # run through the end of that phase
/task status                 # read-only: state, pending gate, what's next
/task change <description>   # mid-task definition change
```

Your only responsibilities: answer the intake/specifier, approve spec/plan/split,
commit at gates (in `human-gated` mode), push, and re-run `/task`.

Definition changes are never absorbed silently: they are recorded in `task.md`
"Evolution & human decisions", spec/plan are updated (re-approval if acceptance
criteria moved), and the state machine rewinds to the affected phase — confirmed with
you first.

## Task types and pipelines

| Type | Pipeline | Logical content | Ends in |
|---|---|---|---|
| `feature` | spec → plan → implement → test → review → release/split | `docs/specs/` + `docs/plans/` + `task.md` | merged PRs + resume |
| `fix` | diagnose → implement → review | `task.md` (Diagnosis, Review) | merged PR + resume |
| `debug` | diagnose | `task.md` (Diagnosis) | `NEEDS_HUMAN` |
| `chore` | implement → review | `task.md` (brief is the plan) | merged PR + resume |
| `spike` | explore | `task.md` (Findings) | `NEEDS_HUMAN` |

```text
Phases:   intake | spec | diagnose | explore | plan | implement | test |
          review | security-review | split | release
Statuses: READY | IN_PROGRESS | AWAITING_COMMIT | NEEDS_HUMAN | BLOCKED |
          CHANGES_REQUESTED | APPROVED | DONE
```

Escalations (`debug → fix`, `fix → feature`, `chore → …`) always require explicit human
confirmation and are logged.

## Agents

| Agent | Does |
|---|---|
| `intake` | Interviews, classifies the type citing the triggering signal, recalls related past work from `docs/tasks/INDEX.md`, creates the task |
| `specifier` | Interactive discovery for a feature → approved spec in `docs/specs/` |
| `planner` | Turns the spec into an implementable, verifiable plan in `docs/plans/` |
| `implementer` | Implements one plan Task at a time, minimal changes, TDD |
| `debugger` | Finds the root cause with evidence; fixes nothing |
| `explorer` | Answers a forward-looking question for a spike |
| `reviewer` | Reviews the diff against plan/diagnosis, emits a verdict |
| `security-reviewer` | Focused review when the diff touches sensitive surfaces |
| `pr-splitter` | Splits a large approved diff into dependency-ordered PR chunks |
| `release-manager` | Release notes, PR summary, merge order, task close |
| `orchestrator` | Dispatches every autonomous phase as a subagent and returns at each gate |

Roles are plain Markdown in `.agents/agents/` — readable and runnable by any CLI.

## Orchestration

```text
your session (any model)              pays only dispatch + short reports
 └── orchestrator (subagent, fast model)
      ├── dispatches each phase as a nested subagent (model per adapter)
      └── gate → writes state to disk and RETURNS (never waits)
```

- Every phase agent reads everything from `task.md`/`progress.md` — it never inherits
  chat history — and answers in ≤10 lines; detail stays on disk.
- The topology is enforced, not suggested: `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=2`
  (Claude Code ≥ 2.1.217) plus phase adapters that deny the `Agent` tool. Coordination
  can't run on your expensive model, and a phase agent can't dispatch on its own.
- CLIs without subagents or without nesting fall back to the `orchestrating-agents`
  skill: in-session coordination (use a cheap model) or the manual per-phase flow.

## Models per agent

`.agents/project/config.yml` is the single source of truth:

```yaml
models:
  agents:                    # tier + effort per agent
    orchestrator: { tier: fast,      effort: low }
    planner:      { tier: standard,  effort: medium }
    pr-splitter:  { tier: reasoning, effort: medium }
  mapping:                   # abstract tier -> concrete model per CLI
    reasoning: { claude-code: opus,   opencode: <provider/model>, codex: <model> }
    standard:  { claude-code: sonnet, opencode: <provider/model>, codex: <model> }
    fast:      { claude-code: haiku,  opencode: <provider/model>, codex: <model> }
```

Edit it, then run `.agents/scripts/agent-models-sync` to regenerate `.claude/agents/`
and `.claude/commands/`. In the manual flow, the `## Next` section of `progress.md`
carries the resolved model/effort (e.g. `reviewer — model: opus, effort: high`) so you
pick the model when opening the session. `agent-task-check` warns when `config.yml` is
newer than the generated adapters.

## State layout

```text
AGENTS.md            # slim always-loaded bootstrap (CLAUDE.md just imports it)
.agents/
  VERSION  README.md
  agents/            # framework — agent roles.        DO NOT edit locally
  templates/         # framework — artifact templates. DO NOT edit locally
  scripts/           # framework — task utilities.     DO NOT edit locally
  skills/            # shared: framework-managed + repo-owned skills
  project/           # ★ this repo's own — the updater NEVER touches it
    project.md  config.yml
    agent-test.sh  agent-verify.sh  checks.sh
    memory/          # architecture, domain, code-map, testing, conventions, decisions
  tasks/<TASK-ID>/   # LOCAL working state (gitignored): task.md + progress.md
  tasks/.current     # active task id (local per dev, gitignored with tasks/)
docs/specs|plans|tasks/   # durable, git-versioned: YYYY-MM-DD-<task-name>.md
```

Two working files per task, no overlap: **`task.md`** is the living logical document
(brief, evolution, decisions, diagnosis, findings, review) — what a human would
re-read. **`progress.md`** is the machine file (state-machine frontmatter, `## Next`
instruction, `## Commit request`, rolling ~5-entry log).

## Scripts

All framework-owned, in `.agents/scripts/`:

| Script | Purpose |
|---|---|
| `agent-task-new` | Low-level task creation (the documented entry point is the intake) |
| `agent-task-current` | Print the active task id |
| `agent-task-next` | Print just the `## Next` section — instead of reading `progress.md` |
| `agent-task-status` | State + brief; `--all` lists every task in one line each |
| `agent-task-check` | Validate every protocol invariant (final step of shutdown) |
| `agent-plan` | Feature-list state machine over the plan (`next`/`show`/`status`/`set`/`check`) |
| `agent-test` | Compact test runner (dispatcher) |
| `agent-verify` | Compact verification gate (dispatcher) |
| `agent-env-check` | Repo readiness report |
| `agent-models-sync` | Regenerate CLI adapters + slash commands from `config.yml` |
| `agent-git-guard` | PreToolUse hook enforcing the git rules |

## Verification: `agent-test` vs `agent-verify`

`agent-test` proves **the tests pass**; `agent-verify` proves **the change is done**.
Both are framework-owned *dispatchers* with a repo-owned implementation in
`.agents/project/` — seeded by the detectors, never touched by the updater.

```text
agent-test all            full suite, compact summary only (counts + failing ids)
agent-test one <pattern>  targeted run
agent-test show <test>    failure message + trimmed stack for one test

agent-verify quick   build + lint + typecheck + project/checks.sh
agent-verify full    quick + the whole suite
agent-verify e2e     full + the app boots and the critical path really runs
agent-verify clean   handoff gate: no debug leftovers, no stray artifacts
```

Every level prints one compact block; full tool output goes to
`.agents/test-logs/verify-<level>.log`, never to stdout. The plan fixes the required
level, and `e2e` is mandatory when the diff crosses a layer — exactly where mocks are
blind. Without evidence of the level executed, an `APPROVED` is just an opinion about a
diff.

`checks.sh` holds **promoted checks**: review findings turned into an executable rule,
so the same mistake is caught by a script next time instead of by a reviewer.

## The plan is a state machine

For a `feature`, the plan's `## Tasks` section **is** the scheduler of the implement
phase: each `### Tn` carries `verify` (an executable command), `state`
(`todo|active|blocked|done`) and `evidence`. It is driven with `agent-plan`, never by
hand, which enforces two rules nobody remembers otherwise: **WIP = 1** (a single
`active` Task) and **nothing reaches `done` without evidence**. The implementer never
promotes its own Task — the orchestrator closes it.

## Cost and context optimizations

Nested orchestration is already the cheap path (coordination runs on the `fast` tier
and dies at every gate). When quota is tight, the levers, in order:

1. **Prefer a script to a read.** `agent-plan next` instead of the plan file,
   `agent-task-next` instead of `progress.md`, `agent-verify` instead of pasting build
   output. A handful of lines instead of hundreds — and unlike a read, the answer
   doesn't occupy context for the rest of the session.
2. **Never dump test-runner output into a session** — it is re-read on every later
   turn. That's the whole reason `agent-test` exists: logs on disk, summary in context.
3. **`/task step`** — one phase at a time, zero accumulated multi-phase coordination.
4. **Context compact gate** (`context.compact_gate`, default 40% of the window): on
   reaching it an agent must not start another phase — it finishes the shutdown
   protocol and hands off. Resuming from disk is free.
5. **Lower tiers in `config.yml`** — e.g. review of a `chore` on `fast`, mechanical
   implementation on `standard` with `effort: low`. Then `agent-models-sync`.
6. **Respect the context budget**: read only what `## Next` lists, `git diff --stat`
   before the full diff, grep before whole-file reads, never re-read a file.
7. **Don't skip the plan gate.** Redoing a drifted implementation is the single largest
   possible token expense.

## Skills

`.agents/skills/` is a shared library; each skill is a folder with a `SKILL.md`.
All CLIs discover it: Codex and OpenCode scan it natively, Claude Code reaches it via
the `.claude/skills -> ../.agents/skills` symlink.

- **Framework skills** carry the `agent-framework:managed` marker: `task-protocol`,
  `orchestrating-agents`, `test-driven-development`, `conventional-commits`.
  `update.sh` replaces/removes **only** these — don't edit them locally.
- **Per-project skills**: drop a folder with a `SKILL.md` into `.agents/skills/` and
  omit the marker. The updater never touches it, and every agent in the repo can use
  it. (If a repo skill shadows a framework name, the installer warns and skips rather
  than overwriting.)
- **Global / personal skills** are a CLI-level feature and live outside the repo
  (for Claude Code, `~/.claude/skills/`). Use them for things that follow *you* across
  repos; use `.agents/skills/` for anything the *team* should get from a checkout.

## Git safety

Agents **never** run `git push`, `git rebase`, `git reset --hard`, `git commit --amend`,
branch deletion, or any history rewrite — including the `gh stack` equivalents. Pushing
is always human. Commits never carry AI co-authorship trailers or "Generated with…"
attribution: authorship belongs to the human operating the session; the trace of which
agent did what (with SHAs) lives in the `## Recent log` of `progress.md`.

On Claude Code these rules are enforced mechanically, not just in prose:
`permissions.deny` entries, plus the `agent-git-guard` PreToolUse hook that catches
compound commands (`cd x && git push`) and blocks `git commit` in `human-gated` mode by
reading `config.yml` live. On other CLIs the same rules stay prose-enforced.

Commit behavior follows `commits.mode` in `config.yml`:

- **`human-gated`** — the agent never commits. At a committable boundary it fills
  `## Commit request` in `progress.md`, sets `AWAITING_COMMIT` and stops. You commit;
  the next agent detects it and resyncs.
- **`agent`** — the agent commits at plan boundaries and records message + SHA in the
  Recent log.

Switching modes doesn't break in-flight tasks: reviewer and pr-splitter work off
`git diff <base_commit>..HEAD` in both.

## PR splitting

When a feature is `APPROVED` and the diff exceeds ~15 files, the `pr-splitter` builds
the dependency graph and proposes a layered partition (contracts → domain/services →
integration/wiring). It writes `split-plan.md` and stops at `NEEDS_HUMAN`: **you
approve the split before anything is touched.** After approval it generates
`split-execute.sh` and creates local branches; pushing and opening PRs stay human. On
each startup it detects already-merged chunks and emits the rebase recipe for the next.

## Task close, resumes and recall

On close, the terminal agent distills `task.md` into
`docs/tasks/YYYY-MM-DD-<task-name>.md` (problem, solution, pending review items,
follow-ups; frontmatter with `tags`, `touched` ≤5, `related`, `outcome`, `harness_gap`,
links to spec/plan) and appends one line to `docs/tasks/INDEX.md`. The intake of every
new task reads only that INDEX, detects overlap by tags/paths, and links just the
matching resumes — so past knowledge reaches the pipeline without exploratory reading.

`harness_gap` (`none|spec|context|env|feedback|state`) is the framework's own feedback
loop:

```sh
grep -h '^harness_gap:' docs/tasks/*.md | sort | uniq -c | sort -rn
```

The layer that shows up most is where to invest; layers that never show up are pruning
candidates. Every piece of this framework exists because some model couldn't do
something alone — models improve, pieces don't delete themselves. Once a month, disable
a component, run a representative task, and if the result doesn't get worse, delete it.

## Repo readiness

`agent-env-check` answers "can this repo actually sustain the pipeline?": `project.md`
free of TODOs, `agent-test.sh`/`agent-verify.sh` present and executable,
`docs/{specs,plans,tasks}` + INDEX, `.agents/tasks/` gitignored, adapters generated. It
runs at the end of `install.sh`/`update.sh` and as a warning inside every
`agent-task-check`. It's the one subsystem an agent cannot fix for itself.

## Multi-CLI

Everything that matters is plain Markdown plus POSIX shell, so any agentic CLI can run
the pipeline:

- `AGENTS.md` is read natively by Codex and OpenCode; `CLAUDE.md` only does `@AGENTS.md`.
- Agent roles (`.agents/agents/*.md`), templates, skills and scripts are CLI-agnostic.
- Handoff lives in `progress.md`, so switching CLIs is just: close one, open the other
  in the same repo, run `/task` or the universal prompt.

Claude Code is the only **actively maintained** adapter target: `agent-models-sync`
currently generates `.claude/agents/` and `.claude/commands/` only, and the git-guard
hook has no equivalent hook point elsewhere. Nothing else is Claude-specific — the
`opencode`/`codex` columns remain in `models.mapping`, and any CLI can follow the manual
flow by reading `.agents/agents/*.md` + `config.yml` directly.

**Adding a CLI** is therefore small: teach `agent-models-sync` to emit that CLI's
subagent/command files (its generation block for OpenCode/Codex is preserved in git
history), fill its column in `models.mapping`, and — if it has a pre-tool hook point —
wire `agent-git-guard` into it. No other file needs to change.

Universal prompts for CLIs without slash commands:

```text
Advance the current task using the persistent agent system.
Advance the current task; run only the next phase, then stop.
Continue TASK-123 as implementer. Read `.agents/tasks/TASK-123/progress.md` and follow the persistent agent protocol.
```

## Updating

```bash
./update.sh /path/to/target/repo
```

Replaces `AGENTS.md`, `.agents/README.md`, `agents/`, `templates/`, `scripts/`,
managed skills and `VERSION`; **never** touches `project/` or `tasks/` (which holds `tasks/.current`).
It shows the diff and leaves the commit to you.

Distribution is via **GitHub Releases** with semver tags (`v1.0.0`, …) — no registry;
the tarball GitHub generates per release is the artifact, and `update.sh` compares
`.agents/VERSION` against the latest release. Override the source repo with
`AGENT_FRAMEWORK_REPO`.

## This repo's layout

```text
framework/         # copied verbatim into every target repo (AGENTS.md, .agents/)
project-template/  # skeleton of the per-repo part (.agents/project/)
detectors/         # kotlin.sh, go.sh, node.sh + agent-test/ and agent-verify/ references
install.sh         # install into a target repo
update.sh          # update the framework in a target repo
CHANGELOG.md
```

`framework/` is the source of truth. This repo **dogfoods itself**: running
`./install.sh .` installs `.agents/` at its own root, so the framework is developed
with the framework.

Human-facing docs for the installed system: `framework/.agents/README.md`.
