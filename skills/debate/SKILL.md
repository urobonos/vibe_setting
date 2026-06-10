---
name: debate
description: >
  Multi-Agent Team Debate Protocol. `/debate`·`/토론` 슬래시로 **명시 호출** 시에만 4 에이전트팀 (각 팀 4 Agent = 총 16 Agent) 풀-병렬 spawn 토론을 수행한다 (토큰 4× 비용 — 자동 발동 없는 수동 호출 전용).
  각 팀원은 cold context 로 독립 spawn 되어 자기 관점만 발언하고, Lead 가 팀 내 의견을 종합한다.
  토론만 수행하며, 코드 구현·커밋은 별도 3-Team 워크플로우로 처리한다.
triggers:
  - "/debate"
  - "/토론"
version: 4.0.1
user-invocable: true
depends_on: [orchestration]
conflicts_with: []
min_claude_md_version: "4.0"
---

# Debate Skill

사용자 질문에 대한 멀티 에이전트 팀 토론. **4 에이전트팀 × 4명 = 총 16 Agent 풀-병렬 spawn**. 각 팀원은 cold context 로 독립 발언하고, Lead 가 팀 내 의견을 종합한다. 토론 결과의 코드 반영이 필요하면 별도로 3-Team 워크플로우를 진행한다.

---

## 트리거 조건

**수동 호출 전용** — `/debate` 또는 `/토론` 슬래시로만 진입한다. 자연어 자동 발동 없음 (16 Agent spawn·토큰 4× 비용 보호). 토론이 필요해 보여도 Lead 는 `/토론` 호출을 *안내*만 하고 자동 spawn 하지 않는다.

## 그룹 구성 (4 에이전트팀, 각 팀 4 Agent = 16 Agent 풀-병렬)

| 팀 | Lead | 멤버 (3명, 각각 독립 Agent) | 핵심 질문 |
|----|------|----------------------------|-----------|
| **팀 A (구현/품질)** | Team-A Lead | Worker / Reviewer / Tester | "구현할 수 있는가? 품질 보장되는가?" |
| **팀 B (설계/데이터)** | Team-B Lead | Architect / Data / Analyst | "설계가 요구사항을 충족? 데이터 구조 적절?" |
| **팀 C (안정/보안/운영)** | Team-C Lead | Security / Performance / Ops | "안전한가? 성능·장애·운영에 견디는가?" |
| **팀 D (전략/대안)** | Team-D Lead | Pragmatist / Visionary / Innovator | "더 나은 방법? 현실적? 혁신적 대안?" |

**실제 Agent spawn = 16** (4 Lead + 12 멤버). 각 멤버는 cold context 로 독립 spawn 되어 자기 관점만 발언. Lead 는 팀 내 3 의견을 종합해 팀 합의 도출.

## 실행 절차

```
1. [Trigger Detection]   — 질문 유형 판별
2. [Question Framing]    — 핵심 쟁점 1~2문장 정리
3. [User Confirmation]   — 토론 진행 여부 확인 (승인 없는 시작은 지침 위반)
4. [Phase-1 Member Spawn] — 12 멤버 Agent 풀-병렬 spawn (한 응답 안에서 동시 호출)
5. [Phase-2 Lead Synthesis] — 12 멤버 의견 수신 후, 4 Lead Agent 병렬 spawn (각 Lead 가 자기 팀 멤버 3 의견 종합)
6. [Cross-Team Synthesis] — 본 세션 Claude 가 4 팀 합의 결과 비교표 작성
7. [User Checkpoint]     — 사용자 의견 확인
8. [Final Answer]        — 최종 답변 도출
```

> **2-Phase 분리 사유:** Lead 가 멤버 의견을 종합하려면 멤버 의견이 먼저 있어야 한다. Phase-1 (멤버 12 병렬) → Phase-2 (Lead 4 병렬) 분리. 총 spawn 16 = 동시는 아니지만 Phase 별 병렬.

### 16 Agent 풀-병렬 spawn 트리

```
Orchestrator (본 세션 Claude)
 │
 ├── 팀 A (구현/품질)                                ── 4 Agent
 │    ├── Team-A Lead   (Agent #1) — 팀 내 종합
 │    ├── Worker        (Agent #2) — 구현 타당성
 │    ├── Reviewer      (Agent #3) — 코드 품질
 │    └── Tester        (Agent #4) — 테스트 전략
 │
 ├── 팀 B (설계/데이터)                               ── 4 Agent
 │    ├── Team-B Lead   (Agent #5)
 │    ├── Architect     (Agent #6) — 아키텍처 적합성
 │    ├── Data          (Agent #7) — 데이터 모델
 │    └── Analyst       (Agent #8) — 요구사항 정합성
 │
 ├── 팀 C (안정/보안/운영)                            ── 4 Agent
 │    ├── Team-C Lead   (Agent #9)
 │    ├── Security      (Agent #10) — 보안 리스크
 │    ├── Performance   (Agent #11) — 성능 영향
 │    └── Ops           (Agent #12) — 운영·장애 견딤
 │
 └── 팀 D (전략/대안)                                 ── 4 Agent
      ├── Team-D Lead   (Agent #13)
      ├── Pragmatist    (Agent #14) — 현실적 단기 해결
      ├── Visionary     (Agent #15) — 장기 비전 정합
      └── Innovator     (Agent #16) — 혁신적 대안
```

### Phase-1 — 멤버 Agent spawn prompt 양식 (12 개 동일 구조)

