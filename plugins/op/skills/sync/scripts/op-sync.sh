#!/usr/bin/env bash
#
# op-sync — share a Rails app's master/credentials keys and its .env files
# between machines using the 1Password CLI (`op`).
#
# Storage model (per app, keyed by the git remote basename — identical on every
# machine that clones the repo):
#
#   Rails keys  -> ONE 1Password "Secure Note" item titled "<app>", with one
#                  CONCEALED field per key file:
#                    config/master.key              -> field  master_key
#                    config/credentials/<env>.key   -> field  <env>_key
#                  Read a single key anywhere with:
#                    op read "op://<vault>/<app>/master_key"
#
#   .env files  -> ONE 1Password "Document" per file, titled "env:<app>:<name>"
#                  (blob mode, the default). Or, in template mode, .env is
#                  rendered from a committed .env.tpl via `op inject`.
#
# Config (first match wins, later sources override earlier):
#   built-in defaults  ->  ~/.config/op-sync/config  ->  <repo>/.op-sync
#   ->  env vars (OP_SYNC_VAULT, OP_SYNC_ENV_MODE, OP_SYNC_ACCOUNT)
#
# Usage:
#   op-sync setup                 # write the user config file (+ optional CLI symlink)
#   op-sync status                # show config + what's local vs. stored for this app
#   op-sync rails-key push        # store local key files in 1Password
#   op-sync rails-key pull [-f]   # restore key files from 1Password
#   op-sync env push              # store local .env files (blob mode)
#   op-sync env pull [-f]         # restore .env files (blob) / render (template)
#   op-sync link                  # (re)install the ~/bin/op-sync convenience symlink
#
# status, rails-key, and env must be run from a Rails app root (the directory
# holding config/application.rb); anywhere else they refuse. setup and link are
# machine-scoped and work from anywhere.
#
# --force / -f lets pull overwrite a local file whose contents differ from the
# vault (a timestamped .bak is made first). Without it, differing files are kept.

set -euo pipefail

# ----------------------------------------------------------------------------- helpers
die()  { printf 'op-sync: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

# ----------------------------------------------------------------------------- config
load_config() {
  OPS_VAULT="Private"
  OPS_ENV_MODE="blob"
  OPS_ACCOUNT=""

  local user_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/op-sync/config"
  [ -f "$user_cfg" ] && parse_cfg "$user_cfg"

  local root; root=$(git rev-parse --show-toplevel 2>/dev/null || true)
  [ -n "$root" ] && [ -f "$root/.op-sync" ] && parse_cfg "$root/.op-sync"

  [ -n "${OP_SYNC_VAULT:-}" ]    && OPS_VAULT="$OP_SYNC_VAULT"
  [ -n "${OP_SYNC_ENV_MODE:-}" ] && OPS_ENV_MODE="$OP_SYNC_ENV_MODE"
  [ -n "${OP_SYNC_ACCOUNT:-}" ]  && OPS_ACCOUNT="$OP_SYNC_ACCOUNT"

  case "$OPS_ENV_MODE" in blob|template) ;; *) die "invalid env_mode '$OPS_ENV_MODE' (use blob or template)";; esac
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
      vault)    OPS_VAULT="$val";;
      env_mode) OPS_ENV_MODE="$val";;
      account)  OPS_ACCOUNT="$val";;
    esac
  done < "$f"
}

# ----------------------------------------------------------------------------- op wrappers
op_() { op "${OP_GLOBAL[@]}" "$@"; }

require_op() {
  command -v op >/dev/null 2>&1 || die "1Password CLI not installed. Run: brew install 1password-cli"
  command -v jq >/dev/null 2>&1 || die "jq not installed. Run: brew install jq"
  # No `op whoami` gate: with 1Password desktop-app integration there is no
  # persistent session — each command authenticates on demand (and whoami would
  # report "not signed in" even when reads/writes work). The real op call below
  # triggers the unlock; if the user truly isn't authorized, op's own error
  # (with a hint) surfaces via op_guard.
}

# Run an op command; on failure, add a sign-in hint to op's own error.
op_guard() {
  if ! op_ "$@"; then
    die "1Password command failed. If it says you're not signed in, unlock the 1Password app (Settings → Developer → 'Integrate with 1Password CLI') or run: eval \$(op signin)"
  fi
}

