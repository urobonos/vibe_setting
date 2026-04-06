---
name: debate
description: >
  Multi-Agent Team Debate Protocol. 질문 유형 시 4팀 12에이전트 토론을 수행한다.
  토론만 수행하며, 코드 구현·커밋은 별도 3-Team 워크플로우로 처리한다.
triggers:
  - "~는 어떻게?", "~가 뭐야?", "~차이가 뭐야?"
  - "~할까?", "~어떨까?", "어떤 게 나아?"
  - "~괜찮아?", "~방식이 맞아?", "~패턴 써도 돼?"
  - "A vs B", "~중에 뭐가?"
version: 2.1.0
user-invocable: true
depends_on: [orchestration]
conflicts_with: []
min_claude_md_version: "4.0"
---

# Debate Skill

사용자 질문에 대한 멀티 에이전트 토론. 토론 결과의 코드 반영이 필요하면 별도로 3-Team 워크플로우를 진행한다.

---

## 트리거 조건

frontmatter `triggers` 참조. **트리거 제외:** 코드 작성/수정 요청, 플랜 요청, 단순 사실 확인

## 팀 구성 (4팀, 12에이전트 + 4 Lead)

| 팀 | Lead 역할 | 멤버 | 핵심 질문 |
|----|----------|------|-----------|
| **Team-A (구현/품질)** | 구현 타당성 종합 | Worker + Reviewer + Tester | "구현할 수 있는가? 품질 보장되는가?" |
| **Team-B (설계/데이터)** | 설계 정합성 종합 | Architect + Data + Analyst | "설계가 요구사항을 충족하는가? 데이터 구조 적절한가?" |
| **Team-C (안정/보안/운영)** | 위험·운영 평가 종합 | Security + Performance + Ops | "안전한가? 성능·장애·운영에 견디는가?" |
| **Team-D (전략/대안)** | 대안 비교 종합 | Pragmatist + Visionary + Innovator | "더 나은 방법? 현실적? 혁신적 대안?" |

## 실행 절차

```
1. [Trigger Detection] — 질문 유형 판별
2. [Question Framing] — 핵심 쟁점 1~2문장 정리
3. [User Confirmation] — 토론 진행 여부 확인 (승인 없는 시작은 지침 위반)
4. [Parallel Team Spawn] — 4개 Team Lead 병렬 spawn
   ⚠️ 각 팀은 원본 질문만으로 독립 토론한다 — 의견 독립성 보장
5. [Synthesis] — 4팀 결과 종합 비교표 작성
6. [User Checkpoint] — 사용자 의견 확인
7. [Final Answer] — 최종 답변 도출
```

### 2-Depth Spawn 구조
```
Orchestrator
  ├── Team-A Lead → 멤버 토론 → 합의 반환 → terminate
  ├── Team-B Lead → 멤버 토론 → 합의 반환 → terminate  ── 병렬
  ├── Team-C Lead → 멤버 토론 → 합의 반환 → terminate
  └── Team-D Lead → 멤버 토론 → 합의 반환 → terminate
```

### Team Lead Spawn Prompt 구성
```
Task_Goal: "Team-{X} Lead로서 [{관점}] 관점에서 질문에 대해 팀 내부 토론 수행"
Question: "{원본 질문}"
Team_Members: "{멤버 목록 및 역할}"
Core_Question: "{팀 핵심 질문}"
Authority_Level: "읽기/분석만 수행한다"
Output_Format: "팀 내부 토론 → 팀 내 쟁점 → 팀 합의 (근거 포함)"
```

**Effort/Model:** Team-A~D 모두 `Max/opus`. 경량 질문은 `High/sonnet` 하향 가능.

## 출력 형식

```
## 질문 분석
> {핵심 쟁점 요약}

---

### Team-A (구현/품질)
**내부 토론:** Worker/Reviewer/Tester 각 의견 + 근거
**팀 내 쟁점:** {의견 갈린 부분}
**팀 합의:** {합의 + 근거(Why)}

### Team-B (설계/데이터)
**내부 토론:** Architect/Data/Analyst 각 의견 + 근거
**팀 내 쟁점:** {의견 갈린 부분}
**팀 합의:** {합의 + 근거(Why)}

### Team-C (안정/보안/운영)
**내부 토론:** Security/Performance/Ops 각 의견 + 근거
**팀 내 쟁점:** {의견 갈린 부분}
**팀 합의:** {합의 + 근거(Why)}

### Team-D (전략/대안)
**내부 토론:** Pragmatist/Visionary/Innovator 각 의견 + 근거
**팀 내 쟁점:** {의견 갈린 부분}
**팀 합의:** {합의 + 근거(Why)}

---

### 종합 비교표
| 관점 | Team-A | Team-B | Team-C | Team-D |
|------|--------|--------|--------|--------|
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
- 각 팀은 자신의 관점에서만 의견 제시
- 4개 팀 병렬 독립, 각 팀은 원본 질문만으로 독립 토론한다
- 모든 의견에 근거(Why) 필수
- 팀 내 쟁점 반드시 식별 (만장일치만 보고는 깊이 부족)
- 종합 비교표 후 사용자 의견 확인 필수

