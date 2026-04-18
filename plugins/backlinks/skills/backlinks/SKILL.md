---
name: backlinks
description: "Use when: user wants to find backlinks, referring domains, or inbound links to a domain using CommonCrawl data"
argument-hint: "example.com"
allowed-tools: Bash
---

# Backlinks — CommonCrawl Domain Backlink Lookup

Find every domain linking to a target domain using CommonCrawl's hyperlinkgraph dataset and DuckDB.

## Requirements

- `duckdb` must be installed (`brew install duckdb`)
- ~16 GB disk space for the edge/vertex files (downloaded once, cached at `~/.cache/cc-backlinks/`)
- First query on a new release scans the full dataset — expect several minutes

## Arguments

`/backlinks $ARGUMENTS` — the argument is the domain to look up (e.g. `example.com`).

If no argument is provided, use AskUserQuestion to ask for the domain.

## Steps

1. **Determine the domain** from `$ARGUMENTS`. If empty, ask via AskUserQuestion.
2. **Check for duckdb**: run `command -v duckdb` — if missing, tell the user to run `brew install duckdb` and stop.
3. **Run the backlink lookup** using the script below.
4. **Report results**: show the table of linking domains sorted by `num_hosts` descending. Summarize the total count.

## Script

Run this as a single Bash command, substituting `DOMAIN` with the user's domain:

```bash
#!/usr/bin/env bash
set -euo pipefail

DOMAIN="<USER_DOMAIN>"
RELEASE="${CC_RELEASE:-cc-main-2026-jan-feb-mar}"
CACHE="${HOME}/.cache/cc-backlinks/${RELEASE}"
BASE="https://data.commoncrawl.org/projects/hyperlinkgraph/${RELEASE}/domain"

VERTICES="${CACHE}/domain-vertices.txt.gz"
EDGES="${CACHE}/domain-edges.txt.gz"

mkdir -p "$CACHE"

# Reverse domain: roots.io -> io.roots
REV_DOMAIN=$(awk -F. '{for(i=NF;i>0;i--) printf "%s%s", $i, (i>1?".":"")}' <<<"$DOMAIN")

download() {
  local url="$1" dest="$2"
  if [[ -f "$dest" ]]; then return; fi
  echo ">> downloading $(basename "$dest") ..." >&2
  curl -L --fail -C - -o "$dest" "$url"
}

download "${BASE}/${RELEASE}-domain-vertices.txt.gz" "$VERTICES"
download "${BASE}/${RELEASE}-domain-edges.txt.gz"    "$EDGES"

echo ">> querying backlinks to ${DOMAIN} (reversed: ${REV_DOMAIN}) ..." >&2
echo ">> first run scans ~16 GB of gzipped edges; expect several minutes" >&2

duckdb <<SQL
.mode box
WITH vertices AS (
  SELECT * FROM read_csv('${VERTICES}', delim='\t', header=false,
    columns={'id':'BIGINT','rev_domain':'VARCHAR','num_hosts':'BIGINT'})
),
target AS (
  SELECT id FROM vertices WHERE rev_domain = '${REV_DOMAIN}'
),
inbound AS (
  SELECT from_id FROM read_csv('${EDGES}', delim='\t', header=false,
    columns={'from_id':'BIGINT','to_id':'BIGINT'})
  WHERE to_id = (SELECT id FROM target)
)
SELECT
  array_to_string(list_reverse(string_split(v.rev_domain, '.')), '.') AS linking_domain,
  v.num_hosts
FROM inbound i
JOIN vertices v ON v.id = i.from_id
ORDER BY v.num_hosts DESC, linking_domain;
SQL
```

## Notes

- Data files are cached — subsequent queries for any domain on the same release are fast (no re-download).
- The `CC_RELEASE` env var can override the default release (e.g. `CC_RELEASE=cc-main-2025-oct-nov-dec /backlinks example.com`).
- Results show `linking_domain` (human-readable) and `num_hosts` (number of distinct hosts on that domain linking to the target).
