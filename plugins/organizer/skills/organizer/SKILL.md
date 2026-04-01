---
name: organizer
description: |
  Organize files across Desktop, Downloads, and Documents. Two modes:
  Quick (recent files only) and Deep (full scan with duplicates and age audit).
  Use when asked to "organize files", "clean up desktop", "sort downloads",
  "tidy up", "file cleanup", or "organizer".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
  - Agent
argument-hint: "quick | deep"
version: 1.0.0
---

# /organizer — File Organization Skill

Organize files across `~/Desktop`, `~/Downloads`, and `~/Documents` into a structured, business-aware folder hierarchy. All moves are logged for undo capability.

## Modes

| Mode | What it does |
|------|-------------|
| **Quick** (default) | Scan Desktop/Downloads for files modified in the last 30 days. Route to Documents subfolders. Fast periodic cleanup. |
| **Deep** | Full scan of all 3 directories. Includes duplicate detection (md5 hashing), age audit (flag files untouched 6+ months), and screenshot sorting. |

## Step 1: Ask Mode

If the user didn't specify a mode in the command arguments, ask:

> Quick mode (sort recent files) or Deep mode (full scan + duplicates + age audit)?

Default to Quick if no answer.

## Step 2: Scan

### Quick Mode
```bash
# Files modified in last 30 days on Desktop and Downloads
find ~/Desktop -maxdepth 1 -not -name '.DS_Store' -not -name '.localized' -newer $(date -v-30d +%Y%m%d) 2>/dev/null
find ~/Downloads -maxdepth 1 -not -name '.DS_Store' -not -name '.localized' -newer $(date -v-30d +%Y%m%d) 2>/dev/null
```

Use `ls -lt` and filter by date if `find -newer` is awkward. The goal is recent files only.

### Deep Mode
```bash
# Everything at top level of all 3 dirs
ls -la ~/Desktop/
ls -la ~/Downloads/
ls -la ~/Documents/
```

Also run duplicate detection:
```bash
# Find files with identical content across all 3 dirs
find ~/Desktop ~/Downloads ~/Documents -maxdepth 2 -type f -exec md5 -q {} + 2>/dev/null | sort | uniq -d
```

And age audit:
```bash
# Files not modified in 6+ months
find ~/Desktop ~/Downloads ~/Documents -maxdepth 1 -type f -mtime +180
```

## Step 3: Classify Files

Use these routing rules to classify each file. Rules are checked in order — first match wins.

### Directory Detection (check FIRST for directories)

**Dev project directories** — any directory containing code project markers:
- `package.json`, `Cargo.toml`, `Gemfile`, `go.mod`, `pyproject.toml`, `setup.py`, `pom.xml`, `build.gradle`, `Makefile`, `CMakeLists.txt`, `.git/`

Route to: `~/Documents/DEV-INBOX/` — NEVER auto-sort dev projects. The user reviews these manually and decides whether to move to `~/dev/` or delete.

### File Routing Rules

**Tax documents** — filename contains: `1040`, `W2`, `w-2`, `7004`, `extension`, `K-1`, `tax`, `Tax`, `TAX`, `1099`, `form-`, `TaxJar`
- Route to: `~/Documents/TAXES/{year}/` — extract year from filename or fall back to file modification year

**Amazon seller documents** — filename contains: `amazon`, `Amazon`, `AMZN`, `amzn`, `FBA`, `fba`, `buy-box`, `BuyBox`, `seller`, `Seller`, `Direct-Fulfillment`, `DirectFulfillment`, `DF-`, `shipment`, `B0` (ASIN prefix)
- Route to: `~/Documents/AMAZON-SELLER/`

**Vendor-specific (Amazon sub-categories):**
- Filename contains `cordova`, `Cordova`, `CORDOVA` → `~/Documents/AMAZON-SELLER/cordova/`
- Filename contains `truper`, `Truper`, `TRUPER` → `~/Documents/AMAZON-SELLER/truper/`
- Filename contains `beacon`, `Beacon`, `BEACON` → `~/Documents/AMAZON-SELLER/beacon/`
- Filename contains `myriad`, `Myriad`, `MYRIAD` → `~/Documents/AMAZON-SELLER/myriad/`
- Filename contains `grassmaster`, `Grassmaster`, `GRASSMASTER` → `~/Documents/AMAZON-SELLER/grassmaster/`
- Filename contains `lasco`, `Lasco`, `LASCO` → `~/Documents/AMAZON-SELLER/reports/`
- Filename contains `mosaic`, `Mosaic` → `~/Documents/AMAZON-SELLER/reports/`

**Amazon reports/data** — file extension is `.csv`, `.xlsx`, `.xls` AND filename suggests Amazon data (contains `catalog`, `pricing`, `SKU`, `sku`, `forecast`, `inventory`, `payment`, `settlement`, `search-term`, `advertising`)
- Route to: `~/Documents/AMAZON-SELLER/reports/`

**FBA guides & manuals** — filename contains: `pallet`, `labeling`, `vendor-manual`, `shipment-guide`, `fulfillment-guide`, `EDI`, `edi`
- Route to: `~/Documents/AMAZON-SELLER/fba-guides/`

**Anderson-Savant** — filename contains: `Anderson-Savant`, `anderson-savant`, `SOW`, `sow`, `consulting-agreement`
- Route to: `~/Documents/ANDERSON-SAVANT/`

**Invoices & receipts** — filename contains: `invoice`, `Invoice`, `INVOICE`, `receipt`, `Receipt`, `RECEIPT`, `credit-memo`, `CREDIT MEMO`, `payment-confirmation`
- Route to: `~/Documents/BOOK-KEEPING/invoices/`

