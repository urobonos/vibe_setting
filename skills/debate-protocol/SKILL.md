---
name: debate-protocol
description: 질문 유형 입력 시 20개 페르소나 5개 그룹 순차 토론을 수행하는 Multi-Persona Debate Protocol
triggers:
  - "~는 어떻게?"
  - "~가 뭐야?"
  - "~차이가 뭐야?"
  - "~할까?"
  - "~어떨까?"
  - "어떤 게 나아?"
  - "~괜찮아?"
  - "~방식이 맞아?"
  - "~패턴 써도 돼?"
  - "A vs B"
  - "~중에 뭐가?"
version: 1.0.0
depends_on: [agent-personas]
conflicts_with: []
min_claude_md_version: "3.2"
---

# Multi-Persona Debate Protocol

사용자의 입력이 **코드 작성/수정 요청이나 플랜이 아닌 질문**일 때 자동으로 발동한다.

## 트리거 조건

아래 패턴에 해당하는 사용자 입력:
- 기술적 질문: "~는 어떻게?", "~가 뭐야?", "~차이가 뭐야?"
- 의견 요청: "~할까?", "~어떨까?", "어떤 게 나아?", "~괜찮아?"
- 설계 판단: "~방식이 맞아?", "~패턴 써도 돼?"
- 비교/선택: "A vs B", "~중에 뭐가?"

**트리거 제외** (Debate 없이 직접 처리):
- 명시적 코드 작성/수정 요청 ("만들어줘", "수정해줘", "추가해줘")
- 플랜 요청 ("플랜 짜줘", "계획 세워줘")
- 단순 사실 확인 ("이 함수 어디 있어?", "이 파일 뭐야?")

## 그룹 구성

20개 페르소나를 5개 그룹으로 편성하여 순차 토론한다.

| 그룹 | 페르소나 | 관점 | 핵심 질문 |
|------|----------|------|-----------|
| **Group-A (구현/품질)** | Worker + Reviewer + Tester + Performance | 구현 가능성, 코드 품질, 엣지케이스, 성능 | "구현할 수 있는가? 품질과 성능은 보장되는가?" |
| **Group-B (설계/데이터)** | Architect + Data + UX/API Designer + Librarian | 아키텍처 일관성, 데이터 모델링, API 경험, 문서화 | "설계적으로 올바른가? 데이터와 API가 직관적인가?" |
| **Group-C (안정/보안)** | Security/DevOps + Compliance + Chaos + Integration | 보안, 규정 준수, 장애 회복력, 연동 안정성 | "안전한가? 장애에 견디는가? 규정을 준수하는가?" |
| **Group-D (운영/진화)** | Manager + Migrator + Optimizer + Mentor | 조율, 마이그레이션, 비용, 지식 전수 | "운영 가능한가? 진화할 수 있는가? 비용은 적절한가?" |
| **Group-E (전략/대안)** | Pragmatist + Visionary + Innovator | 실용성, 확장성, 제3의 대안 | "더 나은 방법은? 현실적인가? 혁신적 대안은?" |

## 실행 절차

```
1. [Trigger Detection] — 사용자 입력이 질문 유형인지 판별
2. [Question Framing] — 질문의 핵심 쟁점을 1~2문장으로 정리
3. [User Confirmation] — 사용자에게 토론 진행 여부를 확인한다.
   "이 질문에 대해 멀티 페르소나 토론을 진행할까요?"
   → 승인 시: Step 4로 진행
   → 거부 시: Debate 없이 직접 답변
   승인 없이 토론을 시작하는 것은 지침 위반이다.
4. [Parallel Group Spawn] — 5개 그룹을 병렬로 동시 spawn한다. 각 그룹은 다른 그룹의 결과를 전달받지 않으며, 오직 원본 질문만을 입력으로 독립 토론한다.
   - Group-A Spawn — 구현/품질 관점 토론 → 그룹 합의 반환 → terminate
   - Group-B Spawn — 설계/데이터 관점 토론 → 그룹 합의 반환 → terminate
   - Group-C Spawn — 안정/보안 관점 토론 → 그룹 합의 반환 → terminate
   - Group-D Spawn — 운영/진화 관점 토론 → 그룹 합의 반환 → terminate
   - Group-E Spawn — 전략/대안 관점 토론 → 그룹 합의 반환 → terminate
   ⚠️ 그룹 간 Injected_Context 전달 금지 — 의견 독립성 보장을 위해 각 그룹은 원본 질문과 자체 관점만으로 토론한다.
5. [Synthesis] — Orchestrator가 5개 그룹 반환 결과를 종합하여 비교표 작성
6. [User Checkpoint] — 사용자에게 종합 의견 제시 후 의견 확인 요청
7. [Final Answer] — 사용자 의견 반영 후 최종 답변 도출
```