# Look up an item by title. Prints the item JSON on stdout and returns 0 when
# found; returns 1 when the item genuinely doesn't exist; prints op's error and
# returns 2 on any other failure (auth, network, bad vault, ambiguous title).
# Never treat rc=2 as "not found" — that's how duplicate items get created.
item_get_json() {
  local title="$1" errf rc=0 err
  errf=$(mktemp)
  op_ item get "$title" --vault "$OPS_VAULT" --format json 2>"$errf" || rc=$?
  err=$(cat "$errf"); rm -f "$errf"
  [ "$rc" -eq 0 ] && return 0
  case "$err" in
    *"isn't an item"*|*"not found"*) return 1;;
    *) printf 'op-sync: 1Password lookup for %s failed: %s\n' "$title" "$err" >&2; return 2;;
  esac
}

# ----------------------------------------------------------------------------- rails root
# Every app-scoped command must run from the root of a Rails app. That's what
# makes the relative paths below (config/master.key, .env) unambiguous.
#
# config/application.rb declaring a Rails::Application is the definition of a
# Rails app root: a subdirectory doesn't have it, and neither does a random
# directory that happens to contain a stray config/ folder.
require_rails_root() {
  [ -f config/application.rb ] \
    && grep -q 'Rails::Application' config/application.rb 2>/dev/null \
    || die "Sorry must be inside Rails app root"
}

# ----------------------------------------------------------------------------- identity
app_name() {
  local remote
  remote=$(git config --get remote.origin.url 2>/dev/null || true)
  if [ -n "$remote" ]; then
    remote="${remote%.git}"
    basename "$remote"
  else
    basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  fi
}

# The Rails app root. require_rails_root has already proven this is it, so the
# app's files are anchored here rather than at the git toplevel — those differ
# when a Rails app lives in a subdirectory of a larger repo.
rails_root() { pwd; }

# config/master.key -> master_key ; config/credentials/production.key -> production_key
keyfield_for() { local b; b=$(basename "$1" .key); printf '%s_key' "$b"; }

# ----------------------------------------------------------------------------- file writer
# write_secret_file <path> <value> — 0600, diff-guarded, backs up before overwrite.
write_secret_file() {
  local path="$1" val="$2"
  mkdir -p "$(dirname "$path")"
  if [ -f "$path" ]; then
    if [ "$(cat "$path")" = "$val" ]; then info "  unchanged: ${path#$PWD/}"; return; fi
    if [ "${FORCE:-0}" != 1 ]; then
      info "  DIFFERS, kept local: ${path#$PWD/}  (rerun with --force to overwrite)"; return
    fi
    cp "$path" "$path.bak.$(date +%Y%m%d%H%M%S)"
    info "  backed up existing -> ${path#$PWD/}.bak.*"
  fi
  ( umask 077; printf '%s' "$val" > "$path" )
  chmod 600 "$path"
  info "  wrote: ${path#$PWD/}"
}

# ----------------------------------------------------------------------------- rails keys
rails_key_files() {
  local f
  [ -f config/master.key ] && printf '%s\n' config/master.key
  if [ -d config/credentials ]; then
    while IFS= read -r f; do printf '%s\n' "$f"; done \
      < <(find config/credentials -maxdepth 1 -type f -name '*.key' | sort)
  fi
}

rails_key_push() {
  local app; app=$(app_name)
  local files; files=$(rails_key_files)
  [ -z "$files" ] && die "No Rails key files here (config/master.key or config/credentials/*.key)."

  local json mode rc=0
  json=$(item_get_json "$app") || rc=$?
  case "$rc" in
    0) mode=edit;;
    1) json=$(jq -n --arg t "$app" '{title:$t, category:"SECURE_NOTE", tags:["op-sync","rails-key"], fields:[]}'); mode=create;;
    *) die "couldn't determine whether item '$app' exists — refusing to risk a duplicate. Fix the error above (often: unlock the 1Password app) and re-run.";;
  esac

  local f field val
  while IFS= read -r f; do
    field=$(keyfield_for "$f")
    val=$(cat "$f")
    json=$(jq --arg id "$field" --arg v "$val" \
      '.fields = ((.fields // []) | map(select(.id != $id and .label != $id)))
                 + [{id:$id, type:"CONCEALED", label:$id, value:$v}]' <<<"$json")
    info "  store ${f} -> field ${field}"
  done <<<"$files"

  # Secret values travel on stdin (JSON), never in argv.
  if [ "$mode" = create ]; then
    printf '%s' "$json" | op_guard item create --vault "$OPS_VAULT" - >/dev/null
    info "created item '$app' in vault '$OPS_VAULT'"
  else
    printf '%s' "$json" | op_guard item edit "$app" --vault "$OPS_VAULT" >/dev/null
    info "updated item '$app' in vault '$OPS_VAULT'"
  fi
}

