---
name: dev-docs
description: "Use when the user invokes /dev-docs. Classifies the request as MICRO/SMALL/BIG and either dispatches inline (MICRO/SMALL) or generates a 3-file plan/context/tasks scaffold under dev/active/ (BIG). Stack assumption: Next.js / React / TypeScript / pnpm."
argument-hint: 작업 설명 (예 "다크모드 토글", "프로필 업로드 시 413 에러", "검색 페이지 추가")
---

# /dev-docs — 구조화된 작업 진입점

**핵심 원칙: AI가 분기를 판정하고 사용자가 확인한다. 잘못된 분기는 비용이 크니 애매하면 SMALL로 떨어뜨린다.**

사용자 요청: **$ARGUMENTS**

전제 스택: **Next.js 16 / React 19 / TypeScript 5 / pnpm**.
검증 명령: `pnpm typecheck`, `pnpm build`, 브라우저 스모크.

---

## STEP 0: 진행 중인 작업 확인 (선행)

`dev/active/` 안에 폴더가 있는지 확인:

```
ls dev/active/ 2>/dev/null
```

- 비어 있음 → STEP 1로
- 폴더 있음 → 사용자에게: "이미 `<task-name>` 진행 중. 이어서 할지, 별개 작업으로 할지?"
  - 이어서 → 기존 `dev/active/<task-name>/tasks.md` 의 미완료 phase 부터 재개. 이 스킬 종료.
  - 별개 → STEP 1로

---

## STEP 1: 모듈/스코프 확인

`modules.conf.sh` 의 `MODULES_PATTERN` 에 등록된 모듈 중 어느 것을 건드리는지 빠르게 짚는다.

```
cat .claude/hooks/modules.conf.sh | head -30
```

추정해서 사용자에게 1줄로 확인:
> "이 작업은 `web/` (Next.js 앱) 영역으로 보이는데 맞나요? `api/` 도 같이?"

> **선택 가드:** 대상 모듈에 `<module>/SPEC.md` 가 존재하면 SMALL 디스패치 `[CONTEXT]` / BIG `context.md` Key Files 섹션에 추가하고, implementer가 작업 시작 전에 읽도록 지시한다. 없으면 무시. 템플릿: `dev/templates/SPEC.md`.

답이 나오면 STEP 1.5.

---

## STEP 1.5: Scope Questions (분기 판정 전 필수)

Next.js / TS 가정이니 stack 질문은 없지만, **분기 판정 품질을 좌우하는 5가지** 는 짚고 가야 한다.
요청에서 자명하게 답이 나오는 항목은 추정값을 보여주고 한 번에 확인. 자명하지 않으면 사용자에게 물어본다.

| 질문 | 영향 |
|------|------|
| **기존 코드 확장? 새로 만들기?** | 새로 만들기는 거의 항상 BIG. 확장은 SMALL 가능성. |
| **API 변경 필요? web 만? api 만? 둘 다?** | 둘 다면 BIG 거의 확정 (다레이어). |
| **외부 라이브러리 / 패키지 추가 필요?** | 추가 시 plan에 dep install + lockfile 영향 명시. SMALL → BIG 확률↑. |
| **상태 관리 / 데이터 페칭 패턴?** | RSC fetch / Server Action / SWR / React Query / Zustand 중 어느 패턴? plan의 데이터 플로우 영향. |
| **성능·UX 요구?** | 스트리밍, optimistic UI, suspense boundary, 가상 스크롤 등 비기능 요구사항. plan의 Risk Assessment 에 들어감. |

**한 번에 묶어서 묻는 형식 (예시):**

> 분기 판정 전 다섯 가지 확인:
> 1. 기존 라우트(`web/src/app/profile/page.tsx`) 확장으로 보이는데 맞나요?
> 2. API 쪽도 손봐야 하나요? (예: 새 endpoint, 기존 응답 스키마 변경)
> 3. 외부 패키지 추가 필요? (예: `react-dropzone`, `zod`)
> 4. 데이터 페칭은 RSC fetch / Server Action / 클라이언트 fetch 중 어느 쪽?
> 5. 비기능 요구 (스트리밍, optimistic, 모바일 viewport 등) 고려할 것 있나요?

자명한 답이 보이면 추정값을 옆에 적어서 사용자가 한 번에 yes/no 만 하면 되도록.

**사용자 답변 없이 STEP 2 로 넘어가지 않는다.** 답이 모이면 STEP 2.

---

## STEP 2: 분기 판정 (BIG / SMALL / MICRO)

| 시그널 | BIG | SMALL | MICRO |
|--------|-----|-------|-------|
| 예상 파일 수 | 4개 이상 | 2-3개 | 1개 (import 조정 포함 최대 2개) |
| 새 파일 생성 | 있음 | 없거나 1개 | 없음 |
| 여러 레이어 | API + UI + 타입 | 단일 레이어 | 단일 파일 |
| 모호함 | 요구사항 불명확 | 명확 | 원인 + 수정 방법 모두 특정 가능 |
| 변경 성격 | 설계 필요 | 로직 변경 | 기계적 (설정값, null 체크, 타입 시그니처) |

**MICRO 판정 (3개 모두 충족):**
- 1-2줄 변경
- 원인이 명확 (예: import 경로 오타, prop 누락, 타입 좁히기)
- 단일 파일

**판정 결과를 사용자에게 한 줄로 통보 후 진행:**

> "MICRO 판정 — 코디네이터가 직접 수정합니다." / "SMALL — implementer 1회 디스패치." / "BIG — 플랜 작성 후 진행합니다."

애매하면 한 단계 위로 (MICRO 의심 → SMALL, SMALL 의심 → BIG). MICRO를 잘못 판정하면 도중 BLOCKED → 재디스패치 비용이 큼.

