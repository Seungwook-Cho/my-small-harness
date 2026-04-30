#!/bin/bash

# ─────────────────────────────────────────────────────────────────
# Stop Hook: Commit + History enforcement
# When module code is modified, forces Claude to:
#   1. Commit the changes
#   2. Record history in dev/history/{module}-history.md
#
# History check: verifies file exists and was recently modified on disk.
# Does NOT require history files to be committed.
#
# Uses a session state file to implement multi-stage enforcement
# (bypasses stop_hook_active single-shot limitation).
#
# Exit codes:
#   0 - All good (or max retries exceeded)
#   2 - Uncommitted changes or missing history - Claude must fix
# ─────────────────────────────────────────────────────────────────

MAX_RETRIES=3

# ─────────────────────────────────────────────────────────────────
# Parse input JSON from stdin
# ─────────────────────────────────────────────────────────────────
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# ─────────────────────────────────────────────────────────────────
# State file per session
# ─────────────────────────────────────────────────────────────────
STATE_DIR="/tmp/claude-commit-history"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/$SESSION_ID"

# Read current state
if [ -f "$STATE_FILE" ]; then
  STATE=$(head -1 "$STATE_FILE")
  RETRIES=$(tail -1 "$STATE_FILE")
else
  STATE="0"
  RETRIES="0"
fi

# Safety: max retries exceeded
if [ "$RETRIES" -ge "$MAX_RETRIES" ] 2>/dev/null; then
  rm -f "$STATE_FILE"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────
# Navigate to project root
# ─────────────────────────────────────────────────────────────────
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // empty')
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
fi
cd "$PROJECT_DIR" || exit 0

# ─────────────────────────────────────────────────────────────────
# Module mapping (MODULES_PATTERN, dir_to_scope, scope_to_history)
# ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./modules.conf.sh
. "$SCRIPT_DIR/modules.conf.sh"

get_uncommitted_modules() {
  {
    git diff --name-only 2>/dev/null
    git diff --cached --name-only 2>/dev/null
  } | grep -E "$MODULES_PATTERN" | sort -u
}

# ─────────────────────────────────────────────────────────────────
# Helper: check that recent commits touching module files use the
# `[scope] type: ...` prefix. Without the prefix the history-check
# silently passes, so reject the commit upfront.
#
# Returns 0 if all recent module-touching commits are properly
# prefixed. Returns 1 + prints "<sha>|<subject>" of the first
# offending commit on stdout.
# ─────────────────────────────────────────────────────────────────
check_prefix_for_recent_commits() {
  local commits
  commits=$(git log --since="5 minutes ago" --format="%h|%s" 2>/dev/null)
  [ -z "$commits" ] && return 0

  while IFS='|' read -r sha subject; do
    [ -z "$sha" ] && continue

    # Did this commit touch any module file?
    local touched_modules
    touched_modules=$(git show --name-only --format="" "$sha" 2>/dev/null \
      | grep -E "$MODULES_PATTERN" || true)
    [ -z "$touched_modules" ] && continue

    # Subject must start with [<known-scope>]
    if ! echo "$subject" | grep -qE '^\[[^]]+\]'; then
      echo "$sha|$subject"
      return 1
    fi

    # Extract scope and verify it maps to a known history file
    local scope
    scope=$(echo "$subject" | sed -n 's/^\[\([^]]*\)\].*/\1/p')
    if [ -z "$(scope_to_history "$scope")" ]; then
      echo "$sha|$subject"
      return 1
    fi
  done <<< "$commits"

  return 0
}

# ─────────────────────────────────────────────────────────────────
# Helper: check if recent commit has corresponding history update
# ─────────────────────────────────────────────────────────────────
check_history_for_recent_commits() {
  # Get scopes from commits in last 5 minutes
  local scopes
  scopes=$(git log --since="5 minutes ago" --format="%s" 2>/dev/null \
    | sed -n 's/^\[\([^]]*\)\].*/\1/p' | sort -u)

  if [ -z "$scopes" ]; then
    return 0  # No recent commits
  fi

  for scope in $scopes; do
    local history_file
    history_file=$(scope_to_history "$scope")
    [ -z "$history_file" ] && continue

    # Check if history file was modified on disk within last 5 minutes
    # Uses file modification time - no git commit required
    if [ -f "$history_file" ]; then
      local recent
      recent=$(find "$history_file" -mmin -5 2>/dev/null)
      if [ -n "$recent" ]; then
        continue  # History file exists and was recently modified
      fi
    fi

    # Also check if it was in a recent commit (covers already-committed case)
    local modified_in_commits
    modified_in_commits=$(git log --since="5 minutes ago" --format="" --name-only 2>/dev/null \
      | grep -F "$history_file" || true)

    if [ -n "$modified_in_commits" ]; then
      continue
    fi

    echo "$scope|$history_file"
    return 1  # History missing for this scope
  done

  return 0
}

