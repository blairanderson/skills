#!/usr/bin/env bash
#
# ts-sync — pull/push a Rails app's secret files between your own machines
# over SSH (pairs naturally with Tailscale, but any ssh-reachable host works).
#
# Files it syncs (discovered automatically, never configured per-file):
#   config/master.key
#   config/credentials/*.key
#   .env and .env.*   (excluding *.example/*.sample/*.tpl/*.template/*.dist
#                      and its own *.bak.* backups)
#
# Model: the repo is cloned at the SAME absolute path on every machine
# (e.g. ~/dev/my-app everywhere). ts-sync ssh-es to the other machine, runs
# the same file discovery there, and moves files with tar over the ssh
# stream — secrets never appear in argv, transfers land chmod 600, and a
# differing destination file is never overwritten without --force (a
# timestamped .bak is made first).
#
# Config (first match wins, later sources override earlier):
#   built-in defaults  ->  ~/.config/ts-sync/config  ->  <repo>/.ts-sync
#   ->  env vars (TS_SYNC_HOST, TS_SYNC_USER)
#
# Usage:
#   ts-sync setup                # write the user config file (+ CLI symlink)
#   ts-sync hosts                # list online Tailscale peers to pick from
#   ts-sync status               # show config + local secret files (no network)
#   ts-sync list  [host]         # compare local vs remote secret files (no transfer)
#   ts-sync pull  [host] [-f]    # fetch remote secret files into this repo
#   ts-sync push  [host] [-f]    # send local secret files to the remote repo
#   ts-sync link                 # (re)install the ~/bin/ts-sync convenience symlink
#
# --force / -f lets pull/push overwrite a destination file whose contents
# differ (a timestamped .bak is made first). Without it, differing files are
# kept and reported.

set -euo pipefail

# ----------------------------------------------------------------------------- helpers
die()  { printf 'ts-sync: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=8)

# ----------------------------------------------------------------------------- config
load_config() {
  TSS_HOST=""
  TSS_USER=""

  local user_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/ts-sync/config"
  [ -f "$user_cfg" ] && parse_cfg "$user_cfg"

  local root; root=$(git rev-parse --show-toplevel 2>/dev/null || true)
  [ -n "$root" ] && [ -f "$root/.ts-sync" ] && parse_cfg "$root/.ts-sync"

  [ -n "${TS_SYNC_HOST:-}" ] && TSS_HOST="$TS_SYNC_HOST"
  [ -n "${TS_SYNC_USER:-}" ] && TSS_USER="$TS_SYNC_USER"
  return 0
}

# Parse a `key=value` file safely (no `source`, so no arbitrary code execution).
parse_cfg() {
  local f="$1" line key val
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"                       # strip comments
    case "$line" in *=*) ;; *) continue;; esac
    key="${line%%=*}"; val="${line#*=}"
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    val="$(printf '%s' "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/')"
    case "$key" in
      host) TSS_HOST="$val";;
      user) TSS_USER="$val";;
    esac
  done < "$f"
}

# ----------------------------------------------------------------------------- identity
repo_root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

require_repo() {
  git rev-parse --show-toplevel >/dev/null 2>&1 \
    || die "not inside a git repo — run ts-sync from inside the app you want to sync."
}

# Resolve the ssh target: positional arg wins, else configured host; prepend
# the configured user unless the host already carries one.
resolve_target() {
  local host="${1:-$TSS_HOST}"
  [ -n "$host" ] || die "no host given and none configured — run 'ts-sync hosts' to list Tailscale peers, then 'ts-sync pull <host>', or set host= in ~/.config/ts-sync/config"
  case "$host" in
    *@*) printf '%s' "$host";;
    *)   if [ -n "$TSS_USER" ]; then printf '%s@%s' "$TSS_USER" "$host"; else printf '%s' "$host"; fi;;
  esac
}

