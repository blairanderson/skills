#!/usr/bin/env bash
# Unit tests for mesh-lib.sh pure functions. No network, no live ssh.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../scripts/mesh-lib.sh"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
no()  { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else no "$1 (want:[$3] got:[$2])"; fi; }

echo "== mlib_host_block =="
blk="$(mlib_host_block air blairs-macbook-air blairanderson)"
echo "$blk" | grep -q '^Host air$'                     && ok "emits Host line"          || no "Host line"
echo "$blk" | grep -q '^    HostName blairs-macbook-air$' && ok "emits HostName"        || no "HostName"
echo "$blk" | grep -q '^    User blairanderson$'       && ok "emits User"               || no "User"
echo "$blk" | grep -q '^    IdentitiesOnly yes$'       && ok "pins IdentitiesOnly"      || no "IdentitiesOnly"
echo "$blk" | grep -q '^    IdentityFile ~/.ssh/id_ed25519$' && ok "default identity"   || no "default identity"
blk2="$(mlib_host_block g gh git '~/.ssh/custom')"
echo "$blk2" | grep -q '^    IdentityFile ~/.ssh/custom$' && ok "custom identity"       || no "custom identity"

echo "== mlib_config_has_host =="
CFG=$'Host hatchbox\n    HostName 1.2.3.4\n\nHost air mini\n    User x\n'
if printf '%s' "$CFG" | mlib_config_has_host air;      then ok "finds single-token";  else no "finds single-token"; fi
if printf '%s' "$CFG" | mlib_config_has_host mini;     then ok "finds multi-alias";   else no "finds multi-alias"; fi
if printf '%s' "$CFG" | mlib_config_has_host hatchbox; then ok "finds first host";    else no "finds first host"; fi
if printf '%s' "$CFG" | mlib_config_has_host nope;     then no "rejects absent";      else ok "rejects absent"; fi
# substring must NOT match (air must not match airplane)
CFG2=$'Host airplane\n    User y\n'
if printf '%s' "$CFG2" | mlib_config_has_host air;     then no "no substring match";  else ok "no substring match"; fi

echo "== mlib_extract_block =="
CFG3=$'Host a\n    HostName ha\n    User ua\nHost b\n    HostName hb\n'
got="$(printf '%s' "$CFG3" | mlib_extract_block a)"
eq "extracts only block a (3 lines)" "$(printf '%s\n' "$got" | grep -c .)" "3"
printf '%s' "$got" | grep -q 'HostName ha' && ok "block a has its hostname" || no "block a hostname"
printf '%s' "$got" | grep -q 'hb' && no "block a leaked into b" || ok "block a does not leak"

echo "== mlib_dedup_append =="
TMP="$(mktemp -d)"; F="$TMP/authorized_keys"
r1="$(mlib_dedup_append "$F" 'ssh-ed25519 AAAA keyone')"
eq "first append reports appended" "$r1" "appended"
r2="$(mlib_dedup_append "$F" 'ssh-ed25519 AAAA keyone')"
eq "second identical reports present" "$r2" "present"
eq "file has exactly one line" "$(wc -l < "$F" | tr -d ' ')" "1"
mlib_dedup_append "$F" 'ssh-ed25519 BBBB keytwo' >/dev/null
eq "distinct key appends" "$(wc -l < "$F" | tr -d ' ')" "2"
perm="$(stat -f '%Lp' "$F" 2>/dev/null || stat -c '%a' "$F")"
eq "authorized_keys is 600" "$perm" "600"
rm -rf "$TMP"

echo "== mlib_parse_tailscale =="
TS=$'100.121.15.16  blairs-macbook-air      blair@  macOS  -\n100.95.157.25   blairs-mac-mini         blair@  macOS  -\n# header junk\n100.87.207.34   iphone-14-pro           blair@  iOS    -'
out="$(printf '%s' "$TS" | mlib_parse_tailscale)"
eq "parses 3 tailscale rows" "$(printf '%s\n' "$out" | grep -c .)" "3"
printf '%s' "$out" | head -1 | grep -q $'100.121.15.16\tblairs-macbook-air\tblair@\tmacOS' && ok "row is tab-separated ip/host/owner/os" || no "tsv shape"
printf '%s' "$out" | grep -q 'header junk' && no "dropped non-ip junk" || ok "dropped non-ip junk"

echo "== mlib_probe_cmd =="
p="$(mlib_probe_cmd mini)"
echo "$p" | grep -q 'BatchMode=yes'  && ok "probe forbids password fallback" || no "BatchMode"
echo "$p" | grep -q 'mini true$'     && ok "probe targets the alias"         || no "target"

echo
echo "unit: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
