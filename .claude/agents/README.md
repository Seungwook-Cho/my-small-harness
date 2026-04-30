# Agents

Specialized agents for coding, verification, and error resolution.

## Available Agents (4)

| Agent | Purpose | Model |
|-------|---------|-------|
| `implementer` | Execute a single coded task with `[FILES]` / `[TASK]` / `[VERIFY]` contract | sonnet |
| `verifier` | Read-only check of implemented code vs plan (fresh context) | sonnet |
| `auto-error-resolver` | Mechanical TypeScript error auto-fix (self-sufficient — runs `tsc` and parses errors) | haiku |
| `frontend-error-fixer` | Next.js / React 19 build & runtime error diagnosis and fix | sonnet |

> Plan 작성용 별도 `planner` 에이전트는 두지 않는다 — Interview 직후 코디네이터가 직접 plan을 작성하는 게 효율적.
> 자세한 근거는 [dev/history/harness_history_generalized.md](../../dev/history/harness_history_generalized.md) Phase 2 참조.

## Usage

Coordinator(메인 세션)가 자연어 요청에 따라 디스패치:

- `/dev-docs [task]` → dev-docs 스킬이 분기 판정. SMALL/BIG이면 `implementer` 디스패치, BIG 완료 후 `verifier`
- "TypeScript 에러 고쳐줘" → `auto-error-resolver`
- "빌드 에러 / 런타임 에러" → `frontend-error-fixer`

## Creating Your Own

Agents are markdown files with YAML frontmatter in `.claude/agents/`:

```markdown
---
name: agent-name
description: When to use this agent
model: sonnet
---

[System prompt for the agent]
```
