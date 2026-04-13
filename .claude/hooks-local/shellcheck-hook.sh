#!/usr/bin/env bash
# PostToolUse hook on Write/Edit: run shellcheck on *.sh files and surface
# findings back to the model via additionalContext. Silently skips if the
# file isn't a shell script or shellcheck isn't installed.

set -u

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_response.filePath // .tool_input.file_path // ""')

# Only shell scripts
case "$file" in
  *.sh|*.bash) ;;
  *) exit 0 ;;
esac

# Skip if shellcheck isn't available (don't fail the tool call)
command -v shellcheck >/dev/null 2>&1 || exit 0

# File may have been deleted/renamed between tool call and hook; guard
[ -r "$file" ] || exit 0

# --severity=info matches the schlock preset; security-focused but not noisy
output=$(shellcheck --severity=info --format=gcc "$file" 2>&1) || true

if [ -n "$output" ]; then
  jq -cn --arg ctx "shellcheck findings for $file:\n$output" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $ctx
    }
  }'
fi

exit 0
