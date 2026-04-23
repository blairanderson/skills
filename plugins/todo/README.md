# Todo Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install todo@blairanderson-skills
```

This plugin adds five skills for a complete task management workflow. Tasks are stored as markdown files in a `.tasks/` directory and managed via the `task_loader` CLI.

---

## `/todo:capture`

Fast task capture mode. Every line you type becomes its own `.tasks/ID.md` file immediately. Enters a strict capture loop — no code written, no clarifying questions, just tasks.

Use when: you want to brain-dump a list of things to do, jot down ideas, or quickly capture tasks from another system.

---

## `/todo:triage`

Batch task processing — the PM step between capture and work. Reviews all tasks with `priority: "later"`, sets priorities (P0–P3), and surfaces stale tasks (pending > 14 days, in-progress > 7 days).

Use when: you want to process the inbox, update priorities, organize TODOs, or see a task dashboard.

---

## `/todo:work`

Pick what to work on next. Shows the top 10 tasks sorted by priority, marks the selected task `in_progress`, and immediately begins implementation.

Use when: you're ready to start working and want to pick a task to tackle.

---

## `/todo:plan`

Expand a rough task into a thorough, actionable plan. Discusses goal, steps, files/systems involved, dependencies, blockers, and edge cases — then writes the expanded plan body back to the task file.

```shell
/todo:plan      # picks a task interactively
/todo:plan 4R   # expands task 4R directly
```

Use when: you want to flesh out a TODO into steps, add detail to an existing task, or plan the implementation of a specific work item.

---

## `/todo:done`

Mark a task as done and delete it. Shows the task details, confirms before deleting, and removes the `.tasks/ID.md` file.

```shell
/todo:done      # picks a task interactively
/todo:done 4R   # deletes task 4R directly
```

Use when: you've completed a task and want to remove it from the list.
