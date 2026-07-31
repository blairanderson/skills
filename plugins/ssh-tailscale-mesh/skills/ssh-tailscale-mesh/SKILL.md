---
name: ssh-tailscale-mesh
version: 1.0.0
description: >-
  Set up and maintain a passwordless SSH mesh across your machines on a Tailscale
  network, and onboard new servers into it. Use when: the user wants passwordless
  SSH between their machines, says "set up SSH keys across my machines", "why does
  ssh keep asking for a password", "too many authentication failures", "add this
  new server to my tailscale mesh", "make ssh passwordless everywhere", "sync my
  ~/.ssh/config across machines", "test my ssh mesh", "onboard a server", or wants
  consistent host aliases (air/mini/etc.) that work identically from every machine.
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# ssh-tailscale-mesh

Wire N machines on a Tailscale tailnet into a **full passwordless SSH mesh** with
**identical `~/.ssh/config` host aliases** everywhere, and keep it that way as new
servers join.

## Core idea — the hub/courier trick

You almost always have **one machine you work from** (the *hub*) that already
reaches the others passwordlessly. Installing a key is nothing more than appending
one line to a target's `~/.ssh/authorized_keys`. So the hub can act as a **courier**:
read each machine's public key, append it to whichever machines need it — wiring
edges that don't exist yet, **without a single password on the remotes**.

This is why you never have to walk over to each server and run `ssh-copy-id`:
`ssh-copy-id` only needs a password because it originates *from* a machine that
lacks access. Route through the hub instead and passwords never come up.

## Contract

A mesh is "done" when:

- Every machine can `ssh <alias>` every other machine passwordlessly (full matrix green).
- Every machine has the **same** `Host` aliases in `~/.ssh/config`, each pinned with
  `IdentityFile ~/.ssh/id_ed25519` + `IdentitiesOnly yes`.
- Each machine keeps its **own** private key (never copy private keys between machines;
  only public keys move, into `authorized_keys`).
- All edits are idempotent — re-running changes nothing.

## Phases

### Phase 1 — Discover
```bash
scripts/mesh.sh discover          # parse `tailscale status` -> ip / host / owner / os
```
Pick the machines to include. Note the **Tailscale hostname** (the 2nd column) — that
is the `HostName` you SSH to, e.g. `blairs-mac-mini`.

### Phase 2 — Confirm the two gotchas (do this BEFORE writing config)
1. **Username.** The macOS/Linux login user is NOT the Tailscale owner email. Verify
   with a plain `ssh <hostname>` (defaults to your *local* username) and read the
   prompt: `blairanderson@host` is the real user, not `blair@`. Put the real login
   user in `User`.
2. **Reachability.** `tailscale status` should show the peer online; sshd/Remote Login
   must be enabled on the target (macOS: System Settings → General → Sharing → Remote
   Login = on, "Allow access for: All users").

### Phase 3 — Config aliases (identical everywhere)
```bash
scripts/mesh.sh config-add <alias> <hostname> <user>   # local ~/.ssh/config, deduped
scripts/mesh.sh config-sync <alias...>                 # push those stanzas to every alias
```
`config-sync` only appends stanzas that are missing on each target; it never touches
existing entries (GitHub, hatchbox, `Host *`, etc.). Back up remote configs first.

### Phase 4 — Wire the keys (courier)
```bash
scripts/mesh.sh courier <hub> <alias...>   # every machine's pubkey -> every other's authorized_keys
```
Requires the hub to already reach every alias passwordlessly (seed that with one
`ssh-copy-id <alias>` from the hub per machine if starting cold). Idempotent.

### Phase 5 — Verify
```bash
scripts/mesh.sh test <hub> <alias...>      # full directed reachability matrix
```
All off-diagonal cells must read `OK`. Any `FAIL` = that source's key is missing from
that target's `authorized_keys`; re-run `courier`.

### Onboarding a new server later
```bash
scripts/mesh.sh add-host <hub> <alias> <hostname> <user> <existing-alias...>
```
Generates a key on the new host if absent, adds+syncs the alias to every machine,
couriers keys across the whole set, and prints the verification matrix.

## Troubleshooting

- **`Too many authentication failures`** — ssh is offering too many keys before the
  password. Cause: no `IdentitiesOnly yes`, or an agent full of identities. Fix: the
  config stanzas here pin one key; for a one-off use
  `ssh -o IdentitiesOnly=yes -o PubkeyAuthentication=no -o PreferredAuthentications=password <host>`.
- **`Permission denied` right after typing a correct password** — wrong `User` (the
  username gotcha above), or macOS Remote Login restricted to specific users.
- **Key hygiene** — check age/comment with `ssh <alias> 'ssh-keygen -lf ~/.ssh/id_ed25519.pub'`.
  A stale comment (old employer email) is cosmetic and grants no access. Only *rotate*
  (new keypair) if you believe the private key leaked; remember a rotated key must also
  be re-added anywhere else it's used (e.g. GitHub).

## Anti-patterns

- Copying **private** keys between machines. Only public keys move.
- Walking to each server to run `ssh-copy-id` when a hub can courier it.
- Guessing `User` from the Tailscale owner email instead of the login user.
- Clobbering `~/.ssh/config` — always append deduped, preserve existing stanzas.

## Output Format

1. Discovery table (ip / host / user / os) and the chosen alias→host→user mapping.
2. What changed: config stanzas added, keys distributed (all deduped).
3. The final reachability matrix + a one-line "mesh: N/N machines fully connected".
