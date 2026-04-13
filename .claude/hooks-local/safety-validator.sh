#!/usr/bin/env bash
# PreToolUse hook on Bash: block obviously destructive commands.
# Reads hook input JSON on stdin, emits permissionDecision JSON on stdout.
# Exit 0 always — decisions are communicated via JSON, not exit codes.

set -u

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

deny() {
  jq -cn --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

ask() {
  jq -cn --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# BLOCKED: obviously catastrophic
case "$cmd" in
  *"rm -rf /"*|*"rm -rf /*"*|*"rm -rf ~"*|*"rm -rf \$HOME"*|*"rm -rf /home"*|*"rm -rf /Users"*)
    deny "Refusing to run recursive rm against a system/home root: $cmd" ;;
  *"mkfs."*|*"mkfs "*)
    deny "Refusing to run mkfs: $cmd" ;;
  *"dd if="*"/dev/sd"*|*"dd if="*"/dev/disk"*|*"dd of=/dev/sd"*|*"dd of=/dev/disk"*)
    deny "Refusing to run dd against a raw disk device: $cmd" ;;
  *":(){ :|:& };:"*|*":(){:|:&};:"*)
    deny "Refusing to run fork bomb" ;;
  *"chmod -R 777 /"*|*"chmod 777 /"*)
    deny "Refusing to chmod 777 a system root: $cmd" ;;
  *"> /etc/passwd"*|*"> /etc/shadow"*|*"tee /etc/passwd"*|*"tee /etc/shadow"*)
    deny "Refusing to overwrite critical system file: $cmd" ;;
esac

# HIGH: destructive but sometimes legitimate — ask
case "$cmd" in
  *"git push"*"--force"*"main"*|*"git push"*"--force"*"master"*|*"git push -f"*"main"*|*"git push -f"*"master"*)
    ask "Force-push to main/master: confirm before proceeding: $cmd" ;;
  *"git reset --hard"*)
    ask "git reset --hard discards uncommitted work: confirm: $cmd" ;;
  *"git clean -"*"f"*)
    ask "git clean -f deletes untracked files: confirm: $cmd" ;;
  *"git branch -D"*)
    ask "git branch -D force-deletes a branch: confirm: $cmd" ;;
esac

# Default: no opinion, let normal permission flow handle it.
exit 0
