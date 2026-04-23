# Document Feature Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install document-feature@blairanderson-skills
```

This plugin adds one skill for keeping marketing pages and documentation in sync with shipped features.

---

## `/document-feature`

Post-ship marketing documentation and page generation workflow. Runs after code has shipped to production — reads what changed, generates or updates marketing pages, syncs documentation, and tracks what has already been processed to avoid redundant work.

Workflow:

1. **Load Config** — reads `.claude/.document-feature-config.json` (initializes if missing) to find the last-run commit and marketing path
2. **Determine Scope** — diffs against the last-run commit to classify changes as new features, updated features, or removed features
3. **Marketing Path Resolution** — uses the saved path or asks once to confirm where marketing pages live (Sitepress, Astro, Jekyll, etc.) and persists the answer permanently
4. **Page Granularity** — determines whether to create one page per major feature, one per feature, or a hybrid layout
5. **Generate / Update Pages** — for each changed feature, writes outcome-focused, user-facing marketing content; skips already-processed features
6. **Documentation Sync** — updates README, ARCHITECTURE, CONTRIBUTING, and CLAUDE.md with factual changes; asks for narrative changes
7. **Consistency Check** — ensures marketing matches product and docs match reality
8. **Persist State** — saves last-run commit and feature tracking to config for future runs
9. **Commit and Push** — stages only modified files, commits, and pushes