# ----------------------------------------------------------------------------- discovery
# Runs with cwd = repo root, prints repo-relative paths. Shipped to the remote
# via `declare -f`, so local and remote discovery can never drift.
secret_files_rel() {
  [ -f config/master.key ] && printf '%s\n' config/master.key
  [ -d config/credentials ] && find config/credentials -maxdepth 1 -type f -name '*.key' | sort
  local f
  for f in .env .env.*; do
    [ -f "$f" ] || continue
    case "$f" in
      *.example|*.sample|*.tpl|*.template|*.dist) continue;;
      *.bak.*) continue;;
    esac
    printf '%s\n' "$f"
  done
}

# stdin: relative paths -> "sha  relpath" lines (portable macOS/Linux).
hash_lines() {
  local f
  while IFS= read -r f; do
    sha256sum "$f" 2>/dev/null || shasum -a 256 "$f"
  done
}

local_manifest() { ( cd "$(repo_root)" && secret_files_rel | hash_lines ); }

# ----------------------------------------------------------------------------- file installer
# install_secret_file <src> <dst> — 0600, diff-guarded, backs up before
# overwrite. File-based (cmp) so the exact same function runs on the remote
# side during push (shipped via `declare -f`).
install_secret_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ]; then
    if cmp -s "$src" "$dst"; then info "  unchanged: $dst"; return 0; fi
    if [ "${FORCE:-0}" != 1 ]; then
      info "  DIFFERS, kept: $dst  (rerun with --force to overwrite)"; return 0
    fi
    cp "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
    info "  backed up existing -> $dst.bak.*"
  fi
  ( umask 077; cp "$src" "$dst" )
  chmod 600 "$dst"
  info "  wrote: $dst"
}

# ----------------------------------------------------------------------------- ssh plumbing
preflight_ssh() {
  local target="$1" err
  err=$(ssh "${SSH_OPTS[@]}" "$target" true 2>&1) \
    || die "cannot ssh to '$target': ${err:-unknown error} — check 'tailscale status' and that Tailscale SSH or key auth is set up (ts-sync uses BatchMode; password prompts are disabled)."
}

# One ssh call: run the shared discovery on the remote, print "sha  relpath"
# lines. Prints the sentinel TS_SYNC_NO_DIR if the repo path doesn't exist.
remote_manifest() {
  local target="$1" root="$2" rootq
  printf -v rootq '%q' "$root"
  {
    printf 'set -euo pipefail\n'
    printf 'cd %s 2>/dev/null || { echo TS_SYNC_NO_DIR; exit 0; }\n' "$rootq"
    declare -f secret_files_rel hash_lines
    printf 'secret_files_rel | hash_lines\n'
  } | ssh "${SSH_OPTS[@]}" "$target" bash -s
}

check_no_dir() {  # <manifest> <target> <root>
  case "$1" in *TS_SYNC_NO_DIR*)
    die "remote $2 has no directory $3 — clone the repo there first (ts-sync assumes the same absolute path on every machine).";;
  esac
}

manifest_hash_for() {  # <manifest> <relpath> -> sha or empty
  awk -v p="$2" '$2==p{print $1}' <<<"$1"
}

# ----------------------------------------------------------------------------- commands
cmd_list() {
  local target; target=$(resolve_target "${1:-}")
  local root; root=$(repo_root)
  preflight_ssh "$target"
  local rman; rman=$(remote_manifest "$target" "$root")
  check_no_dir "$rman" "$target" "$root"
  local lman; lman=$(local_manifest)

  info "host:  $target"
  info "repo:  $root"
  local paths
  paths=$(printf '%s\n%s\n' "$rman" "$lman" | awk 'NF{print $2}' | sort -u)
  if [ -z "$paths" ]; then info "no secret files on either machine."; return 0; fi

  info "files:"
  local p rh lh state
  while IFS= read -r p; do
    rh=$(manifest_hash_for "$rman" "$p")
    lh=$(manifest_hash_for "$lman" "$p")
    if [ -n "$rh" ] && [ -n "$lh" ]; then
      if [ "$rh" = "$lh" ]; then state="same"; else state="DIFFERS (pull keeps local unless --force)"; fi
    elif [ -n "$rh" ]; then state="remote only (pull will fetch)"
    else                    state="local only (push will send)"
    fi
    printf '  %-40s %s\n' "$p" "$state"
  done <<<"$paths"
}