각 멤버 Agent (총 12개) 는 다음 prompt 로 cold context spawn:

```
Task_Goal:       "{역할명} 으로서 질문에 대한 자기 관점 의견 제시"
Role:            "{역할 설명 — orchestration SKILL.md 9-Core + 3-Consultants 페르소나 참조}"
Question:        "{원본 질문}"
Team:            "{소속 팀 A/B/C/D}"
Authority_Level: "읽기/분석만 수행 (mutation 도구 금지)"
Output_Format:   "내 관점 의견 + 근거(Why) — 다른 팀원·다른 관점은 무시, 내 역할에만 집중"
Length_Limit:    "300 자 이내"
```

### Phase-2 — Lead Agent spawn prompt 양식 (4 개 동일 구조)

각 Lead Agent (총 4개) 는 자기 팀 멤버 3 의견을 종합:

```
Task_Goal:           "팀 {X} Lead 로서 팀원 3 의견 종합 + 팀 합의 도출"
Question:            "{원본 질문}"
Team_Members_Opinions: "{Worker 의견 + Reviewer 의견 + Tester 의견}"  ← Phase-1 결과 주입
Core_Question:       "{팀 핵심 질문, 본 SKILL.md §그룹 구성 표 참조}"
Authority_Level:     "읽기/분석만 수행"
Output_Format:       "팀 내 쟁점 (의견 갈린 부분) + 팀 합의 (근거 포함)"
Length_Limit:        "500 자 이내"
```

**Effort/Model:**
- Lead 4개 = `Max/fable` 고정
- 멤버 12개 = `Max/fable` 기본, 경량 질문 (1~2 문장) 은 `High/sonnet` 하향 가능

## 비용 안내 (트레이드오프 명시)

| 항목 | 단독 Agent 4개 (legacy) | 풀-병렬 16 Agent (현행) |
|------|---------------------|--------------------|
| 실제 Agent spawn | 4 | **16** |
| 토큰 비용 | 1× | **4×** |
| 응답 시간 | ~30 초 | ~60~90 초 (Phase 별 병렬) |
| 의견 깊이 | 페르소나 시뮬레이션 | **Cold context 독립** |
| 다양성 | Lead 1 관점 종합 | 4 cold context 진정 다양 |

비용 4 배는 의견 독립성 + 깊이 확보 트레이드오프. 단순 질문에는 `/orchestration` 또는 직접 답변이 비용 효율적이다.

## 출력 형식

```
## 질문 분석
> {핵심 쟁점 요약}

---

### 팀 A (구현/품질)
**Worker:**   {의견 + 근거}
**Reviewer:** {의견 + 근거}
**Tester:**   {의견 + 근거}
**팀 내 쟁점:** {의견 갈린 부분}
**팀 A 합의:** {Lead 종합 + 근거(Why)}

### 팀 B (설계/데이터)
**Architect:** {의견 + 근거}
**Data:**      {의견 + 근거}
**Analyst:**   {의견 + 근거}
**팀 내 쟁점:** {의견 갈린 부분}
**팀 B 합의:** {Lead 종합 + 근거(Why)}

### 팀 C (안정/보안/운영)
**Security:**    {의견 + 근거}
**Performance:** {의견 + 근거}
**Ops:**         {의견 + 근거}
**팀 내 쟁점:** {의견 갈린 부분}
**팀 C 합의:** {Lead 종합 + 근거(Why)}

### 팀 D (전략/대안)
**Pragmatist:** {의견 + 근거}
**Visionary:**  {의견 + 근거}
**Innovator:**  {의견 + 근거}
**팀 내 쟁점:** {의견 갈린 부분}
**팀 D 합의:** {Lead 종합 + 근거(Why)}

---

### 종합 비교표
| 관점 | 팀 A | 팀 B | 팀 C | 팀 D |
|------|------|------|------|------|
| 핵심 주장 | ... | ... | ... | ... |
| 장점 | ... | ... | ... | ... |
| 리스크 | ... | ... | ... | ... |
| 핵심 변수 | ... | ... | ... | ... |
| 권고 | ... | ... | ... | ... |

---

### 의견 확인
> 사용자의 의견을 기다립니다.
```

## 가드레일

- 각 멤버 Agent 는 자기 역할에서만 의견 제시 (다른 관점 침범 금지)
- 4 팀 병렬 독립, 각 팀은 원본 질문만으로 독립 토론
- 모든 의견에 근거(Why) 필수
- 팀 내 쟁점 반드시 식별 (만장일치만 보고는 깊이 부족)
- 종합 비교표 후 사용자 의견 확인 필수
- Phase-1 (멤버 12 병렬) 완료 전 Phase-2 (Lead 4 병렬) 진입 금지 (순서 위반은 Lead 가 빈 의견을 종합하게 되어 토론 깊이 손실)

## 변경 기록

| 날짜 | 버전 | 내용 |
|------|------|------|
| 이전 | 2.1.0 | 2-Depth Spawn (4 Lead Agent + 각 Lead 내부 3 페르소나 시뮬레이션) — "4 Agent spawn + 12 페르소나" 구조 |
| 2026-05-15 | 2.2.0 | `/토론` trigger 추가 |
| 2026-05-15 | 3.0.0 | **풀-병렬 16 Agent 구조로 전환** — 12 멤버를 cold context 독립 Agent 로 spawn (페르소나 시뮬레이션 → 진짜 Agent). 2-Phase 분리 (멤버 12 병렬 → Lead 4 병렬). 사용자 명시 결정 (B 옵션) 으로 채택. |
