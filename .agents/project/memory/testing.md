# Testing

<!-- How to test this repo. The updater NEVER touches this file.
     The detectors pre-fill build/test commands (marked TODO). Verify them. -->

## How to run tests
No automated test suite exists. Verification is manual/scripted:
- `bash -n install.sh update.sh detectors/*.sh .agents/scripts/*` — syntax-check
  every shell script (adjust the glob to the scripts actually touched).
- `./install.sh .` from repo root — end-to-end dogfood run; installing onto this
  repo itself should complete without errors and leave a coherent `.agents/` tree.
- `.agents/scripts/agent-task-check <task-id>` — validates a task's files
  (unreplaced placeholders, stale timestamps, model routing, Commit request vs
  status, Recent log, DONE ⇒ resume + INDEX line) after any task-file edit.

## Test layout
No `tests/` directory. There is no unit/integration test framework in this repo.

## Conventions
None — no fixtures, no mocking, no coverage tooling. Confidence comes from running
the actual scripts (`install.sh`, `update.sh`, `agent-task-check`) against real or
scratch repos and reading the resulting file tree/diff.

## Slow / flaky areas
None known. `install.sh`'s network fetch path (GitHub Release download / `git clone
--depth 1`) depends on external availability when not running from a local
`agent-framework` checkout — the local-copy fallback avoids this in dogfood runs.
