# Issues Plugin

A complete task-management workflow backed by **GitHub Issues**. Tasks are issues in
the current repo — no local files, no `.tasks/` directory.

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install issues@blairanderson-skills
```

## Requirements

The skills manage issues in the repo detected from your `origin` git remote
(`git remote get-url origin`, must point to github.com). For access, **either**:

- be logged in with the GitHub CLI: `gh auth login`, **or**
- export a Personal Access Token with **read/write Issues** permission on the repo:
  ```shell
  export GH_PAT=<your-token>   # also accepts GH_TOKEN / GITHUB_TOKEN
  ```

The backend (`issue_loader`) tries the `gh` CLI first and falls back to the token.
Run `issue_loader doctor` to check what's detected.

### How tasks map to issues

| Task field   | GitHub Issue                          |
|--------------|---------------------------------------|
| id           | issue number (e.g. `#42`)             |
| name         | issue title                           |
| description  | issue body (the plan lives here)      |
| pending      | open, no status label                 |
| in_progress  | open + `in_progress` label            |
| done         | closed                                |
| priority 0–3 | `priority:0`..`priority:3` label      |
| later        | no priority label (default)           |

---

## `/issues:capture`

Fast task capture mode. Every line you type becomes its own GitHub issue immediately.
Enters a strict capture loop — no code written, no clarifying questions, just issues.

Use when: you want to brain-dump a list of things to do, jot down ideas, or quickly
capture tasks from another system.

---

## `/issues:triage`

Batch task processing — the PM step between capture and work. Reviews open issues with
priority `later`, sets priorities (P0–P3), and surfaces stale tasks (pending > 14 days,
in-progress > 7 days). "Archive" closes the issue.

Use when: you want to process the inbox, update priorities, organize TODOs, or see a
task dashboard.

---

## `/issues:work`

Pick what to work on next. Shows the top 10 open tasks sorted by priority, marks the
selected issue `in_progress`, and immediately begins implementation.

Use when: you're ready to start working and want to pick a task to tackle.

---

## `/issues:plan`

Expand a rough task into a thorough, actionable plan. Discusses goal, steps,
files/systems involved, dependencies, blockers, and edge cases — then writes the
expanded plan into the issue body.

```shell
/issues:plan      # picks a task interactively
/issues:plan 42   # expands issue #42 directly
```

Use when: you want to flesh out a TODO into steps, add detail to an existing task, or
plan the implementation of a specific work item.

---

## `/issues:done`

Mark a task as done and close it. Shows the task details, confirms before closing, and
closes the GitHub issue (not deleted — reopenable later).

```shell
/issues:done      # picks a task interactively
/issues:done 42   # closes issue #42 directly
```

Use when: you've completed a task and want to clear it from the open list.
