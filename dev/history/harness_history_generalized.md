# Claude Code Harness — Evolution History (generalized)

`.claude/` 디렉토리(hooks, agents, skills, rules)의 진화 기록. 도메인 색깔(특정 모듈명, 회사 시스템)을 걷어내고 **"왜 이런 구조가 나왔는지"**만 남긴 버전.

> 이 harness는 다스택 모노레포(iOS / Next.js / Go) 환경에서 출발했고, 공개 버전에서는 Next.js / React / TypeScript 부분만 추출했다.

---

## Phase 0 — 초기 골격

기본 라이프사이클과 작성 원칙을 정립.

> **`dev/active` → `dev/done` 라이프사이클**
> 완료된 작업 폴더가 `active/`에 쌓이면 진행 중인 작업과 시각적으로 구분하기 어렵다. `/dev-update`로 점검한 뒤 `done/`으로 아카이브한다.

> **`PROJECT_KNOWLEDGE.md` = "코드를 읽어도 알 수 없는 것"**
> 결정사항·도메인 제약·알려진 함정만 기록한다. LLM에게 기능/파일 목록을 관리시키면 코드와 괴리될 수 있다 — 코드를 source of truth로 둔다.

---

## Phase 1 — 자체 매칭 엔진 폐기, 네이티브 기능으로 전환

`.claude/`가 약 400줄짜리 자체 스킬 매칭 엔진(`skill-rules.json` + `UserPromptSubmit` hook + 세션 플래그)으로 비대해진 시점. Claude Code가 description 기반 auto classification을 네이티브로 지원하면서 자체 엔진이 불필요해졌다.

> **자체 엔진 → 네이티브 auto classification**
> 같은 기능을 두 번 구현하는 구조였다 — 자체 엔진의 유지 비용이 가치보다 컸다. description 필드만 잘 쓰면 매칭 정확도는 동등했다.
> **결과:** hook 8 → 5, hook 이벤트 3 → 2, 약 400줄 제거.

---

## Phase 2 — 멀티에이전트 아키텍처 (현 골격)

실운용에서 누적된 7가지 문제를 한 번에 해결하기 위한 설계서를 작성하고 순차 구현했다. 이 phase가 현재 harness의 골격이다.

### 7가지 문제

1. Opus 싱글 에이전트 — 대화/계획/코딩/검증을 전부 Opus가 담당. context rot + 비용 과잉
2. `CLAUDE.md` 비대 — 모노레포인데 모든 모듈 규칙이 한 파일에 있고, 매 세션마다 무관한 규칙까지 적재
3. `context.md` 일회성 — `/dev-docs` 풀 플래닝 때만 생성, 이후 갱신 없음
4. 글로벌 context 부재 — feature 단위 context만 있고 프로젝트 전체 상태는 알기 어려움
5. `/clear` 타이밍 모름 — context 잔량 가시화 없음
6. 중간 단계 부재 — 풀 플래닝과 즉시 코딩 사이의 경량 모드가 없음
7. 검증 gate 부재 — 완료 선언 전 빌드/stub 체크를 강제하지 못함

### 채택 아키텍처

```
사용자 ─→ Opus (Coordinator: 대화 / 판단 / 디스패치 / plan)
              ├─ implementer (Sonnet) — fresh context로 단일 task 코딩
              ├─ verifier    (Sonnet) — plan vs 코드 독립 대조
              ├─ auto-error-resolver  (Haiku)  — TS 에러 기계적 수정
              └─ frontend-error-fixer (Sonnet) — 빌드/런타임 진단
```

### 핵심 설계 결정

> **planner 별도 서브에이전트 미도입** — Coordinator가 Interview를 직접 수행하므로 요구사항·결정사항을 이미 보유한다. 이를 직렬화해 별도 Opus에 넘기면 비용이 늘고 정보 재해석 리스크가 생긴다.

> **`/dev-docs` BIG/SMALL/MICRO 분기** — 모든 작업을 풀 플래닝으로 처리하는 것도, 모두 즉시 코딩으로 처리하는 것도 비용이 컸다. 5축(파일 수 / 새 파일 / 레이어 / 모호함 / 변경 성격)으로 분기한다.

