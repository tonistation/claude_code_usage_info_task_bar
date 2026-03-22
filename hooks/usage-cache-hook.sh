#!/bin/bash
# Claude Code statusLine hook: captures rate_limits and writes to usage_cache.json
# The ClaudeUsageBar menu bar app reads this file to display usage information.
#
# Input: JSON via stdin with rate_limits, context_window, session_id, model fields
# Output: Short status line for Claude Code's terminal display

CACHE_FILE="$HOME/.claude/usage_cache.json"

input=$(cat)

# Extract rate_limits — if not present, exit silently
rate_limits=$(echo "$input" | jq -e '.rate_limits // empty' 2>/dev/null)
if [ -z "$rate_limits" ]; then
  exit 0
fi

# Save structured data to cache file for the menu bar app
echo "$input" | jq -c '{
  rate_limits: .rate_limits,
  updated_at: (now | floor),
  session_id: (.session_id // null),
  model: (.model // null)
}' > "$CACHE_FILE" 2>/dev/null

# Output short status line for Claude Code terminal
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)
out=""
[ -n "$five" ] && out="5h:$(printf '%.0f' "$five")%"
[ -n "$week" ] && out="$out 7d:$(printf '%.0f' "$week")%"
echo "$out"
