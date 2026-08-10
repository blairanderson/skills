#!/usr/bin/env bash
# stakeholders.sh — deterministic per-project stakeholder config management.
#
# Config lives at <project-root>/.claude/stakeholders.json (project-scoped:
# different apps have different stakeholders).
#
# Usage:
#   stakeholders.sh get                                  # print config JSON (exit 3 if missing)
#   stakeholders.sh init --relationship coworkers|clients --email-cli gws|gog|olk [--tone "notes"]
#   stakeholders.sh add --name NAME --email EMAIL [--send-as to|cc]
#   stakeholders.sh remove --email EMAIL
#   stakeholders.sh recipients                           # emit "--to a@b.com --cc c@d.com" flags
#   stakeholders.sh email-cli [gws|gog|olk]              # get (no arg) or set the sending CLI
#   stakeholders.sh check                                # validate config shape (exit 4 on invalid)
#
# Env:
#   STAKEHOLDERS_FILE — override config path (default: ./.claude/stakeholders.json)

set -euo pipefail

CONFIG_FILE="${STAKEHOLDERS_FILE:-.claude/stakeholders.json}"

die() { echo "stakeholders: $*" >&2; exit 1; }
need_jq() { command -v jq >/dev/null || die "jq is required"; }

cmd="${1:-}"
shift || true

require_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "stakeholders: no config at $CONFIG_FILE (run: stakeholders.sh init)" >&2
    exit 3
  fi
}

case "$cmd" in
  get)
    require_config
    cat "$CONFIG_FILE"
    ;;

  init)
    need_jq
    relationship=""
    tone=""
    email_cli=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --relationship) relationship="${2:-}"; shift 2 ;;
        --tone) tone="${2:-}"; shift 2 ;;
        --email-cli) email_cli="${2:-}"; shift 2 ;;
        *) die "init: unknown flag $1" ;;
      esac
    done
    case "$relationship" in
      coworkers|clients) ;;
      *) die "init: --relationship must be 'coworkers' or 'clients'" ;;
    esac
    case "$email_cli" in
      gws|gog|olk) ;;
      *) die "init: --email-cli must be 'gws', 'gog', or 'olk'" ;;
    esac
    [ -f "$CONFIG_FILE" ] && die "init: $CONFIG_FILE already exists (edit it or remove it first)"
    mkdir -p "$(dirname "$CONFIG_FILE")"
    jq -n --arg rel "$relationship" --arg tone "$tone" --arg cli "$email_cli" \
      '{relationship: $rel, tone: $tone, email_cli: $cli, stakeholders: []}' > "$CONFIG_FILE"
    echo "stakeholders: created $CONFIG_FILE (relationship=$relationship, email_cli=$email_cli)"
    ;;

  add)
    need_jq
    require_config
    name=""
    email=""
    send_as="to"
    while [ $# -gt 0 ]; do
      case "$1" in
        --name) name="${2:-}"; shift 2 ;;
        --email) email="${2:-}"; shift 2 ;;
        --send-as) send_as="${2:-}"; shift 2 ;;
        *) die "add: unknown flag $1" ;;
      esac
    done
    [ -n "$name" ] || die "add: --name is required"
    printf '%s' "$email" | grep -qE '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' || die "add: --email '$email' is not a valid email"
    case "$send_as" in
      to|cc) ;;
      *) die "add: --send-as must be 'to' or 'cc'" ;;
    esac
    if jq -e --arg e "$email" '.stakeholders[] | select(.email == $e)' "$CONFIG_FILE" >/dev/null; then
      die "add: $email already exists in $CONFIG_FILE"
    fi
    tmp="$(mktemp)"
    jq --arg n "$name" --arg e "$email" --arg s "$send_as" \
      '.stakeholders += [{name: $n, email: $e, send_as: $s}]' "$CONFIG_FILE" > "$tmp"
    mv "$tmp" "$CONFIG_FILE"
    echo "stakeholders: added $name <$email> ($send_as)"
    ;;

  remove)
    need_jq
    require_config
    email=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --email) email="${2:-}"; shift 2 ;;
        *) die "remove: unknown flag $1" ;;
      esac
    done
    [ -n "$email" ] || die "remove: --email is required"
    jq -e --arg e "$email" '.stakeholders[] | select(.email == $e)' "$CONFIG_FILE" >/dev/null || die "remove: $email not found"
    tmp="$(mktemp)"
    jq --arg e "$email" '.stakeholders |= map(select(.email != $e))' "$CONFIG_FILE" > "$tmp"
    mv "$tmp" "$CONFIG_FILE"
    echo "stakeholders: removed $email"
    ;;

  recipients)
    need_jq
    require_config
    count="$(jq '.stakeholders | length' "$CONFIG_FILE")"
    [ "$count" -gt 0 ] || die "recipients: no stakeholders configured (run: stakeholders.sh add)"
    jq -r '[.stakeholders[] | if .send_as == "cc" then "--cc \(.email)" else "--to \(.email)" end] | join(" ")' "$CONFIG_FILE"
    ;;

  email-cli)
    need_jq
    require_config
    value="${1:-}"
    if [ -z "$value" ]; then
      cli="$(jq -r '.email_cli // empty' "$CONFIG_FILE")"
      [ -n "$cli" ] || die "email-cli: not set in $CONFIG_FILE (run: stakeholders.sh email-cli gws|gog|olk)"
      echo "$cli"
    else
      case "$value" in
        gws|gog|olk) ;;
        *) die "email-cli: must be 'gws', 'gog', or 'olk'" ;;
      esac
      tmp="$(mktemp)"
      jq --arg cli "$value" '.email_cli = $cli' "$CONFIG_FILE" > "$tmp"
      mv "$tmp" "$CONFIG_FILE"
      echo "stakeholders: email_cli set to $value"
    fi
    ;;

  check)
    need_jq
    require_config
    errors=""
    jq -e 'has("relationship") and has("stakeholders")' "$CONFIG_FILE" >/dev/null 2>&1 || errors="missing relationship/stakeholders keys"
    if [ -z "$errors" ]; then
      rel="$(jq -r '.relationship' "$CONFIG_FILE")"
      case "$rel" in
        coworkers|clients) ;;
        *) errors="relationship '$rel' must be coworkers or clients" ;;
      esac
    fi
    if [ -z "$errors" ]; then
      cli="$(jq -r '.email_cli // empty' "$CONFIG_FILE")"
      case "$cli" in
        gws|gog|olk) ;;
        *) errors="email_cli '${cli:-MISSING}' must be gws, gog, or olk" ;;
      esac
    fi
    if [ -z "$errors" ]; then
      bad="$(jq -r '[.stakeholders[] | select((.email // "" | test("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")) | not) | .name // "?"] | join(", ")' "$CONFIG_FILE")"
      [ -z "$bad" ] || errors="invalid email for: $bad"
    fi
    if [ -n "$errors" ]; then
      echo "stakeholders: check FAILED: $errors" >&2
      exit 4
    fi
    echo "stakeholders: check OK ($(jq -r '.stakeholders | length' "$CONFIG_FILE") stakeholders, relationship=$(jq -r '.relationship' "$CONFIG_FILE"), email_cli=$(jq -r '.email_cli' "$CONFIG_FILE"))"
    ;;

  *)
    die "unknown command '${cmd}' (get|init|add|remove|recipients|email-cli|check)"
    ;;
esac