rails_key_pull() {
  local app; app=$(app_name)
  local item_json
  item_json=$(op_ item get "$app" --vault "$OPS_VAULT" --format json 2>/dev/null) \
    || die "Can't read item '$app' from vault '$OPS_VAULT' — it may not exist yet (push from a machine that has the keys) or 1Password isn't unlocked."
  local rows
  rows=$(printf '%s' "$item_json" \
    | jq -r '.fields[]? | select((.id // "") | endswith("_key"))
             | select((.value // "") != "") | [.id, .value] | @tsv')
  [ -z "$rows" ] && die "Item '$app' has no *_key fields to restore."

  local id val env path
  while IFS=$'\t' read -r id val; do
    env="${id%_key}"
    if [ "$env" = master ]; then path="config/master.key"; else path="config/credentials/${env}.key"; fi
    write_secret_file "$path" "$val"
  done <<<"$rows"
}

# ----------------------------------------------------------------------------- env files
# top-level .env / .env.* (excluding examples, templates, and our own backups)
env_files() {
  local root f base; root=$(rails_root)
  for f in "$root"/.env "$root"/.env.*; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
      *.example|*.sample|*.tpl|*.template|*.dist) continue;;
      *.bak.*) continue;;
    esac
    printf '%s\n' "$f"
  done
}

env_push() {
  if [ "$OPS_ENV_MODE" = template ]; then
    info "env_mode=template: nothing to push. Edit .env.tpl (op:// references) and commit it."
    return
  fi
  local app; app=$(app_name)
  local files; files=$(env_files)
  [ -z "$files" ] && die "No .env files here to push."

  local f base title rc
  while IFS= read -r f; do
    base=$(basename "$f")
    title="env:${app}:${base}"
    rc=0; item_get_json "$title" >/dev/null || rc=$?
    case "$rc" in
      0)
        op_guard document edit "$title" "$f" --vault "$OPS_VAULT" >/dev/null
        info "  updated document: $title";;
      1)
        op_guard document create "$f" --title "$title" --file-name "$base" \
          --tags op-sync,env-sync --vault "$OPS_VAULT" >/dev/null
        info "  created document: $title";;
      *) die "couldn't determine whether document '$title' exists — refusing to risk a duplicate. Fix the error above and re-run.";;
    esac
  done <<<"$files"
}

env_pull() {
  local app root
  app=$(app_name)
  root=$(rails_root)

  if [ "$OPS_ENV_MODE" = template ]; then
    [ -f "$root/.env.tpl" ] || die "env_mode=template but no .env.tpl found in repo root."
    op_ inject -i "$root/.env.tpl" -o "$root/.env" -f
    info "  rendered: .env (from .env.tpl via op inject)"
    return
  fi

  local list_json
  list_json=$(op_guard item list --vault "$OPS_VAULT" --categories Document --format json)
  local rows
  rows=$(printf '%s' "$list_json" \
    | jq -r --arg p "env:${app}:" '.[] | select(.title | startswith($p)) | [.id, .title] | @tsv')
  [ -z "$rows" ] && die "No env documents for '$app' in vault '$OPS_VAULT'."

  local id title base tmp
  while IFS=$'\t' read -r id title; do
    base="${title#env:${app}:}"
    tmp=$(mktemp)
    op_guard document get "$id" --vault "$OPS_VAULT" --out-file "$tmp" --force >/dev/null
    write_secret_file "$root/$base" "$(cat "$tmp")"
    rm -f "$tmp"
  done <<<"$rows"
}

