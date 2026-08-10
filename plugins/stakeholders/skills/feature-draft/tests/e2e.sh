#!/usr/bin/env bash
# E2E smoke test: full first-run pipeline in a fresh fake project —
# init → add → check → recipients → write a draft temp file with the
# to/cc header derived from the config, then assert the draft's shape.
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/stakeholders.sh"
PROJECT="$(mktemp -d)"
trap 'rm -rf "$PROJECT"' EXIT
cd "$PROJECT"

# First run: no config (exit 3 signals the skill to interview)
if bash "$SCRIPT" get 2>/dev/null; then echo "E2E FAIL: expected exit 3 pre-init"; exit 1; fi

# Skill persists the interview results (default config path, project-scoped)
bash "$SCRIPT" init --relationship coworkers --email-cli olk --tone "casual, emoji ok"
bash "$SCRIPT" add --name Tony --email tony@example.com --send-as to
bash "$SCRIPT" add --name Jonas --email jonas@example.com --send-as cc
bash "$SCRIPT" check
[ -f ".claude/stakeholders.json" ] || { echo "E2E FAIL: config not at .claude/stakeholders.json"; exit 1; }
[ "$(bash "$SCRIPT" email-cli)" = "olk" ] || { echo "E2E FAIL: email-cli not readable"; exit 1; }

# Skill drafts the email temp file using the config
to_line="$(jq -r '[.stakeholders[] | select(.send_as=="to") | .email] | join(", ")' .claude/stakeholders.json)"
cc_line="$(jq -r '[.stakeholders[] | select(.send_as=="cc") | .email] | join(", ")' .claude/stakeholders.json)"
draft="/tmp/feature-draft-e2e-test.md"
cat > "$draft" <<EOF
---
to: $to_line
cc: $cc_line
subject: New: E2E Test Feature 📈
---

Hey team,

**What's new** — a test feature.
EOF

grep -q "^to: tony@example.com$" "$draft" || { echo "E2E FAIL: draft missing to header"; exit 1; }
grep -q "^cc: jonas@example.com$" "$draft" || { echo "E2E FAIL: draft missing cc header"; exit 1; }
grep -q "^subject: " "$draft" || { echo "E2E FAIL: draft missing subject"; exit 1; }

# recipients output is usable as CLI mail flags
[ "$(bash "$SCRIPT" recipients)" = "--to tony@example.com --cc jonas@example.com" ] || { echo "E2E FAIL: recipients flags"; exit 1; }

rm -f "$draft"
echo "E2E PASS"
