# Resolver triggers — ssh-tailscale-mesh

Phrases users actually type that should route here (mirror of the `description`
in SKILL.md; kept in sync by `tests/resolver-trigger.sh`):

- "set up passwordless SSH between my machines"
- "make ssh passwordless everywhere"
- "why does ssh keep asking for a password"
- "too many authentication failures"
- "add this new server to my tailscale mesh" / "onboard a server"
- "sync my ~/.ssh/config across machines"
- "test my ssh mesh"
- "set up SSH keys across my machines"
- "run ssh-copy-id to all my boxes"
- wants consistent host aliases (air / mini / …) identical from every machine

## MECE — how this differs from sibling skills

- `ts-sync:sync` — copies a Rails app's **secrets** (master.key / .env) between machines
  over SSH. It *consumes* SSH connectivity; it does not set up the SSH mesh. No overlap.
- `op:sync` — stores/retrieves **secrets** via 1Password. Unrelated to SSH connectivity.
- This skill owns: SSH key distribution, `~/.ssh/config` host aliases, Tailscale host
  onboarding, and passwordless-mesh verification. It is the only skill that wires SSH
  auth itself.
