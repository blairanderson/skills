---
name: todo:done
description: "Use when: user wants to mark a task as done and delete it, remove a completed task, clean up a finished task, or says 'done with task X'. Confirms with user before deleting the task file."
argument-hint: 'e.g. /todo:done or /todo:done 4R'
allowed-tools: Bash(task_loader*), Bash(check_git_policy), Glob(.tasks/*), Read(.tasks/*)
---

# Todo: Done — Complete & Delete a Task

**`task_loader` is a CLI on your $PATH.** Call it directly: `task_loader list`, `task_loader show ID`, `task_loader delete ID`. Do NOT prefix with `bash`, do NOT use a file path like `.tasks/task_loader`.

## !! HARD CONSTRAINT — READ FIRST !!

**You are NOT allowed to write application code in this skill. Ever. Under any circumstances.**

The ONLY action you take is confirming and deleting `.tasks/ID.md` task files.

---

## Current Tasks
!`task_loader list 2>/dev/null || echo "No tasks yet."`

---

## Behavior

### On Load

1. Run `task_loader list` to get all tasks.
2. If the user provided a task ID as an argument, skip to **Confirm Deletion** with that ID.
3. If no argument was provided, show tasks and use `AskUserQuestion` with:
   - question: `"Which task is done?"`
   - suggestions: array of tasks formatted as `"ID — Task Name (status)"` e.g. `"4R — Add login page (in_progress)"`
   - Prioritize showing `in_progress` tasks first, then `pending`.

### Confirm Deletion

1. Read the full task: `task_loader show ID`
2. Display the task name and description to the user.
3. Use `AskUserQuestion` to confirm:
   - question: `"Delete task [ID] — [Task Name]? This permanently removes the file."`
   - options: `"Yes, delete it"` and `"No, keep it"`

### If Confirmed

1. Run: `task_loader delete ID`
2. Say: *"Done. Task [ID] — [Task Name] deleted."*

### If Declined

Say: *"Kept task [ID]. No changes made."*

---

## Rules

- ALWAYS confirm before deleting — never skip the confirmation step
- Show the task details before asking for confirmation so the user knows what they're deleting
- Only delete one task at a time — if the user wants to delete multiple, loop through them one by one
- Do NOT mark the task as `completed` first — just delete the file directly
- Do NOT write any files — this skill only reads and deletes
