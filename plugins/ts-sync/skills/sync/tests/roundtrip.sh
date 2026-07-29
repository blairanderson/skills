#!/usr/bin/env bash
#
# Hermetic end-to-end test for ts-sync.sh.
#
# Stubs `ssh` with a fake that executes the command locally against a second
# "remote" fixture directory (path-rewritten), and stubs `tailscale` with
# canned JSON — so the full list/pull/push round-trip runs with NO real
# network. Run it anywhere: bash tests/roundtrip.sh
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/ts-sync.sh"
[ -f "$SCRIPT" ] || { echo "cannot find ts-sync.sh at $SCRIPT"; exit 1; }

WORK="$(mktemp -d)"
BIN="$WORK/bin"
mkdir -p "$BIN"

# The fake ssh executes commands locally, but rewrites the LOCAL repo path to
# the REMOTE fixture path — simulating "same absolute path on another machine".
export TS_FAKE_LOCAL="$WORK/repo"
export TS_FAKE_REMOTE="$WORK/remote"

# Sandbox everything so the real user's config/env can't leak in.
export XDG_CONFIG_HOME="$WORK/xdg"
unset TS_SYNC_HOST TS_SYNC_USER 2>/dev/null || true
export PATH="$BIN:$PATH"

# --------------------------------------------------------------- fake `ssh`
cat > "$BIN/ssh" <<'FAKE'
#!/usr/bin/env bash
# Minimal fake of ssh: strips options, ignores the host, runs the command
# locally with $TS_FAKE_LOCAL -> $TS_FAKE_REMOTE rewritten (argv and stdin
# scripts), so "the remote machine" is just a sibling directory.
set -uo pipefail
args=("$@")
i=0
while [ $i -lt ${#args[@]} ]; do
  case "${args[$i]}" in
    -o) i=$((i+2));;
    -*) i=$((i+1));;
    *)  break;;
  esac
