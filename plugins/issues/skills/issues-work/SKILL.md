---
name: issues:work
description: "Use when: user wants to start working, asks what to work on next, wants to pick a task to tackle, or is ready to begin implementation. Shows top 10 tasks and asks which one to work on using an interactive prompt."
argument-hint: 'e.g. /issues:work'
allowed-tools: Bash(issue_loader*), Bash(gh issue*), Bash(check_issues_access), Bash, Read, Write, Edit, Glob
---

# Issues: Work — Pick What to Work On

**`issue_loader` is a CLI on your $PATH.** Call it directly: `issue_loader list`, `issue_loader show 42`, `issue_loader update 42 --status in_progress`. Do NOT prefix with `bash`, do NOT use a file path. Tasks are GitHub issues in the current repo.

## Access Check
!`check_issues_access`

## Current Tasks
!`issue_loader list 2>/dev/null || echo "No issues yet."`

---

## Behavior

### On Load

1. If the **Access Check** is `NO_REPO` or `NO_AUTH`, stop and tell the user to set up access (`gh auth login` or `export GH_PAT=<token>`).
2. Run `issue_loader list` to get all tasks. Output is `number | status | priority | created | title | description`.
3. Filter to: `in_progress` tasks first, then `pending` tasks. Skip `completed` (closed) tasks.
4. Sort by priority: `0` (highest) → `1` → `2` → `3` → `later` (lowest). Within same priority, `in_progress` before `pending`.
5. Take the top 10.
6. If there are **no open tasks at all**: say *"No tasks found. Use `/issues:capture` to capture some first."* and stop.
   If there are tasks but all are `priority: later`: say *"All tasks are unprioritized. Run `/issues:triage` to set priorities first."* and continue showing them.
7. If there are tasks, use `AskUserQuestion` with:
   - question: `"What do you want to work on?"`
   - suggestions: array of up to 10 strings, each formatted as `"#number — Title (P0/P1/P2/P3/later) (status)"` e.g. `"#42 — Add login page (P1) (pending)"`

### After the User Picks

1. Parse the selected issue number from their answer.
2. Read the full task: `issue_loader show [number]`
3. Mark it in progress: `issue_loader update [number] --status in_progress`
4. Show the task plan (issue body) to the user.
5. Say: *"Starting on [Title]. Let's go."*
6. Begin working on the task immediately — implement the plan, make code changes, etc.

### If the User Picks Something Not on the List

If they type a free-form task name or say "none of these", ask if they want to:
- Create a new task with `/issues:capture`
- Plan something new with `/issues:plan`

### Rules

- Sort by priority first (`0` > `1` > `2` > `3` > `later`), then `in_progress` before `pending`
- Show at most 10 options — don't overwhelm
- After picking, transition immediately into working — no more meta-questions
- If a picked task has a thin body, suggest running `/issues:plan [number]` before starting
