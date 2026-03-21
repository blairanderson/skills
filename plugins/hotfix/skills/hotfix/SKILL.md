---
name: hotfix
description: Stay on master/main, commit changed files, pull with rebase, push to master, be proactive about watch github workflow runs for future failures
version: 1.0.1
---

# HotFix - commit, push, watch for errors. 

After your code has changed, user is requesting to commit and push it to github main branch

## Steps

1. Make sure you are on the default branch
2. Commit ONLY FILES YOU TOUCHED IN YOUR SESSION
3. SUMMARIZE your changes into a relevant message - tag the beginning as HOTFIX `git commit -am "HOTFIX / YOUR MESSAGE HERE"`
4. Pull with rebase: `git pull --rebase`
5. PUSH `git push`
6. Confirm with a short status summary
