#!/usr/bin/env bash
# Rails Ralph Bootstrap — set up snarktank/ralph in a sibling git worktree
# tailored for a Rails project's conventions.
#
# Usage:
#   bootstrap.sh --feature <name> [--project <path>] [--ralph-cache <path>] [--force]
#
# Exit codes:
#   0  success
#   1  argument error (missing --feature, etc.)
#   2  preflight failed (not a Rails project, dirty tree, etc.)
#   3  git operation failed

set -euo pipefail

# ---- Defaults ---------------------------------------------------------------

PROJECT="${PROJECT:-$PWD}"
RALPH_CACHE="${RALPH_CACHE:-$HOME/dev/ralph}"
FEATURE=""
FORCE=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/../assets"

# ---- Arg parsing ------------------------------------------------------------

usage() {
  cat <<EOF
Usage: bootstrap.sh --feature <name> [--project <path>] [--ralph-cache <path>] [--force]

  --feature <name>       (required) Slug-cased feature name → branch ralph/<name>
  --project <path>       (default: \$PWD) Path to the Rails project
  --ralph-cache <path>   (default: ~/dev/ralph) Where to keep snarktank/ralph clone
  --force                Overwrite existing worktree / branch if present
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --feature) FEATURE="$2"; shift 2 ;;
    --feature=*) FEATURE="${1#*=}"; shift ;;
    --project) PROJECT="$2"; shift 2 ;;
    --project=*) PROJECT="${1#*=}"; shift ;;
    --ralph-cache) RALPH_CACHE="$2"; shift 2 ;;
    --ralph-cache=*) RALPH_CACHE="${1#*=}"; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1" >&2; usage ;;
  esac
done

if [[ -z "$FEATURE" ]]; then
  echo "ERROR: --feature is required" >&2
  usage
fi

