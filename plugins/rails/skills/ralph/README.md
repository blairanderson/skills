# rails:ralph

Set up [Ralph](https://github.com/snarktank/ralph) — Geoffrey Huntley's
autonomous AI agent loop — in a sibling git worktree, tailored for Rails
projects.

## What this is

Ralph runs a loop: pick a `passes: false` story from `prd.json`, spawn a
fresh agent (Amp or Claude Code), implement it, commit, mark `passes: true`,
repeat. The upstream is generic / TypeScript-leaning. This skill adapts it
for Rails:

- Quality checks via `bin/rails zeitwerk:check`, `bin/rails test`, `bin/rubocop`
- Slug-prefix commit format (`feature-name-usNNN / summary`)
- Streaming output via `claude --print --verbose`
- Sibling worktree so master stays untouched while Ralph commits to a branch

## Quick start

```bash
# From the root of any Rails project:
/rails:ralph --feature my-feature-name

# That creates ../<project>-ralph/ as a worktree on branch ralph/my-feature-name,
# with scripts/ralph/{ralph.sh, CLAUDE.md, prd.json} ready to go.

# Then:
cd ../<project>-ralph
# Edit scripts/ralph/prd.json — replace the example story with your real PRD
./scripts/ralph/ralph.sh --tool claude 10
```

## Files

- `SKILL.md` — the skill contract + triggers + phases
- `scripts/bootstrap.sh` — deterministic bash script that does the setup
- `assets/CLAUDE.md.template` — Rails-tailored Ralph operating-loop prompt (Claude Code reads it on every iteration)
- `assets/prd.json.template` — minimal prd.json skeleton
- `tests/unit/bootstrap_test.bats` — unit tests (run with `bats tests/unit/bootstrap_test.bats`)
- `tests/integration/full-flow.sh` — end-to-end: fake Rails fixture → bootstrap → assert side effects
- `tests/eval/triggers.json` — resolver trigger eval cases

## Running the tests

```bash
# From skill root
bats tests/unit/bootstrap_test.bats          # unit (needs bats-core: brew install bats-core)
./tests/integration/full-flow.sh              # integration (needs jq + git)
```

## Design decisions

1. **Worktree, not branch in main checkout** — Ralph commits frequently and
   can break things. Isolation keeps master safe.
2. **`scripts/ralph/` not project root** — Ralph's `ralph.sh` reads
   `$SCRIPT_DIR/prd.json`, so co-locating is correct. The README example
   commands in the upstream repo are misleading.
3. **`--verbose` patch on `claude` invocation** — upstream's silent mode
   makes 5–15-minute iterations look frozen. Verbose gives streaming tool
   calls without breaking the loop's `<promise>COMPLETE</promise>` grep.
4. **Project root `CLAUDE.md` is the authoritative conventions source** —
   Claude Code auto-loads it. `scripts/ralph/CLAUDE.md` is just the
   operating loop, not a duplicate of project rules.
5. **Slug-prefix commit format** — many Rails projects (vendor-db, etc.)
   use `slug / summary` not Conventional Commits. The template documents
   this and tells the agent to check `git log -10` to confirm.

## See also

- `ralph-skills:ralph` (plugin) — converts an existing markdown PRD into the `prd.json` format this skill seeds
- `ralph-skills:prd` (plugin) — generates a markdown PRD from scratch
- Upstream: https://github.com/snarktank/ralph
- Geoffrey Huntley's article: https://ghuntley.com/ralph/
