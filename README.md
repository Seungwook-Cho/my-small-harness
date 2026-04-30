# my-small-harness

**Solo developer 용 Next.js 16 / React 19 / TypeScript 5 / pnpm 모노레포 Claude Code harness.**
Coordinator(Opus) + implementer/verifier(Sonnet) 분업 · `/dev-docs` 라이프사이클(BIG/SMALL/MICRO) · scope 자동 추출 · 커밋·history 강제 hook · TypeScript 에러 자동 수정 에이전트.

> **AI 를 코딩 보조 도구로 쓰기 위한 실험.**
> AI 가 처음부터 끝까지 만들어주는 "vibe coding" 이 아니라, **본인이 어디를 어떻게 고칠지 이미 아는 상태**에서 실행 가속·기계적 fix·결정 기록 자동화에 AI 를 붙이는 방향. 모든 분업·분기·hook 이 이 전제 위에서 설계됨 — 사용자의 판단을 대체하지 않고 보조한다.

---

## 만든 이유 — 실사용 경험에서

### 1. Fresh context 와 `/clear` 의 trade-off

세션이 길어지면 Claude 답변 품질이 눈에 띄게 떨어진다. `/clear` 로 fresh context 를 만들면 회복되지만, 이전에 합의한 plan / 결정 / 진행 상태를 다 잊는다. 매번 처음부터 설명하는 게 가장 큰 비용.

→ `dev/active/<task>/` 안에 plan / context / tasks 3종을 두고 fresh 시작 시 자동 로드. **잊어도 되는 건 잊고, 보존할 가치 있는 것만 명시적으로 재주입.**

### 2. 모델 분업 — Sonnet 코딩, Opus planning

직접 비교: 코딩 품질은 **Sonnet 으로 충분**. Opus 의 진짜 강점은 **planning / 판단 / dispatch / 결과 해석**. 모든 걸 Opus 에 맡기면 비싸기만 하고 코딩 품질 차이는 미미.

→ Coordinator(Opus) 는 디스패치·plan 만, 코딩(implementer)·검증(verifier)은 Sonnet, TS 에러 정리는 Haiku. **비용 절반, 품질 동등.**

### 3. commit 은 필수, PR 은 오버헤드

Claude 가 revert 할 때 / 무엇이 바뀌었는지 확인할 때 / 다른 작업에서 변경 이력 참조할 때 — 모두 commit 단위로 동작. 그런데 솔로 작업에 매번 PR 올리고 머지하는 건 형식적 오버헤드만 되고 정보 가치는 없음.

→ commit 은 hook 으로 강제, PR 워크플로는 out of scope. **`history.md` 가 PR description 역할 (WHY · 검토한 대안 · 실패한 시도) 을 대체.**

### 4. 워크플로의 무게에 대한 고민

유명 harness들(GSD, Superpowers 류) 을 검토하면서 든 느낌은, **어디를 어떻게 고칠지 이미 아는 단순한 fix 에도 인터뷰 → planning → 다단계 서브에이전트가 도는 경향이 있어 헤비하게 느껴졌다**. 작업마다 규모가 다른데 한 가지 흐름만 있으면 짧은 작업에선 오버헤드.

→ `/dev-docs` 가 BIG/SMALL/MICRO 분기 → **가볍게 쓸 일은 가볍게**. MICRO(1-2줄) 는 Coordinator 직접, SMALL 은 implementer 1회, BIG 만 풀 파이프라인.

### 5. "완료" 보고하고 commit / history 망각

Claude 가 작업 완료 보고를 한 뒤 commit 을 빠뜨리거나, commit 만 하고 `history.md` 기록을 누락한 채 세션을 끝내는 경우가 잦았다. 다음 세션에서 보면 "이 변경 왜 했지?" 가 사라져 있음 — `git log` 는 WHAT 만 남기고 WHY 는 망각된 상태.

