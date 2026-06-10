---
name: worktrees
description: "Use when: user wants to create or delete a Rails git worktree, set up isolated dev/test databases per branch, work on multiple branches in parallel, or asks about bin/worktree, rails-worktree, or the FastTravelAS worktree gem"
allowed-tools: Bash, Read, Write, Edit
argument-hint: "create feature-x, create feature-x main, close feature-x, setup"
version: "1.0.1"
---

# Skill: Rails worktrees (rails-worktree)

## Purpose

Spin up isolated git worktrees for a Rails app where each worktree gets its own
development and test databases, copied config (`.env`, `database.yml`, credentials,
`node_modules`), migrations, and seeds — so you can work on several branches in
parallel without DB collisions. Wraps the
[FastTravelAS/rails-worktree](https://github.com/FastTravelAS/rails-worktree) gem.

> **This skill never modifies `config/database.yml`.** It is a tracked file that
> already resolves its database names from ENV, and the gem writes the per-worktree
> database names into each worktree's `.env`. So `database.yml` never needs to
> change. Treat it as read-only: verify it reads the ENV vars, but never edit it.
> If the ENV references are missing, that is a one-time prerequisite for the user
> to add — surface it and stop, don't patch the tracked file yourself.

## Step 0 — Preflight checks

Always run BOTH checks before creating or closing a worktree.

### 0a — Confirm `bin/worktree` exists

```sh
test -f bin/worktree && echo "OK: bin/worktree present" || echo "MISSING"
```

- **If present** → continue to check 0b.
- **If MISSING** → run the setup steps in **Step 1** before doing anything else.

Running `bin/worktree` with no arguments prints its help/usage menu — run it to
confirm the exact supported commands and flags for the installed version before
acting on the documented commands below.

### 0b — Confirm `config/database.yml` reads the ENV database names

The gem only isolates databases if `config/database.yml` reads
`DATABASE_NAME_DEVELOPMENT` (and `DATABASE_NAME_TEST`). Verify:

```sh
grep -q "DATABASE_NAME_DEVELOPMENT" config/database.yml && echo "OK: database.yml reads ENV" || echo "MISSING"
```

- **If OK** → skip to the create/close commands below.
- **If MISSING** → **do not edit `config/database.yml` yourself.** It is a tracked
  file. Show the user the **`config/database.yml` ENV reference** snippet in
  **Step 1** and ask them to add it (or re-run the gem installer, which sets it
  up). Stop until the check passes — skipping it means new worktrees reuse the
  main app's databases, defeating isolation.

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

3. Re-run the **Step 0** preflight checks to confirm `bin/worktree` now exists
   and `config/database.yml` reads the ENV database names.

### `config/database.yml` ENV reference (verify only — never edit)

The gem assigns each worktree a unique database by reading two env vars. Confirm
`config/database.yml` references them with fallback defaults. **This is a
read-only check — never edit `database.yml` from this skill.** If the references
are missing, show the user this snippet and ask them to add it (it is a tracked
file and a one-time prerequisite):

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

### Derive the branch slug (always prefix with the app directory)

The user usually describes the work in plain language ("building a new messaging
tool"), not a branch name. Turn that into a slug, then **prefix it with the
current app's directory name** so the worktree is traceable back to its source app
later.

1. Get the app directory name: `basename "$PWD"` (e.g. `cheese-app`).
2. Slugify the user's description: lowercase, keep the meaningful words, drop
   filler ("building", "new", "a", "the"), join with hyphens
   (e.g. "building a new messaging tool" → `messaging-tool`).
3. Combine as `<app-dir>-<slug>` → `cheese-app-messaging-tool`.

```sh
APP="$(basename "$PWD")"        # cheese-app
SLUG="messaging-tool"           # derived from the user's description
bin/worktree "$APP-$SLUG"       # → cheese-app-messaging-tool
```

Never use the bare slug (`messaging-tool`) — without the app prefix it's hard to
tell which app a worktree belongs to when several exist side by side. Confirm the
final name with the user if the description is ambiguous.

### Run the create command

```sh
bin/worktree cheese-app-messaging-tool        # branch off the CURRENT branch
bin/worktree cheese-app-messaging-tool main   # branch off an explicit base branch
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
| New worktree shares the main app's DB | `config/database.yml` isn't reading `DATABASE_NAME_DEVELOPMENT`/`_TEST` — ask the user to add the ENV refs above (or re-run the gem installer). Never hand-edit the tracked `database.yml`. |
| `gem "rails-worktree"` not found | Confirm it's in the `:development` group and re-run `bundle install` |
| Can't close from main repo | Pass the branch name: `bin/worktree --close feature-branch` |
