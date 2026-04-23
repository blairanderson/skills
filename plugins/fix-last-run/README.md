# Fix Last Run Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install fix-last-run@blairanderson-skills
```

This plugin adds one skill for checking and fixing GitHub Actions workflow failures.

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
