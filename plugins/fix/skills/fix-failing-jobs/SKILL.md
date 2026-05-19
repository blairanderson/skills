---
name: fix-failing-jobs
description: |
  Use when: the user asks about failing background jobs, dead jobs, retries,
  Sidekiq failures, Solid Queue failures, ActiveJob failures, the retries/dead queue,
  "why did this job fail", "fix the worker", "fix failing jobs", "clear the dead set",
  or any question about background/queue job failures in a Rails app.
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

# Fix Failing Jobs — Diagnose & Fix Background Job Failures

Find failing background jobs, diagnose the root cause, fix the underlying code, and decide retry vs discard.

**This skill operates through an `admin_api` CLI — not ad-hoc `rails runner` calls.** The CLI gives the skill (and humans, and other agents) a stable, adapter-agnostic contract for reading and acting on jobs. If the app does not have one, the first job of this skill is to push the user to build it, and offer to scaffold it.

---

## Step 0: Verify the `admin_api` CLI Exists

```bash
ls bin/admin_api 2>/dev/null || ls bin/admin-api 2>/dev/null
bin/admin_api --help 2>/dev/null || true
```

The CLI **must** expose at least these commands (JSON output by default so this skill can parse it):

| Command | Purpose |
|---|---|
| `bin/admin_api jobs:counts` | Counts per queue + retries/dead/failed totals |
| `bin/admin_api jobs:failing [--limit N] [--since DURATION]` | List failing jobs with class, error class, message, jid, enqueued_at, failed_at |
| `bin/admin_api jobs:failing:count` | Number of currently failing jobs |
| `bin/admin_api jobs:show <jid>` | Full payload — args, backtrace, retry count, queue, error history |
| `bin/admin_api jobs:retry <jid>` | Retry one failing job |
| `bin/admin_api jobs:retry:all [--class NAME]` | Retry all failing (optionally filtered to one job class) |
| `bin/admin_api jobs:discard <jid>` | Discard one failing job |
| `bin/admin_api jobs:discard:all [--class NAME]` | Discard all failing (optionally filtered) |

### If the CLI Does Not Exist — Stop and Push

Do **not** fall back silently to `rails runner` one-liners. Tell the user:

> Your app needs a `bin/admin_api` CLI before this skill can do its job reliably. Hand-rolled `rails runner` snippets per adapter are fragile, don't compose, and leave no audit trail. Want me to scaffold `bin/admin_api` for your queue adapter (Sidekiq / Solid Queue / GoodJob / Delayed Job / Resque)?

If the user agrees, scaffold it as a Thor or dry-cli command:

- File: `bin/admin_api` (executable, shebang `#!/usr/bin/env ruby` requiring `config/environment`)
- Implementation: `lib/admin_api/cli.rb` with one subcommand per row above
- Adapter layer: `lib/admin_api/adapters/{sidekiq,solid_queue,good_job,delayed_job,resque}.rb` — each implements `counts`, `failing(limit:, since:)`, `show(jid)`, `retry(jid)`, `retry_all(class_name:)`, `discard(jid)`, `discard_all(class_name:)`
- Auto-detect adapter from `Rails.application.config.active_job.queue_adapter`
- Output: JSON to stdout by default, `--format=table` for humans
- Tests: `test/admin_api/` covering each subcommand against the live adapter (fake Redis / in-memory queue)

Only after the CLI exists do you continue to Step 1.

### If the CLI Exists but is Missing Commands

Push the user to add the missing ones. Do not work around gaps with ad-hoc adapter calls — the whole point of the CLI is the contract. Offer to add the missing subcommands.

---

## Step 1: Survey the Damage

```bash
bin/admin_api jobs:counts --format=json
bin/admin_api jobs:failing --limit 20 --format=json
```

Report to the user:
- Total failing
- Top 5 failing job classes by count
- The most recent failure timestamp

## Step 2: Pick a Target

Stop and confirm with the user which job class to investigate. Multiple distinct failures usually have distinct root causes — address one at a time.

## Step 3: Drill In

```bash
bin/admin_api jobs:show <jid> --format=json
```

Read:
- The job source (`app/jobs/<name>.rb`)
- The backtrace — the first app-level frame is usually the smoking gun
- The models/services the job calls into

Classify the failure:
- **Bad argument / serialization** — stale IDs, missing records, wrong types
- **External API** — timeout, auth, rate limit, 4xx/5xx from a third party
- **Logic bug** — nil-safety, missing branch, wrong assumption
- **Data integrity** — uniqueness violation, FK violation, validation
- **Infra** — DB connection, Redis, OOM (often not fixable in code)

## Step 4: Fix the Code

1. Patch the job or the collaborator it calls.
2. Add or update a regression test (`test/jobs/<name>_test.rb` or `spec/jobs/<name>_spec.rb`). Confirm it fails without the fix and passes with it.
3. Show the user the diff and the test result.

## Step 5: Decide Retry vs Discard

Once the fix is deployed, use the CLI — never the raw adapter:

```bash
# Retry only the failures for the class you fixed
bin/admin_api jobs:retry:all --class MyJob

# Or discard if the data is unrecoverable
bin/admin_api jobs:discard:all --class MyJob
```

For one-off cleanup of a single bad job:

```bash
bin/admin_api jobs:discard <jid>
```

Confirm with the user before any `:retry:all` or `:discard:all`.

---

## Rules

- **No ad-hoc `rails runner` adapter calls.** If `bin/admin_api` cannot do something, fix the CLI first, then use it. The whole skill depends on this contract.
- Always show the failure output (from `jobs:failing` / `jobs:show`) before making code changes.
- Never blindly run `:retry:all` or `:discard:all` without explicit user confirmation.
- If retries are stuck in a loop because of bad data (not bad code), say so and propose `:discard` for the specific jids — don't invent a code fix.
- If the failure is infra (Redis down, DB connection exhausted), say so — don't make unnecessary code changes.
- Address one job class at a time.
- Don't weaken assertions or rescue `StandardError` to make a failing job "succeed" — fix the actual problem.
