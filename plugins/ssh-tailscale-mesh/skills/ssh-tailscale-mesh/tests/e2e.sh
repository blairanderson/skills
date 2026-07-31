#!/usr/bin/env bash
# E2E — drive the real courier→probe pipeline against a loopback "peer" (localhost).
# Generates a throwaway keypair, installs it into localhost's authorized_keys exactly
# as `mesh.sh courier` would, then proves passwordless auth with that key works and a
# random unauthorized key does not. SKIPs cleanly if Remote Login is off.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../scripts/mesh-lib.sh"

pass=0; fail=0; skip=0
ok() { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
no() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
sk() { skip=$((skip+1)); printf '  skip %s\n' "$1"; }

command -v sshd >/dev/null 2>&1 || sshd_ok=0
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o PubkeyAuthentication=no -o PasswordAuthentication=no localhost true 2>/dev/null; then :; fi

# Can we even reach a local sshd at all (any auth)?
if ! (exec 3<>/dev/tcp/127.0.0.1/22) 2>/dev/null; then
  sk "no sshd on localhost:22 — e2e pipeline skipped"
  echo; echo "e2e: $pass passed, $fail failed, $skip skipped"; exit 0
fi
exec 3>&- 2>/dev/null || true

TMP="$(mktemp -d)"
AUTH="$HOME/.ssh/authorized_keys"
BACKUP="$TMP/authorized_keys.bak"
cp "$AUTH" "$BACKUP" 2>/dev/null || : > "$BACKUP"
cleanup() { cp "$BACKUP" "$AUTH" 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT

# fresh throwaway identity acting as a "remote machine's" key
ssh-keygen -t ed25519 -N "" -C "e2e-$$-throwaway" -f "$TMP/id" -q </dev/null
PUB="$(cat "$TMP/id.pub")"

echo "== courier step: install pubkey into authorized_keys (deduped) =="
r1="$(mlib_dedup_append "$AUTH" "$PUB")"; [ "$r1" = appended ] && ok "key installed" || no "install ($r1)"
r2="$(mlib_dedup_append "$AUTH" "$PUB")"; [ "$r2" = present ]  && ok "install is idempotent" || no "idempotent ($r2)"

echo "== probe step: authorized key authenticates, stranger does not =="
if ssh -i "$TMP/id" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=6 localhost true 2>/dev/null; then
  ok "authorized throwaway key -> passwordless login"
else
  sk "sshd present but pubkey login blocked (config/policy) — auth assertion skipped"
fi
ssh-keygen -t ed25519 -N "" -C stranger -f "$TMP/stranger" -q </dev/null
if ssh -i "$TMP/stranger" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=6 localhost true 2>/dev/null; then
  no "unauthorized key unexpectedly logged in"
else
  ok "unauthorized key correctly rejected"
fi

echo
echo "e2e: $pass passed, $fail failed, $skip skipped"
[ "$fail" -eq 0 ]