**Insurance** — filename contains: `insurance`, `Insurance`, `COI`, `certificate-of-insurance`
- Route to: `~/Documents/BOOK-KEEPING/insurance/`

**Legal** — filename contains: `arbitration`, `ARBITRATION`, `reseller-agreement`, `compliance`, `legal`
- Route to: `~/Documents/LEGAL/`

**Personal** — filename contains: `resume`, `passport`, `vasectomy`, `medical`, `consent`, `unclaimed-property`
- Route to: `~/Documents/PERSONAL/`

**Logos & brand assets** — filename contains: `logo`, `Logo`, `LOGO`, or file is in a directory named `LOGOS`
- Route to: `~/Documents/LOGOS/`

**HR** — filename contains: `HR-`, `hr-`, `human-resources`, `HR-violations`
- Route to: `~/Documents/HR/`

**Installers** — file extension is `.dmg`, `.pkg`, `.app`
- Route to: `~/Documents/INSTALLERS/`

**Screenshots** — filename starts with `Screenshot`, `CleanShot`, or matches pattern `YYYY-MM-DD at HH.MM.SS`:
- If filename contains a keyword matching another category above, route there
- Otherwise route to: `~/Documents/PERSONAL/screenshots/`

**Archive candidates** (Deep mode only) — directories that appear inactive (no files modified in 6+ months):
- Route to: `~/Documents/ARCHIVE/`

**Unclassified** — anything that doesn't match above rules:
- Do NOT auto-move. List these separately and ask the user what to do with them.

## Step 4: Present Plan

Group proposed moves by destination category. Show a table like:

```
## Proposed Moves

### TAXES/2024/ (12 files)
- ~/Desktop/2024-Form-1040.pdf
- ~/Downloads/W2-KAnderson-2024.pdf
...

### AMAZON-SELLER/cordova/ (8 files)
- ~/Downloads/cordova/  (entire directory)
...

### DEV-INBOX/ (3 directories)
- ~/Downloads/project/  (has package.json)
- ~/Downloads/grassmaster-site/  (has index.html + JS)
...

### UNCLASSIFIED (5 files)
- ~/Desktop/random-thing.pdf
- ~/Downloads/mystery-file.xlsx
...
```

Ask user to confirm. They can:
- Approve all
- Approve by section
- Skip specific files
- Specify where unclassified files should go

## Step 5: Execute Moves

Create destination directories first:
```bash
mkdir -p ~/Documents/AMAZON-SELLER/{cordova,truper,beacon,myriad,grassmaster,reports,fba-guides,advertising}
mkdir -p ~/Documents/TAXES/{2021,2022,2023,2024,2025}
mkdir -p ~/Documents/BOOK-KEEPING/{invoices,insurance}
mkdir -p ~/Documents/{ANDERSON-SAVANT,LEGAL,PERSONAL,PERSONAL/screenshots,LOGOS,HR,ARCHIVE,DEV-INBOX,INSTALLERS}
```

Move files using `mv -n` (no-clobber — never overwrite existing files).

**Log every move** to `~/Documents/.organize-log`:
```bash
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)|/original/path/file.pdf|/new/path/file.pdf" >> ~/Documents/.organize-log
```

Format: `ISO-TIMESTAMP|SOURCE_PATH|DEST_PATH`

If `mv -n` skips a file (destination exists), log it as a conflict and report to user.

## Step 6: Summary

After moving, show:

```
## Organization Complete

- Moved: X files, Y directories
- Skipped (conflicts): Z files
- Unclassified (needs manual sort): W files
- Dev projects in inbox: N directories (review at ~/Documents/DEV-INBOX/)

### Breakdown
| Category | Count |
|----------|-------|
| TAXES | 12 |
| AMAZON-SELLER | 45 |
| BOOK-KEEPING | 8 |
| ... | ... |

### Move log
All moves recorded in ~/Documents/.organize-log
To undo the last run: review the log and reverse the moves

### Next run
Suggest running /organizer quick in 1-2 weeks to catch new files.
```

## Step 7: Deep Mode Extras

Only in Deep mode, also:

### Duplicate Report
```
## Duplicate Files Found

### Same content (md5 match)
1. ~/Desktop/invoice-123.pdf ↔ ~/Downloads/invoice-123.pdf (2.3 MB each)
   Recommendation: Keep ~/Documents/BOOK-KEEPING/invoices/invoice-123.pdf, delete the other

### Same filename, different content
1. ~/Desktop/report.csv (45 KB, modified 2024-06) ↔ ~/Downloads/report.csv (52 KB, modified 2024-09)
   Recommendation: Keep newer version
```

Ask user to confirm each deletion.

### Age Audit
```
## Stale Files (not modified in 6+ months)

### Archive candidates
- ~/Desktop/old-project/ (last modified: 2023-11-15)
- ~/Downloads/ancient-report.pdf (last modified: 2023-08-20)

Move these to ~/Documents/ARCHIVE/?
```

## Important Rules

1. **NEVER delete files without explicit user confirmation** — always move, never delete by default
2. **NEVER auto-sort dev projects** — always route to DEV-INBOX for manual review
3. **ALWAYS use `mv -n`** — never overwrite existing files
4. **ALWAYS log moves** — every move gets a line in `.organize-log`
5. **ALWAYS present the plan before executing** — no surprise moves
6. **Skip `.DS_Store` and `.localized`** — macOS recreates these, ignore them
7. **Preserve directory structure** — when moving a directory, move it whole (don't flatten)
8. **Handle spaces in filenames** — always quote paths in shell commands
