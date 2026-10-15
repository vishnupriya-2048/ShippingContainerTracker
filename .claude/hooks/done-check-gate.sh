#!/usr/bin/env bash
# Stop hook: re-run the active task's done checks; on failure, block and demand a diagnosis.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

input=$(cat)
# Already continuing because of this hook: don't loop.
echo "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

active=".claude/done-checks/active.txt"
[ -s "$active" ] || exit 0

files=$(grep -v '^[[:space:]]*$' "$active" | tr '\n' ' ')
output=$(docker compose run --rm --no-deps -T web bin/rails test $files 2>&1)
status=$?
[ $status -eq 0 ] && exit 0

# Make the output safe inside a JSON string (backslashes, quotes, control chars).
tail_out=$(echo "$output" | tail -n 40 | tr -d '\r' | tr '\t' ' ' | tr '\n' '|')
tail_out=${tail_out//\\/\\\\}
tail_out=${tail_out//\"/\\\"}

reason="DONE-CHECK FAILED at task end. The goal is not met. Do NOT edit code or tests to force a pass. Spawn ONE read-only subagent (general-purpose) with the failing output below plus the registered files in .claude/done-checks/active.txt, ASSIGNMENT.md and the current TASKS.md step; ask it to find where the implementation diverges from the checks and whether any check itself is wrong. Then report to the user: what failed, the likely root cause, and 2-3 concrete options with your recommendation. Then stop and wait for the user. Failing output (last 40 lines, newlines shown as |): ${tail_out}"
printf '{"decision":"block","reason":"%s"}\n' "$reason"
exit 0
