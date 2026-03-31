---
name: document-feature
version: 1.0.0
description: |
  Post-ship marketing documentation and page generation workflow. Reads code + docs,
  determines marketing structure, generates/updates marketing pages, syncs docs,
  tracks last-run state, and ensures marketing site reflects shipped features.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

# Document Feature: Post-Ship Marketing + Documentation System

You are running the `/document-feature` workflow.

This runs **after code has shipped to production.**

Your responsibilities:

1. Generate or update **marketing pages from shipped code**
2. Ensure **marketing structure is correct and consistent**
3. Sync **documentation with actual shipped behavior**
4. Track **what has already been processed** to avoid redundant work

---

# Runtime Context (Preloaded)

These variables are already evaluated before you read this file:

* GITSTATUS = !`git status`
* GIT_BRANCH = !`git branch --show-current`
* GIT_LOG = !`git log --oneline -20`

Use them directly. Do NOT re-run these commands unless necessary.

---

# Core Principles

* Marketing content is derived from **real shipped functionality**
* Structure must follow **existing project conventions**
* Never invent structure when one should be confirmed
* Always maintain **consistency across runs**
* Minimize repeated work using **last-run tracking**

---

# STOP / CONTINUE RULES

## Only stop for:

* Missing marketing path
* Page granularity ambiguity (feature → page mapping)
* Narrative or positioning changes
* VERSION bump decisions
* New TODO decisions

## Never stop for:

* Using an existing marketing path
* Factual updates from code
* Adding new marketing pages when structure is clear
* Updating timestamps / tracking config

---

# Step 0: Load Config

Read:

`.claude/.document-feature-config.json`

If it does not exist, initialize it.

---

# Step 1: Determine Scope of Changes

## 1.1 Load last-run

From config:

```
{
  "last-run": "commit-or-timestamp",
  "marketing": {
    "path": "string"
  },
  "features": {}
}
```

## 1.2 Determine diff window

If last-run exists, use it as base.

Otherwise treat as first run.

## 1.3 Classify changes

* New features
* Updated features
* Removed features

---

# Step 2: Marketing Path Resolution (CRITICAL)

## 2.1 Read from config

If `marketing.path` exists:

* Use it EXACTLY
* Do NOT modify
* Do NOT attempt detection

## 2.2 If missing

Use AskUserQuestion:

```
Where should marketing pages live? This is strictly for static
    
- /app/content/pages/<feature> (sitepress)
- /<project>/public-marketing/src/features/<feature> (astro)
- /<project>/marketing-site/pages/<feature> (jekyll)
- /marketing/<feature> (other / AskUserQuestion!)
- /pages/<feature> (other / AskUserQuestion!)
- Custom path (AskUserQuestion!)

RECOMMENDATION: make an educated guess, but always AskUserQuestion to confirm and cleanly separates marketing from product code.
```

After user answers:

* Persist immediately to config
* Never ask again

---

# Step 3: Page Granularity Decision (CRITICAL)

## 3.1 Analyze feature size

Read:

* Changed files
* Existing marketing pages (inside marketing.path)

Determine pattern:

* Are small features given pages?
* Or only large features?

## 3.2 Make best guess and confirm

Use AskUserQuestion:

```
How should we map features to marketing pages?

A) One page per major feature only
B) One page per feature (including small ones)
C) Hybrid (major pages + grouped small features)

RECOMMENDATION: Choose C because it balances clarity and avoids page bloat.
```

---

# Step 4: Determine Last Marketing Update

If config missing or feature not tracked:

* Look inside marketing.path
* Infer last update from git history

---

# Step 5: Generate / Update Marketing Pages

For each feature changed since last-run:

## 5.1 Skip unchanged

If feature already processed → skip

## 5.2 Read source

Understand:

* What it does
* Who it benefits

## 5.3 Generate marketing content

* Outcome-focused
* User-facing
* No implementation detail

## 5.4 Write/update page

* Respect existing structure
* Do not overwrite unrelated content

## 5.5 Update feature tracking

```
"features": {
  "feature-name": "updated_at"
}
```

---

# Step 6: Documentation Sync

Update:

* README
* ARCHITECTURE
* CONTRIBUTING
* CLAUDE.md

Rules:

* Auto-update factual changes
* Ask for narrative changes

---

# Step 7: CHANGELOG Voice Polish

* Never rewrite entries
* Only improve wording

---

# Step 8: Consistency Check

Ensure:

* Marketing matches product
* Docs match reality
* No contradictions

---

# Step 9: Persist State

Write config:

```
{
  "last-run": "now",
  "marketing": {
    "path": "..."
  },
  "features": {
    ...
  }
}
```

---

# Step 10: Commit

* Stage only modified files
* Commit
* Push

---

# Key Rules

* Marketing path is permanent once set
* Never guess when you can ask once
* Never re-detect marketing structure
* Always track what has been processed

---

# Outcome

After each run:

* Marketing pages reflect shipped features
* Documentation is accurate
* No duplicate work occurs
* System improves over time via tracking

