# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Claude Code plugin (skill) for the `blairanderson/skills` marketplace. It provides expert frontend guidance for Ruby on Rails ERB templates, supporting three CSS frameworks:

- **Bootstrap 5.1** — `references/bootstrap-5.1-cheatsheet.md`
- **Bootstrap 5.3** — `references/bootstrap-5.3-cheatsheet.md`
- **Tailwind CSS v4** — `references/tailwind4.md`

The skill is framework-agnostic: it detects which framework the project uses and applies the correct patterns. It never mixes frameworks.

## Plugin Status: Registered

Published to the `blairanderson/skills` marketplace. Install with:
```shell
/plugin install @blairanderson-skills/frontend-rails
```

## Key Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Main skill — framework detection logic, Rails view conventions, ERB checklist |
| `references/bootstrap-5.1-cheatsheet.md` | Bootstrap 5.1.3 classes and components (notes what's NOT available vs 5.3) |
| `references/bootstrap-5.3-cheatsheet.md` | Bootstrap 5.3 classes including color modes, subtle utilities, text-bg-*, plus 5.1→5.3 migration table |
| `references/tailwind4.md` | Tailwind v4 utilities, component patterns, CSS-first config |

## Editing Guidelines

- The SKILL.md `description` field controls auto-activation — write trigger conditions, not a summary
- Reference docs are loaded as context when the skill activates — keep them concise
- Never add app-specific helpers to this plugin (it must work for any Rails app)
- When adding a new framework version, clearly document what's new vs the previous version
