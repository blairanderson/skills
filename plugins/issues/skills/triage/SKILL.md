---
name: triage
description: "Use when: user wants to review tasks, process the inbox, update priorities, organize TODOs, clean up stale items, or see a task dashboard. The PM batch-processing step between capture and work."
argument-hint: 'e.g. /issues:triage'
allowed-tools: Bash(issue_loader*), Bash(gh issue*), Bash(check_issues_access), AskUserQuestion
---

# Issues: Triage — Batch Task Processing

## !! HARD CONSTRAINTS — READ BEFORE DOING ANYTHING !!

**No application code. You only read and update GitHub issues via `issue_loader`.**

**`issue_loader` is a CLI on your $PATH.** Call it directly: `issue_loader list`, `issue_loader show 42`, `issue_loader update 42 --priority 2`. Do NOT prefix with `bash`, do NOT use a file path. Tasks are GitHub issues — there is no `.tasks/` directory and no files to edit.

---

## Access Check
!`check_issues_access`

## Current Tasks
!`issue_loader list 2>/dev/null || echo "No issues yet."`

---

## On Load

If the **Access Check** is `NO_REPO` or `NO_AUTH`, stop and tell the user to set up access (run inside a GitHub repo; `gh auth login` or `export GH_PAT=<token>`). Otherwise continue.

## What Triage Is

Triage is a **batch operation**. You make quick decisions about many tasks in one sitting. Think email inbox — fast, decisive, one at a time. This is NOT deep planning (that's `/issues:plan`).

The `issue_loader list` output is pipe-delimited: `number | status | priority | created | title | description`.

---

## Phase 1 — Dashboard

The task list is already loaded above via `issue_loader list`. Use that output (and `issue_loader show <number>` for details) to build the dashboard. **Do NOT iterate with raw loops — always use `issue_loader`.**

Present a summary board:

```
## Task Board

P0 (drop everything): [count]
P1 (high):            [count]
P2 (normal):          [count]
P3 (low):             [count]
Later (inbox):        [count]
───────────────────────────
In progress:          [count]
Completed (closed):   [count]

📥 [N] tasks need triage (priority = later, still open)
⏳ [N] tasks look stale (open & pending with created date > 14 days ago)
```

If there are tasks to triage (open issues with priority = later), go to Phase 2.
If inbox is empty but stale tasks exist, skip to Phase 3.
If everything is clean, show the board, say *"All clear. `/issues:work` to start, `/issues:capture` to add more."* and stop.

---

## Phase 2 — Process Inbox

Work through each open task with `priority: later` one at a time.

For each task, use `AskUserQuestion`:

- **question**: Show the task clearly:
  ```
  #[number] — [title]
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

- **0, 1, 2, 3**: Update priority: `issue_loader update [number] --priority 0` (or 1, 2, 3)
- **skip**: Leave unchanged, move to next task
- **archive**: Close the issue (archived = closed): `issue_loader close [number]`

If the user adds free-text context alongside their choice, append it to the issue body as a dated note. Read the current body with `issue_loader show [number]`, then write it back with the note appended:

```
issue_loader update [number] --body "<existing body>

## Notes
- [YYYY-MM-DD] [user's context]"
```

**Pacing:** If there are more than 10 inbox tasks, after every 5 ask: *"Keep triaging? [N] remaining."* with options `"continue"` and `"stop — show summary"`.

---

## Phase 3 — Stale Review

After the inbox is processed (or if it was already empty), look for stale tasks:

- open & `pending` with `created` date older than 14 days
- open & `in_progress` with `created` date older than 7 days (stuck work)

If no stale tasks, skip to Phase 4.

For each stale task, use `AskUserQuestion`:

- **question**:
  ```
  #[number] — [title]
  Status: [status] since [created date]

  Still relevant?
  ```
- **options**:
  1. `"yes — keep as-is"`
  2. `"bump — raise priority"` (then ask what priority)
  3. `"archive — not doing this"`

Update using `issue_loader update [number] --priority <N>` or close it with `issue_loader close [number]`.

---

## Phase 4 — Summary

Show the updated board grouped by priority, listing actual tasks:

```
## Updated Board

P0: #[number — title], #[number — title]
P1: #[number — title]
P2: #[number — title], #[number — title]
P3: #[number — title]
Later: #[number — title]

✓ [N] triaged · [N] archived (closed) · [N] bumped

Next: /issues:work to start · /issues:plan <number> to expand
```

---

## Rules

- **No application code** — only read/update GitHub issues
- **Quick decisions** — don't deep-dive. If a task needs discussion, tell the user to run `/issues:plan <number>` after triage
- **One task at a time** — present each task individually with AskUserQuestion
- **Respect "skip"** — if the user skips, move on. No pushback
- **Respect "stop"** — if the user stops mid-triage, show Phase 4 summary with whatever progress was made
- **Use issue_loader** — update priority/status via `issue_loader update [number] --priority X` / `--status X`, or close via `issue_loader close [number]`. Never use raw loops.
