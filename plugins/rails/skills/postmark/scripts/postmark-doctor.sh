#!/usr/bin/env bash
#
# postmark-doctor.sh — check a Rails app's Postmark setup.
#
# Everything is read-only except `send`, which sends exactly one email.
#
#   ./postmark-doctor.sh app                    Audit Gemfile + config. No network.
#   ./postmark-doctor.sh dns example.com        Check DKIM / Return-Path / DMARC / MX.
#   ./postmark-doctor.sh api                    Verify the token, dump server settings.
#   ./postmark-doctor.sh send you@example.com   Send one test email.
#   ./postmark-doctor.sh inbound                POST a sample .eml to the local ingress.
#   ./postmark-doctor.sh all example.com        app + dns + api.
#
# Environment:
#   POSTMARK_SERVER_TOKEN         Server API Token.       api, send, inbound
#   POSTMARK_ACCOUNT_TOKEN        Account API Token.      dns (optional, gives exact DKIM host)
#   POSTMARK_FROM                 Verified From address.  send
#   RAILS_INBOUND_EMAIL_PASSWORD  Ingress password.       inbound (falls back to credentials)
#   APP_URL                       Default http://localhost:3000. inbound

set -uo pipefail

API="https://api.postmarkapp.com"

if [ -t 1 ]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[1m'; D=$'\033[2m'; N=$'\033[0m'
else
  R=""; G=""; Y=""; B=""; D=""; N=""
fi

PASS=0; WARN=0; FAIL=0

ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$1"; PASS=$((PASS+1)); }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$1"; WARN=$((WARN+1)); }
bad()  { printf '  %s✗%s %s\n' "$R" "$N" "$1"; FAIL=$((FAIL+1)); }
info() { printf '  %s·%s %s\n' "$D" "$N" "$1"; }
head_() { printf '\n%s%s%s\n' "$B" "$1" "$N"; }

need() {
  command -v "$1" >/dev/null 2>&1 || { printf '%sMissing required command: %s%s\n' "$R" "$1" "$N" >&2; exit 2; }
}

# Extract a top-level or nested key from JSON on stdin. Usage: jget Key [SubKey]
jget() {
  python3 -c '
import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for k in sys.argv[1:]:
    if isinstance(d, dict) and k in d:
        d = d[k]
    else:
        sys.exit(1)
print("" if d is None else d)
' "$@" 2>/dev/null
}

pm_get() {
  local path="$1" header="$2" token="$3"
  curl -sS --max-time 20 "$API$path" \
    -H "Accept: application/json" \
    -H "$header: $token"
}

# ---------------------------------------------------------------- app

cmd_app() {
  head_ "Rails app configuration"

  if [ ! -f config/application.rb ]; then
    bad "config/application.rb not found — run this from the Rails app root"
    return
  fi
  ok "Rails app root detected"

  # --- gem
  if grep -qE '^\s*gem\s+["'"'"']postmark-rails["'"'"']' Gemfile 2>/dev/null; then
    ok "postmark-rails is in the Gemfile"
  elif grep -q "postmark" Gemfile 2>/dev/null; then
    warn "Gemfile mentions postmark but not the postmark-rails gem"
  else
    bad "postmark-rails is not in the Gemfile"
  fi

  # --- delivery method
  # It may be set globally in config/application.rb or per environment. Both are
  # common; Postmark's own quick-start uses application.rb.
  head_ "Outbound"
  local envs global_dm=""
  envs=$(ls config/environments/*.rb 2>/dev/null)

  read_dm() { grep -oE 'delivery_method\s*=\s*:[a-z_]+' "$1" 2>/dev/null | tail -1 | grep -oE ':[a-z_]+$'; }

  global_dm=$(read_dm config/application.rb)
  if [ -n "$global_dm" ]; then
    if [ "$global_dm" = ":postmark" ]; then
      ok "config/application.rb: delivery_method = :postmark (applies to every environment)"
    else
      info "config/application.rb: delivery_method = $global_dm"
    fi
  fi

  local postmark_envs=""
  for f in $envs; do
    local env dm
    env=$(basename "$f" .rb)
    dm=$(read_dm "$f")
    [ -z "$dm" ] && dm="$global_dm"
    [ -z "$dm" ] && continue

    case "$dm" in
      :postmark)
        postmark_envs="$postmark_envs $env"
        [ -n "$(read_dm "$f")" ] && ok "$env: delivery_method = :postmark"
        ;;
      :test) ok "$env: delivery_method = :test" ;;
      :smtp)
        if grep -q "postmarkapp.com" "$f" config/application.rb 2>/dev/null; then
          warn "$env: SMTP to Postmark — send-time errors are invisible; prefer :postmark"
        else
          info "$env: delivery_method = :smtp (not Postmark)"
        fi
        ;;
      *) info "$env: delivery_method = $dm" ;;
    esac
  done

  if [ -z "$postmark_envs" ] && [ "$global_dm" != ":postmark" ]; then
    warn "No environment uses delivery_method = :postmark"
  fi

  # max_retries can live in application.rb or an environment file
  if grep -rq "max_retries" config/ 2>/dev/null; then
    ok "max_retries is configured"
  else
    warn "max_retries is not set anywhere — the gem default is 0, so one timeout drops the email"
  fi

  for env in $postmark_envs; do
    local f="config/environments/$env.rb"

    if grep -qE '^\s*config\.action_mailer\.raise_delivery_errors\s*=\s*false' "$f"; then
      bad "$env: raise_delivery_errors = false — every Postmark error is swallowed silently"
    elif grep -qE '^\s*config\.action_mailer\.raise_delivery_errors\s*=\s*true' "$f"; then
      ok "$env: raise_delivery_errors = true"
    else
      info "$env: raise_delivery_errors not set (framework default is true)"
    fi

    if grep -q "default_url_options" "$f"; then
      ok "$env: default_url_options set"
    else
      warn "$env: default_url_options not set — URL helpers in mail views will raise"
    fi
  done

  # --- token hygiene
  if grep -rqE 'postmark_settings.*["'"'"'][0-9a-f]{8}-[0-9a-f]{4}' config/ 2>/dev/null; then
    bad "A literal Postmark token looks hardcoded in config/ — move it to credentials or ENV"
  else
    ok "No hardcoded Postmark token found in config/"
  fi

  # --- message streams
  if [ -d app/mailers ]; then
    local mailers streamless=0
    mailers=$(grep -rl "def " app/mailers --include="*.rb" 2>/dev/null | grep -v application_mailer || true)
    for m in $mailers; do
      grep -q "message_stream" "$m" || { streamless=$((streamless+1)); info "no message_stream: $m"; }
    done
    if [ "$streamless" -eq 0 ] && [ -n "$mailers" ]; then
      ok "Every mailer sets message_stream"
    elif [ "$streamless" -gt 0 ]; then
      warn "$streamless mailer(s) never set message_stream — they fall back to the server default"
    fi
  fi

  # --- inbound
  head_ "Inbound (Action Mailbox)"
  if [ ! -d app/mailboxes ]; then
    info "No app/mailboxes — Action Mailbox is not installed. Skipping inbound checks."
    return
  fi
  ok "app/mailboxes exists"

  local ingress_envs=""
  for f in $envs; do
    grep -qE 'action_mailbox\.ingress\s*=\s*:postmark' "$f" && ingress_envs="$ingress_envs $(basename "$f" .rb)"
  done
  if [ -n "$ingress_envs" ]; then
    ok "ingress = :postmark in:$ingress_envs"
  else
    bad "config.action_mailbox.ingress = :postmark is not set in any environment — the ingress returns 404"
  fi

  if grep -rqE 'action_mailbox\.ingress\s*=\s*:(relay|mailgun|mandrill|sendgrid|qmail|exim|postfix)' config/environments/ 2>/dev/null; then
    warn "Another ingress is configured somewhere — only one can be active per environment"
  fi

  if [ -f app/mailboxes/application_mailbox.rb ]; then
    if grep -qE '^\s*routing' app/mailboxes/application_mailbox.rb; then
      ok "ApplicationMailbox has routes"
      if grep -qE 'routing\s*\(?\s*:all' app/mailboxes/application_mailbox.rb; then
        local last_all; last_all=$(grep -nE '^\s*routing' app/mailboxes/application_mailbox.rb | tail -1)
        if echo "$last_all" | grep -q ':all'; then
          ok "The :all backstop route is declared last"
        else
          bad "routing :all is not the last route — it swallows every route below it"
        fi
      else
        warn "No routing(:all => :backstop) — unroutable mail raises RoutingError in a background job"
      fi
    else
      bad "ApplicationMailbox has no routes — every inbound email will bounce"
    fi
  fi

  # mail.decoded on multipart
  if grep -rn "mail\.decoded" app/mailboxes/ >/dev/null 2>&1; then
    bad "mail.decoded is used in a mailbox — it raises NoMethodError on multipart mail"
    grep -rn "mail\.decoded" app/mailboxes/ | sed 's/^/      /'
  else
    ok "No bare mail.decoded in mailboxes"
  fi

  # active storage
  if grep -rqE 'active_storage\.service\s*=' config/environments/ 2>/dev/null; then
    ok "Active Storage service configured (required by Action Mailbox)"
  else
    warn "No config.active_storage.service found — Action Mailbox cannot store raw email"
  fi

  # queues
  if command -v bin/rails >/dev/null 2>&1 || [ -x bin/rails ]; then
    local queues
    queues=$(bin/rails runner 'print ActionMailbox.queues.inspect' 2>/dev/null)
    if [ -n "$queues" ]; then
      info "ActionMailbox.queues = $queues"
      case "$queues" in
        *nil*) info "nil means jobs go to the Active Job default queue — make sure a worker listens there" ;;
      esac
    fi
  fi
}

# ---------------------------------------------------------------- dns

dig_short() { dig +short "$@" 2>/dev/null | sed '/^$/d'; }

cmd_dns() {
  local domain="${1:-}"
  [ -z "$domain" ] && { echo "usage: $0 dns example.com" >&2; return 2; }
  need dig

  head_ "DNS for $domain"

  # Return-Path
  local rp; rp=$(dig_short "pm-bounces.$domain" CNAME | head -1)
  if [ "$rp" = "pm.mtasv.net." ] || [ "$rp" = "pm.mtasv.net" ]; then
    ok "Return-Path: pm-bounces.$domain CNAME pm.mtasv.net"
  elif [ -n "$rp" ]; then
    bad "Return-Path CNAME points at '$rp', expected pm.mtasv.net"
    case "$rp" in *"$domain"*) info "The zone name was appended — enter 'pm.mtasv.net.' with a trailing dot" ;; esac
  else
    warn "No pm-bounces.$domain CNAME — SPF will pass but will not align, weakening DMARC"

    # Only meaningful when there is no CNAME: `dig TXT` follows a CNAME and
    # returns the TARGET's TXT records, so this must match the owner name exactly.
    local rp_txt
    rp_txt=$(dig "pm-bounces.$domain" TXT +noall +answer 2>/dev/null \
      | awk -v n="pm-bounces.$domain." '$1 == n && $4 == "TXT"')
    if [ -n "$rp_txt" ]; then
      bad "A TXT record already exists at pm-bounces.$domain — you cannot add the CNAME until it is removed"
    fi
  fi

  # DMARC
  local dmarc; dmarc=$(dig_short "_dmarc.$domain" TXT | tr -d '"')
  if [ -n "$dmarc" ]; then
    ok "DMARC: $dmarc"
    case "$dmarc" in
      *"p=reject"*)     info "Policy is reject — every misaligned sender is blocked" ;;
      *"p=quarantine"*) info "Policy is quarantine" ;;
      *"p=none"*)       info "Policy is none (monitoring). Tighten once reports are clean." ;;
    esac
    case "$dmarc" in *rua=*) : ;; *) warn "No rua= tag — you receive no aggregate reports" ;; esac
  else
    warn "No DMARC record. Gmail and Yahoo bulk-sender rules expect at least p=none."
  fi

  # SPF (informational)
  local spf; spf=$(dig_short "$domain" TXT | tr -d '"' | grep "v=spf1" | head -1)
  if [ -n "$spf" ]; then
    info "Apex SPF: $spf"
    case "$spf" in
      *spf.mtasv.net*) info "Includes Postmark. Optional — Postmark does not require it." ;;
    esac
  else
    info "No apex SPF record. Postmark does not need one."
  fi

  # Inbound MX
  local mx_sub mx_root
  mx_sub=$(dig_short "inbound.$domain" MX)
  mx_root=$(dig_short "$domain" MX)
  if echo "$mx_sub" | grep -q "inbound.postmarkapp.com"; then
    ok "Inbound MX: inbound.$domain → $mx_sub"
  elif echo "$mx_root" | grep -q "inbound.postmarkapp.com"; then
    warn "The inbound MX is on the root domain — Postmark now receives ALL mail for $domain"
  else
    info "No Postmark inbound MX found (fine if you are not receiving, or if you forward to the hash address)"
    [ -n "$mx_root" ] && info "Root MX: $(echo "$mx_root" | tr '\n' ' ')"
  fi

  # DKIM — the selector is account-specific, so ask the API if we can
  head_ "DKIM"
  if [ -n "${POSTMARK_ACCOUNT_TOKEN:-}" ]; then
    local domains; domains=$(pm_get "/domains?count=200&offset=0" "X-Postmark-Account-Token" "$POSTMARK_ACCOUNT_TOKEN")
    local id
    id=$(printf '%s' "$domains" | python3 -c '
import json,sys
try: d = json.load(sys.stdin)
except Exception: sys.exit(1)
target = sys.argv[1].lower()
for x in d.get("Domains", []):
    if x.get("Name","").lower() == target:
        print(x["ID"]); break
' "$domain" 2>/dev/null)

    if [ -n "$id" ]; then
      local det; det=$(pm_get "/domains/$id" "X-Postmark-Account-Token" "$POSTMARK_ACCOUNT_TOKEN")
      local dkim_host dkim_verified rp_verified
      dkim_host=$(printf '%s' "$det" | jget DKIMHost)
      dkim_verified=$(printf '%s' "$det" | jget DKIMVerified)
      rp_verified=$(printf '%s' "$det" | jget ReturnPathDomainVerified)

      [ "$dkim_verified" = "True" ] && ok "Postmark reports DKIM verified" || bad "Postmark reports DKIM NOT verified"
      [ "$rp_verified"   = "True" ] && ok "Postmark reports Return-Path verified" || warn "Postmark reports Return-Path NOT verified"

      if [ -n "$dkim_host" ]; then
        info "DKIM host: $dkim_host"
        local live; live=$(dig_short "$dkim_host" TXT | head -c 60)
        [ -n "$live" ] && ok "DKIM TXT resolves: ${live}..." || bad "DKIM TXT does not resolve at $dkim_host"
      fi
    else
      warn "$domain is not registered as a Verified Domain in this Postmark account"
    fi
  else
    info "Set POSTMARK_ACCOUNT_TOKEN to check the exact DKIM selector and Postmark's verification state."
    info "The selector varies per domain: older ones use 'pm._domainkey', newer ones a timestamped"
    info "'<timestamp>pm._domainkey'. Read the exact host from Postmark's DNS Settings page."

    local guess; guess=$(dig_short "pm._domainkey.$domain" TXT | tr -d '"' | head -1)
    case "$guess" in
      "")            info "Nothing at pm._domainkey.$domain — this domain likely uses a timestamped selector" ;;
      *p=?*)         ok "DKIM key found at pm._domainkey.$domain" ;;
      *"p="*)        warn "pm._domainkey.$domain has an empty key (p= with no value) — that is a revoked or null record" ;;
      *)             info "pm._domainkey.$domain: $guess" ;;
    esac
  fi
}

# ---------------------------------------------------------------- api

cmd_api() {
  need curl; need python3
  [ -z "${POSTMARK_SERVER_TOKEN:-}" ] && { bad "POSTMARK_SERVER_TOKEN is not set"; return 1; }

  head_ "Postmark server"
  local body; body=$(pm_get "/server" "X-Postmark-Server-Token" "$POSTMARK_SERVER_TOKEN")

  if [ -z "$body" ]; then
    bad "No response from $API/server"
    return 1
  fi
  if printf '%s' "$body" | grep -q '"ErrorCode"'; then
    local code msg
    code=$(printf '%s' "$body" | jget ErrorCode)
    msg=$(printf '%s' "$body" | jget Message)
    bad "Postmark rejected the token (ErrorCode $code): $msg"
    info "Use the SERVER API Token (Server → API Tokens), not the Account Token."
    return 1
  fi

  ok "Server API Token is valid"

  local name delivery smtp
  name=$(printf '%s' "$body" | jget Name)
  delivery=$(printf '%s' "$body" | jget DeliveryType)
  smtp=$(printf '%s' "$body" | jget SmtpApiActivated)
  info "Name:         $name"
  info "DeliveryType: ${delivery:-Live}"
  [ "$smtp" = "True" ] && info "SMTP:         enabled" || info "SMTP:         disabled"

  head_ "Inbound settings"
  local addr hook raw indomain spam
  addr=$(printf '%s'     "$body" | jget InboundAddress)
  hook=$(printf '%s'     "$body" | jget InboundHookUrl)
  raw=$(printf '%s'      "$body" | jget RawEmailEnabled)
  indomain=$(printf '%s' "$body" | jget InboundDomain)
  spam=$(printf '%s'     "$body" | jget InboundSpamThreshold)

  [ -n "$addr" ] && info "Inbound address: $addr"

  if [ -n "$hook" ]; then
    ok "InboundHookUrl: $hook"
    case "$hook" in
      *"/rails/action_mailbox/postmark/inbound_emails") ok "URL path matches the Action Mailbox Postmark ingress" ;;
      *"/rails/action_mailbox/"*) bad "URL points at a different Action Mailbox ingress — the path must end in /postmark/inbound_emails" ;;
      *) warn "URL does not look like the Action Mailbox ingress path" ;;
    esac
    case "$hook" in
      "https://actionmailbox:"*) ok "Basic auth present with the correct username" ;;
      "https://"*"@"*)           bad "Basic auth present but the username is not 'actionmailbox'" ;;
      "http://"*)                bad "Webhook uses plain HTTP — the ingress password travels in cleartext" ;;
      *)                         bad "No Basic auth in the webhook URL — the ingress will answer 401" ;;
    esac
  else
    warn "No inbound webhook URL configured on this server"
  fi

  if [ "$raw" = "True" ]; then
    ok "RawEmailEnabled = true"
  else
    bad "RawEmailEnabled = false — tick 'Include raw email content in JSON payload' or the ingress 422s on every message"
  fi

  [ -n "$indomain" ] && info "InboundDomain: $indomain" || info "InboundDomain: (none — forward to the inbound address instead)"
  [ -n "$spam" ] && [ "$spam" != "0" ] && info "SpamAssassin threshold: $spam"

  head_ "Message streams"
  local streams; streams=$(pm_get "/message-streams" "X-Postmark-Server-Token" "$POSTMARK_SERVER_TOKEN")
  printf '%s' "$streams" | python3 -c '
import json,sys
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
for s in d.get("MessageStreams", []):
    print("  · %-14s %-14s %s" % (s.get("ID",""), s.get("MessageStreamType",""), s.get("Name","")))
' 2>/dev/null || info "Could not list message streams"
}

# ---------------------------------------------------------------- send

cmd_send() {
  need curl; need python3
  local to="${1:-test@blackhole.postmarkapp.com}"
  local from="${POSTMARK_FROM:-}"

  [ -z "${POSTMARK_SERVER_TOKEN:-}" ] && { bad "POSTMARK_SERVER_TOKEN is not set"; return 1; }
  [ -z "$from" ] && { bad "POSTMARK_FROM is not set — it must be a verified sender address"; return 1; }

  head_ "Sending one test email"
  info "From: $from"
  info "To:   $to"

  local payload resp
  payload=$(python3 -c '
import json,sys
print(json.dumps({
  "From": sys.argv[1],
  "To": sys.argv[2],
  "Subject": "postmark-doctor test",
  "TextBody": "Sent by postmark-doctor.sh to verify the Postmark configuration.",
  "MessageStream": "outbound",
  "Tag": "postmark-doctor"
}))' "$from" "$to")

  resp=$(curl -sS --max-time 30 "$API/email" -X POST \
    -H "Accept: application/json" -H "Content-Type: application/json" \
    -H "X-Postmark-Server-Token: $POSTMARK_SERVER_TOKEN" \
    -d "$payload")

  local code; code=$(printf '%s' "$resp" | jget ErrorCode)
  if [ "$code" = "0" ]; then
    ok "Accepted — MessageID $(printf '%s' "$resp" | jget MessageID)"
    info "Confirm it in the server's Activity tab."
  else
    bad "ErrorCode $code: $(printf '%s' "$resp" | jget Message)"
    case "$code" in
      300) info "Validation failed — check the From and To addresses." ;;
      400|401) info "The From address is not a confirmed Sender Signature and its domain is not verified." ;;
      405) info "Account out of credits." ;;
      406) info "The recipient is suppressed on this stream (hard bounce or spam complaint)." ;;
      412|413) info "Account is pending approval. Send to test@blackhole.postmarkapp.com meanwhile." ;;
      1235) info "That message stream does not exist on this server." ;;
    esac
    return 1
  fi
}

# ---------------------------------------------------------------- inbound

cmd_inbound() {
  need curl
  local url="${APP_URL:-http://localhost:3000}"
  local endpoint="$url/rails/action_mailbox/postmark/inbound_emails"
  local recipient="${1:-replies+doctor123@example.com}"

  head_ "Local Action Mailbox ingress"

  local pass="${RAILS_INBOUND_EMAIL_PASSWORD:-}"
  if [ -z "$pass" ] && [ -x bin/rails ]; then
    info "Reading the ingress password from Rails credentials..."
    pass=$(bin/rails runner 'print Rails.application.credentials.dig(:action_mailbox, :ingress_password).to_s' 2>/dev/null)
  fi
  if [ -z "$pass" ]; then
    bad "No ingress password. Set RAILS_INBOUND_EMAIL_PASSWORD or add action_mailbox.ingress_password to credentials."
    return 1
  fi
  ok "Ingress password found"

  local eml; eml=$(mktemp -t pmdoctor)
  cat > "$eml" <<EOF
From: Doctor <doctor@example.com>
To: $recipient
Subject: postmark-doctor inbound test
Date: Mon, 15 Jan 2024 12:00:00 -0500
Message-ID: <postmark-doctor-$$@example.com>
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="b1"

--b1
Content-Type: text/plain; charset=UTF-8

This is a multipart test message from postmark-doctor.sh.

--b1
Content-Type: text/html; charset=UTF-8

<p>This is a multipart test message from postmark-doctor.sh.</p>

--b1--
EOF

  info "POST $endpoint"
  info "Recipient: $recipient"

  local status
  status=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 30 \
    -u "actionmailbox:$pass" \
    -F "RawEmail=<$eml" \
    -F "OriginalRecipient=$recipient" \
    "$endpoint")

  rm -f "$eml"

  case "$status" in
    204)
      ok "204 — the email was recorded and enqueued for routing"
      info "Routing is asynchronous. Check the record and the job queue:"
      info "  bin/rails runner 'e = ActionMailbox::InboundEmail.last; puts [e.status, e.mail.recipients].inspect'"
      ;;
    401)
      bad "401 — Basic auth rejected. Credentials take priority over RAILS_INBOUND_EMAIL_PASSWORD."
      ;;
    404)
      bad "404 — config.action_mailbox.ingress is not :postmark in this environment."
      info "  Add: config.action_mailbox.ingress = :postmark"
      ;;
    422)
      bad "422 — RawEmail was rejected. In production this means the raw-email checkbox is unticked in Postmark."
      ;;
    500)
      bad "500 — blank ingress password, or Active Storage / Active Record / Active Job is unavailable."
      ;;
    000)
      bad "No response — is the app running at $url?"
      ;;
    *)
      bad "Unexpected status $status"
      ;;
  esac
}

# ---------------------------------------------------------------- main

summary() {
  printf '\n%s%d passed, %d warnings, %d failures%s\n' "$B" "$PASS" "$WARN" "$FAIL" "$N"
  [ "$FAIL" -gt 0 ] && return 1
  return 0
}

usage() {
  awk 'NR<3 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    app)     cmd_app "$@" ;;
    dns)     cmd_dns "$@" ;;
    api)     cmd_api "$@" ;;
    send)    cmd_send "$@" ;;
    inbound) cmd_inbound "$@" ;;
    all)
      cmd_app
      [ -n "${1:-}" ] && cmd_dns "$1"
      [ -n "${POSTMARK_SERVER_TOKEN:-}" ] && cmd_api || info "Set POSTMARK_SERVER_TOKEN to include the API check"
      ;;
    ""|-h|--help|help) usage; exit 0 ;;
    *) printf '%sUnknown command: %s%s\n\n' "$R" "$cmd" "$N" >&2; usage; exit 2 ;;
  esac

  summary
}

main "$@"