cmd_pull() {
  local target; target=$(resolve_target "${1:-}")
  local root; root=$(repo_root)
  preflight_ssh "$target"
  local rman; rman=$(remote_manifest "$target" "$root")
  check_no_dir "$rman" "$target" "$root"
  local files; files=$(printf '%s\n' "$rman" | awk 'NF{print $2}')
  [ -z "$files" ] && die "remote $target has no secret files in $root."

  local rootq; printf -v rootq '%q' "$root"
  local tmp; tmp=$(mktemp -d); chmod 700 "$tmp"
  # Single tar pipe: file list travels on stdin, contents on the ssh stream —
  # never in argv. Staged into a user-only tmpdir, then guard-installed.
  printf '%s\n' "$files" \
    | ssh "${SSH_OPTS[@]}" "$target" "tar -C $rootq -cf - -T -" \
    | tar -C "$tmp" -xf -
  info "pulled from $target:"
  local rel
  ( cd "$root"
    while IFS= read -r rel; do install_secret_file "$tmp/$rel" "$rel"; done <<<"$files" )
  rm -rf "$tmp"
}

cmd_push() {
  local target; target=$(resolve_target "${1:-}")
  local root; root=$(repo_root)
  preflight_ssh "$target"
  local files; files=$( cd "$root" && secret_files_rel )
  [ -z "$files" ] && die "no local secret files to push (config/master.key, config/credentials/*.key, .env*)."

  local rootq; printf -v rootq '%q' "$root"
  ssh "${SSH_OPTS[@]}" "$target" "test -d $rootq" \
    || die "remote $target has no directory $root — clone the repo there first (ts-sync assumes the same absolute path on every machine)."

  # Call 1: stream files into a private staging dir on the remote.
  local stage
  stage=$(printf '%s\n' "$files" | ( cd "$root" && tar -cf - -T - ) \
    | ssh "${SSH_OPTS[@]}" "$target" 'd=$(mktemp -d) && chmod 700 "$d" && tar -C "$d" -xf - && printf %s "$d"')
  [ -n "$stage" ] || die "failed to stage files on $target."

  # Call 2: guard-install on the remote — the very same install_secret_file
  # runs where the files land, so diff-guards/backups/0600 apply there too.
  info "pushed to $target:"
  {
    printf 'set -euo pipefail\n'
    printf 'FORCE=%s\n' "${FORCE:-0}"
    declare -f info install_secret_file
    printf 'stage=%q\n' "$stage"
    printf 'cd %s\n' "$rootq"
    printf 'while IFS= read -r rel; do install_secret_file "$stage/$rel" "$rel"; done <<TS_SYNC_EOF\n%s\nTS_SYNC_EOF\n' "$files"
    printf 'rm -rf "$stage"\n'
  } | ssh "${SSH_OPTS[@]}" "$target" bash -s
}

cmd_status() {
  local root; root=$(repo_root)
  info "repo:  $root"
  info "host:  ${TSS_HOST:-<none configured — run 'ts-sync hosts'>}"
  [ -n "$TSS_USER" ] && info "user:  $TSS_USER"
  info "secret files (local):"
  local files; files=$( cd "$root" && secret_files_rel )
  if [ -n "$files" ]; then
    local f; while IFS= read -r f; do info "  $f"; done <<<"$files"
  else
    info "  (none)"
  fi
}

# ----------------------------------------------------------------------------- tailscale
tailscale_bin() {
  if command -v tailscale >/dev/null 2>&1; then printf 'tailscale'; return 0; fi
  local mac="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
  if [ -x "$mac" ]; then printf '%s' "$mac"; return 0; fi
  return 1
}

