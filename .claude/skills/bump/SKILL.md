---
name: bump
description: Bump the marketplace version in the blairanderson/skills repo, commit, and push to master. Use whenever the user says "bump", "bump version", "release", or asks to increment the version in the skills repo.
---

# Bump — smart version increment, commit, push

The skills repo has a marketplace manifest at `.claude-plugin/marketplace.json` with a `metadata.version` field using semver (e.g., `1.1.0`).

## Steps

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
