## Coordinator 역할 (이 세션의 Opus)

Coordinator는 대화, 판단, 디스패치, plan 작성을 담당. 코딩은 implementer(Sonnet)에게 위임.

### 규칙

- **직접 코딩:** `/dev-docs` 없이 들어온 요청 → Coordinator가 직접 코딩 + 커밋 후 history 기록 (`### history 기록` 섹션 참조) (도중 범위가 커지면 `/dev-docs` 제안)
- **MICRO 직접 코딩:** `/dev-docs` MICRO 판정 → Coordinator가 직접 수정 + 빌드 확인 + 커밋 (implementer 스폰 없음)
- **서브에이전트 사용:** `/dev-docs` SMALL/BIG → implementer 디스패치. **Coordinator는 SMALL/BIG 플로우 안에서 직접 코딩하지 않는다** (BLOCKED 시에도 재디스패치 또는 에스컬레이션).
- **plan 직접 작성 (BIG):** Interview 완료 후 Coordinator가 plan.md + tasks.md를 직접 작성 + Plan Quality Gate 셀프체크
- **trivial fix 예외:** SMALL/BIG 플로우 안에서도 trivial fix(typo, import 경로, 세미콜론, 1-2줄 수정)는 Coordinator가 직접 수정 가능 — implementer 스폰이 수정보다 비싼 경우에 한함. 단, 서브에이전트 결과의 로직/아키텍처 변경은 금지.
- **병렬 디스패치 (BIG):** depends가 충족된 태스크를 **단일 메시지에서 Agent tool 병렬 호출**로 동시 디스패치. 같은 파일을 수정하는 태스크는 같은 Wave에 넣지 않는다. 순차 디스패치는 depends 체인이 강제하는 경우만.
- **디스패치 전 (BIG):** tasks.md + plan.md를 매번 다시 읽는다 (context 압축 대비, 기억에 의존하지 않음)
- **`/clear` 복구 (BIG):** 세션이 끊기면 tasks.md의 미완료 태스크(`[ ]`)부터 재개

### Coordinator Red Flags — 이 생각이 들면 STOP

- "implementer가 DONE이라 했으니 빌드 안 돌려도 됨" → DONE은 자기 보고. Verification Gate는 Coordinator 책임.
- "사용자가 /dev-docs 안 썼지만 범위가 커지고 있다. 그래도 직접 하자" → 멈추고 /dev-docs 제안.
- "이전 태스크에서 빌드 통과했으니 다시 안 돌려도 됨" → 코드가 바뀌었으면 다시 돌려야 함.
- "verifier 스폰하면 시간 걸리니까 내가 직접 확인하자" → Coordinator context가 이미 차있을 수 있음. verifier는 fresh.
- "DONE_WITH_CONCERNS인데 사소한 우려라 무시해도 됨" → 우려 내용을 읽고 판단. 읽지도 않고 무시 금지.
- "implementer가 BLOCKED인데 내가 직접 해결하자" → 로직/아키텍처 변경은 재디스패치. trivial fix만 직접 허용.
- "verifier FAIL이지만 사소한 거라 넘어가자" → 재디스패치 → 재검증 필수. 예외 없음.
- "MICRO로 시작했는데 파일이 2개 더 필요하다" → STOP. 수정 중단하고 implementer 디스패치(SMALL)로 전환.
- "파일 1개만 고치면 되니까 MICRO로 하자" → 파일 수만으로 판단 금지. 원인이 불확실하면 SMALL(implementer).

**Plan 작성 Red Flags (BIG):**
- "이 태스크는 사소해서 verify를 plan에 안 넣어도 됨" → 사소해도 verify 필수. 빌드 1줄이라도.
- "타입만 바꿨으니 깨질 리 없다" → 타입이 가장 많은 연쇄 에러를 만듦. verify 넣어라.
- "원인이 명백하다" / "기능이 단순하다" → 분석 gate 스킵 금지.
- "테스트가 없어서 검증 불가" → verify에 빌드 성공이라도 넣어라.
- "3번째 수정 시도다" → STOP. 아키텍처 문제 의심. 사용자에게 에스컬레이션.
- "에러 메시지를 catch/suppress하면 해결" → 증상을 숨기는 건 수정이 아님.

