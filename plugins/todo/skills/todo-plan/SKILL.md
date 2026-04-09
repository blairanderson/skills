---
name: todo:plan
description: "Use when: user wants to expand a task, flesh out a plan, break down a TODO into steps, add detail to an existing task, or plan the implementation of a specific work item. Takes a task ID or picks one interactively and builds it into a thorough plan."
argument-hint: 'e.g. /todo:plan 4R'
allowed-tools: Bash(check_git_policy), Bash, Read, Write, Edit, Glob
---

# Todo: Plan — Task Expansion & Deep Planning

## Current Tasks
!`task_loader list 2>/dev/null || echo "No tasks yet."`

---

## Behavior

You help the user turn a rough task into a thorough, actionable plan. **No code is written during planning** — only the task file is updated.

### On Load

Parse `$ARGUMENTS`:

- **If an ID is given** (e.g., `/todo:plan 4R`): load that task immediately with `task_loader show 4R`, then go to **Planning Flow**.
- **If no argument**: show the task list and ask which one to plan using `AskUserQuestion`:
  - question: `"Which task do you want to plan out?"`
  - suggestions: [list of task IDs + names from `task_loader list`]

### Planning Flow

1. Read the full task file: `task_loader show ID`
2. Discuss the task with the user — ask clarifying questions one at a time:
   - What is the goal / definition of done?
   - What priority? (`0` = drop everything, `1` = high, `2` = normal, `3` = low, `later` = someday)
   - What are the steps or phases?
   - What files, systems, or people are involved?
   - Are there blockers or dependencies?
   - Any edge cases or risks?
3. Build an expanded plan body with:
   - `## Goal` — clear definition of done
   - `## Steps` — numbered, ordered implementation steps
   - `## Files / Systems` — relevant paths, services, APIs
   - `## Dependencies` — things that must happen first
   - `## Notes` — risks, open questions, decisions made
4. Write the expanded body back to `.tasks/ID.md` using the Edit tool (preserve frontmatter)
5. Confirm: *"Plan saved to .tasks/ID.md. `/todo:triage` to reprioritize · `/todo:work` when ready to start."*

### Iterative Planning

If the user wants to keep expanding, continue the conversation and keep updating the task file. Each round adds more detail. The plan grows until the user is satisfied.

### Rules

- **Do not write application code** — only update the `.tasks/ID.md` file
- **Ask one question at a time** — don't dump a list of 10 questions at once
- **Preserve frontmatter** — only update the body section (and `priority` field if discussed)
- **Be concrete** — file paths, function names, API endpoints beat vague descriptions
- If a task should be split into multiple tasks, suggest it but let the user decide
