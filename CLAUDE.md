# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

This is the **blairanderson/skills** Claude Code marketplace — a collection of installable plugins (skills) for Claude Code. It is NOT an application. There is no build step, no test suite, no package manager. The repo is pure markdown, JSON, and a few bash scripts.

Users install skills via:
```shell
/plugin marketplace add blairanderson/skills
/plugin install @blairanderson-skills/<plugin-name>
```

## Repository Layout

```
.claude-plugin/marketplace.json   ← Central marketplace manifest (version + plugin registry)
.claude/skills/bump/SKILL.md      ← Local skill for version bumping
plugins/<name>/                   ← Each published plugin
  .claude-plugin/plugin.json      ← Plugin metadata (name, description, version)
  skills/<name>/SKILL.md          ← The actual skill definition
  skills/<name>/references/       ← Optional supporting docs
marketplacify.md                  ← Full guide for adding new plugins
```

The nested `plugins/<name>/skills/<name>/` path is intentional — it preserves the namespace when Claude Code installs the plugin.

## Key Commands

| Action | Command |
|--------|---------|
| Bump marketplace version | `/bump` (reads marketplace.json, increments patch, commits, pushes) |
| Validate JSON | `python3 -m json.tool .claude-plugin/marketplace.json` |

There is no CI/CD. Publishing = push to master.

## Adding a New Plugin

Follow `marketplacify.md` exactly. The short version:

1. Create `plugins/<name>/.claude-plugin/plugin.json` with `{ "name", "description", "version" }`
2. Create `plugins/<name>/skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, `allowed-tools`)
3. Add entry to `.claude-plugin/marketplace.json` → `plugins[]` array (name, source, description, author, category, tags)
4. Update the README.md "Available Skills" table
5. Run `/bump` to increment the marketplace version

## SKILL.md Authoring Rules

Frontmatter is the contract. The `description` field controls when Claude auto-activates the skill — write it as trigger conditions, not a summary.

```yaml
---
name: my-skill
description: "Use when: <specific trigger conditions>"
allowed-tools: Bash, Read, Write, Edit, Glob
---
```

Optional fields: `version`, `argument-hint` (shown to users as example invocations).

Skills can include dynamic shell expansions with `!` backtick blocks that run at load time (see tasks/SKILL.md for examples).

## marketplace.json Structure

```json
{
  "name": "blairanderson-skills",
  "owner": { "name": "...", "email": "..." },
  "metadata": { "description": "...", "version": "1.0.X" },
  "plugins": [
    {
      "name": "<plugin-name>",
      "source": "./plugins/<name>",
      "description": "...",
      "author": { "name": "..." },
      "category": "<planning|rails|git|productivity|...>",
      "tags": ["..."]
    }
  ]
}
```

The `source` path must match the actual directory. The `name` field is used in install commands (`/plugin install @blairanderson-skills/<name>`).

## Current Plugins

| Plugin | Category | Has plugin.json | Notes |
|--------|----------|-----------------|-------|
| `code-spec` | planning | Yes | Spec extraction from code |
| `rails-authentication` | rails | Yes | Phased auth setup, 9 reference docs |
| `hotfix` | git | Yes | Commit/push/watch workflow |
| `tasks` | productivity | Yes | Task tracker with task_loader/test_task_loader scripts |

## Gotchas

- Plugin names in marketplace.json `name` field must match what users type after the `/` in install commands.
- Always bump the marketplace version after adding or modifying plugins. The `/bump` skill handles this automatically.
