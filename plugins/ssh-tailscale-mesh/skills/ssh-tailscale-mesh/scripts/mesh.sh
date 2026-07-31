#!/usr/bin/env bash
# mesh.sh — set up and maintain a passwordless SSH mesh over a Tailscale network.
#
# The guiding idea: one machine you actually work from (the HUB) that already has
# passwordless access to every other machine can act as a COURIER — it reads each
# machine's public key and appends it to the others' authorized_keys, wiring the
# whole mesh without ever typing a password on the remote machines.
#
# Subcommands:
#   discover                              Parse `tailscale status` into ip/host/owner/os TSV.
#   config-add   <alias> <host> <user>    Append a Host stanza to the LOCAL ~/.ssh/config (dedup).
#   config-sync  <alias...>               Copy the named local Host stanzas to every listed alias (dedup).
#   test         <hub> <alias...>         Print the full directed reachability matrix.
#   courier      <hub> <alias...>         Distribute every machine's key to every other (full mesh).
#   add-host     <hub> <alias> <host> <user> <existing...>
#                                         Full onboarding of a new machine into an existing mesh.
#
# All write operations are idempotent (dedup on config lines and authorized_keys).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./mesh-lib.sh
. "$HERE/mesh-lib.sh"

CONFIG="${SSH_CONFIG:-$HOME/.ssh/config}"

die() { echo "mesh: $*" >&2; exit 1; }

# Run a command on <target>. If <target> == $HUB it runs locally; otherwise via ssh.
# Requires HUB to be set for courier/test flows.
run_on() { # <target> <command-string>
  local target="$1"; shift
  if [ "${HUB:-}" = "$target" ]; then
    bash -c "$*"
  else
    ssh "$target" "$*"
  fi
}

# Locate the tailscale CLI: PATH first, then the macOS app bundle.
_tailscale_bin() {
  if command -v tailscale >/dev/null 2>&1; then echo tailscale; return 0; fi
  local app="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
  [ -x "$app" ] && { echo "$app"; return 0; }
  return 1
}

cmd_discover() {
  local ts
  ts="$(_tailscale_bin)" || die "tailscale CLI not found (not on PATH, no /Applications/Tailscale.app)"
  "$ts" status | mlib_parse_tailscale
}

cmd_config_add() {
  local alias="$1" host="$2" user="$3"
  touch "$CONFIG"
  if mlib_config_has_host "$alias" < "$CONFIG"; then
    echo "config-add: '$alias' already in $CONFIG — skipped"
    return 0
  fi
  { printf '\n'; mlib_host_block "$alias" "$host" "$user"; } >> "$CONFIG"
  chmod 600 "$CONFIG"
  echo "config-add: appended '$alias' -> $host ($user)"
}

cmd_config_sync() {
  [ "$#" -ge 1 ] || die "config-sync needs at least one alias"
  local aliases=("$@") target block
  for target in "${aliases[@]}"; do
    for a in "${aliases[@]}"; do
      block="$(mlib_extract_block "$a" < "$CONFIG")"
      [ -n "$block" ] || die "no local Host stanza for '$a' to sync"
      # append remotely only if missing
      if [ "$target" = "$a" ]; then :; fi
      printf '%s\n' "$block" | ssh "$target" '
        cfg="$HOME/.ssh/config"; mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"; touch "$cfg"; chmod 600 "$cfg"
        blk="$(cat)"; first="$(printf "%s\n" "$blk" | head -1)"
        if grep -qxF "$first" "$cfg"; then echo "  ['"$target"'] '"$a"' present"; else printf "\n%s\n" "$blk" >> "$cfg"; echo "  ['"$target"'] '"$a"' appended"; fi
      '
    done
  done
}

# Probe one directed edge; echoes "OK  " or "FAIL".
_probe_edge() { # <from> <to> <hub>
  local from="$1" to="$2" hub="$3" probe rc
  probe="$(mlib_probe_cmd "$to")"
  if [ "$from" = "$hub" ]; then
    eval "$probe" >/dev/null 2>&1 && rc=0 || rc=1
  else
    ssh -o BatchMode=yes -o ConnectTimeout=6 "$from" "$probe" >/dev/null 2>&1 && rc=0 || rc=1
  fi
  [ "$rc" -eq 0 ] && echo "OK  " || echo "FAIL"
}

cmd_test() {
  local hub="$1"; shift
  local aliases=("$@")
  printf '%-14s' 'from\to'
  for to in "${aliases[@]}"; do printf '%-9s' "$to"; done; printf '\n'
  for from in "${aliases[@]}"; do
    printf '%-14s' "$from"
    for to in "${aliases[@]}"; do
      if [ "$from" = "$to" ]; then printf '%-9s' '  —'
      else printf '%-9s' "$(_probe_edge "$from" "$to" "$hub")"; fi
    done
    printf '\n'
  done
}

# Read a machine's public key (via hub courier semantics).
_pubkey_of() { # <alias>
  HUB="$HUB" run_on "$1" 'cat ~/.ssh/id_ed25519.pub'
}

# Install <pubkey> into <target>'s authorized_keys, deduped, correct perms.
_install_key() { # <target> <pubkey>
  local target="$1" key="$2"
  HUB="$HUB" run_on "$target" "
    mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
    grep -qxF '$key' ~/.ssh/authorized_keys && echo present || { echo '$key' >> ~/.ssh/authorized_keys; echo appended; }
  "
}

cmd_courier() {
  local hub="$1"; shift
  HUB="$hub"
  local aliases=("$@")
  declare -A PUB
  local a
  for a in "${aliases[@]}"; do
    PUB[$a]="$(_pubkey_of "$a")" || die "cannot read pubkey from '$a' (is it passwordless from the hub?)"
  done
  local src dst
  for dst in "${aliases[@]}"; do
    for src in "${aliases[@]}"; do
      [ "$src" = "$dst" ] && continue
      printf '  %-10s -> %-10s : ' "$src" "$dst"
      _install_key "$dst" "${PUB[$src]}"
    done
  done
}

cmd_add_host() {
  local hub="$1" alias="$2" host="$3" user="$4"; shift 4
  local existing=("$@")
  HUB="$hub"
  echo "== add-host: $alias ($host, $user) into mesh with ${existing[*]} =="
  # 1. ensure the new host has a keypair
  ssh "$alias" '[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -N "" -C "$(whoami)@$(hostname -s)-$(date +%Y%m%d)" -f ~/.ssh/id_ed25519 </dev/null'
  # 2. local config + push config to everyone
  cmd_config_add "$alias" "$host" "$user"
  local all=("$alias" "${existing[@]}")
  cmd_config_sync "${all[@]}"
  # 3. wire keys both directions across the whole set
  cmd_courier "$hub" "${all[@]}"
  echo "== add-host done; verifying =="
  cmd_test "$hub" "${all[@]}"
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    discover)    cmd_discover "$@" ;;
    config-add)  cmd_config_add "$@" ;;
    config-sync) cmd_config_sync "$@" ;;
    test)        cmd_test "$@" ;;
    courier)     cmd_courier "$@" ;;
    add-host)    cmd_add_host "$@" ;;
    ""|-h|--help)
      grep -E '^#( |$)' "$0" | sed -E 's/^# ?//' ;;
    *) die "unknown subcommand: $sub (try --help)" ;;
  esac
}
main "$@"