> **implementer 상태코드 4종 + 처리 매트릭스** — `DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`. 매트릭스가 없으면 LLM이 상황마다 즉흥 판단을 하게 되어 일관성이 떨어진다. "implementer가 DONE이라 했으니 빌드 안 돌려도 됨" 같은 인지 함정을 규칙으로 차단한다.

> **모듈별 `CLAUDE.md` + 글로벌 `coordinator.md`** — Claude Code의 서브디렉토리 `CLAUDE.md` 조건부 로드 활용. 무관한 모듈 규칙은 적재 안 됨.

### 설계 출처

GSD(`gsd-plan-checker`, `gsd-executor`, `gsd-context-monitor`)와 Superpowers(`implementer-prompt`, `spec-compliance-reviewer`) 패턴을 검토한 뒤, 내 워크플로에 맞는 부분만 추출했다. 통째로 도입하지는 않았다.

---

## Phase 3 — 점검과 경량화

- `CLAUDE.md` 182 → 123줄. Coordinator 규칙 분리, 중복 섹션 제거.
- `python3` 의존성 제거 → `awk` / `bash`로 통일해 환경 의존성 회피.
- `/dev-docs` EXIT GATE를 인라인으로 강제. 별도 섹션을 참조하는 방식은 LLM이 자주 스킵했다.

---

## Phase 4 — 리팩토링 직전 상태

누적된 7가지 문제를 명문화한 뒤 Phase 5로 이동:

1. `dev/*-context.md` 7개 — 파일명 반복 나열로 비대, 가치 낮음
2. `stop-context-update.sh` — 디렉토리 매핑 outdated
3. `stop-context-summary-check.sh` — 동일
4. 루트 `CLAUDE.md`의 Directory Structure 섹션 outdated
5. `.claude/rules/` 4개 globs 없이 항상 로드
6. history 기록 강제 장치 부재 (텍스트 규칙 의존)
7. `/dev-docs` 없이 직접 요청 시 범위 폭주 차단 메커니즘 부재

---

## Phase 5 — 대규모 리팩토링: context → history 전환과 hook 재설계

### 5-1: context.md → history.md 전환

> **shell hook 자동 기록을 폐기하고, AI가 자신의 native context로 직접 작성하는 모델로 전환**
>
> 이전 구조에서는 `stop-context-update.sh`가 편집된 파일명을 자동으로 `dev/*-context.md`에 append했다. 하지만 정작 가치 있는 정보(왜 / 어떤 결정 / 폐기한 접근)는 shell hook이 볼 수 없었다.
>
> | 정보 유형 | shell hook 접근 | AI 접근 | 가치 |
> |-----------|:---:|:---:|------|
> | 편집된 파일명 | O | O | 낮음 (`git log --stat` 으로 복원 가능) |
> | **왜 했는지 (동기)** | **X** | **O** | **높음** |
> | **어떤 결정** | **X** | **O** | **높음** |
> | **폐기한 접근** | **X** | **O** | **높음** |
>
> 결론: **AI가 자신의 conversation context로 직접 기록**하고, shell hook은 누락 시 차단만 담당한다(enforcement gate). 별도 transcript 파싱이나 트릭은 쓰지 않는다 — AI가 방금 무엇을 했는지 스스로 알고 있기 때문이다.

### 5-2 ~ 5-4: 구조 정리

- 모듈별 `CLAUDE.md` 도입, `.claude/rules/` 의 모듈별 파일 흡수 후 삭제 (`coordinator.md` 만 글로벌 유지).
- 죽은 hook 2개(`stop-context-update.sh`, `stop-context-summary-check.sh`) 삭제 — 감시 대상 사라져 존재 이유 소멸.
- 루트 `CLAUDE.md` 124 → 104줄.

### 5-5: 커밋 포맷과 history 작성 원칙 확립

> **`[scope] type: 한국어 한 줄` 강제** — 기존 메시지가 들쭉날쭉했다(`Fix:`, `Task 4-5:`, `Update:`). scope/type 자동 추출이 어려웠다. **`commit-msg` hook 도입 기각** — Claude가 커밋하므로 텍스트 규칙으로 충분했고, 별도 hook은 과잉이라고 판단했다.