→ Stop hook (`stop-commit-history-check.sh`) 으로 **세션 종료 자체를 게이트로 활용**. 모듈 코드 수정 후 커밋 누락이면 차단, 커밋했으나 history 누락이면 차단. Stop hook 이 공식적으로 1회만 차단 가능한 한계를 세션별 state 파일로 우회 → 두 단계 순차 강제 가능.

---

## 핵심 컨셉

### Coordinator + 서브에이전트 분업

메인 세션(Opus)은 **대화·판단·디스패치·plan 작성**만. 실제 코딩·검증·에러 수정은 fresh context 의 별도 에이전트로 분리. Coordinator context 를 빌드 로그/grep 결과로 더럽히지 않기 위함.

```
                              사용자
                                │
                                ▼
        ┌───────────────────────────────────────────────┐
        │           Coordinator   (Opus 4.7)            │
        │     대화 / 판단 / 디스패치 / plan 작성         │
        └───────┬───────────┬────────────┬──────────────┘
                │           │            │
        dispatch│           │            │
                ▼           ▼            ▼
        ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
        │ implementer │ │  verifier   │ │ error fixers│
        │   Sonnet    │ │   Sonnet    │ │             │
        ├─────────────┤ ├─────────────┤ ├─────────────┤
        │ 단일 task   │ │ plan vs 코드│ │ auto-error- │
        │ fresh ctx   │ │ 독립 대조   │ │ resolver    │
        │ 빌드+커밋   │ │ stub/완성도 │ │   (Haiku)   │
        │ 자체수정 ≤2 │ │ PASS / FAIL │ │ TS 에러 자동│
        │             │ │             │ │             │
        │ DONE /      │ │             │ │ frontend-   │
        │ NEEDS_CTX / │ │             │ │ error-fixer │
        │ BLOCKED 보고│ │             │ │   (Sonnet)  │
        └─────────────┘ └─────────────┘ └─────────────┘
```

각 서브에이전트는 **fresh context** 로 받음. Coordinator 가 인계 시 `[FILES]` / `[TASK]` / `[VERIFY]` / `[COMMIT]` 블록으로 명시적 인터페이스. 결과는 상태코드로 회신 → Coordinator 가 매트릭스대로 분기.

### /dev-docs 라이프사이클 (BIG / SMALL / MICRO)

`/dev-docs <작업>` → 스킬이 **5축 시그널**로 분기 판정 → 분기별 다른 처리.

```
                       /dev-docs <작업 설명>
                              │
                              ▼
             ┌────────────────────────────────┐
             │ STEP 0:  dev/active/ 진행 중?  │
             │ STEP 1:  어느 모듈? (web/api)   │
             │ STEP 1.5: scope 질문 5종       │
             │   (확장? API? lib? fetch? 성능?)│
             │ STEP 2:  분기 판정              │
             └─────────────────┬──────────────┘
                               │
              ┌────────────────┼─────────────────┐
              ▼                ▼                 ▼
         ┌─────────┐      ┌─────────┐       ┌─────────┐
         │  MICRO  │      │  SMALL  │       │   BIG   │
         │  1-2줄  │      │ 2-3파일 │       │ 다파일  │
         │ 단일파일│      │ 단일레이어│       │ 다레이어│
         └────┬────┘      └────┬────┘       └────┬────┘
              │                │                 │
              ▼                ▼                 ▼
        Coordinator      implementer        dev/active/<task>/
        직접 수정         1회 디스패치          ├─ plan.md
        + pnpm typecheck  + 빌드 + 커밋        ├─ context.md
        + [scope] 커밋                          └─ tasks.md
                                                     │
                                                     ▼
                                              implementer × N
                                              (depends 기반 병렬 wave)
                                                     │
                                                     ▼
                                              verifier (fresh)
                                              ├─ PASS → 다음
                                              └─ FAIL → 재디스패치
                                                     │
                                                     ▼
                                              [scope] type: 커밋
                                              + history `## 미정리`
                                                append
