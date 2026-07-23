---
name: sync
description: "Use when: the user wants to share, sync, back up, or restore a Rails app's master.key / config/credentials/*.key or its .env files between machines using 1Password; or says 'op-sync', 'store this master key in 1Password', 'get the master key for this app', 'pull the env file', 'my key is missing after cloning', 'set up 1Password for this repo'. Stores each app's keys as one Secure Note and each .env as a 1Password document, keyed by the git remote name so it's identical on every machine."
allowed-tools: Bash, Read
version: 1.0.0
argument-hint: "rails-key push|pull, env push|pull, setup, status"
---

# op-sync — share Rails keys & .env files across machines via 1Password

Wraps a deterministic script (`scripts/op-sync.sh`). The script does all the
`op` work; this skill just picks the right subcommand and reports the result.

## The script

Prefer the installed CLI if present, else call it by absolute path:

```sh
op-sync <cmd>                                   # after `op-sync setup` installs the symlink
bash "${CLAUDE_PLUGIN_ROOT}/skills/sync/scripts/op-sync.sh" <cmd>   # always works
```

Run it from the **root of the target Rails app** — the directory holding
`config/application.rb`. The app name is derived from
`git config remote.origin.url`, so every machine agrees on the name.

`status`, `rails-key`, and `env` refuse to run anywhere else, exiting with
`Sorry must be inside Rails app root`. That covers a subdirectory of the app as
well as any non-Rails directory. If you hit it, `cd` to the app root and retry —
do not try to work around it. (`setup` and `link` are machine-scoped and work
from anywhere.)

## Preflight (always)

1. Confirm `op` is installed: `command -v op`. Do **not** gate on `op whoami` —
   with 1Password desktop-app integration there is no persistent session, so
   `op whoami` reports "not signed in" even when reads/writes work fine. The
   script authenticates on demand when it runs the real command; if the user
   truly isn't authorized, op's own error surfaces with a hint. Never try to
   sign them in for them.
2. Confirm the cwd is the Rails app root (`test -f config/application.rb`). If
   it isn't, `cd` there first — the script will refuse otherwise.
3. Confirm the cwd is a git repo with a remote (`git remote -v`). If there's no
   remote, the app name falls back to the directory basename — mention this so
   the user knows the name won't match a differently-named clone.

## Commands

| User intent | Run |
|---|---|
| First-time setup on a machine | `op-sync setup` (writes `~/.config/op-sync/config`, installs `~/bin/op-sync`) |
| Store this app's key files | `op-sync rails-key push` |
| Restore key files after cloning | `op-sync rails-key pull` |
| Store `.env` file(s) | `op-sync env push` |
| Restore `.env` file(s) | `op-sync env pull` |
| See what's local vs. stored | `op-sync status` |

Add `--force` to a `pull` only when the user explicitly wants to overwrite a
local file that differs from what's in 1Password (a timestamped `.bak` is made
first). By default, differing files are kept and reported.

## Config (why nothing is hardcoded)

Resolution order, later wins:
`built-in defaults` → `~/.config/op-sync/config` → `<repo>/.op-sync` → env vars
(`OP_SYNC_VAULT`, `OP_SYNC_ENV_MODE`, `OP_SYNC_ACCOUNT`).

- `vault` (default **Private**) — which 1Password vault holds the secrets. Point
  a specific repo at a shared team vault by committing a `<repo>/.op-sync` with
  `vault=Shared`.
- `env_mode` (default **blob**) — `blob` stores each `.env` whole as a document;
  `template` renders `.env` from a committed `.env.tpl` via `op inject` (in that
  mode, `env push` is a no-op — you commit the template instead).

## Storage model (so the user can find things in the 1Password app)

- **Rails keys** → one **Secure Note** titled `<app>`, one concealed field per
  key file: `config/master.key` → `master_key`, `config/credentials/<env>.key`
  → `<env>_key`. Read one directly anywhere:
  `op read "op://Private/<app>/master_key"`.
- **.env files** (blob mode) → one **Document** per file, titled
  `env:<app>:<filename>` (e.g. `env:my-app:.env`). `.env.example`, `.sample`,
  `.tpl`, `.template`, `.dist`, and `*.bak.*` are never pushed.

## Notes & gotchas

- The script never prints secret values (except `status`, which prints only
  field/document names). Key values are sent to `op` on **stdin**, never in argv.
- Restored files are written `chmod 600`.
- `rails-key pull` writes `config/master.key` and `config/credentials/<env>.key`
  from whatever `*_key` fields exist on the item — it does not invent keys.
- If `op item get` reports multiple matches for `<app>`, the vault has two items
  with that title; tell the user to rename or scope the vault, don't guess.
