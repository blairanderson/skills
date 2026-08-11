---
name: rails-upgrade
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
description: |
  Rails version upgrade guide (6.0 → 8.1). MUST trigger when the user wants to
  upgrade a Rails app, bump the rails gem version, asks "what breaks in Rails X",
  mentions `app:update`, `load_defaults` / `new_framework_defaults`, or plans a
  multi-hop upgrade path (e.g. "get us from Rails 6.1 to 8.0").
---

# Rails Upgrade

Guide a Rails app through version upgrades one hop at a time, using the official
Rails upgrade guide content bundled in `references/`.

## Phase 1: Detect Versions

1. **Current version** — read `Gemfile.lock` and find the `rails (X.Y.Z)` entry:
   ```bash
   grep -E '^    rails \(' Gemfile.lock
   ```
2. **Loaded defaults** — check `config/application.rb` for `config.load_defaults X.Y`.
   If it lags behind the installed version, the previous upgrade was never finished —
   surface this and finish it first.
3. **Target version** — ask the user (default: latest stable, currently 8.1).

If the app is older than Rails 5.2, this skill's references don't cover the early
hops — point the user at <https://guides.rubyonrails.org/upgrading_ruby_on_rails.html>,
which has chapters back to Rails 3.0, then rejoin this skill at 5.2 → 6.0.

## Phase 2: Plan the Hop Path

Never jump versions. Upgrade one minor version at a time, with green tests
committed between hops (see `references/general-advice.md` for why, Ruby version
requirements, and the full rationale).

| Hop | Reference file |
|---|---|
| 5.2 → 6.0 | `references/rails-5-2-to-6-0.md` |
| 6.0 → 6.1 | `references/rails-6-0-to-6-1.md` |
| 6.1 → 7.0 | `references/rails-6-1-to-7-0.md` |
| 7.0 → 7.1 | `references/rails-7-0-to-7-1.md` |
| 7.1 → 7.2 | `references/rails-7-1-to-7-2.md` |
| 7.2 → 8.0 | `references/rails-7-2-to-8-0.md` |
| 8.0 → 8.1 | `references/rails-8-0-to-8-1.md` |

List the hops between current and target, then work through them in order.
Read ONLY the reference file(s) for the hop currently in play.

## Phase 3: Execute Each Hop

For every hop, in order:

1. **Check Ruby first** — each Rails version has a minimum Ruby
   (see `references/general-advice.md`). Upgrade Ruby before Rails if needed.
2. **Bump the pin** — update the `rails` entry in the `Gemfile`, then:
   ```bash
   bundle update rails
   ```
3. **Run the update task** — walk through each diff interactively, keeping local
   customizations:
   ```bash
   bin/rails app:update
   ```
4. **Read the hop's reference file** and apply the breaking changes and
   deprecations that affect this app (grep the codebase for each affected API
   before assuming it applies).
5. **Run the test suite.** Fix failures before touching framework defaults.
6. **Flip defaults last** — enable settings from
   `config/initializers/new_framework_defaults_X_Y.rb` one at a time, running
   tests after each. When all are enabled, set `config.load_defaults X.Y` in
   `config/application.rb` and delete the initializer.
7. **Commit** before starting the next hop.

## Notes

- The reference files are verbatim chapters from the official guide (v8.1.2).
  For anything newer, check the live guide.
- Deprecation warnings in the current version are the to-do list for the next
  hop — run the suite with deprecations visible and clear them before moving on.

## Maintenance

Run `scripts/check-new-versions.sh` monthly. It compares the chapters on the
live guide against `references/` and exits 1 (with next steps) when the guide
has a chapter this skill does not.