> **history = "git에서 복원 불가능한 것만"** — 동기 / 대안 검토 / 결정 근거 / 실패한 접근을 기록한다. 파일명 나열·diff·커밋 메시지 반복은 금지한다(`git log --stat`으로 복원 가능). `## 미정리` 섹션에 시간순으로 append하고, 누적되면 손으로 Phase를 정리한다.

### 5-8: stop hook state machine — 커밋과 history 2단계 강제

> **세션별 state 파일로 `stop_hook_active` 1회 차단 한계 우회**
> 공식 가이드는 `stop_hook_active: true`일 때 exit 0을 권장한다(무한루프 방지). 하지만 1회만 차단되면 "커밋 강제 → 그 다음 history 강제" 2단계 확인이 불가능했다.
> 세션별 state 파일(`/tmp/claude-commit-history/{session_id}`)로 자체 state machine: State 0(초기) → State 1(커밋 강제) → State 2(history 강제). max retry 3으로 무한루프 방지.

### 5-9: 빌드 체크 hook 6개 삭제

> **수 주간 미작동했지만 문제가 없었음 → 가치 검증 실패**
> `post-tool-use-tracker.sh` 의 디렉토리 매핑이 리팩토링 후 outdated → 소비 hook 4개(`tsc`, `go-build`, `eslint`, `go-error`) 미작동 상태로 수 주 운영. 그 사이 문제 0건.
> **대안 (경로 수정) 기각:** 본인 주작업이 long-build 환경(예: 모바일 — `xcodebuild ~30s+`) 라 stop hook 빌드 비현실적. 커버리지 절반 이하.
> **대체:** `coordinator.md`와 `CLAUDE.md`의 텍스트 규칙으로 커버한다. 사람과 AI가 모두 읽는 규칙이 hook보다 더 robust하다고 판단했다.

### 5-10: post-scope-escalation.sh — scope 자동 에스컬레이션

> **`/dev-docs` 없이 모듈 파일 3개 이상 편집 시 hard block**
> `coordinator.md`의 "범위가 커지면 `/dev-docs` 권유" 규칙은 텍스트 Red Flag에 가까웠고, context 압축 시 LLM이 빠뜨릴 수 있었다. PostToolUse `decision: "block"`으로 기계적 강제.
> threshold: 1개는 통과 / 2개는 soft warning / 3개 이상은 hard block. 카운터는 `git commit` 감지 시 리셋한다(새 작업 사이클).

### 5-12: hook 별도 문서 폐기

> **`SETUP.md`, `README.md`, `CONFIG.md` 삭제 → hook 파일 상단 주석으로 인라인화**
> 3개 문서는 hook 추가/삭제마다 동기화가 필요했다. outdated 문서는 오히려 더 큰 문제가 됐다. 각 hook 파일 상단에 역할/exit code/input을 명시해 단일 source of truth로 둔다.

---

## Phase 6 — 공개 준비

내부 harness를 외부용으로 추출했다. 도메인 정보를 분리하고 일관된 narrative로 정리했다.

> **stack-agnostic → Next.js / React / TypeScript / pnpm 락인**
> 공개 시 첫인상을 sharp하게 가져가는 것이 중요했다. "stack-agnostic"은 모호하고 demoability가 낮았다. 청중 손실(Go/Swift/Python)을 감수하고 더 sharp한 pitch를 선택했다. README 첫 줄에 "패턴은 stack 무관, 포함된 에이전트만 Next.js 전제"라고 명시했다 — 다른 스택은 본문을 swap하면 된다.

> **planner 에이전트 삭제 — 정합성 정리**
> Phase 2 결정에도 불구하고 `planner.md`가 남아 있어 `CLAUDE.md` / `README.md` / agents README 사이에 모순이 있었다. plan 작성 책임은 dev-docs 스킬이 담당한다.

> **scope 자동 추출 헬퍼 (`scope-for-staged.sh`) — 커밋 형식 강제의 마지막 조각**
> Phase 5-5 의 `[scope]` 형식 강제는 사람이 매번 입력 → 오타·누락 시 stop hook silent pass.
> staged 파일의 top-level directory를 `dir_to_scope`로 자동 매핑한다. 다중 모듈이 staged된 경우에는 거부해 커밋 분리를 강제한다.
> **stop hook 강화 병행:** 최근 5분 commit에 prefix가 없으면 reject하고 amend 명령을 제시한다. **사전 자동화(헬퍼) + 사후 검증(stop hook)의 두 층 방어.**

