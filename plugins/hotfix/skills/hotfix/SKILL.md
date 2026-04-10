---
name: hotfix
description: Stay on master/main, commit changed files, pull with rebase, push to master, be proactive about watch github workflow runs for future failures
argument-hint: "quickly commit and push, commit to main. push"
---

# HotFix - commit, push, watch for errors.

Solo-dev workflow: commit directly to main/master, no branching.

## Arguments → Commit Tag

`/hotfix $ARGUMENTS` — the arguments become the commit tag after slugification.

**Slugify rules:** lowercase, replace spaces/special chars with hyphens, strip leading/trailing hyphens.

**CRITICAL: The slug REPLACES the word "hotfix" in the commit message.** Do NOT use the literal word "hotfix" or "HOTFIX" as the tag when arguments are provided.

| User types | Slug (commit tag) | Commit message |
|---|---|---|
| `/hotfix SOMETHING AWESOME HERE` | `something-awesome-here` | `something-awesome-here / your summary` |
| `/hotfix Fix Login Bug` | `fix-login-bug` | `fix-login-bug / your summary` |
| `/hotfix turnstile error page` | `turnstile-error-page` | `turnstile-error-page / your summary` |
| `/hotfix` (no args) | `hotfix` | `hotfix / your summary` |

### WRONG — do NOT do this:

- `/hotfix turnstile error page` → ~~`HOTFIX / ...`~~ ← WRONG, must be `turnstile-error-page / ...`
- `/hotfix Fix Login Bug` → ~~`hotfix / ...`~~ ← WRONG, must be `fix-login-bug / ...`

## Steps

1. Confirm you are on the default branch (main/master)
2. **Slugify `$ARGUMENTS`:** lowercase the arguments, replace spaces with hyphens → this is your SLUG. Only use the word `hotfix` as the slug if NO arguments were given.
3. Stage ONLY files you changed in this session
4. Commit with: `git commit -m "SLUG / YOUR SUMMARY"` where SLUG is the result from step 2 (the slugified arguments, NOT the literal word "hotfix")
5. Pull with rebase: `git pull --rebase`
6. Push: `git push`
7. Confirm with a short status summary
