---
name: tasks
description: "TODO and task tracker for any project. Manages tasks as markdown files in .tasks/ directory. Use when: tracking TODOs, creating tasks, listing tasks, showing task status, updating tasks, marking tasks done, planning multi-step work, managing a backlog, asking what to work on next, or when the user mentions anything about work items, action items, or things to do later."
argument-hint: 'list, show 7T, create 4R "Task Name", update 7T status=completed'
allowed-tools: Bash, Read, Write, Edit, Glob
---

# Task Manager — The Universal TODO & Task Tracker

## Current Tasks
!`TL="${CLAUDE_SKILL_DIR:+${CLAUDE_SKILL_DIR}/task_loader}"; TL="${TL:-$(find ~/.claude -name task_loader -path "*/tasks/task_loader" -type f 2>/dev/null | head -1)}"; [ -n "$TL" ] && "$TL" list 2>/dev/null || echo "No tasks yet."`

## Git Commit Policy
!`TL="${CLAUDE_SKILL_DIR:+${CLAUDE_SKILL_DIR}/task_loader}"; TL="${TL:-$(find ~/.claude -name task_loader -path "*/tasks/task_loader" -type f 2>/dev/null | head -1)}"; if [ -f .tasks/.config ] && grep -q 'git_commit=true' .tasks/.config 2>/dev/null; then echo "ENABLED — after every create, run: git add .tasks/<ID>.md && git commit -m 'task: <ID>' to commit the new task file immediately."; elif [ -f .tasks/.config ]; then echo "DISABLED — .tasks/ is gitignored. Do NOT run any git commands for task files."; else echo "NOT_INITIALIZED — before creating any task, you MUST ask the user: Shared (committed to git for teammates) or Private (local only, gitignored)? Then run: $TL init --git-commit true OR --git-commit false. Default to private if the user dismisses."; fi`

## Statusline Setup Check
!`GC="${CLAUDE_SKILL_DIR:+${CLAUDE_SKILL_DIR}/.global-config}"; GC="${GC:-$(find ~/.claude -name .global-config -path "*/tasks/.global-config" 2>/dev/null | head -1)}"; if [ -n "$GC" ] && grep -q 'statusline_asked=never' "$GC" 2>/dev/null; then echo "STATUSLINE_SKIP"; elif grep -q 'statusline' ~/.claude/settings.json 2>/dev/null && grep -q 'statusline-command.sh' ~/.claude/settings.json 2>/dev/null; then echo "STATUSLINE_CONFIGURED"; else echo "STATUSLINE_NOT_CONFIGURED"; fi`

## INIT Flow

When the Git Commit Policy above says `NOT_INITIALIZED`, run the full init flow:

1. **Git commit preference**: Ask shared vs private, then run `${CLAUDE_SKILL_DIR}/task_loader init --git-commit true|false`
2. **Statusline setup** (only if the Statusline Setup Check above says `STATUSLINE_NOT_CONFIGURED`):
   - Use `AskUserQuestion` with question: "Want to see your tasks in the Claude Code status line? It shows in_progress tasks first (▸ yellow), blocked (✗ red), then pending (· gray) — sorted oldest-first, up to 5 tasks." and suggestions: `["Yes please", "Not now", "No thanks and stop asking"]`
   - **"Yes please"**: Use the `statusline-setup` agent to configure the user's status line to use the command `bash ~/.claude/statusline-command.sh` (type: command). Then ensure the statusline script exists at `~/.claude/statusline-command.sh`. If it doesn't exist, create it with a script that:
     - Shows git branch with color (green parens for clean, red braces for dirty)
     - Shows the current path in bold yellow
     - Reads `.claude-statusline` config for an optional website URL (shown in cyan)
     - Lists open tasks from `.tasks/` sorted: in_progress first, then blocked, then pending — each group sorted oldest-first by file creation time
     - Uses colored prefixes: `▸` yellow for in_progress, `✗` red for blocked, `·` gray for pending
     - Caps at 5 tasks with a count header like `Tasks (3):`
   - **"Not now"**: Continue without changes.
   - **"No thanks and stop asking"**: Write `statusline_asked=never` to `${CLAUDE_SKILL_DIR}/.global-config` (append if file exists, create if not). This suppresses the question in all future inits.

If the Statusline Setup Check says `STATUSLINE_CONFIGURED` or `STATUSLINE_SKIP`, skip step 2 entirely.

---

Manage project tasks stored as individual markdown files in the `.tasks/` directory of the current repo. Each file has YAML frontmatter (name, description, status) and a markdown body with full plan details.

The script is at `${CLAUDE_SKILL_DIR}/task_loader` — it works with any repo, no framework dependency. Tasks are always scoped to the current working directory's `.tasks/` folder.

## Auto-Commit Behavior

When `git_commit=true` in `.tasks/.config`, every `create` command automatically commits the new task file to git. No manual commit step needed — the task_loader handles `git add` + `git commit` internally.

