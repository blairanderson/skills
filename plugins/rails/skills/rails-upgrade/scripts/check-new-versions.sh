#!/usr/bin/env bash
set -euo pipefail

# Check guides.rubyonrails.org for new "Upgrading from Rails X to Rails Y"
# chapters that have no reference file in this skill. Run monthly:
#
#   plugins/rails/skills/rails-upgrade/scripts/check-new-versions.sh
#
# Exit 0: up to date. Exit 1: new chapter(s) found.

REFS_DIR="$(cd "$(dirname "$0")/../references" && pwd)"
URL="https://guides.rubyonrails.org/upgrading_ruby_on_rails.html"
FLOOR="5.2" # chapters that start below this version are out of scope

chapters=$(curl -fsSL "$URL" \
  | grep -oE 'Upgrading from Rails [0-9]+\.[0-9]+ to Rails [0-9]+\.[0-9]+' \
  | sort -uV)

if [ -z "$chapters" ]; then
  echo "ERROR: no chapters found at $URL (page layout changed?)" >&2
  exit 2
fi

missing=0
while read -r chapter; do
  from=$(echo "$chapter" | awk '{print $4}')
  to=$(echo "$chapter" | awk '{print $7}')
  # skip chapters below the floor
  lowest=$(printf '%s\n%s\n' "$FLOOR" "$from" | sort -V | head -1)
  [ "$lowest" = "$FLOOR" ] || continue
  file="rails-${from//./-}-to-${to//./-}.md"
  if [ ! -f "$REFS_DIR/$file" ]; then
    echo "NEW CHAPTER: $chapter -> references/$file is missing"
    missing=1
  fi
done <<<"$chapters"

if [ "$missing" -eq 0 ]; then
  echo "Up to date. No new upgrade chapters on $URL"
else
  cat <<'EOF'

Next steps:
  1. Extract the new chapter into references/ (verbatim, from the stable
     rails/rails tag: guides/source/upgrading_ruby_on_rails.md).
  2. Add the hop to the table in SKILL.md.
  3. Update plugins/rails/README.md and the root README.md.
  4. Run /bump.
EOF
  exit 1
fi
