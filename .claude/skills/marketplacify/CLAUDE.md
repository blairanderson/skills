# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Skill Is

`marketplacify` is a local Claude Code skill (not a published plugin) that guides users through publishing a new plugin to the `blairanderson/skills` marketplace. It lives at `.claude/skills/marketplacify/SKILL.md` and is invoked via `/marketplacify`.

## Single File

This skill is entirely contained in `SKILL.md`. There are no scripts, references, or other files. All logic is prose instructions that Claude follows at runtime.

## How the Skill Works

When invoked, Claude reads `SKILL.md` and executes the 6-step checklist:

1. Create `plugins/<name>/.claude-plugin/plugin.json`
2. Create `plugins/<name>/skills/<name>/SKILL.md` with YAML frontmatter
3. Add an entry to `.claude-plugin/marketplace.json` → `plugins[]`
4. Update `README.md` "Available Skills" table
5. Bump the marketplace version (or run `/bump`)
6. Commit and push to master

## SKILL.md Frontmatter Contract

The `description` field controls when Claude auto-activates this skill. Edit it carefully — it is the trigger condition, not a summary.

```yaml
---
name: marketplacify
description: "Marketplacify — How to Publish a Plugin to This Marketplace"
allowed-tools: Bash, Read, Write, Edit, Glob
---
```

## Modifying This Skill

To improve the skill, edit `SKILL.md` directly. After editing, run `/bump` from the repo root to increment the marketplace version and push to master.
