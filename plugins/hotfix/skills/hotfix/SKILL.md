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

**NEVER auto-default the tag to `hotfix`.** If no arguments are provided, you MUST use AskUserQuestion to ask the user for the tag. Offer `hotfix` as one of the suggested options, but the user picks.

| User types | Slug (commit tag) | Commit message |
|---|---|---|
| `/hotfix SOMETHING AWESOME HERE` | `something-awesome-here` | `something-awesome-here / your summary` |
| `/hotfix Fix Login Bug` | `fix-login-bug` | `fix-login-bug / your summary` |
| `/hotfix turnstile error page` | `turnstile-error-page` | `turnstile-error-page / your summary` |
| `/hotfix` (no args) | **ask user via AskUserQuestion** | `<user-chosen-slug> / your summary` |

### WRONG — do NOT do this:

- `/hotfix turnstile error page` → ~~`HOTFIX / ...`~~ ← WRONG, must be `turnstile-error-page / ...`
- `/hotfix Fix Login Bug` → ~~`hotfix / ...`~~ ← WRONG, must be `fix-login-bug / ...`
- `/hotfix` (no args) → ~~silently commit as `hotfix / ...`~~ ← WRONG, must ask user first

## Steps

1. Confirm you are on the default branch (main/master)
2. **Determine the SLUG:**
   - If `$ARGUMENTS` is present: slugify it (lowercase, spaces → hyphens) → SLUG
   - If `$ARGUMENTS` is empty: use **AskUserQuestion** to prompt for the tag. Suggest options like `hotfix`, `fix`, `chore`, `docs`, plus one inferred from the diff if obvious. Whatever the user picks becomes the SLUG (slugified).
3. Stage ONLY files you changed in this session
4. Commit with: `git commit -m "SLUG / YOUR SUMMARY"` using the SLUG from step 2
5. Pull with rebase: `git pull --rebase`
6. Push: `git push`
7. Confirm with a short status summary
