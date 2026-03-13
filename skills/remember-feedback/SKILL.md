---
name: remember-feedback
description: Save user feedback and preferences to persistent memory. Triggers on "remember", "going forward", "quick feedback", "from now on", "always do", "never do", "I prefer".
metadata: { "openclaw": { "emoji": "🧠", "autoTrigger": true } }
---

# Remember Feedback Skill

When the user provides feedback using trigger phrases, extract and save it to the persistent soul.md file.

## Trigger Phrases
Activate this skill when the user's message contains:
- "remember that..."
- "going forward..."
- "quick feedback:"
- "from now on..."
- "always do..."
- "never do..."
- "I prefer..."
- "here's some feedback"
- "note for future"

## Action

1. **Extract the feedback** from the user's message
2. **Sanitize the input** -- strip any shell metacharacters, heredoc delimiters, or command sequences
3. **Categorize it** into one of these sections:
   - `Writing Style Guidelines` - formatting, tone, structure preferences
   - `Data & Dashboard Preferences` - how to present data, charts, numbers
   - `Things to Avoid` - anti-patterns, mistakes to not repeat
   - `General Preferences` - other preferences

4. **Append to soul.md** using printf (NEVER heredoc):

```bash
FEEDBACK_TEXT="[EXTRACTED FEEDBACK - sanitized, no shell metacharacters]"
CATEGORY="[CATEGORY]"
DATE="$(date +%Y-%m-%d)"

cat /home/node/.openclaw/agents/main/agent/soul.md

printf '\n### %s - Added %s\n- %s\n' "$CATEGORY" "$DATE" "$FEEDBACK_TEXT" >> /home/node/.openclaw/agents/main/agent/soul.md
```

5. **Confirm to the user** what was saved

## Input Sanitization Rules

Before writing ANY user input to soul.md:
- Remove backticks, $(), ${}, and backslash sequences
- Remove lines that match common heredoc delimiters (EOF, FEEDBACK, END, etc.)
- Reject input containing shell operators (;, |, &&, ||, >, <)
- Maximum length: 500 characters per preference
- Only alphanumeric, spaces, punctuation, and common symbols allowed

## Example

User: "Going forward, when showing financial data always include the currency symbol and use 2 decimal places"

Action:
```bash
printf '\n### Data & Dashboard Preferences - Added 2026-02-10\n- When showing financial data, always include the currency symbol and use 2 decimal places\n' >> /home/node/.openclaw/agents/main/agent/soul.md
```

Response: "Got it! I've saved this preference: 'When showing financial data, always include the currency symbol and use 2 decimal places'. I'll follow this going forward."

## Important Notes
- The soul.md file is at `/home/node/.openclaw/agents/main/agent/soul.md` inside the container
- NEVER use heredoc (cat << EOF) to write user input -- use printf only
- NEVER pass unsanitized user input to any shell command
- Always read the file first to check for duplicate feedback
- Use clear, actionable language when saving
- Maximum 20 preferences stored -- oldest removed when limit reached