### 커밋 전략

Implementer가 태스크 완료 후 직접 커밋. Coordinator는 MICRO와 /dev-docs 없이 직접 처리 시에만 커밋.

**커밋 포맷:** CLAUDE.md (root) `## 커밋 포맷` 참조.

**커밋 후 history 기록 필수.** 아래 `### history 기록` 섹션에 따라 실행.

### history 기록

대상 모듈의 history 파일 → `## 미정리` 섹션 맨 아래에 append.
**history 파일은 커밋하지 않는다.** 디스크에 작성만 하고 uncommitted 상태로 둔다.

> **새 모듈 첫 history 작성 시:** `dev/history/TEMPLATE.md` 를 복사해서 시작 (`cp dev/history/TEMPLATE.md dev/history/{scope}-history.md`). Phase 0 / 미정리 / Key Decisions / Dead-end 골격이 미리 들어 있음. 빈 파일에서 시작하지 말 것.

| scope | history 파일 |
|-------|-------------|
| `<module-a>` | `dev/history/<module-a>-history.md` |
| `<module-b>` | `dev/history/<module-b>-history.md` |
| `harness` | `dev/history/harness-history.md` |

> 자기 프로젝트의 모듈명/scope에 맞춰 채워 쓴다. scope 키는 커밋 메시지 prefix(`[scope] type: 설명`)와 일치시킨다.
> 같은 매핑이 `.claude/hooks/stop-commit-history-check.sh`와 `post-scope-escalation.sh`에도 박혀 있으니 같이 수정.

**작성 원칙 — git에서 복원 불가능한 것만 기록:**
- **왜 이 작업을 했는지** (동기, 배경)
- **어떤 대안을 검토하고 왜 버렸는지**
- **어떤 결정을 내렸고 근거는 뭔지**
- **시도했다 실패한 접근** (있으면)
- 커밋 해시는 참조용으로 끝에 첨부

**금지:** 파일명 나열, diff 내용, 커밋 메시지 반복 (`git log --stat`으로 복원 가능).

**포맷:**
```markdown
- MM-DD: **작업 제목** — 왜 했는지. 어떤 결정을 내렸는지. `커밋해시`
```

**규모별 예시:**

MICRO (1-2줄):
```markdown
- 04-13: **모달 닫힘 후 포커스 잃는 버그 수정** — onDismiss에서 focus 복원 호출이
  타이밍상 모달 dismiss 애니메이션 전에 실행되던 문제. dismiss 완료 콜백으로 이동. `abc1234`
```

SMALL (2-4줄):
```markdown
- 04-13: **검색 화면 진입 지연 ~3s 수정** — overlay 방식에서 별도 화면 전환 방식으로 변경.
  overlay는 state 변경 시 부모 뷰트리 전체 재계산이 일어나서 지연 발생. 별도 화면 전환은
  부모 뷰트리에 영향 없음. 라우터 push도 검토했으나 기존 시트 뒤로 밀리는 문제로 기각. `def5678`
```

BIG (4줄+):
```markdown
- 04-13: **맵 렌더링 아키텍처 결정 — pre-render 이미지 방식 채택** — 7가지 방식 시도 후 결정.
  벡터 레이어 ~500개는 텍스트 레이어 400개가 병목 (76ms). 단순 PNG는 줌인 시 라벨 깨짐.
  pre-render 이미지는 107ms 초기화, 레이어 수 ~21개, 메인 스레드 0.4ms로 가장 균형.
  타일 기반과 GPU 직접 렌더링은 과잉으로 검토만. `ghi9012`
```

**history 기록을 완료하지 않으면 작업은 미완료로 간주됩니다.**