# ----------------------------------------------------------------------------- setup / link / status
self_path() { cd "$(dirname "${BASH_SOURCE[0]}")" && printf '%s/%s' "$PWD" "$(basename "${BASH_SOURCE[0]}")"; }

cmd_link() {
  local self; self=$(self_path)
  local dir
  for dir in "$HOME/bin" "$HOME/.local/bin"; do
    if [ -d "$dir" ]; then
      ln -sf "$self" "$dir/op-sync"
      info "linked: $dir/op-sync -> $self"
      case ":$PATH:" in *":$dir:"*) ;; *) info "  (note: $dir is not on your PATH)";; esac
      return
    fi
  done
  info "no ~/bin or ~/.local/bin found; run op-sync via: bash \"$self\""
}

cmd_setup() {
  local dir="${XDG_CONFIG_HOME:-$HOME/.config}/op-sync" cfg
  cfg="$dir/config"
  mkdir -p "$dir"
  if [ -f "$cfg" ]; then
    info "config already exists: $cfg"
  else
    cat > "$cfg" <<'EOF'
# op-sync configuration
# Which 1Password vault to store app secrets in.
vault=Private

# How .env files sync:
#   blob     — store each .env file whole, as a 1Password document (default)
#   template — render .env from a committed .env.tpl via `op inject`
env_mode=blob

# Optional: pin a 1Password account (shorthand or sign-in address).
# account=my.1password.com
EOF
    info "created config: $cfg"
  fi
  info "  vault=$OPS_VAULT  env_mode=$OPS_ENV_MODE  account=${OPS_ACCOUNT:-<default>}"
  cmd_link
}

cmd_status() {
  local app; app=$(app_name)
  info "app:      $app  (vault '$OPS_VAULT', env_mode '$OPS_ENV_MODE')"
  info "rails keys (local):"
  local f; while IFS= read -r f; do [ -n "$f" ] && info "  $f"; done <<<"$(rails_key_files)"
  local item_json rc=0
  item_json=$(item_get_json "$app") || rc=$?
  case "$rc" in
    0)
      info "rails keys (stored fields):"
      printf '%s' "$item_json" \
        | jq -r '.fields[]? | select((.id // "")|endswith("_key")) | "  " + .id' || true;;
    1) info "rails keys (stored): none — item '$app' not found";;
    *) info "rails keys (stored): UNKNOWN — 1Password lookup failed (see error above)";;
  esac
  info ".env files (local):"
  while IFS= read -r f; do [ -n "$f" ] && info "  ${f##*/}"; done <<<"$(env_files)"
  info ".env documents (stored):"
  op_ item list --vault "$OPS_VAULT" --categories Document --format json \
    | jq -r --arg p "env:${app}:" '.[] | select(.title|startswith($p)) | "  " + .title' || true
}

usage() {
  # Print the header comment block: every line after the shebang up to the
  # first non-comment line. No hardcoded line numbers, so editing the header
  # can't spill code into the help text.
  awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "${BASH_SOURCE[0]}"
  exit "${1:-0}"
}

# ----------------------------------------------------------------------------- main
main() {
  load_config
  OP_GLOBAL=()
  [ -n "$OPS_ACCOUNT" ] && OP_GLOBAL=(--account "$OPS_ACCOUNT")
  FORCE=0
  local args=() a
  for a in "$@"; do case "$a" in --force|-f) FORCE=1;; *) args+=("$a");; esac; done
  set -- "${args[@]:-}"

  local group="${1:-}" action="${2:-}"
  case "$group" in
    setup)  cmd_setup;;
    link)   cmd_link;;
    status) require_rails_root; require_op; cmd_status;;
    rails-key)
      require_rails_root; require_op
      case "$action" in
        push) rails_key_push;;
        pull) rails_key_pull;;
        *) die "usage: op-sync rails-key {push|pull}";;
      esac;;
    env)
      require_rails_root; require_op
      case "$action" in
        push) env_push;;
        pull) env_pull;;
        *) die "usage: op-sync env {push|pull}";;
      esac;;
    ""|-h|--help|help) usage 0;;
    *) die "unknown command '$group' (try: op-sync help)";;
  esac
}

# Only run when executed directly, so the functions can be sourced for testing.
[ "${BASH_SOURCE[0]}" = "${0}" ] && main "$@"
