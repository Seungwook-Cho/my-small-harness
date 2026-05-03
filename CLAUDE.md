# CLAUDE.md

이 파일은 Claude Code가 세션 시작 시 자동으로 로드한다. 프로젝트 루트의 운영 규칙을 정의.

**전제 스택**: Next.js 16 / React 19 / TypeScript 5 / pnpm. 빌드 검증은 `pnpm typecheck` / `pnpm build`,
타입 에러는 `tsc --noEmit` 기준. ship 된 에이전트(`auto-error-resolver`, `frontend-error-fixer`) 와
스킬(`dev-docs`) 모두 이 가정 위에서 동작한다.

> 사용 시작하기 전: `README.md` → harness 전체 구조와 초기 셋업.
> 진행 중인 작업 컨텍스트: `PROJECT_KNOWLEDGE.md`(있으면) + `dev/active/`.

---

## 코디네이터 (메인 세션)

이 세션은 **Coordinator**. 대화·판단·디스패치·plan 작성을 담당. 코딩은 서브에이전트에게 위임이 기본.

전체 운영 규칙: [.claude/rules/coordinator.md](.claude/rules/coordinator.md) — 세션 시작 시 함께 읽는다.

핵심만:
- `/dev-docs` 없이 들어온 요청 → 코디네이터가 직접 처리 + 커밋 + history 기록
- `/dev-docs` MICRO → 코디네이터 직접 (1-2줄 수정 한정)
- `/dev-docs` SMALL/BIG → implementer 디스패치 (코디네이터 직접 코딩 금지, trivial fix 제외)
- BIG plan도 코디네이터가 직접 작성 (Interview 직후 context가 깨끗할 때 직접 작성하는 게 효율적 — 별도 planner 에이전트 없음)

---

## Implementer 행동 원칙

코드 작성 시 따르는 4원칙(Think Before / Simplicity / Surgical / Goal-Driven): [.claude/rules/implementer.md](.claude/rules/implementer.md).
implementer 서브에이전트는 매 태스크 시작 전 자동 참조. Coordinator도 MICRO 직접 작업 / `/dev-docs` 없는 직접 처리 시 동일하게 따른다.

---

## dev-docs 라이프사이클

| 분기 | 기준 | 처리 주체 |
|------|------|----------|
| MICRO | 1-2줄, 원인 명확, 단일 파일 | Coordinator 직접 |
| SMALL | 단일 모듈, 1-2 파일, 원인 명확 | implementer 1회 디스패치 |
| BIG | 다파일/다모듈/아키텍처/원인 불확실 | Coordinator가 plan 작성 → implementer 병렬 → verifier |

판단 애매하면 SMALL로. MICRO는 잘못 판단했을 때 손실 큼 (스코프가 커지면 BLOCKED → 재디스패치 비용).

---

## 작업 시작 전 체크

1. `dev/active/` — 진행 중인 task가 있는지
2. `PROJECT_KNOWLEDGE.md` — 도메인 결정사항·제약
3. 관련 모듈의 `dev/history/{module}-history.md` 최근 항목 — 최근에 비슷한 작업 했는지

---

## 커밋 포맷

```
[scope] type: 한국어 한 줄 설명

(선택) 본문 — 왜 이 결정을 내렸는지. diff 설명 X.
```

- `scope`: 커밋된 모듈의 scope 키 (`.claude/hooks/modules.conf.sh`의 `dir_to_scope` 매핑과 일치)
- `type`: `feat` / `fix` / `refactor` / `docs` / `chore` / `test`
- 한 커밋에 여러 모듈 섞지 않는다. 분리 커밋.

커밋 직후 반드시 `dev/history/{scope}-history.md`의 `## 미정리` 섹션에 한 줄 append. 작성 원칙은 [coordinator.md의 history 기록 섹션](.claude/rules/coordinator.md) 참조.

**history 파일은 커밋하지 않는다** — 디스크에만 두고 uncommitted 상태로 둔다.

---

## 모듈 매핑 (hook 동작에 영향)

`MODULES_PATTERN` / `dir_to_scope` / `scope_to_history`는 [.claude/hooks/modules.conf.sh](.claude/hooks/modules.conf.sh) 한 곳에서 관리.
새 모듈을 추가하면 이 파일 한 군데만 수정하면 두 hook (post-scope-escalation, stop-commit-history-check) 모두 반영됨.

---

## 자주 쓰는 명령

```
/dev-docs <설명>     # 새 작업 분기 판정 + plan 생성 (BIG일 때)
/clear               # tasks.md 다 끝났을 때 stop hook이 추천
```

---

## 도메인 정보

전제 스택은 파일 상단(Next.js / React / TS / pnpm)에 박혀 있다. 본인 프로젝트의 추가 도메인 정보 — 비즈니스 룰, 외부 API 의존성, 알려진 함정 — 는 `PROJECT_KNOWLEDGE.md` 에 따로 정리. 이 파일에는 적지 않는다.
