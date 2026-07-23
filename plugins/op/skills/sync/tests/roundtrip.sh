#!/usr/bin/env bash
#
# Hermetic end-to-end test for op-sync.sh.
#
# Stubs the `op` CLI with a fake backed by a directory "vault", so the full
# rails-key + env push/pull round-trip runs with NO real 1Password and NO
# Touch ID. Run it anywhere: bash tests/roundtrip.sh
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/op-sync.sh"
[ -f "$SCRIPT" ] || { echo "cannot find op-sync.sh at $SCRIPT"; exit 1; }

WORK="$(mktemp -d)"
BIN="$WORK/bin"
export OP_FAKE_HOME="$WORK/vault"
mkdir -p "$BIN" "$OP_FAKE_HOME/items" "$OP_FAKE_HOME/docs"

# Sandbox everything so the real user's config/env can't leak in.
export XDG_CONFIG_HOME="$WORK/xdg"
unset OP_SYNC_VAULT OP_SYNC_ENV_MODE OP_SYNC_ACCOUNT 2>/dev/null || true
export PATH="$BIN:$PATH"

# --------------------------------------------------------------- fake `op`
cat > "$BIN/op" <<'FAKE'
#!/usr/bin/env bash
# Minimal fake of the 1Password CLI, backed by $OP_FAKE_HOME/{items,docs}.
set -uo pipefail
H="${OP_FAKE_HOME:?}"; mkdir -p "$H/items" "$H/docs"

group="${1:-}"
format=""; outfile=""; title=""; pos=()
i=1; a=( "$@" )
while [ $i -lt ${#a[@]} ]; do
  case "${a[$i]:-}" in
    --format)     format="${a[$((i+1))]:-}"; i=$((i+2));;
    --out-file|-o) outfile="${a[$((i+1))]:-}"; i=$((i+2));;
    --title)      title="${a[$((i+1))]:-}"; i=$((i+2));;
    --vault|--file-name|--tags) i=$((i+2));;   # value ignored by the fake
    --force|--iso-timestamps|--no-color) i=$((i+1));;
    -)            pos+=("-"); i=$((i+1));;
    --*)          i=$((i+1));;
    *)            pos+=("${a[$i]}"); i=$((i+1));;
  esac
done

item_file() { printf '%s/items/%s.json' "$H" "$1"; }
doc_file()  { printf '%s/docs/%s.content' "$H" "$1"; }

