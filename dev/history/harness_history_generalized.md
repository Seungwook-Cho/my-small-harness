# Claude Code Harness — Evolution History (generalized)

`.claude/` 디렉토리(hooks, agents, skills, rules) 의 진화 기록. 도메인 색깔(특정 모듈명, 회사 시스템)을 걷어내고 **"왜 이런 구조가 나왔는지"** 만 남긴 버전.

> 본 harness 는 다스택 모노레포(iOS / Next.js / Go) 환경에서 출발했고, 공개 버전에선 Next.js/React/TS 부분만 추출.

---

## Phase 0 — 초기 골격

기본 라이프사이클·작성 원칙 정립.

> **`dev/active` → `dev/done` 라이프사이클**
> 완료 작업 폴더가 `active/` 에 쌓이면 진행 중 작업과 시각적 구분 불가. `/dev-update` 로 점검 후 done/ 으로 아카이브.

> **`PROJECT_KNOWLEDGE.md` = "코드를 읽어도 알 수 없는 것"**
> 결정사항·도메인 제약·알려진 함정만. LLM 에게 기능/파일 목록을 관리시키면 코드와 괴리 — 코드가 진실.

---

## Phase 1 — 자체 매칭 엔진 폐기, 네이티브 전환

`.claude/` 가 ~400줄짜리 자체 스킬 매칭 엔진(`skill-rules.json` + `UserPromptSubmit` hook + 세션 플래그)으로 비대해진 시점. Claude Code 가 description 기반 auto classification 을 네이티브 지원하면서 자체 엔진 불필요.

> **자체 엔진 → 네이티브 auto classification**
> 같은 기능 두 번 구현 — 자체 엔진 유지 비용 > 가치. description 필드만 잘 쓰면 매칭 정확도 동등.
> **결과:** hook 8 → 5, hook 이벤트 3 → 2, ~400줄 제거.

---

## Phase 2 — 멀티에이전트 아키텍처 (현 골격)

실운용에서 누적된 7가지 문제를 한 번에 해결할 설계서를 작성하고 순차 구현. 이 phase 가 현재 harness 의 골격.

### 7가지 문제

1. Opus 싱글 에이전트 — 대화/계획/코딩/검증 전부 Opus. context rot + 비용 과잉
2. `CLAUDE.md` 비대 — 모노레포인데 모든 모듈 규칙이 한 파일, 매 세션 무관 규칙까지 적재
3. `context.md` 일회성 — `/dev-docs` 풀 플래닝 때만 생성, 이후 갱신 없음
4. 글로벌 context 부재 — feature 단위 context 만 있고 프로젝트 전체 상태 unknown
5. `/clear` 타이밍 모름 — context 잔량 가시화 없음
6. 중간 단계 부재 — 풀 플래닝 vs 그냥 코딩 사이가 비어 있음
7. 검증 gate 부재 — 완료 선언 전 빌드/stub 체크 강제 없음

### 채택 아키텍처

```
사용자 ─→ Opus (Coordinator: 대화 / 판단 / 디스패치 / plan)
              ├─ implementer (Sonnet) — fresh ctx 로 단일 task 코딩
              ├─ verifier    (Sonnet) — plan vs 코드 독립 대조
              ├─ auto-error-resolver  (Haiku)  — TS 에러 기계적 수정
              └─ frontend-error-fixer (Sonnet) — 빌드/런타임 진단
```

### 핵심 설계 결정

> **planner 별도 서브에이전트 미도입** — Coordinator 가 Interview 직접 수행 → 요구사항·결정사항을 이미 보유. 직렬화해서 별도 Opus 에 넘기면 비용 2배 + 정보 재해석 리스크.

> **`/dev-docs` BIG/SMALL/MICRO 분기** — 전부 풀 플래닝도, 전부 그냥 코딩도 비용 큼. 5축(파일 수 / 새 파일 / 레이어 / 모호함 / 변경 성격)으로 분기.

