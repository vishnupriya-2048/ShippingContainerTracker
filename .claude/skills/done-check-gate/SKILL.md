---
name: done-check-gate
description: Register the current task's done checks so the Stop hook re-runs them when Claude finishes. Use right after the done-checks skill has produced a valid red run and before implementing, and again to clear the registration once the user accepts the task.
---

# Done-check gate

The Stop hook (`.claude/hooks/done-check-gate.sh`) re-runs the active task's done checks every
time Claude finishes a turn. If they fail, it blocks the stop and requires a diagnosis subagent.
The hook does nothing unless a task is registered.

## Register (after the red run is confirmed)

1. Write the test file paths, one per line, to `.claude/done-checks/active.txt`
   (e.g. `test/models/shipment_test.rb`). Paths are relative to the repo root.
2. Create the directory if needed. Do not commit this file (it is gitignored).
3. Confirm to the user which files are registered.

## Tests run in Docker

The hook runs: `docker compose run --rm --no-deps web bin/rails test <files>`.
The `db` container must be up (`docker compose up -d db`).

## Clear

When the user accepts the task as done, delete `.claude/done-checks/active.txt` so the next
task starts clean.

## If the hook blocks you

Follow its instruction exactly: spawn one subagent to diagnose (read-only), then report its
findings and suggested options to the user and stop. Do not edit code or tests to force green.