case "$group" in
  whoami) echo "fake-user"; exit 0;;

  item)
    action="${pos[0]:-}"
    case "$action" in
      get)
        name="${pos[1]:-}"
        if [ -f "$(item_file "$name")" ]; then
          [ "$format" = json ] && cat "$(item_file "$name")" || echo "$name"
          exit 0
        elif [ -f "$(doc_file "$name")" ]; then
          [ "$format" = json ] && jq -n --arg t "$name" '{title:$t,category:"DOCUMENT"}' || echo "$name"
          exit 0
        fi
        echo "\"$name\" isn't an item in the vault." >&2; exit 1;;
      create)   # JSON template on stdin; title comes from the JSON
        json="$(cat)"
        name="$(printf '%s' "$json" | jq -r '.title')"
        printf '%s' "$json" > "$(item_file "$name")"
        jq -n --arg id "$name" '{id:$id}'; exit 0;;
      edit)     # existing item name in argv, full JSON on stdin
        name="${pos[1]:-}"
        cat > "$(item_file "$name")"; exit 0;;
      list)     # only Documents are ever listed by op-sync
        for f in "$H"/docs/*.content; do
          [ -e "$f" ] || continue
          b="$(basename "$f" .content)"; printf '%s\n' "$b"
        done | jq -R 'select(length>0) | {id:., title:.}' | jq -s '.'
        exit 0;;
      delete)
        name="${pos[1]:-}"; rm -f "$(item_file "$name")" "$(doc_file "$name")"; exit 0;;
    esac
    echo "fake op: unknown item action '$action'" >&2; exit 2;;

  document)
    action="${pos[0]:-}"
    case "$action" in
      create)   # op document create <file> --title T ...
        src="${pos[1]:-}"; cp "$src" "$(doc_file "$title")"; jq -n --arg id "$title" '{id:$id}'; exit 0;;
      edit)     # op document edit <title> <file> ...
        name="${pos[1]:-}"; src="${pos[2]:-}"; cp "$src" "$(doc_file "$name")"; exit 0;;
      get)      # op document get <id> --out-file PATH
        id="${pos[1]:-}"
        [ -f "$(doc_file "$id")" ] || { echo "no doc $id" >&2; exit 1; }
        if [ -n "$outfile" ]; then cp "$(doc_file "$id")" "$outfile"; else cat "$(doc_file "$id")"; fi
        exit 0;;
    esac
    echo "fake op: unknown document action '$action'" >&2; exit 2;;

  read)   # op read op://Vault/Item/field
    ref="${pos[0]:-}"; rest="${ref#op://}"
    name="$(printf '%s' "$rest" | cut -d/ -f2)"
    field="$(printf '%s' "$rest" | cut -d/ -f3)"
    f="$(item_file "$name")"
    [ -f "$f" ] || { echo "isn't an item" >&2; exit 1; }
    val="$(jq -r --arg k "$field" '.fields[]? | select(.id==$k or .label==$k) | .value' "$f")"
    [ -n "$val" ] || { echo "no field $field" >&2; exit 1; }
    printf '%s' "$val"; exit 0;;
esac
echo "fake op: unhandled: $*" >&2; exit 2
FAKE
chmod +x "$BIN/op"

# --------------------------------------------------------------- fixture repo
REPO="$WORK/repo"; mkdir -p "$REPO"; cd "$REPO"
git init -q
git remote add origin "git@github.com:blairanderson/op-testapp.git"
APP="op-testapp"

mkdir -p config/credentials
printf 'aaaa1111aaaa1111aaaa1111aaaa1111'  > config/master.key
printf 'bbbb2222bbbb2222bbbb2222bbbb2222'  > config/credentials/production.key
printf 'SECRET=hunter2\nDB=postgres://localhost/foo\n' > .env
printf 'API=zzz\n'      > .env.local
printf 'API=IGNORED\n'  > .env.example   # must never be pushed or pulled

# --------------------------------------------------------------- assertions
pass=0; fail=0
ok()   { echo "  PASS: $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL: $1"; fail=$((fail+1)); }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi; }
yes()  { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
no()   { if eval "$2"; then bad "$1"; else ok "$1"; fi; }

echo "== push =="
out=$(bash "$SCRIPT" rails-key push 2>&1); echo "$out"
yes "rails-key push exit 0" "[ $? -eq 0 ]"
out=$(bash "$SCRIPT" env push 2>&1); echo "$out"

echo "== op read one-liners =="
eq "read master_key"     "aaaa1111aaaa1111aaaa1111aaaa1111" "$(op read "op://Private/$APP/master_key")"
eq "read production_key" "bbbb2222bbbb2222bbbb2222bbbb2222" "$(op read "op://Private/$APP/production_key")"

echo "== stored shape =="
yes ".env pushed as document"        "[ -f \"$OP_FAKE_HOME/docs/env:$APP:.env.content\" ]"
yes ".env.local pushed as document"  "[ -f \"$OP_FAKE_HOME/docs/env:$APP:.env.local.content\" ]"
no  ".env.example NOT pushed"         "[ -f \"$OP_FAKE_HOME/docs/env:$APP:.env.example.content\" ]"

echo "== wipe + pull =="
rm -rf config .env .env.local .env.example
bash "$SCRIPT" rails-key pull
bash "$SCRIPT" env pull

eq "master.key restored"     "aaaa1111aaaa1111aaaa1111aaaa1111" "$(cat config/master.key 2>/dev/null)"
eq "production.key restored" "bbbb2222bbbb2222bbbb2222bbbb2222" "$(cat config/credentials/production.key 2>/dev/null)"
eq ".env restored"           "SECRET=hunter2
DB=postgres://localhost/foo" "$(cat .env 2>/dev/null)"
eq ".env.local restored"     "API=zzz" "$(cat .env.local 2>/dev/null)"
no  ".env.example not recreated" "[ -f .env.example ]"
eq "master.key perms 600"    "-rw-------" "$(stat -f '%Sp' config/master.key 2>/dev/null || stat -c '%A' config/master.key)"
eq ".env perms 600"          "-rw-------" "$(stat -f '%Sp' .env 2>/dev/null || stat -c '%A' .env)"

echo "== idempotent re-pull (expect 'unchanged') =="
out=$(bash "$SCRIPT" rails-key pull 2>&1); echo "$out"
yes "re-pull reports unchanged" "printf '%s' \"\$out\" | grep -q unchanged"

echo "== --force overwrite makes a backup =="
printf 'LOCALDIFF' > config/master.key
out=$(bash "$SCRIPT" rails-key pull 2>&1); echo "$out"
yes "differing file kept without --force" "printf '%s' \"\$out\" | grep -q DIFFERS"
eq  "local still differs (not overwritten)" "LOCALDIFF" "$(cat config/master.key)"
bash "$SCRIPT" rails-key pull --force >/dev/null 2>&1
eq  "force restored vault value" "aaaa1111aaaa1111aaaa1111aaaa1111" "$(cat config/master.key)"
yes "backup file created" "ls config/master.key.bak.* >/dev/null 2>&1"

echo
echo "================  $pass passed, $fail failed  ================"
cd /; rm -rf "$WORK"
[ "$fail" -eq 0 ]
