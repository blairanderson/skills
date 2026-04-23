---
name: rails-conductor-setup-config
description: "Use when: the user asks to set up Conductor, configure Conductor, add Conductor support, or says 'conductor setup' for a Rails project. Also trigger when the user mentions Conductor workspaces, CONDUCTOR_PORT, or conductor.json in the context of Rails app configuration."
version: 1.0.0
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: "/rails-setup-conductor-config"
---

# Rails Conductor Setup

Configure a Rails application to work with Conductor workspaces. Conductor gives each workspace its own port and file isolation — this skill sets up the scripts and config to make that work.

## Before you start

Read the project to understand what already exists:

1. Check if `conductor.json` exists at the project root
2. Check if `bin/conductor-setup` exists
3. Check if `script/server` exists (and what's in it)
4. Read `config/puma.rb` to understand the current setup
5. Check for `config/initializers/default_host.rb`
6. Check if `Procfile.dev` exists (needed by `script/server`)
7. Check if `script/bootstrap` exists (called by `bin/conductor-setup`)

Read `references/conductor-templates.md` for the complete reference templates.

## What to create or update

Work through each file below. For each one: read the existing file first, decide what needs to change, and make the smallest edit that gets the job done. Don't replace files that are already working — merge in the Conductor-specific parts.

### 1. conductor.json (create if missing)

This tells Conductor which scripts to run. Create it at the project root if it doesn't exist. If it exists, check that it points to the right scripts and update if needed.

### 2. bin/conductor-setup (create if missing)

This runs when Conductor creates a new workspace. It symlinks `.env`, credentials, storage, and `.bundle` from the root repo. See the template in references.

After creating, run `chmod +x bin/conductor-setup`.

**Merge guidance**: If `bin/setup` already exists and does similar work, don't duplicate logic. The conductor-setup script should handle Conductor-specific symlinks and then delegate to the existing setup script (often `script/bootstrap` or `bin/setup`). Adapt the `script/bootstrap` call at the bottom of the template to match whatever setup script the project actually uses.

### 3. script/server (create if missing)

This starts the dev server with the correct port. The critical line is:
```bash
export PORT=${CONDUCTOR_PORT:-${PORT:-3000}}
```

After creating, run `chmod +x script/server`.

**Merge guidance**: If `script/server` or `bin/dev` already exists, add the `CONDUCTOR_PORT` line near the top rather than replacing the whole file. The project may have its own process manager setup (foreman, overmind, etc.) — keep that, just make sure PORT is set from CONDUCTOR_PORT.

### 4. config/initializers/default_host.rb (create or merge)

This makes Rails URL generation, mailer links, and asset hosts respect the dynamic PORT. Without this, links in emails and redirects will point to the wrong port.

**Merge guidance**: If this initializer already exists, check whether it already reads `ENV["PORT"]`. If so, it may just need minor tweaks. If the project uses a different host configuration pattern, adapt rather than replace.

### 5. config/puma.rb (merge, don't replace)

The existing puma.rb likely already works. The Conductor-specific bits to ensure are present:

- `port ENV['PORT'] || 3000` (reads PORT from environment)
- The `on_booted` block that prints the URL (nice to have, not critical)

**Merge guidance**: Read the existing file carefully. Most Rails puma configs already have `port ENV.fetch("PORT") { 3000 }` or similar — if so, no changes needed for the port line. Only add what's genuinely missing. Don't change thread counts, worker counts, or other tuning the project already has.

### 6. Verify supporting files exist

- `Procfile.dev` — needed if `script/server` uses foreman. If it doesn't exist and the project uses a different process manager, adapt `script/server` accordingly.
- `script/bootstrap` or `bin/setup` — called by `bin/conductor-setup`. Make sure the reference in the setup script points to whichever one the project actually has.

## After setup

Tell the user:
1. Which files were created vs modified
2. Any manual steps needed (e.g., "You'll need a `.env` file at your repo root")
3. Remind them to test in Conductor: create a workspace and verify the app boots on the assigned port
4. If `script/bootstrap` doesn't exist and there's no equivalent, flag that — the setup script needs something to call for dependency installation

## Things to watch out for

- **Don't break existing setups.** If the app already runs fine outside Conductor, it should still work after these changes. The `CONDUCTOR_PORT` fallback chain (`CONDUCTOR_PORT -> PORT -> 3000`) ensures backward compatibility.
- **Credential files are copied, not symlinked.** This is intentional — Rails credential files can have issues with symlinks in some setups.
- **The `.bundle` symlink check is strict.** If `.bundle` exists as a real directory (not a symlink), the setup script errors out rather than silently overwriting. This prevents destroying local bundle config.
