---
name: todo:triage
description: "Use when: user wants to review tasks, process the inbox, update priorities, organize TODOs, clean up stale items, or see a task dashboard. The PM batch-processing step between capture and work."
argument-hint: 'e.g. /todo:triage'
allowed-tools: Bash(task_loader*), Glob(.tasks/*), Read(.tasks/*), Write(.tasks/*), Edit(.tasks/*), AskUserQuestion
---

# Todo: Triage — Batch Task Processing

## !! HARD CONSTRAINT !!

**No application code. Only `.tasks/*.md` files are modified.**

---

## Current Tasks
!`task_loader list 2>/dev/null || echo "No tasks yet."`

## Git Commit Policy
!`check_git_policy`

---

## What Triage Is

Triage is a **batch operation**. You make quick decisions about many tasks in one sitting. Think email inbox — fast, decisive, one at a time. This is NOT deep planning (that's `/todo:plan`).

---

## Phase 1 — Dashboard

On load, read all `.tasks/*.md` files and present a summary board:

```
## Task Board

P0 (drop everything): [count]
P1 (high):            [count]
P2 (normal):          [count]
P3 (low):             [count]
Later (inbox):        [count]
───────────────────────────
In progress:          [count]
Blocked:              [count]
Completed:            [count]

📥 [N] tasks need triage (priority = later)
⏳ [N] tasks look stale (pending with created date > 14 days ago)
```

If there are tasks to triage (priority = later), go to Phase 2.
If inbox is empty but stale tasks exist, skip to Phase 3.
If everything is clean, show the board, say *"All clear. `/todo:work` to start, `/todo:capture` to add more."* and stop.

---

## Phase 2 — Process Inbox

Work through each task with `priority: "later"` one at a time.

For each task, use `AskUserQuestion`:

- **question**: Show the task clearly:
  ```
  [ID] — [name]
  [description or first ~100 chars of body]
  
  Priority?
  ```
- **options**:
  1. `"0 — drop everything"`
  2. `"1 — high"`
  3. `"2 — normal"`
  4. `"3 — low"`
  5. `"skip — leave as later"`
  6. `"archive — not doing this"`

**Handle response:**

- **0, 1, 2, 3**: Update the `priority` field in frontmatter using Edit
- **skip**: Leave unchanged, move to next task
- **archive**: Set `status: "archived"` in frontmatter using Edit

If the user adds free-text context alongside their choice, append it to the task body as a dated note:

```markdown

## Notes
- [YYYY-MM-DD] [user's context]
```

**Pacing:** If there are more than 10 inbox tasks, after every 5 ask: *"Keep triaging? [N] remaining."* with options `"continue"` and `"stop — show summary"`.

---

## Phase 3 — Stale Review

After the inbox is processed (or if it was already empty), look for stale tasks:

- `status: "pending"` with `created` date older than 14 days
- `status: "in_progress"` with `created` date older than 7 days (stuck work)

If no stale tasks, skip to Phase 4.

For each stale task, use `AskUserQuestion`:

- **question**:
  ```
  [ID] — [name]
  Status: [status] since [created date]
  
  Still relevant?
  ```
- **options**:
  1. `"yes — keep as-is"`
  2. `"bump — raise priority"` (then ask what priority)
  3. `"archive — not doing this"`

Update frontmatter accordingly.

---

## Phase 4 — Summary

Show the updated board grouped by priority, listing actual tasks:

```
## Updated Board

P0: [ID — name], [ID — name]
P1: [ID — name]
P2: [ID — name], [ID — name], [ID — name]
P3: [ID — name]
Later: [ID — name]

✓ [N] triaged · [N] archived · [N] bumped

Next: /todo:work to start · /todo:plan <ID> to expand
```

---

## Rules

- **No application code** — only `.tasks/*.md` files
- **Quick decisions** — don't deep-dive. If a task needs discussion, tell the user to run `/todo:plan <ID>` after triage
- **One task at a time** — present each task individually with AskUserQuestion
- **Respect "skip"** — if the user skips, move on. No pushback
- **Respect "stop"** — if the user stops mid-triage, show Phase 4 summary with whatever progress was made
- **Preserve task body** — when updating frontmatter, use Edit to change only the priority/status fields. Don't rewrite the body
- **Add `created` if missing** — if a task file lacks a `created` field in frontmatter, add today's date when you touch it for any other reason