cmd_hosts() {
  local ts
  if ! ts=$(tailscale_bin); then
    info "tailscale CLI not found — ssh still works with any reachable host or ~/.ssh/config alias."
    info "Set host= in ${XDG_CONFIG_HOME:-$HOME/.config}/ts-sync/config, or pass a host explicitly."
    return 0
  fi
  command -v jq >/dev/null 2>&1 || die "jq not installed. Run: brew install jq"
  local rows
  rows=$("$ts" status --json 2>/dev/null \
    | jq -r '.Peer[]? | select(.Online) | [(.DNSName | rtrimstr(".")), .HostName, .OS] | @tsv') || true
  if [ -z "$rows" ]; then info "no online Tailscale peers found (is Tailscale up?)"; return 0; fi

  info "online Tailscale peers (use the first column as the ssh host):"
  local dns hn os short mark
  while IFS=$'\t' read -r dns hn os; do
    short="${dns%%.*}"
    mark=" "
    if [ -n "$TSS_HOST" ]; then
      case "$TSS_HOST" in "$dns"|"$hn"|"$short") mark="*";; esac
    fi
    printf '%s %-45s %-16s %s\n' "$mark" "$dns" "$hn" "$os"
  done <<<"$rows"
  [ -n "$TSS_HOST" ] && info "(* = configured default host: $TSS_HOST)"
  return 0
}

# ----------------------------------------------------------------------------- setup / link
self_path() { cd "$(dirname "${BASH_SOURCE[0]}")" && printf '%s/%s' "$PWD" "$(basename "${BASH_SOURCE[0]}")"; }

cmd_link() {
  local self; self=$(self_path)
  local dir
  for dir in "$HOME/bin" "$HOME/.local/bin"; do
    if [ -d "$dir" ]; then
      ln -sf "$self" "$dir/ts-sync"
      info "linked: $dir/ts-sync -> $self"
      case ":$PATH:" in *":$dir:"*) ;; *) info "  (note: $dir is not on your PATH)";; esac
      return
    fi
  done
  info "no ~/bin or ~/.local/bin found; run ts-sync via: bash \"$self\""
}

cmd_setup() {
  local dir="${XDG_CONFIG_HOME:-$HOME/.config}/ts-sync" cfg
  cfg="$dir/config"
  mkdir -p "$dir"
  if [ -f "$cfg" ]; then
    info "config already exists: $cfg"
  else
    cat > "$cfg" <<'EOF'
# ts-sync configuration
# Default remote machine to sync with — an ssh target: a Tailscale MagicDNS
# name, plain hostname, IP, or ~/.ssh/config alias.
# Run `ts-sync hosts` to list your online Tailscale peers.
# host=desktop.your-tailnet.ts.net

# Optional: ssh username, if it differs between machines.
# user=blair
EOF
    info "created config: $cfg"
  fi
  info "  host=${TSS_HOST:-<none>}  user=${TSS_USER:-<ssh default>}"
  cmd_link
}

usage() {
  sed -n '2,35p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# ----------------------------------------------------------------------------- main
main() {
  load_config
  FORCE=0
  local args=() a
  for a in "$@"; do case "$a" in --force|-f) FORCE=1;; *) args+=("$a");; esac; done
  set -- "${args[@]:-}"

  local cmd="${1:-}"
  case "$cmd" in
    setup)  cmd_setup;;
    link)   cmd_link;;
    hosts)  cmd_hosts;;
    status) cmd_status;;
    list)   require_repo; cmd_list "${2:-}";;
    pull)   require_repo; cmd_pull "${2:-}";;
    push)   require_repo; cmd_push "${2:-}";;
    ""|-h|--help|help) usage 0;;
    *) die "unknown command '$cmd' (try: ts-sync help)";;
  esac
}

# Only run when executed directly, so the functions can be sourced for testing.
[ "${BASH_SOURCE[0]}" = "${0}" ] && main "$@"
