---
name: issues:done
description: "Use when: user wants to mark a task as done, close a completed task, clean up a finished task, or says 'done with task X'. Confirms with user before closing the GitHub issue."
argument-hint: 'e.g. /issues:done or /issues:done 42'
allowed-tools: Bash(issue_loader*), Bash(gh issue*), Bash(check_issues_access), AskUserQuestion
---

# Issues: Done — Complete & Close a Task

**`issue_loader` is a CLI on your $PATH.** Call it directly: `issue_loader list`, `issue_loader show 42`, `issue_loader close 42`. Do NOT prefix with `bash`, do NOT use a file path. Tasks are GitHub issues — "done" **closes** the issue (it is not deleted, so history is preserved and it can be reopened).

## !! HARD CONSTRAINT — READ FIRST !!

**You are NOT allowed to write application code in this skill. Ever. Under any circumstances.**

The ONLY action you take is confirming and closing GitHub issues.

---

## Access Check
!`check_issues_access`

## Current Tasks
!`issue_loader list 2>/dev/null || echo "No issues yet."`

---

## Behavior

### On Load

1. If the **Access Check** is `NO_REPO` or `NO_AUTH`, stop and tell the user to set up access (`gh auth login` or `export GH_PAT=<token>`).
2. Run `issue_loader list` to get all tasks.
3. If the user provided an issue number as an argument, skip to **Confirm Close** with that number.
4. If no argument was provided, show tasks and use `AskUserQuestion` with:
   - question: `"Which task is done?"`
   - suggestions: array of open tasks formatted as `"#number — Title (status)"` e.g. `"#42 — Add login page (in_progress)"`
   - Prioritize showing `in_progress` tasks first, then `pending`.

### Confirm Close

1. Read the full task: `issue_loader show [number]`
2. Display the title and description to the user.
3. Use `AskUserQuestion` to confirm:
   - question: `"Close issue #[number] — [Title]? It will be marked completed (reopenable later)."`
   - options: `"Yes, close it"` and `"No, keep it open"`

### If Confirmed

1. Run: `issue_loader close [number]`
2. Say: *"Done. Closed issue #[number] — [Title]."*

### If Declined

Say: *"Kept issue #[number] open. No changes made."*

---

## Rules

- ALWAYS confirm before closing — never skip the confirmation step
- Show the task details before asking for confirmation so the user knows what they're closing
- Only close one task at a time — if the user wants to close multiple, loop through them one by one
- Closing = completed; the issue is **not deleted** and can be reopened on GitHub if needed
- Do NOT write any files — this skill only reads and closes issues
