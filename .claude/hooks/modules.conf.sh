#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# Module / scope / history mapping
#
# Edit this file to match your monorepo. Both hooks source it:
#   - post-scope-escalation.sh   (uses MODULES_PATTERN)
#   - stop-commit-history-check.sh (uses MODULES_PATTERN + dir_to_scope + scope_to_history)
#
# Three things to keep in sync:
#   1. MODULES_PATTERN — regex of top-level module dirs (relative to repo root)
#   2. dir_to_scope     — maps a top-level dir to a short scope key (used in commit prefix [scope])
#   3. scope_to_history — maps a scope key to its history file path
#
# The scope key is the same one that appears in commit messages: "[scope] type: ..."
# (`.claude` is included so harness changes also enforce commit + history.)
# ─────────────────────────────────────────────────────────────────

# Edit me ↓ — list every top-level module dir you want enforced, pipe-separated.
# Defaults assume a Next.js + Node API monorepo: `web/` (Next.js app) and `api/` (backend).
# `.claude` 는 기본에서 빠져 있다. harness 자체를 추적 대상에 넣고 싶으면
# 워크플로 안정화 후 직접 추가하라 (README 의 "harness 자체 추적 활성화" 섹션 참조).
MODULES_PATTERN="^(web|api)/"

# Edit me ↓ — directory name → scope key
dir_to_scope() {
  case "$1" in
    web) echo "web" ;;
    api) echo "api" ;;
    *) echo "" ;;
  esac
}

# Edit me ↓ — scope key → history file
scope_to_history() {
  case "$1" in
    web) echo "dev/history/web-history.md" ;;
    api) echo "dev/history/api-history.md" ;;
    *) echo "" ;;
  esac
}
