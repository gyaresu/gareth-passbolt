#!/usr/bin/env bash
# PreToolUse hook on Bash: block Anthropic/Claude advertising in commit messages.
# The `if` matcher in settings.json already narrows this to `git commit`, so
# we just need to inspect the command string for advertising trailers.

set -u

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Patterns that indicate AI attribution in the commit message.
# Case-insensitive to catch variants.
shopt -s nocasematch
banned_reason=""
case "$cmd" in
  *"co-authored-by: claude"*)              banned_reason="Co-Authored-By: Claude trailer" ;;
  *"co-authored-by: anthropic"*)           banned_reason="Co-Authored-By: Anthropic trailer" ;;
  *"generated with [claude code]"*)        banned_reason="Claude Code generated-with line" ;;
  *"generated with claude code"*)          banned_reason="Claude Code generated-with line" ;;
  *"🤖 generated with"*)                   banned_reason="robot-emoji generated-with line" ;;
  *"noreply@anthropic.com"*)               banned_reason="Anthropic noreply email" ;;
esac
shopt -u nocasematch

if [ -n "$banned_reason" ]; then
  jq -cn --arg reason "Commit message contains AI advertising ($banned_reason). Rewrite the commit without Claude/Anthropic attribution." '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
fi

exit 0
