---
name: sync
description: "Use when: the user wants to copy a Rails app's master.key / config/credentials/*.key or .env files between their own machines over SSH/Tailscale; or says 'ts-sync', 'pull my env from my other machine', 'grab the master key from my desktop over tailscale', 'my .env is on my laptop', 'push these secrets to my mac mini', 'sync secrets between machines over ssh'. Assumes the repo is cloned at the same absolute path on both machines; lists remote files first, then transfers via ssh/tar with diff-guards, backups, and chmod 600."
allowed-tools: Bash, Read
version: 1.0.0
argument-hint: "hosts, list [host], pull [host], push [host], status, setup"
---

# ts-sync — pull/push Rails keys & .env files between your machines over SSH/Tailscale

Wraps a deterministic script (`scripts/ts-sync.sh`). The script does all the
ssh/tar work; this skill picks the right subcommand, shows the user what will
move **before** anything transfers, and reports the result.

ts-sync is a thin **teaching wrapper around `ssh`/`scp`**. When the agent can
run a step, it runs it; when it can't (see _When SSH auth fails_), it shows the
user the equivalent raw `ssh`/`scp` command to paste into their own terminal —
so the user learns the underlying tool, not just the wrapper.

## The script

Prefer the installed CLI if present, else call it by absolute path:

```sh
ts-sync <cmd>                                    # after `ts-sync setup` installs the symlink
bash "${CLAUDE_PLUGIN_ROOT}/skills/sync/scripts/ts-sync.sh" <cmd>   # always works
```

Run it from **inside the target app's repo**. The core assumption: the repo is
cloned at the **same absolute path on every machine** (e.g. `~/dev/my-app`
everywhere). If the remote doesn't have that path, the script fails with a
clear message — tell the user to clone the repo there first.

## Preflight (always)

1. Confirm the cwd is a git repo (`git rev-parse --show-toplevel`).
2. **Check what's actually missing locally first.** Before any network call,
   run `ts-sync status` and compare against the app's expected secrets
   (`.env`, `config/master.key`, `config/credentials/*.key`). If the file the
   user needs is already present, say so and stop — no sync required. Only the
   *missing* files justify a pull; report the gap explicitly, e.g.
   "missing locally: .env — everything else present."
3. The script verifies ssh reachability (`BatchMode` — it never hangs on a
   password prompt). If ssh fails, **don't try to fix auth silently — follow
   _When SSH auth fails_ below** and hand the user the underlying `ssh`/`scp`
   command to run themselves.

## The pull flow (ALWAYS in this order)

1. **Resolve the host.** If the user named a machine or one is configured
   (`ts-sync status` shows it), confirm it. Otherwise run `ts-sync hosts` to
   list online Tailscale peers and ask the user which machine has the files.
2. **`ts-sync list <host>`** — one ssh call, hashes only, no content moves.
   **Show the user the resulting file table** (`same` / `DIFFERS` /
   `remote only` / `local only`) before transferring anything.
3. Once the user confirms, run **`ts-sync pull <host>`**.
4. Report the per-file results (`wrote` / `unchanged` / `DIFFERS, kept`).

Only add `--force` when the user explicitly wants to overwrite a local file
that differs from the remote (a timestamped `.bak` is made first). By default,
differing files are kept and reported.

## The push flow

Same shape, reversed: `ts-sync list <host>` → show the table → `ts-sync push
<host>`. The same diff-guards run **on the remote** — a differing remote file
is kept unless `--force`, and remote backups/`chmod 600` apply there too.

## When SSH auth fails (the copy-paste fallback)

The agent's Bash tool runs in a **non-interactive shell with no TTY**, and the
script forces `BatchMode=yes`. So if the remote needs a password — or the right
key isn't loaded in an agent this shell can reach — every `list`/`pull`/`push`
fails with "Permission denied" or "Too many authentication failures", and
**there is no way to type a password through the agent.** Do not keep retrying,
and never collect a password with a prompt tool (it would land in plaintext in
the transcript).

Instead, since ts-sync is a teaching wrapper, hand the user the exact command to
paste into *their own* terminal (where their TTY and ssh-agent work), and stop:

    # run this in YOUR terminal, then tell me when it's done:
    cd <repo-root>
    ts-sync pull <host>                          # the wrapper, or the raw equivalent:
    scp <host>:<repo-root>/.env <repo-root>/.env # plain scp does the same transfer

Then offer the durable fix so it never recurs — this also makes the agent's own
shell able to auth next time (key auth works from every shell, TTY or not):

    ssh-copy-id -i ~/.ssh/id_ed25519.pub <host>  # one-time; enables key auth

After key auth is set up, `ts-sync` (and plain `scp`) work directly from the
agent — no copy-paste needed. If key auth already works in the user's terminal
but not here, the key is loaded in their interactive agent only; `ssh-add
~/.ssh/id_ed25519` re-loads it into the shared macOS launchd agent this shell
also sees.

## Commands

| User intent | Run |
|---|---|
| First-time setup on a machine | `ts-sync setup` (writes `~/.config/ts-sync/config`, installs `~/bin/ts-sync`) |
| Which machines can I sync with? | `ts-sync hosts` |
| What would move? (confirm step) | `ts-sync list [host]` |
| Get this app's secrets from another machine | `ts-sync pull [host]` |
| Send this app's secrets to another machine | `ts-sync push [host]` |
| See config + local secret files (no network) | `ts-sync status` |

## Config (why nothing is hardcoded)

Resolution order, later wins:
`built-in defaults` → `~/.config/ts-sync/config` → `<repo>/.ts-sync` → env vars
(`TS_SYNC_HOST`, `TS_SYNC_USER`).

- `host` — default ssh target: a Tailscale MagicDNS name, hostname, IP, or
  `~/.ssh/config` alias. A positional `[host]` argument always wins.
- `user` — optional ssh username, for machines with different usernames.

## Notes & gotchas

- **Same-path model**: `pull`/`push`/`list` all key off the local repo root and
  expect it verbatim on the remote. The "clone the repo there first" error
  means exactly that.
- Files synced: `config/master.key`, `config/credentials/*.key`, `.env`,
  `.env.*` — excluding `.example`, `.sample`, `.tpl`, `.template`, `.dist`,
  and `*.bak.*`.
- Secrets never appear in argv (file contents travel on the ssh/tar stream);
  transferred files land `chmod 600`; staging dirs are user-only (0700).
- The tailscale CLI is optional: `hosts` needs it (plus `jq`), but
  `list`/`pull`/`push` work with any ssh-reachable host.
- ssh runs with `BatchMode=yes` — it will never prompt for a password. If auth
  fails, the user needs Tailscale SSH enabled or ssh keys set up.
- **You cannot type an SSH password through the agent.** No TTY + hardcoded
  `BatchMode=yes` means password / keyboard-interactive auth is impossible from
  the agent's shell, and a prompt tool would leak the password into the
  transcript. Supported paths are key-based: (1) `ssh-copy-id` once (best —
  passwordless everywhere), or (2) `ssh-add ~/.ssh/id_ed25519` in the user's
  terminal to load the key into the shared macOS launchd agent this shell also
  sees. Anything password-only must run in the user's own terminal — hand them
  the raw `ssh`/`scp` command (see _When SSH auth fails_).
