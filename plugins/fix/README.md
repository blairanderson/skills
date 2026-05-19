# Fix Plugin

Diagnose and fix things that broke — CI runs and failing background jobs.

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install plugin:

```
/plugin install fix@blairanderson-skills
```

This plugin bundles two skills:

---

## `/fix-last-run`

Check the most recent GitHub Actions workflow run on the current branch. If it failed, diagnose and fix the issue.

Trigger phrases: "what happened", "did it pass", "fix the build", "fix CI", "last run", "check the action", or any question about a recent GitHub Actions run.

Steps:

1. **Identify the repo** — `gh repo view`
2. **Get the last run** — checks the current branch first, falls back to the default branch
3. **Report status** — success stops here; in-progress runs `gh run watch` and reports when done; failures continue to diagnosis
4. **Diagnose** — reads `gh run view --log-failed` and classifies the failure: test failures, lint/format errors, build errors, deploy errors, or infrastructure/flaky issues
5. **Fix** — reads the relevant source files, makes the fix, explains what changed, and offers to commit and push so CI re-runs

Rules: always shows failure output before attempting a fix; never skips failing tests or weakens assertions; addresses multiple failures one at a time starting with the most recent.

---

## `/fix-failing-jobs`

Find the most recent failing background jobs in a Rails app, diagnose the root cause, and fix the underlying code.

Trigger phrases: "fix failing jobs", "dead jobs", "retries queue", "Sidekiq failures", "Solid Queue failed", "why did this job fail", "fix the worker".

Steps:

1. **Detect the job backend** — Sidekiq, Solid Queue, GoodJob, Delayed Job, or Resque
2. **List recent failures** — uses `bin/rails runner` against the appropriate adapter
3. **Report failures** — groups by job class, shows exception class and message, confirms which one to investigate
4. **Diagnose** — reads the job file and the backtrace; classifies as bad argument, external API, logic bug, data integrity, or infra
5. **Fix** — patches the code, adds a regression test, then proposes a retry/discard plan for the stuck jobs

Rules: always shows failure output before making changes; never blindly retries or clears the dead set without confirmation; addresses one job class at a time.
