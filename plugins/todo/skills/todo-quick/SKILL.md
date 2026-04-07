---
name: todo:quick
description: "Use when: user wants to quickly capture tasks, brainstorm TODOs, jot down ideas, dump a list of things to do, or do a brain dump of work items. Enters fast capture mode — NO code written, every line typed becomes its own task file immediately."
argument-hint: 'e.g. /todo:quick'
allowed-tools: Bash, Read, Write, Glob
---

# Todo: Quick — Fast Task Capture

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

Then output **exactly** the capture prompt:

```
Quick mode — go:
```

Nothing else. Wait.

---

## The Capture Loop

Every time the user sends a message, follow this sequence exactly:

### Step 1 — Check for exit

If the user's message is only one of these words: `done`, `exit`, `stop`, `quit`, `/done` — exit the loop. Output:

```
Done. [N tasks captured total]
/todo:plan <ID> to expand · /todo:work to start
```

Then stop. Do not continue the loop.

### Step 2 — Write files

For every non-empty line in the user's message:

1. Generate a unique random 2-char alphanumeric ID (glob `.tasks/*.md` to check collisions)
2. Write `.tasks/ID.md` directly:

```markdown
---
name: "The line of text verbatim"
description: "The line of text verbatim"
status: "pending"
---

Captured.
```

Write all files in parallel. Do not call `task_loader` — write the files directly with the Write tool (faster, no shell overhead).

### Step 3 — Output the capture prompt (THE ONLY ALLOWED RESPONSE FORMAT)

After writing, output **exactly** this and nothing else:

```
✓ ID  Task name
✓ ID  Task name
...

```

One `✓ ID  name` line per task just created. Blank line after. Then stop. Do not add commentary. Do not ask questions. Do not summarize. Do not suggest next steps. Just wait for the next message.

---

## What You Must Never Do Inside the Loop

- Write application code
- Ask clarifying questions ("What do you mean by...?")
- Offer priority ratings, estimates, or suggestions
- Explain what you're doing
- Say "Great!", "Sure!", or any filler
- Add context or planning to task bodies — just write `Captured.`
- Break out of the loop for any reason except the exit words above

---

## Exit

The loop ends only when the user types one of: `done`, `exit`, `stop`, `quit`, `/done`

On exit, show the full task list one time, then suggest `/todo:plan` and `/todo:work`.
