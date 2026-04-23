---
name: pgsync
description: "Use when: user wants to sync production Postgres data to local dev database, set up pgsync with an SSH tunnel to Hatchbox, or asks about pgsync-tunnel setup"
allowed-tools: Bash, Read, Write, Edit
argument-hint: "setup, sync users, sync group:core"
version: "1.0.0"
---

# Skill: pgsync-tunnel setup

## Purpose

Install `bin/pgsync-tunnel` on a Rails app so you can sync production Postgres data
to your local dev database through an SSH tunnel (no direct DB exposure required).
Designed for apps hosted on Hatchbox.io.

## What this skill creates

| File | Committed? | Purpose |
|---|---|---|
| `bin/pgsync-tunnel` | ✅ yes | SSH tunnel + pgsync wrapper script |
| `.pgsync.yml` | ✅ yes | Tables/groups to sync (no secrets) |
| `.env.pgsync.example` | ✅ yes | Template — committed so teammates know what's needed |
| `.env.pgsync` | ❌ gitignored | Real credentials — never committed |

---

## Step 1 — Prerequisites

Install `pgsync` on your machine:

```sh
gem install pgsync
```

Make sure your SSH config has an entry for the Hatchbox app server (e.g. `hatchbox`):

```
# ~/.ssh/config
Host hatchbox
  HostName <your-hatchbox-server-ip>
  User deploy
  IdentityFile ~/.ssh/id_rsa
```

Verify it works: `ssh hatchbox echo ok`

---

## Step 2 — Where to find Hatchbox credentials

