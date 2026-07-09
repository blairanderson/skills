---
name: worktrees
description: "Use when: user wants to create or delete a Rails git worktree, set up isolated dev/test databases per branch, work on multiple branches in parallel, or asks about bin/worktree, rails-worktree, or the FastTravelAS worktree gem"
allowed-tools: Bash, Read, Write, Edit
argument-hint: "create feature-x, create feature-x main, close feature-x, setup"
version: "1.1.0"
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

- **If OK** → continue to check 0c.
- **If MISSING** → **do not edit `config/database.yml` yourself.** It is a tracked
  file. Show the user the **`config/database.yml` ENV reference** snippet in
  **Step 1** and ask them to add it (or re-run the gem installer, which sets it
  up). Stop until the check passes — skipping it means new worktrees reuse the
  main app's databases, defeating isolation.

### 0c — Confirm `bin/setup` does not boot the dev server

The gem's `--init` runs `bin/setup` non-interactively. The stock Rails `bin/setup`
ends with `exec "bin/dev"` (unless `--skip-server` is passed — and the gem passes
no flags). That means worktree init either **blocks on a foreman server** or
**crashes** (foreman isn't in the Gemfile, so the bundler-wrapped exec dies with
`Gem::Exception: can't find executable foreman`). Setup should set up, not run.

```sh
grep -q 'exec "bin/dev"' bin/setup && echo "WILL BOOT SERVER" || echo "OK: setup does not start server"
```

- **If OK** → continue to the create/close commands below.
- **If WILL BOOT SERVER** → propose this fix to the user (with confirmation —
  `bin/setup` is tracked) **before** creating the worktree:

  1. In `bin/setup`, delete the trailing server block:

     ```ruby
     unless ARGV.include?("--skip-server")
       puts "\n== Starting development server =="
       STDOUT.flush
       exec "bin/dev"
     end
     ```

     Replace with: `puts "\n== Done! Run bin/dev to start the server =="`.

  2. While there, make `bin/dev` survive bundler contexts (the foreman shim
     refuses to run inside a bundled env). Just before its `exec foreman` line:

     ```sh
     unset BUNDLE_GEMFILE BUNDLE_BIN_PATH RUBYOPT RUBYLIB
     ```

  Remind the user the fix only reaches *future* worktrees once committed —
  worktrees check out tracked files from the branch.

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

### After running: inspect the output

The gem prints `✓ Worktree initialized successfully!` **even when `bin/setup`
failed** — do not trust the success banner alone. Scan the output for these
signatures and act on them:

| Output contains | Diagnosis → action |
|---|---|
| `Warning: bin/setup failed` | Setup partially ran. Find the real error above this line and match it against the rows below. Verify the DBs were actually created and migrated before declaring success. |
| `can't find executable foreman` (`Gem::Exception`) | `bin/setup` exec'd `bin/dev`, whose foreman exec dies inside the bundler env. Apply the **Step 0c** fix. The worktree and DBs are usually fine — only the (unwanted) server start failed. |
| `== Starting development server ==` then a hang | `bin/setup` booted the server and is blocking the init. Stop it, then apply the **Step 0c** fix. |
| `database ... already exists` / migrations against the main DB name | `database.yml` isn't reading the ENV names — re-check **Step 0b**. |

When a known signature matches, don't just report the error — propose the
specific fix, apply it on user confirmation, and offer to re-run the failed step
(e.g. `cd <worktree> && bin/setup --skip-server`).

## Close (delete) a worktree

> **Do NOT use `bin/worktree --close` in this setup.** The gem assumes the worktree
> directory is named after the branch and lives at `<main>/.worktrees/<branch>`.
> But worktrees here are created by the `ccw` shell function, which puts the dir at
> `<repo>-<branch>` (a repo-prefixed sibling) while keeping the branch bare
> (`<branch>`). So `--close` `Dir.chdir`s into a path that never existed and crashes:
> `Dir.chdir': No such file or directory @ ... /.worktrees/<branch>` — failing
> *before* it drops the DBs, leaving everything orphaned. Tear down manually instead
> (this mirrors exactly what `ccw -d` does).

### Manual teardown (the correct path here)

1. **Find the worktree's actual path and confirm work is safe.** Never assume the
   path — read it from git:

   ```sh
   git worktree list                              # locate the <repo>-<branch> dir
   git -C <worktree-path> status --short          # must be clean (no uncommitted work)
   git log --oneline main..<branch>               # any commits not on main?
   ```

   If there are unmerged commits, confirm they're pushed / the PR is merged
   (`git ls-remote --heads origin <branch>`, `gh pr list --head <branch> --state all`)
   before deleting. Closing is destructive and irreversible.

2. **Derive the two database names** (the gem wrote them into the worktree's `.env`):

   ```sh
   grep DATABASE_NAME <worktree-path>/.env
   # DATABASE_NAME_DEVELOPMENT=<repo>_<branch>_development
   # DATABASE_NAME_TEST=<repo>_<branch>_test
   ```

3. **Drop DBs, remove the worktree at its real path, delete the branch, prune refs:**

   ```sh
   cd <main-repo>
   dropdb --if-exists "<repo>_<branch>_development"
   dropdb --if-exists "<repo>_<branch>_test"
   git worktree remove <worktree-path> --force
   git branch -D <branch>
   git worktree prune
   ```

4. **Verify:** `git worktree list` no longer shows it and the directory is gone.

This is destructive — it drops both databases and deletes the branch. Confirm the
branch name with the user and make sure any wanted work is merged or pushed first.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `bin/worktree` missing after `bundle install` | Run `bundle exec rake worktree:install` |
| New worktree shares the main app's DB | `config/database.yml` isn't reading `DATABASE_NAME_DEVELOPMENT`/`_TEST` — ask the user to add the ENV refs above (or re-run the gem installer). Never hand-edit the tracked `database.yml`. |
| `gem "rails-worktree"` not found | Confirm it's in the `:development` group and re-run `bundle install` |
| `can't find executable foreman` during create | `bin/setup` exec's `bin/dev` and foreman isn't in the Gemfile — apply the **Step 0c** fix (remove the server block from `bin/setup`, unset bundler env in `bin/dev`) |
| `Warning: bin/setup failed` but `✓ Worktree initialized successfully!` | The success banner is unreliable — read the error above the warning, match it in **After running: inspect the output**, and verify DBs/migrations actually completed |
| `Dir.chdir': No such file or directory @ ... /.worktrees/<branch>` during close | `bin/worktree --close` assumes the dir is `.worktrees/<branch>`, but `ccw` creates it at `<repo>-<branch>` with a bare branch. **Don't use `--close` here** — use the **Manual teardown** above (dropdb ×2 + `git worktree remove --force` at the real path + `git branch -D`). |