```

| 축 | BIG | SMALL | MICRO |
|----|-----|-------|-------|
| 파일 수 | 4개+ | 2-3개 | 1개 (max 2) |
| 새 파일 | 있음 | 0-1개 | 없음 |
| 레이어 | API+UI+타입 | 단일 | 단일 파일 |
| 모호함 | 요구사항 불명확 | 명확 | 원인+수정 모두 특정 |
| 변경 성격 | 설계 필요 | 로직 변경 | 기계적 |

자세한 룰은 [.claude/skills/dev-docs/SKILL.md](.claude/skills/dev-docs/SKILL.md).

### 두 층 기록 — commit vs history

| 층 | 위치 | 내용 | 청중 |
|----|------|------|------|
| **commit** (push) | git log | `[scope] type: 한국어 한 줄` — WHAT 요약 | 외부 협업·revert |
| **history** (`.gitignore`) | `dev/history/{scope}-history.md ## 미정리` | WHY · 검토한 대안 · 실패한 시도 | AI 컨텍스트 + 본인 working notebook |

scope 는 [`scope-for-staged.sh`](.claude/hooks/scope-for-staged.sh) 가 staged 파일의 top-level dir 로 자동 추출. 다중 모듈 staging 시 거부(커밋 분리 강제). history 는 messy 해도 OK 한 layer — push 부담 없도록 의도적 분리.

### scope-escalation hook

`/dev-docs` 없이 같은 모듈 파일 3개+ 편집하면 PostToolUse hook 이 hard block. 즉흥 코딩이 BIG 으로 번지는 걸 기계적으로 차단(텍스트 Red Flag 가 LLM 에게 자주 스킵되는 문제 우회).

---

## Scope 명시 — out of scope

**솔로 dev 의 productivity tool.** 팀 협업(PR 자동 생성 / 코드리뷰 봇 / CI gating) 은 **out of scope** — GitHub native 도구가 잘 함. 이 harness 가 채우는 빈자리는 (a) Claude Code 와 일할 때의 분업 + 자동화, (b) `git log` 로 복원 안 되는 정보 보존 두 개로 한정.

**stack lock-in.** harness 의 패턴 자체(분업·분기·hook·scope·history)는 스택 무관. 다만 ship 된 에이전트와 스킬은 **Next.js / React / TS / pnpm 전제** — 다른 스택이면 `auto-error-resolver` / `frontend-error-fixer` / `dev-docs` 본문을 자기 스택 도구로 swap.

이 repo 는 다음 Next.js 프로젝트에서도 계속 쓰려고 분리 + 포트폴리오 목적. 모듈명·scope·history 매핑은 placeholder (`web` / `api`) — 본인 프로젝트에 맞게 수정.

---

## 구성

```
.claude/
├── settings.json           # hook 등록, 권한, statusline
├── agents/                 # 서브에이전트 (implementer / verifier / 에러 픽서)
├── hooks/                  # PreToolUse / PostToolUse / Stop / Notification + scope helper
├── rules/coordinator.md    # Coordinator 운영 규칙
└── skills/dev-docs/        # /dev-docs 스킬 (BIG/SMALL/MICRO 분기 + 템플릿)
dev/
└── history/
    ├── harness_history_generalized.md  # 진화 기록 (참고용 reference doc)
    └── TEMPLATE.md                      # 새 모듈 history 시작용 템플릿
```

`.claude/skills/` 는 `dev-docs` 만 동봉. 스택별 가이드라인 스킬은 도메인 종속이 강해서 새 프로젝트마다 직접 작성.
`dev/active/`, `dev/done/` 은 `.gitignore` — `/dev-docs` 가 BIG 판정 시 자동 생성.

## 에이전트

| 에이전트 | 모델 | 역할 |
|---------|------|------|
| `implementer` | Sonnet | SMALL/BIG 태스크 코딩 + 빌드 + 커밋 |
| `verifier` | Sonnet | plan vs 코드 독립 대조 (fresh context) |
| `auto-error-resolver` | Haiku | TS 컴파일 에러 기계적 수정 (자족형 — 직접 `tsc` 실행) |
| `frontend-error-fixer` | Sonnet | Next.js / React 빌드·런타임 에러 진단 |

