---
name: hotfix
description: Stay on master/main, commit changed files, pull with rebase, push to master, be proactive about watch github workflow runs for future failures
version: 1.1.0
argument-hint: "fix login redirect, add dark mode toggle, update pricing page"
---

# HotFix - commit, push, watch for errors.

Solo-dev workflow: commit directly to main/master, no branching.

## Arguments

`/hotfix $ARGUMENTS` — the arguments are slugified and used as the commit tag.

**Slugify the arguments:** lowercase, replace spaces/special chars with hyphens, strip leading/trailing hyphens. The slug REPLACES the word "hotfix" — it is NOT a prefix added to "hotfix".

Examples:
- `/hotfix SOMETHING AWESOME HERE` → slug: `something-awesome-here` → commit: `something-awesome-here / your summary`
- `/hotfix Fix Login Bug` → slug: `fix-login-bug` → commit: `fix-login-bug / your summary`
- `/hotfix` (no args) → slug: `hotfix` → commit: `hotfix / your summary`

## Steps

1. Make sure you are on the default branch
2. Slugify `$ARGUMENTS` into the tag (default to `hotfix` ONLY if no arguments given)
3. Commit ONLY FILES YOU TOUCHED IN YOUR SESSION
4. SUMMARIZE your changes into a relevant message, prefixed with the slug: `git commit -am "SLUG / YOUR SUMMARY HERE"` — the SLUG is the slugified arguments, NOT the literal word "hotfix" (unless no arguments were provided)
5. Pull with rebase: `git pull --rebase`
6. PUSH `git push`
7. Confirm with a short status summary