> **implementer 상태코드 4종 + 처리 매트릭스** — `DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`. 매트릭스가 없으면 LLM 이 상황마다 즉흥 판단 → 일관성 없음. "implementer 가 DONE 이라 했으니 빌드 안 돌려도 됨" 같은 인지 함정을 규칙으로 차단.

> **모듈별 `CLAUDE.md` + 글로벌 `coordinator.md`** — Claude Code 의 서브디렉토리 `CLAUDE.md` 조건부 로드 활용. 무관한 모듈 규칙은 적재 안 됨.

### 설계 출처

GSD (`gsd-plan-checker`, `gsd-executor`, `gsd-context-monitor`) + Superpowers (`implementer-prompt`, `spec-compliance-reviewer`) 패턴 검토 후 본인 워크플로에 맞는 부분만 추출. 통째 도입 안 함.

---

## Phase 3 — 점검·경량화

- `CLAUDE.md` 182 → 123줄. Coordinator 규칙 분리, 중복 섹션 제거.
- `python3` 의존성 제거 → `awk` / `bash` 통일 (환경 의존성 회피).
- `/dev-docs` EXIT GATE 인라인 강제 (별도 섹션 참조 방식이 LLM 에게 자주 스킵됨).

---

## Phase 4 — 리팩토링 직전 스냅샷

누적된 7가지 문제 명문화 후 Phase 5 로:

1. `dev/*-context.md` 7개 — 파일명 반복 나열로 비대, 가치 낮음
2. `stop-context-update.sh` — 디렉토리 매핑 outdated
3. `stop-context-summary-check.sh` — 동일
4. 루트 `CLAUDE.md` Directory Structure outdated
5. `.claude/rules/` 4개 globs 없이 항상 로드
6. history 기록 강제 장치 부재 (텍스트 규칙 의존)
7. `/dev-docs` 없이 직접 요청 시 범위 폭주 차단 메커니즘 부재

---

## Phase 5 — 대규모 리팩토링: context → history + hook 재설계

### 5-1: context.md → history.md 전환 (핵심 인사이트)

> **shell hook 자동 기록 폐기, AI 가 자기 native context 로 직접 작성하는 모델로 전환**
>
> 이전 구조에선 `stop-context-update.sh` 가 편집된 파일명을 자동으로 `dev/*-context.md` 에 append. 그런데 정작 가치 있는 정보(왜 / 어떤 결정 / 폐기한 접근)는 shell hook 이 못 봄.
>
> | 정보 유형 | shell hook 접근 | AI 접근 | 가치 |
> |-----------|:---:|:---:|------|
> | 편집된 파일명 | O | O | 낮음 (`git log --stat` 으로 복원 가능) |
> | **왜 했는지 (동기)** | **X** | **O** | **높음** |
> | **어떤 결정** | **X** | **O** | **높음** |
> | **폐기한 접근** | **X** | **O** | **높음** |
>
> 결론: **AI 가 자기 conversation context 로 직접 기록**, shell hook 은 누락 시 차단만 (enforcement gate). 별도 transcript 파싱이나 트릭 없음 — AI 가 방금 자기가 무얼 했는지 본인이 아니까.

### 5-2 ~ 5-4: 정리

- 모듈별 `CLAUDE.md` 도입, `.claude/rules/` 의 모듈별 파일 흡수 후 삭제 (`coordinator.md` 만 글로벌 유지).
- 죽은 hook 2개(`stop-context-update.sh`, `stop-context-summary-check.sh`) 삭제 — 감시 대상 사라져 존재 이유 소멸.
- 루트 `CLAUDE.md` 124 → 104줄.

### 5-5: 커밋 포맷 + history 작성 원칙 확립

> **`[scope] type: 한국어 한 줄` 강제** — 기존 메시지가 들쭉날쭉(`Fix:`, `Task 4-5:`, `Update:`). scope/type 자동 추출 불가. **`commit-msg` hook 도입 기각** — Claude 가 커밋하니 텍스트 규칙으로 충분, hook 은 과잉.

