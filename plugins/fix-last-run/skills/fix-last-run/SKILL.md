---
name: fix-last-run
description: |
  Use when: the user asks about GitHub Actions, CI status, workflow runs, build failures,
  "what happened", "did it pass", "fix the build", "fix CI", "last run", "check the action",
  or any question about the most recent GitHub Actions workflow run.
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

# Fix Last Run — Check & Fix GitHub Actions Failures

Check the most recent GitHub Actions workflow run. If it failed, diagnose and fix the issue.

## Step 1: Identify the Repo

```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

## Step 2: Get the Last Workflow Run

```bash
# Most recent run on the current branch
gh run list --branch "$(git branch --show-current)" --limit 5 --json databaseId,status,conclusion,name,headBranch,createdAt

# If no runs on current branch, check default branch
gh run list --limit 5 --json databaseId,status,conclusion,name,headBranch,createdAt
```

Report the status to the user immediately:
- **Success** → tell the user, done.
- **In progress** → immediately run `gh run watch <id> --exit-status` and report the result when it completes.
- **Failure** → continue to Step 3.

## Step 3: Diagnose the Failure

```bash
# Get the full run details including failed jobs
gh run view <run-id>

# Get logs for the failed job(s)
gh run view <run-id> --log-failed
```

Read the failed logs carefully. Common failure categories:
- **Test failures** — read the failing test and the code it tests
- **Lint/format errors** — identify the exact files and violations
- **Build errors** — missing dependencies, type errors, compilation failures
- **Deploy errors** — config issues, secrets, permissions
- **Flaky/infra** — timeouts, rate limits, runner issues (not fixable in code)

## Step 4: Fix the Issue

1. Read the relevant source files to understand the failure context
2. Make the fix
3. Show the user what you changed and why
4. Offer to commit and push so CI re-runs

## Rules

- Always show the user the failure output before attempting a fix
- If the failure is infrastructure/flaky (not a code problem), say so — don't make unnecessary code changes
- If you're unsure about the fix, explain your diagnosis and proposed fix before editing files
- If multiple workflows failed, address them one at a time starting with the most recent
- Never skip failing tests or weaken assertions to "fix" CI — fix the actual problem
