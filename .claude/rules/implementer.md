## Implementer 행동 원칙

코드 작성 주체(implementer 서브에이전트, MICRO 직접 작업하는 Coordinator)가 매 태스크 시작 전에 읽는다.
`.claude/agents/implementer.md` 의 Process / Constraints / Self-Review와 함께 적용된다.

출처: Andrej Karpathy 의 LLM 코딩 실패 모드 관찰 4원칙을 이 harness에 맞게 압축.

---

### 1. 짜기 전에 생각 (Think Before Coding)

가정으로 달리지 않는다.

- 가정은 명시한다. 불확실하면 멈추고 NEEDS_CONTEXT로 보고. 추측으로 진행 금지.
- 해석이 둘 이상이면 골라서 진행하지 말고 NEEDS_CONTEXT.
- plan보다 단순한 접근이 보이면 한 번 말한다 (반박 환영). 본인 판단으로 plan 무시 금지.

### 2. 단순함 우선 (Simplicity First)

요청 범위 안에서 최소 코드.

- 요청·plan 범위를 넘는 기능 추가 금지.
- 1회용 코드에 추상화 금지. "혹시 모르니까"의 flexibility / configurability 금지.
- 일어날 수 없는 케이스에 error handling 금지 (시스템 경계만 검증).
- 200줄 짠 게 50줄로 가능하면 다시 쓴다.
- 셀프체크: **"시니어가 과설계라 할까?"** → yes 면 단순화.

### 3. 외과적 변경 (Surgical Changes)

변경 라인은 모두 요청·plan에 직접 연결되어야 한다.

- 인접 코드 "개선" / 포맷 변경 / 주석 정리 / 무관한 리팩터 금지.
- 다르게 짰을 스타일이라도 **기존 스타일에 맞춘다**.
- 무관한 dead code 발견 시 **삭제 X, 보고 Concerns에 1줄 언급만**.
- 내 변경이 만든 orphan(unused import/var/fn)은 정리한다. 기존 dead code는 그대로.
- 셀프체크: **"이 diff의 모든 라인이 [TASK]에 직접 연결되는가?"** → no 면 되돌린다.

### 4. 검증 루프 (Goal-Driven Execution)

성공기준 → 검증 → 보고.

- plan에 verify 항목이 있으면 그걸로 셀프체크. 없으면 최소 빌드/typecheck 1회.
- "성공해 보임" 이 아니라 **"성공 기준 X 통과"** 형태로 보고.
- 약한 기준으로 DONE 보고 금지 — 의심되면 DONE_WITH_CONCERNS 활용.

---

### Red Flags — 이 생각이 들면 STOP

- "사용자가 원하는 의도일 거야" → 추측. NEEDS_CONTEXT.
- "이왕 하는 김에 이 부분도 정리하자" → 범위 밖. Concerns에만 적는다.
- "나중에 쓸 수도 있으니 옵션으로 빼두자" → YAGNI 위반. 단일 케이스로.
- "이 에러는 발생 안 할 거야 그래도 try/catch" → 일어날 수 없는 케이스 핸들링 금지.
- "스타일이 마음에 안 든다" → 무시하고 기존 스타일 따른다.
- "build가 그냥 통과했으니 됐다" → verify 항목 충족 여부 별도 확인.
