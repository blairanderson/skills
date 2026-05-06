---
name: claude-file
description: |
  Audit the current project's CLAUDE.md against Blair Anderson's Rails conventions.
  Use when: "audit CLAUDE.md", "check my CLAUDE.md", "update conventions", 
  "does my CLAUDE.md have everything", "add rails conventions", or any request 
  to review or sync the CLAUDE.md in a Rails project.
allowed-tools:
  - Read
  - Edit
  - Bash
  - AskUserQuestion
argument-hint: "audit, sync, update"
---

# Rails Conventions Audit

Audit the current project's `CLAUDE.md` against the agreed Rails conventions and
propose additions or removals. Never make changes without confirmation.

## Step 1 — Read the current CLAUDE.md

```bash
cat CLAUDE.md
```

If no `CLAUDE.md` exists, say so and ask if the user wants to create one.

## Step 2 — Check for each convention

For each item below, note whether it is **present**, **missing**, or **present but wrong**.

### Ruby Style
- [ ] No `private` / `private_class_method` rule stated
- [ ] Time rule: `Time.current`, `Time.zone.today`, `Time.zone.parse()` — never `Time.now` / `Date.today`
- [ ] Secrets rule: `Rails.application.credentials` — never `ENV["KEY"]`
- [ ] Generators rule: always `bin/rails generate` for models, migrations, mailers — never hand-write
- [ ] Inline logic until repeated 3+ times

### Views
- [ ] Use `link_to` — never raw `<a href="">`
- [ ] Use `image_tag` — never raw `<img>`

### Routing (37signals style)
- [ ] Everything is CRUD
- [ ] Nouns over verbs
- [ ] Many small controllers over few large ones
- [ ] Redirects over dynamic render
- [ ] Self-documenting URLs

### Linting & Security
- [ ] `bin/rails zeitwerk:check` listed and noted as pre-commit requirement
- [ ] `bin/rubocop` listed
- [ ] `bin/brakeman --no-pager` listed

### Skill Routing
- [ ] Skill routing table present with at minimum these triggers:
  - bugs/errors → `investigate`
  - ship/deploy → `ship`
  - QA → `qa`
  - code review → `review`
  - brainstorm → `office-hours`
  - retro → `retro`

## Step 3 — Report findings

Show the user a clear checklist of:

**Missing** — conventions not mentioned at all  
**Present** — already covered (no action needed)  
**Outdated / wrong** — something that contradicts the conventions (e.g. `ENV["KEY"]` used, `private` encouraged, `Time.now` mentioned)

Format the report as:

```
✅ Present
  - No private methods rule
  - Rubocop listed

❌ Missing
  - zeitwerk:check pre-commit hook
  - Generators rule
  - Skill routing table

⚠️  Outdated / Wrong
  - Uses ENV["KEY"] pattern (should be credentials)
```

## Step 4 — Ask before changing

Use AskUserQuestion to confirm which items the user wants to act on.
List the missing/wrong items as options. Allow multi-select.
Do NOT edit the file until the user confirms.

## Step 5 — Apply changes

For each confirmed item:
- Add missing conventions to the most logical existing section, or create a new section
- Fix wrong/outdated entries in place
- Do not reformat or restructure sections the user did not ask to change
- Do not remove anything unless the user explicitly said to remove it

After editing, show a brief summary of what changed.