---

## STEP 3a: MICRO 처리

이 스킬은 더 이상 동작하지 않는다. 사용자에게 안내:

> "MICRO 입니다. 변경 위치: `<file>:<line>`. 코디네이터가 직접 수정 + `pnpm typecheck` + 커밋합니다."

코디네이터(메인 세션) 가 이어받아 실행. 끝.

---

## STEP 3b: SMALL 처리

`implementer` 에이전트에 1회 디스패치 형식으로 코디네이터에게 넘긴다. 사용자에게 보일 인계 메시지:

```
[implementer 디스패치]

[FILES]
- web/src/components/<file>.tsx
- web/src/types/<file>.ts (필요 시)

[TASK]
<한 줄 액션>

[VERIFY]
pnpm typecheck && pnpm build
브라우저 스모크: <어디 페이지에서 어떤 동작 확인>

[COMMIT]
SCOPE=$(.claude/hooks/scope-for-staged.sh) || exit 1
git commit -m "[$SCOPE] feat: <한국어 한 줄>"
```

이 스킬은 종료. 코디네이터가 실제 디스패치 실행.

---

## STEP 3c: BIG 처리 — `dev/active/<task-name>/` 3종 생성

태스크 이름은 kebab-case (`dark-mode-toggle`, `profile-upload-413`). 영어 권장 (파일명 안전).

```bash
mkdir -p dev/active/<task-name>
```

세 파일을 다음 템플릿으로 작성:

### `dev/active/<task-name>/<task-name>-plan.md`

```markdown
# <Task Name> - Plan
Last Updated: YYYY-MM-DD

## Executive Summary
2-3 줄. 무엇을 어떻게 왜.

## Current State
지금 어떻게 동작하나, 한계는 뭔가.

## Proposed Solution
아키텍처/데이터 플로우/기술 선택 + 근거. 대안 검토 결과.

## Implementation Phases

### Phase 1: <Name>
**Goal**: 이 phase가 끝나면 무엇이 동작하나.
**Tasks**:
- [ ] Task 1 — File: `web/src/...` — Size: S/M/L/XL
- [ ] Task 2 — File: `api/src/...` — Size: S/M/L/XL

### Phase 2: <Name>
(반복)

## Risk Assessment
- **High**: <위험> — Mitigation: <전략>
- **Medium**: <위험> — Mitigation: <전략>

## Done Checklist
- [ ] `pnpm typecheck` (0 errors)
- [ ] `pnpm build` 성공
- [ ] 브라우저 스모크: <페이지/동작>
- [ ] 모바일(375px)에서 깨지지 않음 (UI 변경 시)
- [ ] Server vs Client component 경계 검증 (RSC 변경 시)
- [ ] API 변경 시 `web` 측 호출부 동기화 확인
```

### `dev/active/<task-name>/<task-name>-context.md`

```markdown
# <Task Name> - Context & Decisions
Last Updated: YYYY-MM-DD

## Status
- Phase: <current>
- Progress: X / Y tasks

## Scope
- 모듈: web / api / web+api
- 영향 범위: <어떤 페이지·라우트·컴포넌트>

## Key Files

**Existing (참고)**:
- `web/src/app/<route>/page.tsx` — <역할>
- `web/src/components/<X>.tsx` — <역할>
- `api/src/routes/<X>.ts` — <역할>

**New (생성 예정)**:
- `web/src/...` — <목적>

## Key Decisions
1. **<Decision>** (YYYY-MM-DD)
   - Rationale: <근거>
   - Alternatives: <검토하고 기각한 대안>

## Known Issues / Blockers
<해결 안 된 것, 워크어라운드, 추후 개선>
```

### `dev/active/<task-name>/<task-name>-tasks.md`

```markdown
# <Task Name> - Task Checklist
Last Updated: YYYY-MM-DD

## Status Legend
- [ ] Not started
- [x] Done
- [~] Skipped
- [!] Blocked

## Progress Summary
0 / N tasks complete

## Phase 1: <Name>
- [ ] <Task 1 description>
  - File: `web/src/...`
  - Details: <요구사항·제약>
  - Acceptance: <어떻게 검증>
  - Size: S/M/L/XL
  - depends: -

- [ ] <Task 2 description>
  - File: `web/src/...`
  - depends: Task 1

## Phase 2: <Name>
(반복)

## Done Checklist
(plan.md 의 Done Checklist 사본 — 모든 phase 끝난 후 코디네이터가 verifier 디스패치 + 빌드 검증)

## Notes
<진행 중 발견·질문>
```

---

## STEP 4: 사용자에게 BIG 결과 보고

```
Plan 작성 완료: dev/active/<task-name>/

**개요**: <2-3 줄>
**스코프**: <web / api / web+api>

**파일**:
- Plan: <task-name>-plan.md
- Context: <task-name>-context.md
- Tasks: <task-name>-tasks.md

**다음 단계**:
1. plan 검토하고 수정 의견 알려주세요.
2. "Phase 1 부터 시작해줘" 라고 하면 implementer 디스패치 시작.

**주요 위험**: <top 2-3>
```

이 스킬은 여기서 종료. 이후 진행은 코디네이터.

---

## Sizing Guide (참고)

S = 30분, M = 1-2시간, L = 2-4시간, XL = 반나절+

## 코디네이터 인계 시 주의

- BIG 의 plan/tasks 작성은 이 스킬이 함. 그 이후 implementer 병렬 디스패치는 코디네이터가 직접.
- depends 가 있는 태스크는 같은 wave 에 넣지 않는다.
- 같은 파일을 수정하는 태스크도 같은 wave 에 넣지 않는다.
- BIG 완료 시 verifier 디스패치 → PASS 시 commit (`scope-for-staged.sh` 헬퍼 사용) → history 기록.
