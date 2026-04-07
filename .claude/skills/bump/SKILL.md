---
name: bump
description: Bump the marketplace version in the blairanderson/skills repo, commit, and push to master. Use whenever the user says "bump", "bump version", "release", or asks to increment the version in the skills repo. Also handles plugin-specific bumps like "bump todo:capture".
argument-hint: 'e.g. /bump or /bump todo:capture'
---

# Bump — smart version increment, commit, push

## Two modes depending on whether an argument is provided

---

## Mode A — Plugin bump: `/bump <plugin-name>` or `/bump <plugin>:<skill>`

If an argument is given (e.g. `todo` or `todo:capture`), bump the **plugin's own version** in `plugins/<plugin>/.claude-plugin/plugin.json`.

The `<plugin>` is always the part before the colon (or the whole argument if no colon).

### Steps

1. Derive the plugin directory: `plugins/<plugin>/` (e.g. `plugins/todo/`)
2. Read `plugins/<plugin>/.claude-plugin/plugin.json` and find the current `version` value
3. Check git log for recent changes to that plugin's directory: `git log --oneline -10 -- plugins/<plugin>/`
4. Decide the version increment:
   - **Patch** (x.y.Z): bug fixes, typo fixes, tweaks to skill content
   - **Minor** (x.Y.0): new skills added to plugin, significant rewrites
   - **Major** (X.0.0): breaking changes to plugin interface or structure
5. Update the `version` field in `plugins/<plugin>/.claude-plugin/plugin.json`
6. Commit: `git commit -am "Bump <plugin> plugin version to <new-version>"`
7. Push: `git push`
8. Confirm: old version → new version, one-line reason

---

## Mode B — Marketplace bump: `/bump` (no argument)

The skills repo has a marketplace manifest at `.claude-plugin/marketplace.json` with a `metadata.version` field using semver (e.g., `1.1.0`).

### Steps

1. git branch must be CLEAN. Run `git status --porcelain` — if output is empty the branch is clean, otherwise stop and alert the user with what's dirty.
2. Read `.claude-plugin/marketplace.json` and find the current `metadata.version` value
3. Find the last bump commit: `git log --oneline --grep="Bump marketplace version" -1`
4. Review all commits since that bump: `git log --oneline <last-bump-hash>..HEAD`
5. Decide the version increment based on what changed:
   - **Patch** (x.y.Z): bug fixes, typo fixes, tweaks to existing skill content, doc updates
   - **Minor** (x.Y.0): new plugins added, plugins removed, significant skill rewrites
   - **Major** (X.0.0): structural changes to marketplace.json format, breaking changes to how plugins are installed or discovered
6. Update the file with the new version
7. Commit: `git commit -am "Bump marketplace version to <new-version>"`
8. Push: `git push`
9. Confirm with a summary: old version, new version, why that increment was chosen (one line)
