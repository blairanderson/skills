#!/usr/bin/env bash
# Integration tests — real filesystem + real ssh. These exercise side effects the
# unit mocks hide. Live-ssh checks SKIP (not fail) when Remote Login is unavailable,
# so the suite is green in any environment but genuinely exercises ssh when it can.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MESH="$HERE/../scripts/mesh.sh"
. "$HERE/../scripts/mesh-lib.sh"

pass=0; fail=0; skip=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
no()  { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
sk()  { skip=$((skip+1)); printf '  skip %s\n' "$1"; }

echo "== config-add writes a real ssh config (deduped) =="
TMP="$(mktemp -d)"; CFG="$TMP/config"
printf 'Host existing\n    HostName keep.me\n' > "$CFG"
SSH_CONFIG="$CFG" bash "$MESH" config-add air blairs-macbook-air blairanderson >/dev/null
grep -q '^Host air$' "$CFG"            && ok "alias written to real file"      || no "alias written"
grep -q '^Host existing$' "$CFG"       && ok "existing stanza preserved"       || no "existing preserved"
# idempotency: second add must not duplicate
SSH_CONFIG="$CFG" bash "$MESH" config-add air blairs-macbook-air blairanderson >/dev/null
n="$(grep -c '^Host air$' "$CFG")"
[ "$n" -eq 1 ] && ok "re-adding does not duplicate" || no "duplicate on re-add (n=$n)"
rm -rf "$TMP"

echo "== probe reports FAIL for an unreachable host =="
probe_bogus="$(mlib_probe_cmd 'no-such-host.invalid')"
if eval "$probe_bogus" >/dev/null 2>&1; then no "unreachable host somehow OK"; else ok "unreachable host -> non-zero"; fi

echo "== live ssh loopback (needs Remote Login) =="
if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new localhost true 2>/dev/null; then
  probe_local="$(mlib_probe_cmd localhost)"
  if eval "$probe_local" >/dev/null 2>&1; then ok "passwordless localhost probe OK"; else no "localhost probe failed"; fi
else
  sk "localhost passwordless ssh unavailable (Remote Login off or no self-auth) — live probe skipped"
fi

echo
echo "integration: $pass passed, $fail failed, $skip skipped"
[ "$fail" -eq 0 ]
