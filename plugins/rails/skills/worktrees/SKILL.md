---
name: worktrees
description: "Use when: user wants to create or delete a Rails git worktree, set up isolated dev/test databases per branch, work on multiple branches in parallel, or asks about bin/worktree, rails-worktree, or the FastTravelAS worktree gem"
allowed-tools: Bash, Read, Write, Edit
argument-hint: "create feature-x, create feature-x main, close feature-x, setup"
version: "1.0.0"
---

# Skill: Rails worktrees (rails-worktree)

## Purpose

Spin up isolated git worktrees for a Rails app where each worktree gets its own
development and test databases, copied config (`.env`, `database.yml`, credentials,
`node_modules`), migrations, and seeds — so you can work on several branches in
parallel without DB collisions. Wraps the
[FastTravelAS/rails-worktree](https://github.com/FastTravelAS/rails-worktree) gem.

## Step 0 — Confirm `bin/worktree` exists

Always run this check first:

```sh
test -f bin/worktree && echo "OK: bin/worktree present" || echo "MISSING"
```

- **If present** → skip to the create/close commands below.
- **If MISSING** → run the setup steps in **Step 1** before doing anything else.

## Step 1 — Install the gem (only if `bin/worktree` is missing)

1. Add the gem to the **development** group in the `Gemfile`. Open the `Gemfile`,
   find (or create) the `group :development do` block, and add:

   ```ruby
   group :development do
     gem "rails-worktree"
   end
   ```

   If a `group :development do ... end` block already exists, insert the
   `gem "rails-worktree"` line inside it rather than creating a second block.

2. Install and generate the binstub:

   ```sh
   bundle install
   ```

   The gem auto-creates `bin/worktree` on `bundle install`. If it does not appear:

   ```sh
   bundle exec rake worktree:install
   ```

3. Re-run the Step 0 check to confirm `bin/worktree` now exists.

### Required `config/database.yml` setup

The gem assigns each worktree a unique database by reading two env vars. Confirm
`config/database.yml` references them with fallback defaults (edit if not):

```yaml
development:
  <<: *default
  database: <%= ENV.fetch("DATABASE_NAME_DEVELOPMENT", "myapp_development") %>
test:
  <<: *default
  database: <%= ENV.fetch("DATABASE_NAME_TEST", "myapp_test") %>
```

The gem writes `DATABASE_NAME_DEVELOPMENT` / `DATABASE_NAME_TEST` into each
worktree's `.env`. Without these ENV references the worktree would reuse the main
app's databases — defeating the isolation.

> **Prerequisites:** Ruby ≥ 2.6, a standard Rails project, and PostgreSQL.

## Create a worktree

```sh
bin/worktree feature-branch        # branch off the CURRENT branch
bin/worktree feature-branch main   # branch off an explicit base branch
```

Creating a worktree automatically:
- generates isolated dev + test databases with unique names
- copies config files (`.env`, `database.yml`, `Procfile.dev`, credentials)
- copies `node_modules` from the main worktree
- runs migrations and seeds the new databases

## Close (delete) a worktree

```sh
bin/worktree --close feature-branch   # run from the MAIN repo
bin/worktree --close                  # run from INSIDE the worktree
```

Closing a worktree automatically:
- drops both the development and test databases
- removes the worktree directory
- deletes the associated branch
- cleans up git references

> Closing is destructive — it drops databases and deletes the branch. Confirm the
> branch name with the user before running `--close`, and make sure any wanted work
> is merged or pushed first.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `bin/worktree` missing after `bundle install` | Run `bundle exec rake worktree:install` |
| New worktree shares the main app's DB | `config/database.yml` isn't reading `DATABASE_NAME_DEVELOPMENT`/`_TEST` — add the ENV refs above |
| `gem "rails-worktree"` not found | Confirm it's in the `:development` group and re-run `bundle install` |
| Can't close from main repo | Pass the branch name: `bin/worktree --close feature-branch` |
