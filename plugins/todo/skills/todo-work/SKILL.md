---
name: todo:work
description: "Use when: user wants to start working, asks what to work on next, wants to pick a task to tackle, or is ready to begin implementation. Shows top 10 tasks and asks which one to work on using an interactive prompt."
argument-hint: 'e.g. /todo:work'
allowed-tools: Bash(check_git_policy), Bash, Read, Write, Edit, Glob
---

# Todo: Work — Pick What to Work On

**`task_loader` is a CLI on your $PATH.** Call it directly: `task_loader list`, `task_loader show ID`, `task_loader update ID --status in_progress`. Do NOT prefix with `bash`, do NOT use a file path like `.tasks/task_loader`.

## Current Tasks
!`task_loader list 2>/dev/null || echo "No tasks yet."`

---

## Behavior

### On Load

1. Run `task_loader list` to get all tasks.
2. Filter to: `in_progress` tasks first, then `pending` tasks. Skip `completed` and `blocked` unless nothing else exists.
3. Sort by priority: `0` (highest) → `1` → `2` → `3` → `later` (lowest). Within same priority, `in_progress` before `pending`.
4. Take the top 10.
4. If there are **no tasks at all**: say *"No tasks found. Use `/todo:capture` to capture some first."* and stop.
   If there are tasks but all are `priority: "later"`: say *"All tasks are unprioritized. Run `/todo:triage` to set priorities first."* and continue showing them.
5. If there are tasks, use `AskUserQuestion` with:
   - question: `"What do you want to work on?"`
   - suggestions: array of up to 10 strings, each formatted as `"ID — Task Name (P0/P1/P2/P3/later) (status)"` e.g. `"4R — Add login page (P1) (pending)"`

### After the User Picks

1. Parse the selected task ID from their answer.
2. Read the full task: `task_loader show ID`
3. Mark it in progress: `task_loader update ID --status in_progress`
4. Show the task plan to the user.
5. Say: *"Starting on [Task Name]. Let's go."*
6. Begin working on the task immediately — implement the plan, make code changes, etc.

### If the User Picks Something Not on the List

If they type a free-form task name or say "none of these", ask if they want to:
- Create a new task with `/todo:capture`
- Plan something new with `/todo:plan`

### Rules

- Sort by priority first (`0` > `1` > `2` > `3` > `later`), then `in_progress` before `pending`
- Show at most 10 options — don't overwhelm
- After picking, transition immediately into working — no more meta-questions
- If a picked task has no plan body, suggest running `/todo:plan ID` before starting
