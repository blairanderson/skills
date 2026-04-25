# statusline

Claude Code status line enhancements — per-project config via `.claude-statusline` with website display and health check polling.

## Skills

| Skill | Trigger | Description |
|---|---|---|
| `statusline-health` | "add health check to statusline", "monitor uptime in statusline" | Add a cached uptime indicator — polls your health URL every 5 minutes, shows green `(up)` or a full red alert |

## Install

```shell
/plugin install statusline@blairanderson-skills
```

## .claude-statusline format

Create `.claude-statusline` in any project root:

```
website=https://mysite.com/
HEALTH=https://mysite.com/up
```

| Key | Required | Description |
|---|---|---|
| `website=` | No | Display URL shown in cyan in the statusline |
| `HEALTH=` | No | URL polled every 5 minutes; must return HTTP 200 when healthy |

## Status indicators

| State | Display |
|---|---|
| Healthy | `https://mysite.com/ (up)` (green) |
| Down | Full red line: `WEBSITE IS DOWN. I REPEAT https://mysite.com/ IS DOWN` |
| `HEALTH=` missing | `https://mysite.com/ (add HEALTH= to .claude-statusline)` (dim) |

Cache lives at `/tmp/statusline-health-<hash>.cache`. Delete it to force an immediate re-check.
