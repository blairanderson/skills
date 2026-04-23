# Hotfix Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install hotfix@blairanderson-skills
```

This plugin adds one skill for the solo-dev commit-and-push workflow directly on master.

---

## `/hotfix`

Commit changed files directly to main/master, pull with rebase, push, and watch GitHub Actions for failures. Designed for solo developers who commit straight to the default branch.

```shell
/hotfix fix login bug        # commits as "fix-login-bug / <summary>"
/hotfix turnstile error page # commits as "turnstile-error-page / <summary>"
/hotfix                      # asks you to pick a tag first
```

The argument is slugified (lowercase, spaces → hyphens) and becomes the commit tag. If no argument is given, the skill asks for one — it never silently defaults to `hotfix`.

Steps:
1. Confirms you are on main/master
2. Determines the slug from `$ARGUMENTS` or asks via prompt
3. Stages only files changed in the current session
4. Commits: `slug / summary`
5. Pulls with rebase
6. Pushes
7. Watches GitHub Actions for failures
