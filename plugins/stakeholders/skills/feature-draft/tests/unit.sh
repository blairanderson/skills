#!/usr/bin/env bash
# Unit tests for stakeholders.sh — covers every subcommand branch.
# Run: tests/unit.sh   (prints PASS/FAIL per case, exit 1 on any failure)
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/stakeholders.sh"
WORKDIR="$(mktemp -d)"
export STAKEHOLDERS_FILE="$WORKDIR/stakeholders.json"
trap 'rm -rf "$WORKDIR"' EXIT

fails=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; fails=$((fails+1)); }

expect_exit() { # expect_exit CODE DESC -- cmd...
  local want="$1" desc="$2"; shift 2
  "$@" >/dev/null 2>&1
  local got=$?
  [ "$got" = "$want" ] && pass "$desc" || fail "$desc (want exit $want, got $got)"
}

# --- get / require_config ---
expect_exit 3 "get with no config exits 3" bash "$SCRIPT" get
expect_exit 3 "recipients with no config exits 3" bash "$SCRIPT" recipients
expect_exit 3 "check with no config exits 3" bash "$SCRIPT" check

# --- init ---
expect_exit 1 "init without relationship fails" bash "$SCRIPT" init
expect_exit 1 "init with bad relationship fails" bash "$SCRIPT" init --relationship friends --email-cli olk
expect_exit 1 "init without email-cli fails" bash "$SCRIPT" init --relationship coworkers
expect_exit 1 "init with bad email-cli fails" bash "$SCRIPT" init --relationship coworkers --email-cli sendmail
expect_exit 0 "init coworkers succeeds" bash "$SCRIPT" init --relationship coworkers --email-cli olk --tone "casual, emoji ok"
expect_exit 1 "init refuses to overwrite existing config" bash "$SCRIPT" init --relationship clients --email-cli gws
[ "$(jq -r '.relationship' "$STAKEHOLDERS_FILE")" = "coworkers" ] && pass "init wrote relationship" || fail "init wrote relationship"
[ "$(jq -r '.tone' "$STAKEHOLDERS_FILE")" = "casual, emoji ok" ] && pass "init wrote tone" || fail "init wrote tone"
[ "$(jq -r '.email_cli' "$STAKEHOLDERS_FILE")" = "olk" ] && pass "init wrote email_cli" || fail "init wrote email_cli"

# --- email-cli get/set ---
[ "$(bash "$SCRIPT" email-cli)" = "olk" ] && pass "email-cli prints current value" || fail "email-cli prints current value"
expect_exit 1 "email-cli rejects invalid value" bash "$SCRIPT" email-cli sendmail
expect_exit 0 "email-cli sets gws" bash "$SCRIPT" email-cli gws
[ "$(bash "$SCRIPT" email-cli)" = "gws" ] && pass "email-cli set persisted" || fail "email-cli set persisted"
bash "$SCRIPT" email-cli olk >/dev/null 2>&1
tmpjson="$(mktemp)"; jq 'del(.email_cli)' "$STAKEHOLDERS_FILE" > "$tmpjson" && mv "$tmpjson" "$STAKEHOLDERS_FILE"
expect_exit 1 "email-cli get fails when unset" bash "$SCRIPT" email-cli
expect_exit 4 "check exits 4 when email_cli missing" bash "$SCRIPT" check
bash "$SCRIPT" email-cli olk >/dev/null 2>&1

# --- add ---
expect_exit 1 "add without name fails" bash "$SCRIPT" add --email a@b.com
expect_exit 1 "add with invalid email fails" bash "$SCRIPT" add --name X --email not-an-email
expect_exit 1 "add with bad send-as fails" bash "$SCRIPT" add --name X --email x@y.com --send-as bcc
expect_exit 0 "add first stakeholder (to)" bash "$SCRIPT" add --name Tony --email tony@example.com --send-as to
expect_exit 0 "add second stakeholder (cc)" bash "$SCRIPT" add --name Jonas --email jonas@example.com --send-as cc
expect_exit 1 "add duplicate email fails" bash "$SCRIPT" add --name Tony2 --email tony@example.com
[ "$(jq '.stakeholders | length' "$STAKEHOLDERS_FILE")" = "2" ] && pass "two stakeholders persisted" || fail "two stakeholders persisted"

# --- default send_as is to ---
bash "$SCRIPT" add --name D --email default@example.com >/dev/null 2>&1
[ "$(jq -r '.stakeholders[] | select(.email=="default@example.com") | .send_as' "$STAKEHOLDERS_FILE")" = "to" ] \
  && pass "send_as defaults to 'to'" || fail "send_as defaults to 'to'"
bash "$SCRIPT" remove --email default@example.com >/dev/null 2>&1

# --- recipients ---
out="$(bash "$SCRIPT" recipients)"
[ "$out" = "--to tony@example.com --cc jonas@example.com" ] && pass "recipients emits to/cc flags" || fail "recipients emits to/cc flags (got: $out)"

# --- remove ---
expect_exit 1 "remove without email fails" bash "$SCRIPT" remove
expect_exit 1 "remove unknown email fails" bash "$SCRIPT" remove --email nobody@example.com
expect_exit 0 "remove existing email succeeds" bash "$SCRIPT" remove --email jonas@example.com
[ "$(jq '.stakeholders | length' "$STAKEHOLDERS_FILE")" = "1" ] && pass "remove shrinks list" || fail "remove shrinks list"

# --- recipients with empty list ---
bash "$SCRIPT" remove --email tony@example.com >/dev/null 2>&1
expect_exit 1 "recipients with zero stakeholders fails" bash "$SCRIPT" recipients

# --- check ---
bash "$SCRIPT" add --name Tony --email tony@example.com >/dev/null 2>&1
expect_exit 0 "check passes on valid config" bash "$SCRIPT" check
jq '.relationship = "friends"' "$STAKEHOLDERS_FILE" > "$WORKDIR/t" && mv "$WORKDIR/t" "$STAKEHOLDERS_FILE"
expect_exit 4 "check exits 4 on bad relationship" bash "$SCRIPT" check
jq '.relationship = "clients" | .stakeholders[0].email = "broken"' "$STAKEHOLDERS_FILE" > "$WORKDIR/t" && mv "$WORKDIR/t" "$STAKEHOLDERS_FILE"
expect_exit 4 "check exits 4 on invalid stakeholder email" bash "$SCRIPT" check

# --- unknown command ---
expect_exit 1 "unknown command fails" bash "$SCRIPT" bogus

echo
if [ "$fails" -gt 0 ]; then echo "$fails FAILURE(S)"; exit 1; else echo "ALL PASS"; fi