> **history = "git 에서 복원 불가능한 것만"** — 동기 / 대안 검토 / 결정 근거 / 실패한 접근. 파일명 나열·diff·커밋 메시지 반복 금지(`git log --stat` 으로 복원 가능). `## 미정리` 섹션 시간순 append → 누적되면 손으로 Phase 정리.

### 5-8: stop hook state machine — 커밋 + history 2단계 강제

> **세션별 state 파일로 `stop_hook_active` 1회 차단 한계 우회**
> 공식 가이드는 `stop_hook_active: true` 일 때 exit 0 권장(무한루프 방지)이지만, 1회만 차단되면 "커밋 강제 → 그 다음 history 강제" 2단계 불가.
> 세션별 state 파일(`/tmp/claude-commit-history/{session_id}`) 로 자체 state machine: State 0(초기) → State 1(커밋 강제) → State 2(history 강제). max retry 3 으로 무한루프 방지.

### 5-9: 빌드 체크 hook 6개 일괄 삭제

> **수 주간 미작동했으나 문제 없었음 → 가치 검증 실패**
> `post-tool-use-tracker.sh` 의 디렉토리 매핑이 리팩토링 후 outdated → 소비 hook 4개(`tsc`, `go-build`, `eslint`, `go-error`) 미작동 상태로 수 주 운영. 그 사이 문제 0건.
> **대안 (경로 수정) 기각:** 본인 주작업이 long-build 환경(예: 모바일 — `xcodebuild ~30s+`) 라 stop hook 빌드 비현실적. 커버리지 절반 이하.
> **대체:** `coordinator.md` + `CLAUDE.md` 의 텍스트 규칙으로 커버. 사람·AI 둘 다 읽는 규칙이 hook 보다 robust.

### 5-10: post-scope-escalation.sh — Scope 자동 에스컬레이션

> **`/dev-docs` 없이 모듈 파일 3개+ 편집 시 hard block**
> `coordinator.md` 의 "범위 커지면 `/dev-docs` 권유" 가 텍스트 Red Flag → context 압축 시 LLM 이 빠뜨림. PostToolUse `decision: "block"` 으로 기계적 강제.
> threshold: 1 통과 / 2 soft 경고 / 3+ hard block. 카운터는 `git commit` 감지 시 리셋(새 작업 사이클).

### 5-12: hook 별도 문서 폐기

> **`SETUP.md`, `README.md`, `CONFIG.md` 삭제 → hook 파일 상단 주석 인라인**
> 3개 문서가 hook 추가/삭제마다 동기화 필요. outdated 문서 = 더 큰 문제. 각 hook 파일 상단에 역할/exit code/input 명시. 단일 source of truth.

---

## Phase 6 — 공개 준비

내부 harness 를 외부용으로 추출. 도메인 분리 + 일관 narrative.

> **stack-agnostic → Next.js / React / TS / pnpm 락인**
> 공개 시 첫인상 sharp 해야 함. "stack-agnostic" 은 모호하고 demoability 낮음. 청중 손해(Go/Swift/Python) 받아들이고 sharper pitch 채택. README 첫 줄에 "패턴은 stack 무관, ship 된 에이전트만 Next.js 전제" 명시 — 다른 스택은 본문 swap.

> **planner 에이전트 삭제 — 정합성 정리**
> Phase 2 결정에도 불구하고 `planner.md` 가 남아 있어 CLAUDE/README/agents-README 셋이 모순. dev-docs 스킬이 plan 작성 책임.

> **scope 자동 추출 헬퍼 (`scope-for-staged.sh`) — 커밋 형식 강제의 마지막 조각**
> Phase 5-5 의 `[scope]` 형식 강제는 사람이 매번 입력 → 오타·누락 시 stop hook silent pass.
> staged 파일 top-level dir → `dir_to_scope` 매핑 자동. 다중 모듈 staging 시 거부(커밋 분리 강제).
> **stop hook 강화 병행:** 최근 5분 commit 에 prefix 없으면 reject + amend 명령 제시. **사전 자동화(헬퍼) + 사후 검증(stop hook) 두 층 방어.**

