---
name: bump
description: Bump the marketplace version in the blairanderson/skills repo, commit, and push to master. Use whenever the user says "bump", "bump version", "release", or asks to increment the version in the skills repo.
---

# Bump — increment version, commit, push

The skills repo has a marketplace manifest at `.claude-plugin/marketplace.json` with a `metadata.version` field using semver (e.g., `1.0.3`).

## Steps

1. Read `.claude-plugin/marketplace.json` and find the current `metadata.version` value
2. Increment the **patch** version (e.g., `1.0.3` → `1.0.4`)
3. Update the file with the new version
4. Commit the change: `git commit -am "Bump marketplace version to <new-version>"`
5. Push: `git push`
6. Confirm with a one-line summary showing the old and new version