# ─────────────────────────────────────────────────────────────────
# State machine
# ─────────────────────────────────────────────────────────────────
save_state() {
  echo "$1" > "$STATE_FILE"
  echo "$2" >> "$STATE_FILE"
}

cleanup() {
  rm -f "$STATE_FILE"
}

case "$STATE" in
  0)
    # Initial check: uncommitted module changes?
    UNCOMMITTED=$(get_uncommitted_modules)
    if [ -n "$UNCOMMITTED" ]; then
      FIRST_DIR=$(echo "$UNCOMMITTED" | head -1 | cut -d'/' -f1)
      SCOPE=$(dir_to_scope "$FIRST_DIR")
      save_state "1" "0"
      echo "모듈 코드 수정 후 커밋 누락. [$SCOPE] 커밋 + history 기록(dev/history/ ## 미정리) 후 종료하세요." >&2
      echo "  scope helper: SCOPE=\$(.claude/hooks/scope-for-staged.sh)" >&2
      exit 2
    fi

    # Recent commits with module changes must use [scope] prefix.
    BAD_PREFIX=$(check_prefix_for_recent_commits)
    if [ $? -ne 0 ]; then
      BAD_SHA=$(echo "$BAD_PREFIX" | cut -d'|' -f1)
      BAD_SUBJ=$(echo "$BAD_PREFIX" | cut -d'|' -f2-)
      save_state "0" "$RETRIES"
      echo "커밋 prefix 누락: $BAD_SHA \"$BAD_SUBJ\"" >&2
      echo "  모듈 파일을 건드린 커밋은 \"[scope] type: ...\" 형식 필수." >&2
      echo "  scope helper: SCOPE=\$(.claude/hooks/scope-for-staged.sh)" >&2
      echo "  amend: git commit --amend -m \"[\$SCOPE] type: 한국어 한 줄\"" >&2
      exit 2
    fi

    # No uncommitted changes. Check recent commits for history.
    MISSING=$(check_history_for_recent_commits)
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
      SCOPE=$(echo "$MISSING" | cut -d'|' -f1)
      HFILE=$(echo "$MISSING" | cut -d'|' -f2)
      save_state "2" "0"
      echo "[$SCOPE] 커밋 완료했으나 history 기록 누락. $HFILE 의 ## 미정리 섹션에 기록하세요." >&2
      exit 2
    fi

    # All good
    cleanup
    exit 0
    ;;

  1)
    # Previously blocked for uncommitted. Recheck.
    UNCOMMITTED=$(get_uncommitted_modules)
    if [ -n "$UNCOMMITTED" ]; then
      NEXT_RETRIES=$((RETRIES + 1))
      save_state "1" "$NEXT_RETRIES"
      echo "아직 모듈 코드 커밋 안 됨. 커밋 후 종료하세요." >&2
      exit 2
    fi

    # Committed. Verify [scope] prefix on recent module-touching commits.
    BAD_PREFIX=$(check_prefix_for_recent_commits)
    if [ $? -ne 0 ]; then
      BAD_SHA=$(echo "$BAD_PREFIX" | cut -d'|' -f1)
      BAD_SUBJ=$(echo "$BAD_PREFIX" | cut -d'|' -f2-)
      NEXT_RETRIES=$((RETRIES + 1))
      save_state "1" "$NEXT_RETRIES"
      echo "커밋 prefix 누락: $BAD_SHA \"$BAD_SUBJ\"" >&2
      echo "  amend: git commit --amend -m \"[\$(.claude/hooks/scope-for-staged.sh)] type: ...\"" >&2
      exit 2
    fi

    # Now check history.
    MISSING=$(check_history_for_recent_commits)
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
      SCOPE=$(echo "$MISSING" | cut -d'|' -f1)
      HFILE=$(echo "$MISSING" | cut -d'|' -f2)
      save_state "2" "$RETRIES"
      echo "[$SCOPE] 커밋 완료. history 기록 누락. $HFILE 의 ## 미정리 섹션에 기록하세요." >&2
      exit 2
    fi

    # All good
    cleanup
    exit 0
    ;;

  2)
    # Previously blocked for history. Recheck.
    MISSING=$(check_history_for_recent_commits)
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
      # History recorded
      cleanup
      exit 0
    fi

    NEXT_RETRIES=$((RETRIES + 1))
    HFILE=$(echo "$MISSING" | cut -d'|' -f2)
    save_state "2" "$NEXT_RETRIES"
    echo "아직 history 기록 안 됨. $HFILE 의 ## 미정리 섹션에 기록하세요." >&2
    exit 2
    ;;

  *)
    cleanup
    exit 0
    ;;
esac
