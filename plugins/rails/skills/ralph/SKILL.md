---
name: ralph
description: "Use when: the user asks to set up Ralph, bootstrap Ralph, configure Ralph for a Rails project, run Ralph autonomously on a Rails app, or says 'ralph rails', 'setup ralph', 'ralph this project', 'ralph bootstrap'. Creates a sibling git worktree, vendors snarktank/ralph, and writes Rails-tailored CLAUDE.md + prd.json templates so the agent loop runs against Rails conventions (bin/rails test, zeitwerk:check, rubocop, slug-prefix commits)."
version: 1.0.0
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: "/rails:ralph [--feature <name>] [--project <path>]"
---

# Rails Ralph Bootstrap

Set up the [Ralph](https://github.com/snarktank/ralph) autonomous agent loop in a sibling git worktree so it can iterate on a Rails project without touching the main checkout.

## What this skill does

Given a Rails project (default: current working directory) and a feature name, this skill:

1. Verifies the target is a Rails app (`bin/rails`, `Gemfile`, `config/application.rb`)
2. Creates a sibling git worktree at `<project>-ralph` on a new branch `ralph/<feature>`
3. Ensures a cached clone of `snarktank/ralph` lives at `~/dev/ralph` (clones if absent, pulls if present)
4. Vendors `ralph.sh` into the worktree at `scripts/ralph/ralph.sh`, patched with `--verbose` so iterations stream tool-call activity instead of running silently
5. Writes a Rails-tailored `scripts/ralph/CLAUDE.md` that:
   - Routes quality checks through `bin/rails zeitwerk:check`, `bin/rails test`, `bin/rubocop` (not the upstream's TS-leaning `typecheck`)
   - Uses slug-prefix commit format (`feature-name-usNNN / summary`) instead of `feat:` / `chore:` conventional commits
   - Pulls Rails conventions forward from the project root `CLAUDE.md` (no private methods, no Turbo, money/cents, generators, `bin/rails runner` verification)
   - References the `/browse` skill (gstack) for browser verification, NOT the non-existent `dev-browser` skill
6. Seeds a `scripts/ralph/prd.json` skeleton with one example user story (the user replaces this with their real PRD via `/ralph-skills:ralph` or by hand)
7. Commits the setup on the new branch
8. Prints next-step instructions

## Triggers

Real phrases users type:
- "setup ralph for this project"
- "bootstrap ralph"
- "ralph this rails app"
- "set up ralph in <project name>"
- "configure ralph for rails"
- "I want to run ralph on this project"
- "/rails:ralph"

**Does NOT trigger for:**
- "convert this prd to prd.json" → `/ralph-skills:ralph` (different skill, PRD converter)
- "create a prd" → `/ralph-skills:prd` (PRD generator)
- "run ralph" → user runs `./scripts/ralph/ralph.sh` themselves once setup is done

## Contract

Inputs:
- `--feature <name>` (required) — slug-cased feature name; becomes the branch name (`ralph/<feature>`) and a placeholder in the seeded PRD
- `--project <path>` (optional, default `$PWD`) — absolute path to the Rails project to bootstrap from
- `--ralph-cache <path>` (optional, default `~/dev/ralph`) — where to keep the snarktank/ralph clone

Side effects:
- Creates `<project>-ralph` (sibling directory) as a git worktree
- Adds `scripts/ralph/{ralph.sh, CLAUDE.md, prd.json}` to the worktree
- Creates one commit on `ralph/<feature>` with the bootstrap files
- Clones `snarktank/ralph` to `~/dev/ralph` if missing
- Main project checkout is unchanged

Failures:
- Not a Rails project → exit 1 with `bin/rails not found` etc.
- Working tree dirty in the project → exit 1 (override with `--force`)
- `--feature` missing → exit 1 with usage
- Branch `ralph/<feature>` already exists → exit 1 (override with `--force` to recreate)
- Sibling directory `<project>-ralph` already exists → exit 1 (override with `--force` to wipe)

## Phases (when invoked via this skill)

### Phase 1: Audit

1. Confirm the target project (use `--project` if passed, else `$PWD`)
2. Verify Rails-app markers: `bin/rails`, `Gemfile`, `config/application.rb` all exist
3. Read the project's root `CLAUDE.md` if present — surface any project-specific rules to the user (so they know the bootstrap will inherit them via Claude Code's auto-load)
4. Check `git status` for uncommitted changes; flag if dirty

### Phase 2: Pull args (interactive if missing)

1. If `--feature <name>` not supplied, ask the user for one via `AskUserQuestion` ("What's the feature name? Slug-cased, becomes `ralph/<name>` branch.")
2. Confirm worktree path (default `<project>-ralph`) and branch name (`ralph/<feature>`)
3. Confirm destination of the snarktank/ralph cache (default `~/dev/ralph`)

### Phase 3: Run the bootstrap script

Run `scripts/bootstrap.sh` with the resolved args. The script is deterministic; no LLM calls inside it.

### Phase 4: Report

Print:
- Worktree path
- Branch name (and that it's not yet pushed)
- The `cd <worktree> && ./scripts/ralph/ralph.sh --tool claude N` command to start the loop
- A reminder to replace `prd.json` with the real PRD (via `/ralph-skills:ralph` or by hand) before running

## Output Format

After a successful run, output to the user:

```
✓ Ralph bootstrapped for <feature>

Worktree:  /Users/<you>/dev/<project>-ralph
Branch:    ralph/<feature>
Cache:     ~/dev/ralph (snarktank/ralph @ <sha>)

Next steps:
  1. cd /Users/<you>/dev/<project>-ralph
  2. Edit scripts/ralph/prd.json — replace the example user story with your real PRD
     (or run /ralph-skills:ralph to convert an existing markdown PRD)
  3. ./scripts/ralph/ralph.sh --tool claude 10   # 10 iterations
  4. Watch git log and progress.txt for activity
```

## Anti-patterns this skill avoids

- **Working directly in the main checkout** — Ralph commits frequently and can break things; isolating in a sibling worktree keeps master safe.
- **Upstream's generic `typecheck` step** — Rails has no typecheck; use `bin/rails zeitwerk:check` for the closest analog.
- **Conventional commit prefixes** — vendor-db (and most Rails projects with slug-prefix history) use `slug / summary`; the upstream template's `feat:` / `chore:` doesn't match.
- **Letting Ralph run silently for 15 minutes** — the bootstrap patches `claude --print` to `claude --print --verbose` so tool calls stream live.
- **Forgetting that Claude Code auto-loads the project root `CLAUDE.md`** — the Rails-tailored `scripts/ralph/CLAUDE.md` is the *operating loop*, not a duplicate of the project's conventions. References the root CLAUDE.md as the authoritative source.

## References

- `assets/CLAUDE.md.template` — the Rails-tailored Ralph prompt (parameterized with `{PROJECT_NAME}`, `{BRANCH_NAME}`, `{FEATURE_NAME}`)
- `assets/prd.json.template` — minimal prd.json skeleton with one example story
- `scripts/bootstrap.sh` — the deterministic setup script
- `tests/` — unit (bats), integration (bash fixture), and trigger-eval (JSON) tests

## See also

- `/ralph-skills:ralph` — converts an existing markdown PRD into `prd.json` format (run *after* this bootstrap to fill in the seeded `prd.json`)
- `/ralph-skills:prd` — generates a PRD from a problem statement
- Upstream: https://github.com/snarktank/ralph
