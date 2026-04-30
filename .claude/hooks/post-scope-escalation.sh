#!/bin/bash

# ─────────────────────────────────────────────────────────────────
# PostToolUse Hook: Scope escalation
# Counts unique module files edited per session. When threshold
# is reached, blocks Claude and forces /dev-docs recommendation.
#
# - Edit 1: pass
# - Edit 2: soft warning (additionalContext)
# - Edit 3+: hard block (decision: "block")
#
# Counter resets on git commit (new task cycle).
# Only counts edits in 5 module directories.
# ─────────────────────────────────────────────────────────────────

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# ─────────────────────────────────────────────────────────────────
# Git commit detection → reset counter
# ─────────────────────────────────────────────────────────────────
if [ "$TOOL_NAME" = "Bash" ]; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
  if echo "$COMMAND" | grep -q 'git commit'; then
    rm -f "/tmp/cc-scope-${SESSION_ID}"
    rm -f "/tmp/cc-scope-files-${SESSION_ID}"
  fi
  exit 0
fi

# ─────────────────────────────────────────────────────────────────
# Only track Edit/Write tools
# ─────────────────────────────────────────────────────────────────
if [ "$TOOL_NAME" != "Edit" ] && [ "$TOOL_NAME" != "MultiEdit" ] && [ "$TOOL_NAME" != "Write" ]; then
  exit 0
fi

# ─────────────────────────────────────────────────────────────────
# Get file path and check if it is in a module directory
# ─────────────────────────────────────────────────────────────────
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

# Extract relative path from project dir
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // empty')
if [ -n "$PROJECT_DIR" ]; then
  RELATIVE="${FILE_PATH#$PROJECT_DIR/}"
else
  RELATIVE="$FILE_PATH"
fi

# Check if file belongs to a module directory (mapping in modules.conf.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./modules.conf.sh
. "$SCRIPT_DIR/modules.conf.sh"
if ! echo "$RELATIVE" | grep -qE "$MODULES_PATTERN"; then
  exit 0
fi

# ─────────────────────────────────────────────────────────────────
# Deduplicate: count unique FILES, not edit operations
# ─────────────────────────────────────────────────────────────────
FILES_LOG="/tmp/cc-scope-files-${SESSION_ID}"
touch "$FILES_LOG"

if grep -qF "$RELATIVE" "$FILES_LOG" 2>/dev/null; then
  # Same file edited again, do not increment
  exit 0
fi

echo "$RELATIVE" >> "$FILES_LOG"

# ─────────────────────────────────────────────────────────────────
# Count unique files
# ─────────────────────────────────────────────────────────────────
COUNT=$(wc -l < "$FILES_LOG" | tr -d ' ')

if [ "$COUNT" -ge 3 ]; then
  # Hard block: force Claude to stop editing and suggest /dev-docs
  cat <<'ENDJSON'
{
  "decision": "block",
  "reason": "Scope escalation: 3개 이상 모듈 파일을 /dev-docs 없이 편집했습니다. 더 이상 파일을 편집하지 마세요. 사용자에게 이 작업은 /dev-docs가 필요하다고 안내하고, 지금까지 파악한 내용을 요약해 전달하세요."
}
ENDJSON
  exit 0
fi

if [ "$COUNT" -eq 2 ]; then
  # Soft warning: inject context
  cat <<ENDJSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[Scope Check] 모듈 파일 ${COUNT}개 편집됨. 범위가 커지고 있다면 /dev-docs 사용을 고려하세요."
  }
}
ENDJSON
  exit 0
fi

exit 0
