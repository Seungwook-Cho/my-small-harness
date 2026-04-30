#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# scope-for-staged.sh
#
# Resolves the [scope] commit prefix for currently staged files.
# Implementer / coordinator MUST call this before `git commit` so the
# commit message follows `[scope] type: ...` and the stop hook can
# track history correctly.
#
# Usage:
#   SCOPE=$(.claude/hooks/scope-for-staged.sh) || exit 1
#   git commit -m "[$SCOPE] feat: 한국어 한 줄"
#
# Behavior:
#   - exit 0 + scope on stdout : exactly one module matched
#   - exit 1 + reason on stderr: 0 staged, no module match, or multiple modules
#
# Multiple modules → fail by design ([CLAUDE.md] "한 커밋에 여러 모듈
# 섞지 않는다"). Split your stage and commit twice.
# ─────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./modules.conf.sh
. "$SCRIPT_DIR/modules.conf.sh"

# Must be inside a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "scope-for-staged: not a git repository" >&2
  exit 1
fi

# Collect top-level dirs from staged files
staged=$(git diff --cached --name-only 2>/dev/null)
if [ -z "$staged" ]; then
  echo "scope-for-staged: nothing staged" >&2
  exit 1
fi

dirs=$(echo "$staged" | awk -F/ 'NF>1 {print $1}' | sort -u)

# Map each dir to a scope; collect uniques
scopes=""
for d in $dirs; do
  s=$(dir_to_scope "$d")
  [ -z "$s" ] && continue
  scopes="$scopes $s"
done

scopes=$(echo "$scopes" | tr ' ' '\n' | sort -u | grep -v '^$' || true)
count=$(echo "$scopes" | grep -c . || true)

if [ "$count" -eq 0 ]; then
  echo "scope-for-staged: no staged file matches any module in modules.conf.sh" >&2
  echo "  staged top-level dirs: $(echo "$dirs" | tr '\n' ' ')" >&2
  exit 1
fi

if [ "$count" -gt 1 ]; then
  echo "scope-for-staged: staged files span multiple modules — split commits" >&2
  echo "  scopes: $(echo "$scopes" | tr '\n' ' ')" >&2
  exit 1
fi

echo "$scopes"
