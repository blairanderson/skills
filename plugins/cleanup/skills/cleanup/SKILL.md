---
name: cleanup
description: Switch back to master, pull with rebase, and delete the current feature branch. Use whenever the user says "cleanup", "back to master", "done with this branch", or after a PR has been merged and the user wants to reset their local repo.
---

# Branch Cleanup

After a PR is merged, clean up the local repo by switching to master, pulling latest, and deleting the feature branch.

## Steps

1. Capture the current branch name (so you know what to delete)
2. If there are uncommitted changes, warn the user and stop — don't discard work
3. Switch to master: `git checkout master`
4. Pull with rebase: `git pull --rebase`
5. Delete the old feature branch: `git branch -D <branch-name>`
6. Optionally run `git fetch --prune` to clean up stale remote tracking refs
7. Confirm with a short status summary