1. Log in to [Hatchbox.io](https://hatchbox.io) → your app → **Databases** tab.
2. Find your PostgreSQL database and click **Show Connection Details** (or similar).
3. Copy the **Private Connection URI** — it looks like:
   `postgres://user_12345:password12345@10.0.1.2/myapp_production`
4. The `10.0.1.2` is `PGSYNC_REMOTE_HOST` (private IP, only reachable from the Hatchbox server).
5. The `user_12345`, `password12345`, and `myapp_production` go into `PGSYNC_FROM_URL`.

> **SSH host alias:** The SSH `Host` entry you use in `~/.ssh/config` becomes `PGSYNC_SSH_HOST`
> (default: `hatchbox`). Point it at your Hatchbox app server's **public** IP.

---

## Step 3 — Create the files

### `bin/pgsync-tunnel`

```bash
#!/usr/bin/env bash
# Opens an SSH tunnel to the Hatchbox server and runs pgsync, then tears the tunnel down.
# Usage: bin/pgsync-tunnel [pgsync args...]
#   bin/pgsync-tunnel                  # sync everything (per .pgsync.yml)
#   bin/pgsync-tunnel users            # one table
#   bin/pgsync-tunnel group:core       # a group from .pgsync.yml
set -euo pipefail

ENV_FILE="$(dirname "$0")/../.env.pgsync"
if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
else
  echo "Missing .env.pgsync — copy .env.pgsync.example and fill in values." >&2
  exit 1
fi

SSH_HOST="${PGSYNC_SSH_HOST:-hatchbox}"
LOCAL_PORT="${PGSYNC_LOCAL_PORT:-5433}"
REMOTE_HOST="${PGSYNC_REMOTE_HOST:-localhost}"
REMOTE_PORT="${PGSYNC_REMOTE_PORT:-5432}"

cat <<EOF
┌─────────────────────────────────────────────────────────────────────
│ Setting up SSH tunnel
│
│   Your laptop                Hatchbox app server          Postgres DB
│   ──────────────             ────────────────────         ────────────
│   localhost:${LOCAL_PORT}  ──SSH──▶  ${SSH_HOST} (jump)  ──▶  ${REMOTE_HOST}:${REMOTE_PORT}
│
│ Why: the prod DB (${REMOTE_HOST}) lives on Hatchbox's private
│ network — your laptop can't reach it directly. We SSH into
│ '${SSH_HOST}' (which CAN reach it) and tell SSH to forward
│ anything sent to localhost:${LOCAL_PORT} through that connection
│ to ${REMOTE_HOST}:${REMOTE_PORT} on the other side.
│
│ Result: pgsync connects to localhost:${LOCAL_PORT} as if it were
│ prod Postgres. SSH does the relay invisibly.
└─────────────────────────────────────────────────────────────────────
EOF

echo "→ Opening tunnel: ssh -f -N -L ${LOCAL_PORT}:${REMOTE_HOST}:${REMOTE_PORT} ${SSH_HOST}"
echo "   (-f = fork to background, -N = no shell, -L = local port forward)"
ssh -f -N -o ExitOnForwardFailure=yes -L "${LOCAL_PORT}:${REMOTE_HOST}:${REMOTE_PORT}" "$SSH_HOST"

SSH_PID=$(pgrep -f "ssh -f -N -o ExitOnForwardFailure=yes -L ${LOCAL_PORT}:" | head -1 || true)
echo "   Tunnel is live (background ssh pid ${SSH_PID:-?})"
trap '[[ -n "${SSH_PID:-}" ]] && kill "$SSH_PID" 2>/dev/null || true; echo "→ Tunnel closed (killed background ssh)"' EXIT

echo ""
echo "→ Running pgsync — it connects to localhost:${LOCAL_PORT} (the tunnel entrance)"
echo "   pgsync --from <prod via tunnel> --to <local dev> --defer-constraints $*"
# --defer-constraints avoids FK ordering errors + truncate deadlocks during parallel sync
pgsync --from "$PGSYNC_FROM_URL" --to "$PGSYNC_TO_URL" --defer-constraints "$@"
```

Make it executable:

```sh
chmod +x bin/pgsync-tunnel
```

---

### `.env.pgsync.example`

```sh
# Copy to .env.pgsync and fill in real values. .env.pgsync is gitignored.
#
# Private IP of the Hatchbox Postgres server (from Hatchbox "Private Connection URI").
PGSYNC_REMOTE_HOST=10.0.1.1
#
# Local tunneled URL — host/port MUST stay localhost:5433 (bin/pgsync-tunnel forwards that).
# Use the real user/password/dbname from the Hatchbox Private Connection URI.
PGSYNC_FROM_URL=postgres://user_12345:password12345@localhost:5433/myapp_production
#
# Destination = your local dev DB
PGSYNC_TO_URL=postgres://localhost/myapp_development
```

---

### `.pgsync.yml`

Customize the exclude/groups lists for your app's tables.

```yaml
# from/to URLs are passed as CLI flags by bin/pgsync-tunnel (from .env.pgsync)

exclude:
  - ar_internal_metadata
  - schema_migrations
  - solid_queue_*
  - solid_cache_entries
  - solid_cable_messages
  - sessions

groups:
  core:
    - users
    - products
    # add your app's key tables here
```

---

### `.gitignore`

Add these lines (the `!` keeps the example committed):

```
/.env*
!/.env.pgsync.example
```

---

## Step 4 — Fill in `.env.pgsync`

```sh
cp .env.pgsync.example .env.pgsync
# then edit .env.pgsync with real values from Hatchbox
```

---

## Step 5 — Run it

```sh
# Sync everything defined in .pgsync.yml
bin/pgsync-tunnel

# Sync one table
bin/pgsync-tunnel users

# Sync a named group
bin/pgsync-tunnel group:core
```

The tunnel opens, pgsync runs, and the tunnel closes automatically when done.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Missing .env.pgsync` | `cp .env.pgsync.example .env.pgsync` and fill in values |
| SSH connection refused | Check `~/.ssh/config` Host entry and Hatchbox server IP |
| `bind: Address already in use` | Another tunnel on port 5433 — `pkill -f "ssh -f -N"` to clear it |
| FK constraint errors | Already handled by `--defer-constraints`; if persists, try syncing tables individually |
| Wrong database synced | Double-check `PGSYNC_FROM_URL` dbname matches Hatchbox "Private Connection URI" |
