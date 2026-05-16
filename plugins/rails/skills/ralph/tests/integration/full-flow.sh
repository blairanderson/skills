#!/usr/bin/env bash
# Integration test: spin up a fake Rails project, run bootstrap.sh end-to-end,
# assert the worktree exists with all expected files.
#
# Run from skill root: ./tests/integration/full-flow.sh
# Exits 0 on success, non-zero on any assertion failure.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BOOTSTRAP="$SKILL_DIR/scripts/bootstrap.sh"

# --- Set up a temp Rails fixture --------------------------------------------

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

PROJECT="$TMP/fake-rails-app"
mkdir -p "$PROJECT/bin" "$PROJECT/config"
echo "#!/bin/bash" > "$PROJECT/bin/rails"
chmod +x "$PROJECT/bin/rails"
echo 'source "https://rubygems.org"' > "$PROJECT/Gemfile"
echo "module FakeApp; class Application; end; end" > "$PROJECT/config/application.rb"

cd "$PROJECT"
git init --quiet --initial-branch=master
git -c user.email=t@t -c user.name=T add .
git -c user.email=t@t -c user.name=T commit --quiet -m "init"

# --- Run bootstrap ----------------------------------------------------------

echo "→ Running bootstrap.sh against fake Rails project at $PROJECT"
"$BOOTSTRAP" --feature integration-test --project "$PROJECT" --ralph-cache "$TMP/ralph-cache"

WORKTREE="$TMP/fake-rails-app-ralph"

# --- Assertions -------------------------------------------------------------

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "  ✓ $1"; }

[[ -d "$WORKTREE" ]] || fail "worktree directory not created at $WORKTREE"
pass "worktree directory exists"

[[ -d "$WORKTREE/scripts/ralph" ]] || fail "scripts/ralph/ not created"
pass "scripts/ralph/ exists"

[[ -x "$WORKTREE/scripts/ralph/ralph.sh" ]] || fail "ralph.sh missing or not executable"
pass "ralph.sh exists and is executable"

grep -q "claude --dangerously-skip-permissions --print --verbose" "$WORKTREE/scripts/ralph/ralph.sh" \
  || fail "ralph.sh was not patched with --verbose"
pass "ralph.sh has --verbose patch"

[[ -f "$WORKTREE/scripts/ralph/CLAUDE.md" ]] || fail "CLAUDE.md missing"
pass "CLAUDE.md exists"

grep -q "fake-rails-app" "$WORKTREE/scripts/ralph/CLAUDE.md" \
  || fail "CLAUDE.md placeholder substitution failed (no PROJECT_NAME)"
pass "CLAUDE.md placeholders substituted"

[[ -f "$WORKTREE/scripts/ralph/prd.json" ]] || fail "prd.json missing"
pass "prd.json exists"

jq empty "$WORKTREE/scripts/ralph/prd.json" || fail "prd.json is not valid JSON"
pass "prd.json is valid JSON"

jq -e '.branchName == "ralph/integration-test"' "$WORKTREE/scripts/ralph/prd.json" >/dev/null \
  || fail "prd.json branchName placeholder not substituted"
pass "prd.json branchName substituted"

# --- Branch state ----------------------------------------------------------

BRANCH=$(git -C "$WORKTREE" rev-parse --abbrev-ref HEAD)
[[ "$BRANCH" == "ralph/integration-test" ]] || fail "expected branch ralph/integration-test, got $BRANCH"
pass "worktree on branch ralph/integration-test"

COMMITS=$(git -C "$WORKTREE" log master..HEAD --oneline | wc -l | tr -d ' ')
[[ "$COMMITS" -eq 1 ]] || fail "expected 1 commit ahead of master, got $COMMITS"
pass "exactly 1 bootstrap commit on the branch"

# --- Idempotency: re-running without --force should fail --------------------

echo "→ Verifying re-run without --force fails cleanly"
if "$BOOTSTRAP" --feature integration-test --project "$PROJECT" --ralph-cache "$TMP/ralph-cache" 2>/dev/null; then
  fail "second run without --force should have errored"
fi
pass "second run without --force errors as expected"

# --- Idempotency: --force should succeed -----------------------------------

echo "→ Verifying --force re-run succeeds"
"$BOOTSTRAP" --feature integration-test --project "$PROJECT" --ralph-cache "$TMP/ralph-cache" --force
[[ -d "$WORKTREE" ]] || fail "worktree gone after --force re-run"
pass "--force re-run succeeded"

echo ""
echo "✓ All integration assertions passed"
