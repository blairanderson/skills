#!/bin/bash
# onboard-tazk.sh — PreToolUse hook for TaskCreate/TaskUpdate
#
# First time per project: adds tazk instructions to CLAUDE.md, saves flag.
# After that: exits immediately (CLAUDE.md handles the rest).

SETTINGS_LOCAL=".claude/settings.local.json"

# Fast path: already onboarded this project
if [ -f "$SETTINGS_LOCAL" ]; then
  ONBOARDED=$(python3 -c "
import json, sys
try:
    d = json.load(open('$SETTINGS_LOCAL'))
    print(d.get('skills',{}).get('tazk',{}).get('onboarded', False))
except: print(False)
" 2>/dev/null)
  if [ "$ONBOARDED" = "True" ]; then
    exit 0
  fi
fi

# --- First encounter in this project ---

# Add tazk section to CLAUDE.md if not already there
CLAUDE_MD="CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
  if ! grep -q "/tazk" "$CLAUDE_MD"; then
    printf '\n## Task Management\n\nUse `/tazk` for all task tracking (list, create, update, show). Do NOT use the built-in TaskCreate/TaskUpdate tools — they are ephemeral and vanish when the session ends. `/tazk` persists tasks as markdown files in `.tasks/` across sessions.\n' >> "$CLAUDE_MD"
  fi
else
  printf '# CLAUDE.md\n\n## Task Management\n\nUse `/tazk` for all task tracking (list, create, update, show). Do NOT use the built-in TaskCreate/TaskUpdate tools — they are ephemeral and vanish when the session ends. `/tazk` persists tasks as markdown files in `.tasks/` across sessions.\n' > "$CLAUDE_MD"
fi

# Save onboarded flag to .claude/settings.local.json
mkdir -p .claude
if [ -f "$SETTINGS_LOCAL" ]; then
  python3 -c "
import json
with open('$SETTINGS_LOCAL') as f:
    d = json.load(f)
d.setdefault('skills', {}).setdefault('tazk', {})['onboarded'] = True
with open('$SETTINGS_LOCAL', 'w') as f:
    json.dump(d, f, indent=2)
"
else
  python3 -c "
import json
d = {'skills': {'tazk': {'onboarded': True}}}
with open('$SETTINGS_LOCAL', 'w') as f:
    json.dump(d, f, indent=2)
"
fi

# Block this call and redirect to /tazk
echo "Use /tazk instead of TaskCreate/TaskUpdate. I've added this to CLAUDE.md for future sessions." >&2
exit 2
