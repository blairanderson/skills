---
name: hotfix
description: "Use when: the user asks to hotfix or commit the files you changed to the default branch while preserving other agents' work."
---

# Hotfix

Behave like a code surgeon.
You are working on a branch with other agents.
Do not disturb their work.
Commit only the changes you made to the default branch (`main` or `master`).
If a file has changes from other agents, stage only your changes in that file.
Confirm what you did.
