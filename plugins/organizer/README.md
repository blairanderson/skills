# Organizer Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install organizer@blairanderson-skills
```

This plugin adds one skill for organizing files across Desktop, Downloads, and Documents.

---

## `/organizer`

Organize files across `~/Desktop`, `~/Downloads`, and `~/Documents` into a structured, business-aware folder hierarchy. All moves are logged to `~/Documents/.organize-log` for undo capability.

```shell
/organizer        # defaults to Quick mode
/organizer quick  # recent files (last 30 days) only
/organizer deep   # full scan + duplicate detection + age audit
```

**Modes:**

| Mode | What it does |
|------|-------------|
| **Quick** | Scans Desktop and Downloads for files modified in the last 30 days. Routes to Documents subfolders. Fast periodic cleanup. |
| **Deep** | Full scan of all three directories. Includes duplicate detection (md5 hashing), age audit (flags files untouched 6+ months), and screenshot sorting. |

Routes files to business-aware destinations including `TAXES/{year}/`, `AMAZON-SELLER/`, `BOOK-KEEPING/`, `LEGAL/`, `PERSONAL/`, `LOGOS/`, `INSTALLERS/`, `DEV-INBOX/` (for code project directories — never auto-sorted), and more.

Always presents a grouped plan before executing any moves. Uses `mv -n` (no-clobber) so existing files are never overwritten. Unclassified files are listed separately and the user decides their destination.
