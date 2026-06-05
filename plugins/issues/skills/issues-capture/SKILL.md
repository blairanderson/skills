---
name: issues:capture
description: "Use when: user wants to quickly capture tasks, brainstorm TODOs, jot down ideas, dump a list of things to do, or do a brain dump of work items. Enters fast capture mode — NO code written, every line typed becomes its own GitHub issue immediately."
argument-hint: 'e.g. /issues:capture'
allowed-tools: Bash(issue_loader*), Bash(gh issue*), Bash(check_issues_access), Bash(gh auth status)
---

# Issues: Capture — Fast Task Capture

**`issue_loader` is a CLI on your $PATH.** Call it directly: `issue_loader list`, `issue_loader show 42`, `issue_loader create --title "..."`. Do NOT prefix with `bash`, do NOT use a file path. Tasks are **GitHub issues** in the current repo (no `.tasks/` directory). The backend uses the `gh` CLI when available and falls back to a `$GH_PAT` token.

## !! HARD CONSTRAINT — READ FIRST !!

**You are NOT allowed to write application code in this skill. Ever. Under any circumstances.**

The ONLY thing you may do is create GitHub issues via `issue_loader create`.

If you notice yourself about to write a `.rb`, `.js`, `.ts`, `.py`, `.sh`, `.html`, `.css`, `.json` file — or ANY file at all — **STOP IMMEDIATELY**. That is not what this skill does.

---

## Access Check
!`check_issues_access`

## Current Tasks
!`issue_loader list 2>/dev/null || echo "No issues yet."`

---

## On Load

Read the **Access Check** above:

- `OK` → enter the capture loop immediately.
- `NO_REPO` → stop. Say: *"No GitHub repo detected. Run this inside a git repo whose `origin` remote points to github.com."*
- `NO_AUTH` → stop. Say: *"No GitHub access. Either run `gh auth login`, or export a token with `export GH_PAT=<personal-access-token>` (needs read/write Issues on this repo)."*

---

## YOU ARE IN A CAPTURE LOOP

This skill runs a **strict capture loop**. There are only two things you are allowed to do:

1. **Create an issue** for every non-empty line the user types
2. **Output the capture prompt** (defined below) after creating

That is all. No explanations. No analysis. No code. No questions. No suggestions.

---

## The Capture Loop

The loop has exactly two steps. Repeat forever until the user exits.

### Step 1 — Ask the user

Simply output a text prompt. **Do NOT use AskUserQuestion.** Just ask directly:

- First run: `"What's the first task?"`
- Subsequent runs: `"✓ [list issues just created, e.g. #42, #43] — next?"`

The user types their task as a normal message. The user can exit capture mode at any time by pressing Escape — you do not need to offer an exit option.

### Step 2 — Handle response

Treat the entire response as task input. For every non-empty line:

1. Generate a concise task **title** summarized from the input.
2. From the user input, summarize the task details into an intelligent long-description for the issue **body**. The user might paste in an entire todo from another system — don't dump the whole text as the title; break it into a readable title + body.
3. Create the issue:

```
issue_loader create --title "Concise task title" --body "Nice longer description / plan"
```

`issue_loader create` prints the new **issue number** (assigned by GitHub — you do not pick IDs). New issues default to open, priority `later` (no priority label) — the user sets priority later via `/issues:triage`.

Create issues in parallel (multiple `issue_loader create` calls at once) for speed. Then immediately go back to **Step 1** with the question showing the issue numbers just created.

---

## What You Must Never Do Inside the Loop

- Write application code or any file
- Ask clarifying questions ("What do you mean by...?")
- Offer estimates or suggestions (priority defaults to "later" — user sets it manually)
- Explain what you're doing
- Say "Great!", "Sure!", or any filler
- Set a priority unless the user explicitly states one
- Break out of the loop for any reason except "exit"
