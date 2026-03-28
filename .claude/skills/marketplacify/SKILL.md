# Marketplacify — How to Publish a Plugin to This Marketplace

Step-by-step checklist for adding a new plugin to the `blairanderson/skills` marketplace.

## Required Directory Structure

Every marketplace plugin must follow this exact layout:

```
plugins/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata (name, description, version)
└── skills/
    └── <plugin-name>/
        ├── SKILL.md          # The skill definition (frontmatter + instructions)
        └── (optional files)  # Helper scripts, references/, etc.
```

The nested `skills/<plugin-name>/` path is required — it preserves the namespace when installed.

## Step 1: Create `plugin.json`

Create `.claude-plugin/plugin.json` inside your plugin directory:

```json
{
  "name": "<plugin-name>",
  "description": "One-line description of what the plugin does",
  "version": "1.0.0"
}
```

- **name**: Must match the directory name (e.g., `plugins/tasks/` → `"name": "tasks"`)
- **description**: Same or similar to the SKILL.md description
- **version**: Semver, start at `1.0.0`

## Step 2: Write `SKILL.md`

Place it at `plugins/<plugin-name>/skills/<plugin-name>/SKILL.md`.

Required frontmatter:

```yaml
---
name: <plugin-name>
description: "When to activate this skill — be specific about trigger conditions"
allowed-tools: Bash, Read, Write, Edit, Glob
---
```

Optional frontmatter fields:
- `version`: Skill-level version (independent of plugin.json version)
- `argument-hint`: Example invocations shown to users (e.g., `'list, show 7T, create 4R "Task Name"'`)

The body contains the full instructions Claude follows when the skill activates.

## Step 3: Add Entry to `marketplace.json`

Edit `.claude-plugin/marketplace.json` and add an object to the `plugins` array:

```json
{
  "name": "<plugin-name>",
  "source": "./plugins/<plugin-name>",
  "description": "Human-readable description for marketplace browsing",
  "author": {
    "name": "Your Name"
  },
  "category": "<category>",
  "tags": ["tag1", "tag2", "tag3"]
}
```

### Field reference

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | Plugin identifier, used in `/plugin install @blairanderson-skills/<name>` |
| `source` | Yes | Relative path from repo root, always `./plugins/<name>` |
| `description` | Yes | Shown in `/plugin search` results |
| `author.name` | Yes | Author display name |
| `category` | Yes | One of: `planning`, `rails`, `git`, `productivity`, or a new category |
| `tags` | Yes | Array of searchable keywords |

## Step 4: Update `README.md`

Add the new plugin to the "Available Skills" table in `README.md`:

```markdown
| `<plugin-name>` | Category | Description |
```

## Step 5: Bump the Marketplace Version

Increment the patch version in `.claude-plugin/marketplace.json` → `metadata.version`.

Or just run `/bump` which automates this.

## Step 6: Commit and Push

Stage all new files, commit, and push to master.

---

## Checklist (copy-paste for PRs)

```
- [ ] `plugins/<name>/.claude-plugin/plugin.json` exists with name, description, version
- [ ] `plugins/<name>/skills/<name>/SKILL.md` exists with valid frontmatter
- [ ] Entry added to `.claude-plugin/marketplace.json` plugins array
- [ ] README.md "Available Skills" table updated
- [ ] Marketplace version bumped
- [ ] All helper scripts/files are inside `plugins/<name>/skills/<name>/`
```

## Existing Plugins for Reference

| Plugin | Category | Path |
|--------|----------|------|
| `code-spec` | planning | `plugins/code-spec/` |
| `rails-authentication` | rails | `plugins/rails-authentication/` |
| `git:cleanup_branch` | git | `plugins/cleanup/` |
| `hotfix` | git | `plugins/hotfix/` |
