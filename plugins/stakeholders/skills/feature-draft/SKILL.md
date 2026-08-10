---
name: feature-draft
description: Draft a readme-style feature announcement email for this project's stakeholders, presented in Claude Code for review first — never written to any mail drafts folder. Persists a per-project stakeholder config (.claude/stakeholders.json) with who they are, coworkers vs clients, and which email CLI (gws/gog/olk) sends for this project. Use when the user says "feature draft", "draft an email about this feature", "recap this for the team", "announce this feature", "email the stakeholders", or just shipped a feature and wants to tell people about it.
argument-hint: "optional: feature name or link to include"
---

# Feature Draft — stakeholder announcement emails

Just shipped a feature? This skill drafts the announcement email for the project's stakeholders and **presents it inside Claude Code for review**. It never sends, and it never creates a draft in the mail system — Outlook/Gmail drafts folders are off-limits until the user explicitly says send.

**Different apps have different stakeholders.** The registry is project-scoped at `.claude/stakeholders.json`, managed by `scripts/stakeholders.sh` (in this skill's directory — call it `$SCRIPT` below).

## Contract

- Input: the feature just built in this session (plus optional `$ARGUMENTS`: feature name, example link).
- Config: `.claude/stakeholders.json` in the project root — created interactively on first run, reused forever after. Records stakeholders, `relationship` (coworkers|clients), `tone`, and `email_cli` (gws|gog|olk).
- Output: the draft **presented in chat** (primary), backed by a temp file at `/tmp/feature-draft-<slug>.md`.
- This skill NEVER sends and NEVER writes into any mail system (no `drafts create`, no Gmail drafts). Sending happens only after explicit user approval, via the configured email CLI's own skill.

## Phase 1: Load or create the stakeholder config

```bash
"$SCRIPT" get   # exit 3 = no config yet
```

**If config exists:** run `"$SCRIPT" check`, show the user a one-line recap ("Drafting for: Tony (to), Jonas (cc) — coworkers — sends via olk"), and proceed. Do not re-interview.

**If missing (exit 3):** interview with AskUserQuestion:

1. "Who are the stakeholders for this project?" — free-form names + emails.
2. "Are they coworkers or clients?" — options: `coworkers` (internal team — casual tone, emoji fine, internal shorthand OK) / `clients` (external — professional tone, lead with benefits, no internal jargon, no repo/CI details).
3. "Which email CLI sends mail for this project?" — options built from the email skills available in this session:
   - `olk` — Outlook work email (blair@andersonassociates.net)
   - `gws` — Google Workspace (blair.anderson@loopedsustainability.com)
   - `gog` — Google Workspace via gog CLI
   Each has its own skill for sending; this choice only records the handoff target.

Then persist:

```bash
"$SCRIPT" init --relationship coworkers --email-cli olk --tone "casual, emoji ok"
"$SCRIPT" add --name Tony --email tony@example.com --send-as to
"$SCRIPT" add --name Jonas --email jonas@example.com --send-as cc
"$SCRIPT" check
```

(`"$SCRIPT" email-cli olk` updates the CLI later; `"$SCRIPT" email-cli` prints it.)

## Phase 2: Gather feature context

From the current session and git — the feature that was JUST built:

- What changed, from the user's perspective (not the implementation's)
- Where to see it: a URL if the app is deployed (ask for an example link if one would help and none is known)
- The 3-6 details that matter to a reader (behavior changes, data caveats, how to undo/toggle)

## Phase 3: Write the draft and PRESENT it in Claude Code

Structure — short and scannable, like a good README section:

1. **Subject line** — `New: <feature>` or `Update: <feature>`, one emoji max
2. Greeting + one-sentence "what shipped"
3. **What's new** — 1-2 short paragraphs, user-facing behavior only
4. **The details that matter** — bulleted list (3-6 bullets, bold lead-ins)
5. **Try it here** — link(s)
6. One-sentence "why this matters" close + invitation for feedback

Tone by relationship (from config):

- `coworkers` — conversational, emoji in bullets OK, can reference internal tools/pages by name
- `clients` — professional, benefit-first, zero internal jargon, no mention of commits/CI/deploys; frame as "we've added" not "I shipped"

Honor `tone` notes from the config over these defaults.

**Presentation (required):** render the complete draft in chat as a clearly framed block —

```
📧 DRAFT — not sent
To:      tony@example.com
Cc:      jonas@example.com
Via:     olk
Subject: New: <feature> 📈
─────────────────────────────
<full body, readme-style markdown>
```

— then save the same content to `/tmp/feature-draft-<slug>.md` (with a `to:/cc:/subject:` frontmatter block) and mention the path. The chat presentation is the deliverable; the temp file is the artifact for a later send.

## Phase 4: Hand off (only on explicit "send")

Wait for the user. On edits: revise and re-present in chat. On explicit approval to send, dispatch by `"$SCRIPT" email-cli`:

- `olk` — work email: convert body to HTML and use the olk skill's `sigmail` wrapper (`~/.claude/skills/olk/sigmail send $("$SCRIPT" recipients) --subject "..." --body-file draft.html`) — it appends and verifies the signature.
- `gws` — invoke the `gws` skill and follow its send workflow.
- `gog` — invoke the `gog` skill and follow its send workflow.

Never send through a CLI other than the configured one without the user redirecting.

## Output Format

1. One-line stakeholder recap (who + relationship + email CLI)
2. The framed draft presented in chat (Phase 3)
3. The temp file path

## Anti-Patterns

- Writing into any mail system's drafts folder — the draft lives in chat + temp file only.
- Sending without an explicit user "send" — presenting the draft is the end of the default flow.
- Re-interviewing when `.claude/stakeholders.json` exists.
- Sending via a different CLI than the configured `email_cli`.
- Implementation-speak in client drafts (PRs, CI, class names).
- Walls of text — if a bullet runs three lines, split or cut it.
