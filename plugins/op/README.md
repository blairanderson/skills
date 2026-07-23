# op — share Rails keys & .env files across machines via 1Password

A Claude Code plugin that keeps the secrets a Rails app needs — its
`config/master.key`, any `config/credentials/*.key`, and its `.env` files — in
1Password, so a fresh clone on another machine can restore them in one command.

Everything is keyed by the git remote name, so every machine that clones the
repo agrees on where the secrets live. No secret values ever appear in shell
`argv` (they travel to `op` on stdin); restored files are written `chmod 600`.

## Install

```
/plugin marketplace add blairanderson/skills
/plugin install op@blairanderson-skills
```

Requires the 1Password CLI: `brew install 1password-cli`, then unlock the app
(CLI integration) or `eval $(op signin)`.

## Use

Run from inside a Rails app. The skill activates on requests like "store this
master key in 1Password", "pull the env file", or "my key is missing after
cloning". Or call the script directly:

```sh
op-sync setup              # write ~/.config/op-sync/config + install ~/bin/op-sync
op-sync rails-key push     # store config/master.key + config/credentials/*.key
op-sync rails-key pull     # restore them on another machine
op-sync env push           # store .env files (blob mode)
op-sync env pull           # restore them
op-sync status             # show what's local vs. stored for this app
```

Read a single key anywhere without the script:

```sh
op read "op://Private/<app>/master_key"
```

## Config (nothing is hardcoded)

Resolution order, later wins: built-in defaults → `~/.config/op-sync/config` →
`<repo>/.op-sync` → env vars (`OP_SYNC_VAULT`, `OP_SYNC_ENV_MODE`,
`OP_SYNC_ACCOUNT`). See `skills/sync/references/config.example`.

| Key | Default | Meaning |
|---|---|---|
| `vault` | `Private` | 1Password vault the secrets live in |
| `env_mode` | `blob` | `blob` = whole `.env` as a document; `template` = render `.env` from a committed `.env.tpl` via `op inject` |
| `account` | *(default)* | pin a specific 1Password account |

## Where things land in 1Password

- **Rails keys** → one Secure Note titled `<app>` with a concealed field per
  key file (`master_key`, `<env>_key`).
- **.env files** (blob mode) → one Document per file titled `env:<app>:<name>`.
  `.env.example`, `.sample`, `.tpl`, `.template`, `.dist`, and `*.bak.*` are
  never pushed.
