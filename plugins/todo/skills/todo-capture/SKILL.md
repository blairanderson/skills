---
name: todo:capture
description: "Use when: user wants to quickly capture tasks, brainstorm TODOs, jot down ideas, dump a list of things to do, or do a brain dump of work items. Enters fast capture mode — NO code written, every line typed becomes its own task file immediately."
argument-hint: 'e.g. /todo:capture'
allowed-tools: Bash(task_loader*), Bash(check_git_policy), Bash(mkdir -p .tasks), Glob(.tasks/*), Read(.tasks/*), Write(.tasks/*)
---

# Todo: Capture — Fast Task Capture

## !! HARD CONSTRAINT — READ FIRST !!

**You are NOT allowed to write application code in this skill. Ever. Under any circumstances.**

The ONLY files you may write are `.tasks/ID.md` task capture files.

If you notice yourself about to write a `.rb`, `.js`, `.ts`, `.py`, `.sh`, `.html`, `.css`, `.json` file — or ANY file that is not inside `.tasks/` — **STOP IMMEDIATELY**. That is not what this skill does.

---

## Current Tasks
!`task_loader list 2>/dev/null || echo "No tasks yet."`

## Git Commit Policy
!`check_git_policy`

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

### Step 1 — Ask the user

Simply output a text prompt. **Do NOT use AskUserQuestion.** Just ask directly:

- First run: `"What's the first task?"`
- Subsequent runs: `"✓ [list tasks just written] — next?"`

The user types their task as a normal message. The user can exit capture mode at any time by pressing Escape — you do not need to offer an exit option.

### Step 2 — Handle response

Treat the entire response as task input:

For every non-empty line:

1. Generate a task name summarized from the contents of the input.
2. Decide if the input is detailed enough or if the plan still needs research/planning put this answer in the description
3. Generate a unique random 2-char alphanumeric ID (glob `.tasks/*.md` to avoid collisions)
4. Write `.tasks/ID.md` directly:

From the user input, summarize the task details into an intelligent long-description of the task. 
Remember the user might paste in an entire todo from another system and we wouldn't want to have the whole text listed as the name or a single sentance description. break it up so that its easy to read.  
 

```markdown
---
name: "The line of text verbatim"
description: "The line of text verbatim"
status: "pending"
priority: "later"
created: "YYYY-MM-DD"
---

{nice long description plan}
```

Use today's actual date for the `created` field (e.g. `"2026-04-09"`).

Write all files in parallel. Do not call `task_loader` — write the files directly with the Write tool (faster).

Then immediately go back to **Step 1** with the question showing what was just captured.

---

## What You Must Never Do Inside the Loop

- Write application code
- Ask clarifying questions ("What do you mean by...?")
- Offer estimates or suggestions (priority defaults to "later" — user sets it manually)
- Explain what you're doing
- Say "Great!", "Sure!", or any filler
- Add context or planning to task bodies — just write `Captured.`
- Break out of the loop for any reason except "exit"
