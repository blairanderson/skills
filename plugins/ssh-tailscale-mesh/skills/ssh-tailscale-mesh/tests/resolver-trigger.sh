#!/usr/bin/env bash
# Resolver trigger eval — assert the phrases a user ACTUALLY types route to this
# skill, and that unrelated phrases do not. Self-contained (no live resolver):
# it (a) checks SKILL.md advertises the key trigger phrases, and (b) runs those
# phrases through the same intent patterns and asserts match / no-match.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$HERE/../SKILL.md"

pass=0; fail=0
ok() { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
no() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }

# The intent matcher: a phrase routes here if it hits any of these patterns.
route_here() { # <phrase> -> exit 0 if routes to ssh-tailscale-mesh
  printf '%s' "$1" | grep -qiE \
    'passwordless ssh|ssh.*(mesh|passwordless)|ssh keeps? asking|too many authentication failures|(add|onboard).*(server|machine|host).*(tailscale|mesh)|tailscale.*(mesh|ssh)|ssh.*across .*machines|sync .*ssh.?config|ssh-copy-id'
}

echo "== SKILL.md advertises real trigger phrases =="
# YAML folded scalar wraps across lines; flatten whitespace before matching.
SKILL_FLAT="$(tr '\n' ' ' < "$SKILL" | tr -s ' ')"
for phrase in \
  "too many authentication failures" \
  "passwordless SSH" \
  "add this new server" \
  "sync my ~/.ssh/config" \
  "test my ssh mesh"; do
  printf '%s' "$SKILL_FLAT" | grep -qiF "$phrase" && ok "description mentions: $phrase" || no "description missing: $phrase"
done

echo "== positive routing (should hit this skill) =="
for p in \
  "set up passwordless ssh between my machines" \
  "why does ssh keep asking for a password" \
  "I keep getting too many authentication failures" \
  "add this new server to my tailscale mesh" \
  "onboard a server into the mesh" \
  "sync my ssh config across machines" \
  "test my ssh mesh" \
  "run ssh-copy-id to all my boxes"; do
  route_here "$p" && ok "routes: \"$p\"" || no "should route: \"$p\""
done

echo "== negative routing (should NOT hit this skill) =="
for p in \
  "write a python script to parse csv" \
  "what's the weather tomorrow" \
  "deploy the rails app to hatchbox" \
  "summarize this pdf"; do
  if route_here "$p"; then no "should NOT route: \"$p\""; else ok "ignores: \"$p\""; fi
done

echo
echo "resolver-trigger: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