> **`/dev-docs` 스킬 ship — generic 버전**
> 도메인 keyword detection 빼고 BIG/SMALL/MICRO 판정 + plan/context/tasks 3종 템플릿만. **STEP 1.5 (scope 인터뷰)** 추가: 기존 확장 vs 신규 · API 변경 · 외부 라이브러리 · 데이터 페칭 · 비기능 요구. stack 인터뷰는 사라졌지만 분기 품질 좌우 질문은 살림.

> **`.claude` 추적 기본 비활성**
> 클론한 사람이 settings 손볼 때 self-block 방지. README 에 "harness 자체 추적 활성화 (선택)" 섹션 — 안정화 후 직접 켜는 옵션.

> **두 층 영속화 모델 명문화 (commit vs history)**
> commit(push) = WHAT 요약 / 외부용 / scope 자동. history(`.gitignore`) = WHY / 폐기한 대안 / AI 컨텍스트 + 본인 working notebook. messy 해도 OK 한 분리. README 첫 화면 명시로 "왜 push 안 함?" 의문 선제 차단.

---

## Key Decisions

| 결정 | 한 줄 근거 |
|------|----------|
| 네이티브 auto classification | description 만 잘 쓰면 자체 매칭 엔진 불필요. ~400줄 제거 |
| Coordinator + 서브에이전트 | Opus 싱글의 context rot + 비용 해소. fresh ctx per task |
| planner 미도입 | Coordinator 가 Interview 보유 → 직렬화 비용 회피 |
| `/dev-docs` BIG/SMALL/MICRO | 풀 플래닝 vs 그냥 코딩 사이의 경량 모드 부재 해소 |
| 모듈별 `CLAUDE.md` > rules/+globs | 공식 동작 동등, 모듈 구조에 더 자연스러움 |
| **history 는 Claude 가 직접 작성** | shell hook 은 대화 context 접근 불가 |
| state machine 으로 2단계 강제 | `stop_hook_active` 1회 한계 우회 |
| 빌드 체크 hook 전부 삭제 | 미작동 상태로 문제없이 운영 → 가치 검증 실패 |
| `commit-msg` hook 기각 | Claude 가 커밋하니 텍스트 규칙으로 충분 |
| scope 에스컬레이션 = PostToolUse block | Red Flag 텍스트 의존 대신 기계적 강제 |
| `scope-for-staged.sh` 헬퍼 | 사전 자동화 + stop hook 사후 검증 두 층 방어 |
| Next.js/TS 락인 (공개) | sharper pitch + demoability |

---

## Dead-end (재탐색 금지)

| 접근 | 폐기 이유 |
|------|----------|
| 자체 스킬 매칭 엔진 | 네이티브가 동등 기능 |
| python3 hooks | 환경 의존성, awk/bash 충분 |
| shell hook 으로 history 자동 기록 | 대화 context 접근 불가 |
| 빌드 체크 stop hooks | 경로 outdated + long-build 커버 불가 + 미작동인데 문제없음 |
| `post-tool-use-tracker.sh` | 소비 hook 전부 삭제로 존재 이유 소멸 |
| `commit-msg` hook | Claude 커밋하니 과잉 |
| hook 에서 `/dev-docs` 직접 실행 | 공식 제약, 안내까지만 |
| hook 에서 history 내용 품질 체크 | shell hook 은 기록 여부만 가능 |
| `.agents/skills/` 경로 | 공식 미인식 + symlink git 관리 부담 |
| hook 별도 문서 (SETUP/README/CONFIG) | 동기화 부담, 파일 상단 주석으로 통일 |
| `planner` 별도 서브에이전트 | Coordinator 가 Interview 보유 |
| `transcript_path` 트릭으로 history 자동 | AI 가 자기 컨텍스트로 직접 쓰는 게 더 단순 |