자세한 규칙은 [.claude/rules/coordinator.md](.claude/rules/coordinator.md).

## Hook (settings.json 등록)

| 타이밍 | 파일 | 동작 |
|--------|------|------|
| PreToolUse (Edit/Write) | `pre-env-protect.sh` | `.env*` 편집 차단 |
| PostToolUse (Edit/Write/Bash) | `post-scope-escalation.sh` | 모듈 파일 3개+ 편집 시 `/dev-docs` 강제 |
| PostToolUse (모든 툴) | `context-monitor.js` | context 잔량 낮으면 경고 주입 |
| Stop | `stop-clear-check.js` | `tasks.md` 전부 체크되면 `/clear` 추천 |
| Stop | `stop-commit-history-check.sh` | 모듈 코드 수정 시 commit + history 기록 강제 (state machine) |
| statusLine | `context-statusline.js` | 모델 / 작업 / context 잔량 표시 |

추가 헬퍼: [`scope-for-staged.sh`](.claude/hooks/scope-for-staged.sh) — staged 파일에서 `[scope]` 자동 추출.

---

## 초기 설정

```bash
chmod +x .claude/hooks/*.sh
```

별도 설치 없음. node hook 들은 built-in 모듈(`fs`, `path`, `os`)만 사용.

복사해온 직후 할 것:

1. **모듈 매핑 — [.claude/hooks/modules.conf.sh](.claude/hooks/modules.conf.sh) 한 군데만**
   - 기본 placeholder: `web/`, `api/`. 본인 디렉토리 구조에 맞게 교체.
   - `MODULES_PATTERN` (정규식) / `dir_to_scope` (커밋 prefix) / `scope_to_history` (파일 경로) 셋 다 한 파일에서 관리.
2. `dev/history/{module}-history.md` 생성 — 빈 파일 대신 템플릿 복사 권장:
   ```bash
   cp dev/history/TEMPLATE.md dev/history/web-history.md
   cp dev/history/TEMPLATE.md dev/history/api-history.md
   ```
   (없으면 stop hook 이 fail)
3. **권한 모드 확인** — [`.claude/settings.json`](.claude/settings.json) 은 `acceptEdits` + `Bash:*` 풀 허용. 보수적으로 시작하려면 `defaultMode` 를 `default` 로.

### 커밋 흐름

```bash
SCOPE=$(.claude/hooks/scope-for-staged.sh) || exit 1
git commit -m "[$SCOPE] feat: 한국어 한 줄"
```

stop hook 이 `[scope] type: ...` 형식 강제. prefix 누락 시 reject + amend 명령 제시.

### harness 자체 추적 활성화 (선택)

기본값은 `.claude/` 가 추적 대상에서 빠짐 (첫 사용자 self-block 방지). 워크플로 안정화 후 켜고 싶다면 `modules.conf.sh` 에 `\.claude` / `harness` 스코프 + 본인 history 파일 매핑 추가.

---

## 한국어 사용법

```
[세션 시작]  CLAUDE.md 자동 로드, dev/active/ 진행 중이면 이어서

1. /dev-docs 다크모드 토글
   → 스킬이 모듈 + scope 5질문 + BIG/SMALL/MICRO 판정
   → BIG 이면 dev/active/dark-mode-toggle/ 3종 자동 생성

2. "Phase 1 부터 시작해줘"
   → Coordinator 가 implementer 디스패치
   → 완료 후 verifier 디스패치
   → PASS → commit + history 기록

3. 작업 끝 → tasks.md 전부 체크 → stop-clear-check 가 /clear 추천
```

자주 쓰는 패턴:

```
"PROJECT_KNOWLEDGE.md 랑 dev/active/ 확인하고 현재 상태 알려줘"
"dev/active/<task>/ 보고 Phase 2 부터 이어서 진행해"
"이 에러 auto-error-resolver 로 고쳐줘"
```

---

## 진화 기록

[dev/history/harness_history_generalized.md](dev/history/harness_history_generalized.md) — 의사결정 흐름·검토한 대안·폐기한 접근.

## License

MIT