done
# args[i] is the host — ignored.
i=$((i+1))
cmd=("${args[@]:$i}")
rewrite() { sed "s|${TS_FAKE_LOCAL:?}|${TS_FAKE_REMOTE:?}|g"; }
[ ${#cmd[@]} -eq 0 ] && exit 0
joined="${cmd[*]}"
joined="$(printf '%s' "$joined" | rewrite)"
if [ "$joined" = "bash -s" ]; then
  script="$(cat | rewrite)"
  printf '%s' "$script" | bash -s
else
  bash -c "$joined"
fi
FAKE
chmod +x "$BIN/ssh"

# --------------------------------------------------------------- fake `tailscale`
cat > "$BIN/tailscale" <<'FAKE'
#!/usr/bin/env bash
cat <<'JSON'
{"Peer":{
  "n1":{"DNSName":"desktop.tail1234.ts.net.","HostName":"desktop","OS":"macOS","Online":true},
  "n2":{"DNSName":"pi.tail1234.ts.net.","HostName":"pi","OS":"linux","Online":false}
}}
JSON
FAKE
chmod +x "$BIN/tailscale"

# --------------------------------------------------------------- fixtures
REPO="$WORK/repo"; mkdir -p "$REPO"; cd "$REPO"
git init -q
git remote add origin "git@github.com:blairanderson/ts-testapp.git"

REMOTE="$WORK/remote"
mkdir -p "$REMOTE/config/credentials"
printf 'aaaa1111aaaa1111aaaa1111aaaa1111'  > "$REMOTE/config/master.key"
printf 'bbbb2222bbbb2222bbbb2222bbbb2222'  > "$REMOTE/config/credentials/production.key"
printf 'SECRET=hunter2\nDB=postgres://localhost/foo\n' > "$REMOTE/.env"
printf 'API=zzz\n'      > "$REMOTE/.env.local"
printf 'API=IGNORED\n'  > "$REMOTE/.env.example"   # must never be synced

# --------------------------------------------------------------- assertions
pass=0; fail=0
ok()   { echo "  PASS: $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL: $1"; fail=$((fail+1)); }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi; }
yes()  { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
no()   { if eval "$2"; then bad "$1"; else ok "$1"; fi; }

echo "== config ladder =="
mkdir -p "$XDG_CONFIG_HOME/ts-sync"
printf 'host=userhost\n' > "$XDG_CONFIG_HOME/ts-sync/config"
out=$(bash "$SCRIPT" status)
yes "user config host wins over none"    "printf '%s' \"\$out\" | grep -q 'host:  userhost'"
printf 'host=repohost\n' > .ts-sync
out=$(bash "$SCRIPT" status)
yes "repo .ts-sync overrides user config" "printf '%s' \"\$out\" | grep -q 'host:  repohost'"
out=$(TS_SYNC_HOST=envhost bash "$SCRIPT" status)
yes "env var overrides repo config"       "printf '%s' \"\$out\" | grep -q 'host:  envhost'"
rm -f .ts-sync "$XDG_CONFIG_HOME/ts-sync/config"

echo "== no host configured =="
out=$(bash "$SCRIPT" list 2>&1)
yes "list without host fails helpfully" "printf '%s' \"\$out\" | grep -q 'no host given'"

echo "== hosts (fake tailscale) =="
out=$(bash "$SCRIPT" hosts)
yes "online peer listed"   "printf '%s' \"\$out\" | grep -q 'desktop.tail1234.ts.net'"
no  "offline peer hidden"  "printf '%s' \"\$out\" | grep -q 'pi.tail1234.ts.net'"

echo "== list (remote has files, local empty) =="
out=$(bash "$SCRIPT" list fakehost 2>&1); echo "$out"
yes "list exit 0" "[ $? -eq 0 ]"
yes "master.key listed remote-only"  "printf '%s' \"\$out\" | grep 'config/master.key' | grep -q 'remote only'"
yes ".env listed remote-only"        "printf '%s' \"\$out\" | grep -E '^\s+\.env\s' | grep -q 'remote only'"
no  ".env.example never listed"      "printf '%s' \"\$out\" | grep -q '.env.example'"

echo "== pull =="
out=$(bash "$SCRIPT" pull fakehost 2>&1); echo "$out"
eq "master.key restored"     "aaaa1111aaaa1111aaaa1111aaaa1111" "$(cat config/master.key 2>/dev/null)"
eq "production.key restored" "bbbb2222bbbb2222bbbb2222bbbb2222" "$(cat config/credentials/production.key 2>/dev/null)"
eq ".env restored"           "SECRET=hunter2
DB=postgres://localhost/foo" "$(cat .env 2>/dev/null)"
eq ".env.local restored"     "API=zzz" "$(cat .env.local 2>/dev/null)"
no  ".env.example not pulled" "[ -f .env.example ]"
eq "master.key perms 600"    "-rw-------" "$(stat -f '%Sp' config/master.key 2>/dev/null || stat -c '%A' config/master.key)"
eq ".env perms 600"          "-rw-------" "$(stat -f '%Sp' .env 2>/dev/null || stat -c '%A' .env)"

echo "== idempotent re-pull =="
out=$(bash "$SCRIPT" pull fakehost 2>&1); echo "$out"
yes "re-pull reports unchanged" "printf '%s' \"\$out\" | grep -q unchanged"

echo "== list now agrees =="
out=$(bash "$SCRIPT" list fakehost 2>&1)
yes "master.key now same" "printf '%s' \"\$out\" | grep 'config/master.key' | grep -q 'same'"

echo "== differing local kept without --force =="
printf 'LOCALDIFF' > config/master.key
out=$(bash "$SCRIPT" pull fakehost 2>&1); echo "$out"
yes "differing file reported DIFFERS" "printf '%s' \"\$out\" | grep -q DIFFERS"
eq  "local not overwritten" "LOCALDIFF" "$(cat config/master.key)"
out=$(bash "$SCRIPT" list fakehost 2>&1)
yes "list flags the difference" "printf '%s' \"\$out\" | grep 'config/master.key' | grep -q DIFFERS"

echo "== --force overwrite makes a backup =="
bash "$SCRIPT" pull fakehost --force >/dev/null 2>&1
eq  "force restored remote value" "aaaa1111aaaa1111aaaa1111aaaa1111" "$(cat config/master.key)"
yes "backup file created" "ls config/master.key.bak.* >/dev/null 2>&1"
rm -f config/master.key.bak.*

echo "== push (wiped remote) =="
rm -rf "$REMOTE"; mkdir -p "$REMOTE"
out=$(bash "$SCRIPT" push fakehost 2>&1); echo "$out"
eq "remote master.key pushed"     "aaaa1111aaaa1111aaaa1111aaaa1111" "$(cat "$REMOTE/config/master.key" 2>/dev/null)"
eq "remote production.key pushed" "bbbb2222bbbb2222bbbb2222bbbb2222" "$(cat "$REMOTE/config/credentials/production.key" 2>/dev/null)"
eq "remote .env pushed"           "SECRET=hunter2
DB=postgres://localhost/foo" "$(cat "$REMOTE/.env" 2>/dev/null)"
no  ".env.example not pushed"      "[ -f \"$REMOTE/.env.example\" ]"
eq "remote master.key perms 600"  "-rw-------" "$(stat -f '%Sp' "$REMOTE/config/master.key" 2>/dev/null || stat -c '%A' "$REMOTE/config/master.key")"

echo "== push guard: differing remote kept without --force =="
printf 'REMOTEDIFF' > "$REMOTE/.env"
out=$(bash "$SCRIPT" push fakehost 2>&1); echo "$out"
yes "remote DIFFERS reported"  "printf '%s' \"\$out\" | grep -q DIFFERS"
eq  "remote not overwritten"   "REMOTEDIFF" "$(cat "$REMOTE/.env")"
bash "$SCRIPT" push fakehost --force >/dev/null 2>&1
eq  "force pushed local value" "SECRET=hunter2
DB=postgres://localhost/foo" "$(cat "$REMOTE/.env")"
yes "remote backup created"    "ls \"$REMOTE\"/.env.bak.* >/dev/null 2>&1"

echo "== missing remote dir =="
rm -rf "$REMOTE"
out=$(bash "$SCRIPT" list fakehost 2>&1)
yes "same-path error surfaced (list)" "printf '%s' \"\$out\" | grep -q 'clone the repo there first'"
out=$(bash "$SCRIPT" push fakehost 2>&1)
yes "same-path error surfaced (push)" "printf '%s' \"\$out\" | grep -q 'clone the repo there first'"

echo
echo "================  $pass passed, $fail failed  ================"
cd /; rm -rf "$WORK"
[ "$fail" -eq 0 ]
