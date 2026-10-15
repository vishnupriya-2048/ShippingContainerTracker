---
name: project-slop-check
description: Project-specific slop review for ShippingContainerTracker. Run after the global noslopcheck, before reporting any task done. Catches what the generic checklist misses - deviation from ASSIGNMENT.md/TASKS.md, over-engineering, symptom-patching instead of fixing the root cause, and Rails/Karafka convention breaks.
allowed-tools: Bash(git diff:*), Bash(git status:*), Read, Grep, Glob
---

# Project slop check

Reports only; never edits. Review `git diff HEAD` plus untracked files (`git status --short`)
against ASSIGNMENT.md and the current TASKS.md step. Read both first.

Run the global `noslopcheck` skill for its 10 generic points (dead code, unhandled errors,
duplication, naming, edges, comments, consistency, scope, fake done, verified-not-claimed).
Then check these project-specific points:

1. **Plan deviation** - Does every change map to a requirement in ASSIGNMENT.md and the current
   TASKS.md step? Flag anything built that is not asked for (extra models, columns, screens,
   gems, endpoints) and anything asked for that is missing or quietly changed.
2. **Over-engineering** - Service objects, concerns, base classes, config options, or
   abstractions with a single caller. Rails already provides the default; use it unless the
   task needs more. Prefer fewer files and fewer layers.
3. **Root cause vs symptom** - Is the change fixing the cause, or patching around it
   (rescue-and-ignore, `try`/`&.` sprinkled to silence nil, retries, sleeps, special-case
   `if`s, duplicated fixes in several places)? State the root cause in one sentence and
   confirm the diff addresses it at its source.
4. **Rails conventions** - Logic in the right layer (models for data rules, controllers thin,
   no queries in views), RESTful routes, validations in the model AND constraints/indexes in
   the migration, strong params, no N+1 queries, migrations reversible and not edited after
   being run.
5. **Kafka/Karafka conventions** - Consumers idempotent and fast, malformed messages handled
   (not crashing the consumer), topic names/keys consistent with the plan, broker address read
   from `KAFKA_BROKERS`, no business logic inside the consumer beyond parsing + persisting.
6. **Naming vs domain** - Names match the assignment's vocabulary (shipment, container,
   location...); one word per concept across models, columns, routes, and JS.
7. **Secrets & config** - No keys in code; `MAPS_JS_API_KEY` only via ENV; `.env` untracked.

## Output

For each of the 7 points: `clean`, `violation: file:line - problem - suggested fix`, or
`justified exception: why`. Finish with exactly one line, nothing after it:

`PROJECT-SLOP: PASS` or `PROJECT-SLOP: BLOCK`

BLOCK if any violation is unresolved or unjustified.
