---
name: hotfix
description: Stay on master/main, commit changed files, pull with rebase, push to master, be proactive about watch github workflow runs for future failures
version: 1.1.0
argument-hint: "fix login redirect, add dark mode toggle, update pricing page"
---

# HotFix - commit, push, watch for errors.

Solo-dev workflow: commit directly to main/master, no branching.

## Arguments

`/hotfix $ARGUMENTS` — the arguments become the commit tag prefix.

**Slugify the arguments:** lowercase, replace spaces/special chars with hyphens, strip leading/trailing hyphens.

Examples:
- `/hotfix SOMETHING AWESOME HERE` → tag: `something-awesome-here`
- `/hotfix Fix Login Bug` → tag: `fix-login-bug`
- `/hotfix` (no args) → tag: `hotfix`

## Steps

1. Make sure you are on the default branch
2. Slugify `$ARGUMENTS` into the tag (default to `hotfix` if no arguments given)
3. Commit ONLY FILES YOU TOUCHED IN YOUR SESSION
4. SUMMARIZE your changes into a relevant message, prefixed with the slug tag: `git commit -am "TAG / YOUR SUMMARY HERE"`
5. Pull with rebase: `git pull --rebase`
6. PUSH `git push`
7. Confirm with a short status summary
