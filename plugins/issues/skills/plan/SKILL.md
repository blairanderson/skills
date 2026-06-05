---
name: plan
description: "Use when: user wants to expand a task, flesh out a plan, break down a TODO into steps, add detail to an existing task, or plan the implementation of a specific work item. Takes an issue number or picks one interactively and builds it into a thorough plan."
argument-hint: 'e.g. /issues:plan 42'
allowed-tools: Bash(issue_loader*), Bash(gh issue*), Bash(check_issues_access), AskUserQuestion
---

# Issues: Plan — Task Expansion & Deep Planning

**`issue_loader` is a CLI on your $PATH.** Call it directly: `issue_loader list`, `issue_loader show 42`, `issue_loader update 42 --body "..."`. Do NOT prefix with `bash`, do NOT use a file path. Tasks are GitHub issues — the plan lives in the **issue body**.

## Access Check
!`check_issues_access`

## Current Tasks
!`issue_loader list 2>/dev/null || echo "No issues yet."`

---

## Behavior

You help the user turn a rough task into a thorough, actionable plan. **No code is written during planning** — only the issue body is updated.

### On Load

If the **Access Check** is `NO_REPO` or `NO_AUTH`, stop and tell the user to set up access (`gh auth login` or `export GH_PAT=<token>`). Otherwise parse `$ARGUMENTS`:

- **If a number is given** (e.g., `/issues:plan 42`): load that task immediately with `issue_loader show 42`, then go to **Planning Flow**.
- **If no argument**: show the task list and ask which one to plan using `AskUserQuestion`:
  - question: `"Which task do you want to plan out?"`
  - suggestions: [list of issue numbers + titles from `issue_loader list`]

### Planning Flow

1. Read the full task: `issue_loader show [number]`
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
4. Write the expanded body back to the issue: `issue_loader update [number] --body "<full markdown plan>"` (this replaces the issue body — include any existing content you want to keep). If priority was decided, also `issue_loader update [number] --priority <N>`.
5. Confirm: *"Plan saved to issue #[number]. `/issues:triage` to reprioritize · `/issues:work` when ready to start."*

### Iterative Planning

If the user wants to keep expanding, continue the conversation and keep updating the issue body. Each round adds more detail. The plan grows until the user is satisfied.

### Rules

- **Do not write application code** — only update the issue (title/body/priority)
- **Ask one question at a time** — don't dump a list of 10 questions at once
- **Preserve content** — `--body` replaces the whole body, so include the parts of the existing body you want to keep
- **Be concrete** — file paths, function names, API endpoints beat vague descriptions
- If a task should be split into multiple tasks, suggest it but let the user decide (a new issue per split via `/issues:capture` or `issue_loader create`)