# Slugify the feature name (lowercase, replace non-alnum with -)
FEATURE_SLUG=$(echo "$FEATURE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/-/g; s/^-//; s/-$//')
BRANCH_NAME="ralph/${FEATURE_SLUG}"

# Resolve project path (absolute)
PROJECT=$(cd "$PROJECT" 2>/dev/null && pwd) || { echo "ERROR: project path not found: $PROJECT" >&2; exit 2; }

# Worktree path: sibling directory named <basename>-ralph
PROJECT_NAME=$(basename "$PROJECT")
WORKTREE="$(dirname "$PROJECT")/${PROJECT_NAME}-ralph"

# ---- Preflight: is this a Rails project? -----------------------------------

is_rails_project() {
  [[ -x "$1/bin/rails" ]] && [[ -f "$1/Gemfile" ]] && [[ -f "$1/config/application.rb" ]]
}

if ! is_rails_project "$PROJECT"; then
  echo "ERROR: $PROJECT does not look like a Rails app" >&2
  echo "  expected: bin/rails (executable), Gemfile, config/application.rb" >&2
  exit 2
fi

# ---- Preflight: git clean? -------------------------------------------------

if ! git -C "$PROJECT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: $PROJECT is not a git repository" >&2
  exit 2
fi

if [[ -n "$(git -C "$PROJECT" status --porcelain)" ]] && [[ $FORCE -eq 0 ]]; then
  echo "WARNING: $PROJECT has uncommitted changes. Use --force to proceed anyway." >&2
  git -C "$PROJECT" status --short >&2
  exit 2
fi

# ---- Preflight: worktree / branch collisions -------------------------------

if [[ -d "$WORKTREE" ]]; then
  if [[ $FORCE -eq 1 ]]; then
    echo "→ --force: removing existing worktree $WORKTREE"
    git -C "$PROJECT" worktree remove --force "$WORKTREE" 2>/dev/null || rm -rf "$WORKTREE"
  else
    echo "ERROR: worktree path $WORKTREE already exists. Use --force to wipe it." >&2
    exit 2
  fi
fi

if git -C "$PROJECT" show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  if [[ $FORCE -eq 1 ]]; then
    echo "→ --force: deleting existing branch $BRANCH_NAME"
    git -C "$PROJECT" branch -D "$BRANCH_NAME"
  else
    echo "ERROR: branch $BRANCH_NAME already exists. Use --force to recreate." >&2
    exit 2
  fi
fi

# ---- Ensure snarktank/ralph cache ------------------------------------------

if [[ ! -d "$RALPH_CACHE/.git" ]]; then
  echo "→ Cloning snarktank/ralph to $RALPH_CACHE"
  mkdir -p "$(dirname "$RALPH_CACHE")"
  git clone --quiet https://github.com/snarktank/ralph.git "$RALPH_CACHE"
else
  echo "→ Updating snarktank/ralph cache at $RALPH_CACHE"
  git -C "$RALPH_CACHE" pull --quiet --ff-only || echo "  (skipped: not on a fast-forwardable branch)"
fi

RALPH_SHA=$(git -C "$RALPH_CACHE" rev-parse --short HEAD)

# ---- Create the worktree ---------------------------------------------------

echo "→ Creating worktree at $WORKTREE on branch $BRANCH_NAME"

# Determine the project's default branch (master or main)
DEFAULT_BRANCH=$(git -C "$PROJECT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' \
  || git -C "$PROJECT" rev-parse --abbrev-ref HEAD)

git -C "$PROJECT" worktree add "$WORKTREE" -b "$BRANCH_NAME" "$DEFAULT_BRANCH"

# ---- Vendor Ralph files ----------------------------------------------------

mkdir -p "$WORKTREE/scripts/ralph"

# Copy ralph.sh, patch with --verbose
cp "$RALPH_CACHE/ralph.sh" "$WORKTREE/scripts/ralph/ralph.sh"
chmod +x "$WORKTREE/scripts/ralph/ralph.sh"

# Patch: add --verbose to the claude invocation so iterations stream tool calls
# Match the line and inject --verbose before the redirect
if grep -q "claude --dangerously-skip-permissions --print <" "$WORKTREE/scripts/ralph/ralph.sh"; then
  sed -i.bak 's|claude --dangerously-skip-permissions --print <|claude --dangerously-skip-permissions --print --verbose <|' \
    "$WORKTREE/scripts/ralph/ralph.sh"
  rm -f "$WORKTREE/scripts/ralph/ralph.sh.bak"
  echo "  ✓ patched ralph.sh with --verbose"
else
  echo "  ⚠ ralph.sh upstream layout changed; --verbose patch skipped"
fi

# ---- Render templates ------------------------------------------------------

if [[ ! -f "$ASSETS_DIR/CLAUDE.md.template" ]]; then
  echo "ERROR: missing template $ASSETS_DIR/CLAUDE.md.template" >&2
  exit 3
fi

render_template() {
  local src="$1"
  local dest="$2"
  sed \
    -e "s|{PROJECT_NAME}|$PROJECT_NAME|g" \
    -e "s|{FEATURE_NAME}|$FEATURE_SLUG|g" \
    -e "s|{BRANCH_NAME}|$BRANCH_NAME|g" \
    "$src" > "$dest"
}

render_template "$ASSETS_DIR/CLAUDE.md.template" "$WORKTREE/scripts/ralph/CLAUDE.md"
render_template "$ASSETS_DIR/prd.json.template" "$WORKTREE/scripts/ralph/prd.json"

# ---- Add a .gitignore entry for the Ralph internal state file --------------

GITIGNORE="$WORKTREE/scripts/ralph/.gitignore"
cat > "$GITIGNORE" <<EOF
# Ralph internal state — regenerated each run
.last-branch
EOF

# ---- Commit ----------------------------------------------------------------

git -C "$WORKTREE" add scripts/ralph/
git -C "$WORKTREE" commit --quiet -m "ralph-bootstrap / vendor snarktank/ralph (@${RALPH_SHA}) under scripts/ralph/ — Rails-tailored CLAUDE.md prompt + --verbose ralph.sh patch + seed prd.json skeleton for feature '${FEATURE_SLUG}' on branch ${BRANCH_NAME}; worktree at ${WORKTREE} sibling to ${PROJECT}"

COMMIT_SHA=$(git -C "$WORKTREE" rev-parse --short HEAD)

# ---- Report ----------------------------------------------------------------

cat <<EOF

✓ Ralph bootstrapped for ${FEATURE_SLUG}

  Worktree:  ${WORKTREE}
  Branch:    ${BRANCH_NAME} (commit ${COMMIT_SHA}, not yet pushed)
  Cache:     ${RALPH_CACHE} (snarktank/ralph @ ${RALPH_SHA})

Next steps:
  1. cd ${WORKTREE}
  2. Edit scripts/ralph/prd.json — replace the example user story with your real PRD
     (or run /ralph-skills:ralph to convert an existing markdown PRD)
  3. ./scripts/ralph/ralph.sh --tool claude 10    # run 10 iterations
  4. Watch git log and scripts/ralph/progress.txt for activity

When done:
  - git push -u origin ${BRANCH_NAME}
  - gh pr create  # against your default branch
EOF
