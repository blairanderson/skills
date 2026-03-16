---
name: hotfix
description: Stay on master/main, commit changed files, pull with rebase, push to master, be proactive about watch github workflow runs for future failures
---

# HotFix - commit, push, watch for errors. 

After your code has changed, user is requesting to commit and push it to github main branch

## Steps

1. Make sure you are on the default branch
2. Commit your changes with a relevant message - tag the beginning as HOTFIX `git commit -am "YOUR MESSAGE HERE"`
4. Pull with rebase: `git pull --rebase`
5. PUSH `git push`
6. Confirm with a short status summary
