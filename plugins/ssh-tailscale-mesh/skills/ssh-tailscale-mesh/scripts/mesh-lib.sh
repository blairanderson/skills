#!/usr/bin/env bash
# mesh-lib.sh — pure, side-effect-light helpers for the ssh-tailscale-mesh skill.
# Every function here is unit-testable without touching a live machine.
# Source this file; do not execute it.

# Render one ~/.ssh/config Host stanza.
# args: <alias> <hostname> <user> [identityfile]
mlib_host_block() {
  local alias="$1" hostname="$2" user="$3" identity="${4:-~/.ssh/id_ed25519}"
  printf 'Host %s\n    HostName %s\n    User %s\n    IdentityFile %s\n    IdentitiesOnly yes\n' \
    "$alias" "$hostname" "$user" "$identity"
}

# Does the ssh config on stdin already define <alias> as a Host?
# Matches multi-alias Host lines (e.g. "Host a b c"). Returns 0 if present.
# args: <alias>   stdin: ssh config text
mlib_config_has_host() {
  awk -v a="$1" '
    $1=="Host"{ for(i=2;i<=NF;i++) if($i==a){found=1} }
    END{ exit !found }
  '
}

# Extract the full Host stanza for <alias> from the ssh config on stdin.
# args: <alias>   stdin: ssh config text
mlib_extract_block() {
  awk -v a="$1" '
    $1=="Host"{ inblk=0; for(i=2;i<=NF;i++) if($i==a) inblk=1 }
    inblk{ print }
  '
}

# Append <line> to <file> only if an exact copy is not already present.
# Creates the file (and parent dir) with safe perms. Echoes "appended" or "present".
# args: <file> <line>
mlib_dedup_append() {
  local file="$1" line="$2" dir
  dir="$(dirname "$file")"
  mkdir -p "$dir"; chmod 700 "$dir" 2>/dev/null || true
  touch "$file"; chmod 600 "$file" 2>/dev/null || true
  if grep -qxF -- "$line" "$file"; then
    echo present
  else
    printf '%s\n' "$line" >> "$file"
    echo appended
  fi
}

# Parse `tailscale status` output on stdin into TSV: ip<TAB>host<TAB>owner<TAB>os
# Only rows with a 100.x.y.z Tailscale IP are emitted.
# stdin: tailscale status text
mlib_parse_tailscale() {
  awk 'NF>=4 && $1 ~ /^100\.[0-9]+\.[0-9]+\.[0-9]+$/ { print $1"\t"$2"\t"$3"\t"$4 }'
}

# Build the shell command that probes passwordless reachability of <to>.
# Success (exit 0) means key-auth works; it never falls back to a password.
# args: <to-alias>
mlib_probe_cmd() {
  printf 'ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=6 %s true' "$1"
}
