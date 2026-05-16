#!/usr/bin/env bats
# Unit tests for bootstrap.sh
# Run with: bats tests/unit/bootstrap_test.bats

setup() {
  SKILL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  BOOTSTRAP="$SKILL_DIR/scripts/bootstrap.sh"
  TEST_TMP=$(mktemp -d)
}

teardown() {
  [[ -n "$TEST_TMP" ]] && rm -rf "$TEST_TMP"
}

# --- Argument parsing -------------------------------------------------------

@test "errors when --feature is missing" {
  run "$BOOTSTRAP"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "feature is required" ]]
}

@test "errors when an unknown arg is passed" {
  run "$BOOTSTRAP" --feature foo --unknown-arg bar
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "Unknown arg" ]]
}

@test "accepts --feature=value syntax (equals form)" {
  cd "$TEST_TMP"
  run "$BOOTSTRAP" --feature=test --project "$TEST_TMP"
  # Will fail preflight (not a Rails app) but should pass arg parsing
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "does not look like a Rails app" ]]
}

# --- Slug derivation --------------------------------------------------------

@test "feature slug lowercases and dashes the name" {
  cd "$TEST_TMP"
  run "$BOOTSTRAP" --feature "My Great Feature" --project "$TEST_TMP"
  # Preflight will fail but the slug should appear in error output
  [[ "$status" -eq 2 ]]
}

# --- Rails project detection ------------------------------------------------

@test "rejects non-Rails directories" {
  run "$BOOTSTRAP" --feature foo --project "$TEST_TMP"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "does not look like a Rails app" ]]
}

@test "rejects when only some Rails markers present" {
  # Only Gemfile, no bin/rails or config/application.rb
  touch "$TEST_TMP/Gemfile"
  run "$BOOTSTRAP" --feature foo --project "$TEST_TMP"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "does not look like a Rails app" ]]
}

@test "accepts a minimal Rails fixture (all 3 markers)" {
  mkdir -p "$TEST_TMP/bin" "$TEST_TMP/config"
  echo "#!/bin/bash" > "$TEST_TMP/bin/rails"
  chmod +x "$TEST_TMP/bin/rails"
  touch "$TEST_TMP/Gemfile"
  touch "$TEST_TMP/config/application.rb"
  # Not a git repo yet, should fail at the next preflight
  run "$BOOTSTRAP" --feature foo --project "$TEST_TMP"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "not a git repository" ]]
}

# --- Git preflight ----------------------------------------------------------

@test "rejects dirty git tree without --force" {
  mkdir -p "$TEST_TMP/bin" "$TEST_TMP/config"
  echo "#!/bin/bash" > "$TEST_TMP/bin/rails"
  chmod +x "$TEST_TMP/bin/rails"
  touch "$TEST_TMP/Gemfile"
  touch "$TEST_TMP/config/application.rb"
  cd "$TEST_TMP"
  git init --quiet --initial-branch=master
  git -c user.email=t@t -c user.name=T add . && git -c user.email=t@t -c user.name=T commit --quiet -m "init"
  echo "dirt" > untracked.txt
  run "$BOOTSTRAP" --feature foo --project "$TEST_TMP"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "uncommitted changes" ]]
}

# --- Required assets exist --------------------------------------------------

@test "assets/CLAUDE.md.template exists and has required placeholders" {
  ASSETS="$SKILL_DIR/assets"
  [[ -f "$ASSETS/CLAUDE.md.template" ]]
  grep -q "{PROJECT_NAME}" "$ASSETS/CLAUDE.md.template"
  grep -q "{BRANCH_NAME}" "$ASSETS/CLAUDE.md.template"
}

@test "assets/prd.json.template exists and is valid JSON" {
  ASSETS="$SKILL_DIR/assets"
  [[ -f "$ASSETS/prd.json.template" ]]
  # Strip placeholders before validating JSON
  sed -e 's/{PROJECT_NAME}/test/g; s/{BRANCH_NAME}/ralph\/test/g' "$ASSETS/prd.json.template" | jq empty
}

# --- Help / usage -----------------------------------------------------------

@test "prints usage on -h" {
  run "$BOOTSTRAP" -h
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "--feature" ]]
}
