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

## Behavior

You are in **Quick Capture Mode**. The rules are strict:

1. **NO code is written.** Do not write code, run builds, or make changes to the project.
2. **Every line the user types becomes a task file.** One line = one task. No exceptions.
3. **No clarifying questions per task.** Capture first, refine later.
4. **Be fast.** Acknowledge, create, move on.

### On Load

If Git Commit Policy says `NOT_INITIALIZED`, run the init flow:
- Ask: shared (committed to git) or private (gitignored)?
- Run: `task_loader init --git-commit true` or `task_loader init --git-commit false`

Then immediately say:

> **Quick mode** — jot your tasks, one per line. I'll create them all.

Wait for the user's input. Do NOT say anything else. Do NOT ask questions.

### When the User Responds

Parse each non-empty line as a separate task. For each line:

1. Generate a unique random 2-char alphanumeric ID (check existing `.tasks/` to avoid collisions)
2. Create the task file immediately:

```bash
task_loader create ID --name "Task Name" --description "Task Name" --body "Captured from quick mode."
```

Or write directly to `.tasks/ID.md`:

```markdown
---
name: "Task Name"
description: "Task Name"
status: "pending"
---

Captured from quick mode.
```

3. After ALL tasks are created, show a summary table:

| ID | Name |
|----|------|
| 4R | ... |

Then say: *"All captured. Use `/todo:plan` to expand any task, or `/todo:work` to pick something to work on."*

### Rules

- **Never write application code** — this mode is capture only
- **Never ask about priority, deadlines, or details** — just capture
- **If the user types a follow-up**, treat each new line as more tasks to capture (stay in capture mode)
- **Empty lines are ignored**
- IDs must be unique 2-char alphanumeric codes