When `git_commit=false` (or no config exists), tasks are created but never touched by git. The `.tasks/` directory is in `.gitignore`.

## IMPORTANT: Global Permissions Setup

This skill needs global permissions so it works seamlessly across all projects without prompting every time. If you get a permission prompt when running task commands, **tell the user**:

> To make task management seamless across all your projects, I need global permissions. Please add these to `~/.claude/settings.json` under `permissions.allow`:
>
> ```json
> "Bash(*/tasks/task_loader*)",
> "Bash(mkdir -p .tasks)",
> "Bash(rm .tasks/*)",
> "Bash(git add .tasks/*)",
> "Bash(git commit -m *)",
> "Read(.tasks/*)",
> "Write(.tasks/*)",
> "Edit(.tasks/*)",
> "Glob(.tasks/*)"
> ```

## CRITICAL: Context-Efficient Workflow

**Always start with `list` to read only frontmatter.** Never read full task files unless the user asks for details on a specific task. This keeps context small.

## When to Use This Skill (Be Proactive!)

You should **proactively suggest** creating tasks when:
- The user describes multi-step work ("I need to add auth, then set up roles, then...")
- The user mentions something they'll do later ("I'll fix that tomorrow", "we should also...")
- You discover TODO/FIXME/HACK comments in code during your work
- The user finishes one piece of work and there's more to do
- A bug is found but not immediately fixable
- The user asks "what should I work on?" — list their tasks

**Say things like:**
- "Want me to track that as a task so we don't lose it?"
- "I've broken this into 3 tasks — here's the plan:"
- "You have 2 pending tasks from earlier — want to pick one up?"

## Commands

Parse the user's `$ARGUMENTS` to determine which action to take:

### `list` (default when no argument given)

Show a summary table of all tasks. Run:

```bash
${CLAUDE_SKILL_DIR}/task_loader list
```

Format the output as a markdown table for the user:

| ID | Status | Name | Description |
|----|--------|------|-------------|

If no tasks exist, say: "No tasks yet. Want me to create some to track your work?"

### `show <id>`

Show full details for a single task. Run:

```bash
${CLAUDE_SKILL_DIR}/task_loader show TASK_ID
```

Display the frontmatter fields and render the body as markdown.

### `create <id> <name>`

Create a new task. The **ID is a unique 2-character alphanumeric code** (e.g., `4R`, `7B`, `A3`). Generate one randomly, checking existing tasks to avoid collisions.

- **description**: one-line summary (required)
- **body**: full plan details (required — this is the whole point of a task)

For simple single-line bodies:

```bash
${CLAUDE_SKILL_DIR}/task_loader create 4R --name "Task Name" --description "One-liner" --body "Plan details"
```

For multi-line body content, write the file directly:

1. Build the markdown file content with frontmatter + body
2. Write it to `.tasks/<ID>.md` using the Write tool (e.g., `.tasks/4R.md`)
3. Verify with `${CLAUDE_SKILL_DIR}/task_loader show ID`

### `update <id> [field=value ...]`

Update an existing task. Common operations:

```bash
# Update status
${CLAUDE_SKILL_DIR}/task_loader update TASK_ID --status in_progress

# Update name
${CLAUDE_SKILL_DIR}/task_loader update TASK_ID --name "New Name"

# Mark completed
${CLAUDE_SKILL_DIR}/task_loader update TASK_ID --status completed
```

To update the body, read the file with the Read tool, then edit it with the Edit tool.

### `delete <id>`

Delete a task file:

```bash
rm .tasks/TASK_ID.md
```

Confirm with the user before deleting.

## Task File Format

Files are named `<ID>.md` where ID is a 2-char alphanumeric code (e.g., `.tasks/4R.md`):

```markdown
---
name: "Descriptive Task Name"
description: "One-line summary of what needs to be done"
status: "pending"
---

## Plan

Full implementation details here...

### Steps

1. Step one
2. Step two

### Notes

- Context, file references, architectural decisions
```

## Status Values

- `pending` — not started
- `in_progress` — actively being worked on
- `completed` — done
- `blocked` — waiting on something

## Workflow Integration

When working on a task:
1. **Start**: `update <id> --status in_progress` before beginning work
2. **Progress**: Update the task body with notes as you go (files changed, decisions made)
3. **Complete**: `update <id> --status completed` when done
4. **Next**: Show remaining tasks and ask what to tackle next

## Rules

- **Never read full task files during list** — frontmatter only
- **IDs are 2-char alphanumeric** — e.g., `4R`, `7B`, `A3`
- **Bodies should be thorough** — include file paths, line numbers, step-by-step plans
- If no argument is provided, default to `list`
- Each repo has its own `.tasks/` directory — tasks never leak across repos
- **Be proactive** — suggest task creation when you see multi-step work ahead
- **Track your own work** — when implementing something complex, create tasks and update them as you go
