# ts-sync — pull/push Rails keys & .env files between your machines over SSH/Tailscale

A Claude Code plugin that moves the secrets a Rails app needs — its
`config/master.key`, any `config/credentials/*.key`, and its `.env` files —
directly between your own machines over ssh. No vault, no up-front pushing:
if the files exist on any machine you can reach, you can pull them.

The model is deliberately simple: the repo is cloned at the **same absolute
path on every machine** (e.g. `~/dev/my-app` everywhere). ts-sync ssh-es over
(Tailscale MagicDNS names work great), runs the same file discovery on the
other side, shows you what would move, then transfers with tar over the ssh
stream. Secrets never appear in shell `argv`; transferred files land
`chmod 600`; a differing destination file is never overwritten without
`--force` (a timestamped `.bak` is made first).

## Install

```
/plugin marketplace add blairanderson/skills
/plugin install ts-sync@blairanderson-skills
```

Requires ssh access between your machines (Tailscale SSH or plain ssh keys).
The `tailscale` CLI and `jq` are only needed for the `hosts` command.

## Use

Run from inside the app's repo. The skill activates on requests like "pull my
env from my other machine" or "grab the master key from my desktop over
tailscale". Or call the script directly:

```sh
ts-sync setup              # write ~/.config/ts-sync/config + install ~/bin/ts-sync
ts-sync hosts              # list online Tailscale peers to pick from
ts-sync list  my-desktop   # compare local vs remote secret files (no transfer)
ts-sync pull  my-desktop   # fetch the remote's secret files into this repo
ts-sync push  my-desktop   # send this repo's secret files to the remote
ts-sync status             # config + local secret files (no network)
```

## Config (nothing is hardcoded)

Resolution order, later wins: built-in defaults → `~/.config/ts-sync/config` →
`<repo>/.ts-sync` → env vars (`TS_SYNC_HOST`, `TS_SYNC_USER`). See
`skills/sync/references/config.example`.

| Key | Default | Meaning |
|---|---|---|
| `host` | *(none)* | default ssh target — MagicDNS name, hostname, IP, or `~/.ssh/config` alias |
| `user` | *(ssh default)* | ssh username, if it differs between machines |

## What moves

`config/master.key`, `config/credentials/*.key`, `.env`, `.env.*` — excluding
`.example`, `.sample`, `.tpl`, `.template`, `.dist`, and `*.bak.*` backups.
Discovery runs identically on both ends (the same shell function is shipped
over ssh), so the two machines can never disagree about what counts.
