#!/bin/bash
# PreToolUse hook: Block edits to .env files (contain secrets)

tool_info=$(cat)
file_path=$(echo "$tool_info" | jq -r '.tool_input.file_path // empty')

if [[ -z "$file_path" ]]; then
    exit 0
fi

# Block .env, .env.local, .env.production etc
if [[ "$(basename "$file_path")" =~ ^\.env ]]; then
    echo "BLOCKED: Cannot edit $file_path (contains secrets). Edit manually if needed." >&2
    exit 2
fi

exit 0
