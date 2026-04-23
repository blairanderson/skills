# Backlinks Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install backlinks@blairanderson-skills
```

This plugin adds one skill for finding every domain linking to any domain using CommonCrawl data.

---

## `/backlinks`

Find all domains linking to a target domain using CommonCrawl's hyperlinkgraph dataset and DuckDB.

```shell
/backlinks example.com
```

**Requirements:**
- `duckdb` installed (`brew install duckdb`)
- ~16 GB disk space for the edge/vertex files (downloaded once, cached at `~/.cache/cc-backlinks/`)

Downloads the CommonCrawl hyperlinkgraph vertices and edges for the current quarterly release, then queries inbound links using a DuckDB SQL join. Results are sorted by `num_hosts` descending and show `linking_domain` plus the number of distinct hosts on that domain pointing to the target.

Data files are cached — subsequent queries on the same release run fast with no re-download. Override the release with `CC_RELEASE=cc-main-2025-oct-nov-dec /backlinks example.com`.
