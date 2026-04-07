---
name: todo:quick
description: "Use when: user wants to quickly capture tasks, brainstorm TODOs, jot down ideas, dump a list of things to do, or do a brain dump of work items. Enters fast capture mode — NO code written, every line typed becomes its own task file immediately."
argument-hint: 'e.g. /todo:quick'
allowed-tools: Bash(task_loader*), Bash(mkdir -p .tasks), Glob(.tasks/*), Read(.tasks/*), Write(.tasks/*), AskUserQuestion
---

# Todo: Quick — Fast Task Capture

## !! HARD CONSTRAINT — READ FIRST !!

**You are NOT allowed to write application code in this skill. Ever. Under any circumstances.**

The ONLY files you may write are `.tasks/ID.md` task capture files.

If you notice yourself about to write a `.rb`, `.js`, `.ts`, `.py`, `.sh`, `.html`, `.css`, `.json` file — or ANY file that is not inside `.tasks/` — **STOP IMMEDIATELY**. That is not what this skill does.

---

## Current Tasks
!`task_loader list 2>/dev/null || echo "No tasks yet."`

## Git Commit Policy
!`if [ -f .tasks/.config ] && grep -q 'git_commit=true' .tasks/.config 2>/dev/null; then echo "ENABLED"; elif [ -f .tasks/.config ]; then echo "DISABLED"; else echo "NOT_INITIALIZED"; fi`

---

## YOU ARE IN A CAPTURE LOOP

This skill runs a **strict capture loop**. There are only two things you are allowed to do:

1. **Write task files** for every non-empty line the user types
2. **Output the capture prompt** (defined below) after writing

That is all. No explanations. No analysis. No code. No questions. No suggestions.

---

## On Load

If Git Commit Policy says `NOT_INITIALIZED`:
- Ask: shared (committed to git) or private (gitignored)?
- Run: `task_loader init --git-commit true` or `task_loader init --git-commit false`

Then immediately enter the capture loop (Step 2 below).

---

## The Capture Loop

The loop has exactly two steps. Repeat forever until the user exits.

### Step 1 — Ask with AskUserQuestion

Call `AskUserQuestion` with:
- **question**: `"What's the next task?"` (on first run) or `"✓ [list tasks just written] — next?"` (on subsequent runs, showing what was just captured)
- **suggestions**: `["type your next task idea", "exit quick capture mode"]`

Wait for response.

### Step 2 — Handle response

**If the user chose or typed "exit quick capture mode"** (or any close variant):

Show the final summary:
```
Done. [N] tasks captured.
/todo:plan <ID> to expand · /todo:work to start
```
Stop. Do not loop again.

**Otherwise** — treat the entire response as task input:

For every non-empty line:

1. Generate a unique random 2-char alphanumeric ID (glob `.tasks/*.md` to avoid collisions)
2. Write `.tasks/ID.md` directly:

```markdown
---
name: "The line of text verbatim"
description: "The line of text verbatim"
status: "pending"
---

Captured.
```

Write all files in parallel. Do not call `task_loader` — write the files directly with the Write tool (faster).

Then immediately go back to **Step 1** with the question showing what was just captured.

---

## What You Must Never Do Inside the Loop

- Write application code
- Ask clarifying questions ("What do you mean by...?")
- Offer priority ratings, estimates, or suggestions
- Explain what you're doing
- Say "Great!", "Sure!", or any filler
- Add context or planning to task bodies — just write `Captured.`
- Break out of the loop for any reason except "exit quick capture mode"