## 출력 형식

```
## 질문 분석
> {질문의 핵심 쟁점 요약}

---

### Group-A (구현/품질): Worker + Reviewer + Tester + Performance
**내부 토론 요약:**
- Worker: {구현 관점 의견}
- Reviewer: {품질 관점 의견}
- Tester: {테스트/엣지케이스 관점 의견}
- Performance: {성능 관점 의견}
**그룹 합의:** {합의 내용}

---

### Group-B (설계/데이터): Architect + Data + UX/API Designer + Librarian
**내부 토론 요약:**
- Architect: {아키텍처 관점 의견}
- Data: {데이터 모델링 관점 의견}
- UX/API Designer: {API 소비자 경험 관점 의견}
- Librarian: {문서화/명확성 관점 의견}
**그룹 합의:** {합의 내용}

---

### Group-C (안정/보안): Security/DevOps + Compliance + Chaos + Integration
**내부 토론 요약:**
- Security/DevOps: {보안/인프라 관점 의견}
- Compliance: {규정 준수 관점 의견}
- Chaos: {장애 회복력 관점 의견}
- Integration: {연동 안정성 관점 의견}
**그룹 합의:** {합의 내용}

---

### Group-D (운영/진화): Manager + Migrator + Optimizer + Mentor
**내부 토론 요약:**
- Manager: {조율/일관성 관점 의견}
- Migrator: {마이그레이션/호환성 관점 의견}
- Optimizer: {비용 최적화 관점 의견}
- Mentor: {지식 전수/온보딩 관점 의견}
**그룹 합의:** {합의 내용}

---

### Group-E (전략/대안): 3-Consultants
**내부 토론 요약:**
- Pragmatist: {실용적 대안}
- Visionary: {이상적 대안}
- Innovator: {제3의 대안 또는 리스크 분석}
**그룹 합의:** {합의 내용}

---

### 종합 비교표

| 관점 | Group-A | Group-B | Group-C | Group-D | Group-E |
|------|---------|---------|---------|---------|---------|
| 핵심 주장 | ... | ... | ... | ... | ... |
| 장점 | ... | ... | ... | ... | ... |
| 리스크 | ... | ... | ... | ... | ... |
| 권고 | ... | ... | ... | ... | ... |

---

### 의견 확인
> 위 토론 결과를 바탕으로, 사용자의 의견을 기다립니다.
> 특정 그룹의 방향에 동의하시거나, 추가 고려사항이 있으시면 말씀해 주세요.
```

## 가드레일

- 각 그룹은 **자신의 관점에서만** 의견을 제시한다. 타 그룹의 영역을 침범하지 않는다.
- 5개 그룹은 **병렬 독립 실행**된다. 그룹 간 결과를 Injected_Context로 전달하지 않는다. 각 그룹은 원본 질문만으로 토론하여 의견 독립성을 보장한다.
- 모든 의견은 **근거(Why)**를 반드시 포함한다. 근거 없는 주장은 지침 위반이다.
- 종합 비교표 제시 후 **반드시 사용자 의견을 확인**한다. 자의적으로 최종 답변을 도출하지 않는다.