> **`/dev-docs` 스킬 ship — generic 버전**
> 도메인 keyword detection을 빼고 BIG/SMALL/MICRO 판정과 plan/context/tasks 3종 템플릿만 남겼다. **STEP 1.5(scope 인터뷰)** 추가: 기존 확장 vs 신규 · API 변경 · 외부 라이브러리 · 데이터 페칭 · 비기능 요구. stack 인터뷰는 사라졌지만, 분기 품질을 좌우하는 질문은 살렸다.

> **`.claude` 추적 기본 비활성**
> 클론한 사람이 settings를 수정할 때 self-block되는 상황을 방지하기 위함. README에 "harness 자체 추적 활성화 (선택)" 섹션을 두어, 안정화 후 직접 켤 수 있게 했다.

> **두 층 영속화 모델 명문화(commit vs history)**
> commit(push) = WHAT 요약 / 외부용 / scope 자동. history(`.gitignore`) = WHY / 폐기한 대안 / AI 컨텍스트 + 개인 working notebook. messy해도 괜찮은 계층으로 분리했다. README 첫 화면에 명시해 "왜 push 안 함?"이라는 의문을 선제적으로 차단했다.

---

## Key Decisions

| 결정 | 한 줄 근거 |
|------|----------|
| 네이티브 auto classification | description만 잘 쓰면 자체 매칭 엔진 불필요. 약 400줄 제거 |
| Coordinator + 서브에이전트 | Opus 싱글의 context rot + 비용 해소. task별 fresh context |
| planner 미도입 | Coordinator가 Interview 보유 → 직렬화 비용 회피 |
| `/dev-docs` BIG/SMALL/MICRO | 풀 플래닝 vs 그냥 코딩 사이의 경량 모드 부재 해소 |
| 모듈별 `CLAUDE.md` > rules/+globs | 공식 동작은 동등하고, 모듈 구조에는 더 자연스러움 |
| **history는 Claude가 직접 작성** | shell hook은 대화 context 접근 불가 |
| state machine으로 2단계 강제 | `stop_hook_active` 1회 한계 우회 |
| 빌드 체크 hook 전부 삭제 | 미작동 상태로 문제없이 운영 → 가치 검증 실패 |
| `commit-msg` hook 기각 | Claude가 커밋하므로 텍스트 규칙으로 충분 |
| scope 에스컬레이션 = PostToolUse block | Red Flag 텍스트 의존 대신 기계적 강제 |
| `scope-for-staged.sh` 헬퍼 | 사전 자동화 + stop hook 사후 검증 두 층 방어 |
| Next.js/TS 락인 (공개) | sharper pitch + demoability |

---

## Dead ends (재탐색 금지)

| 접근 | 폐기 이유 |
|------|----------|
| 자체 스킬 매칭 엔진 | 네이티브가 동등 기능 제공 |
| python3 hooks | 환경 의존성, awk/bash 충분 |
| shell hook으로 history 자동 기록 | 대화 context 접근 불가 |
| 빌드 체크 stop hooks | 경로 outdated + long-build 커버 불가 + 미작동 상태에서도 문제없음 |
| `post-tool-use-tracker.sh` | 소비 hook 전부 삭제로 존재 이유 소멸 |
| `commit-msg` hook | Claude가 커밋하므로 과잉 |
| hook에서 `/dev-docs` 직접 실행 | 공식 제약상 안내까지만 가능 |
| hook에서 history 내용 품질 체크 | shell hook은 기록 여부만 확인 가능 |
| `.agents/skills/` 경로 | 공식 미인식 + symlink git 관리 부담 |
| hook 별도 문서(SETUP/README/CONFIG) | 동기화 부담이 커서 파일 상단 주석으로 통일 |
| `planner` 별도 서브에이전트 | Coordinator가 Interview 보유 |
| `transcript_path` 트릭으로 history 자동 | AI가 자기 컨텍스트로 직접 쓰는 게 더 단순 |
