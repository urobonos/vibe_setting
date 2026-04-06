---
name: debate-protocol
description: 질문 유형 입력 시 20개 에이전트를 5개 팀으로 편성, 팀 리드가 멤버를 spawn하여 토론 후 Orchestrator에 반환하는 Multi-Agent Team Debate Protocol
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
version: 2.0.0
depends_on: [agent-personas]
conflicts_with: []
min_claude_md_version: "3.2"
---

# Multi-Agent Team Debate Protocol

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

## 에이전트 팀 구성

20개 에이전트를 5개 팀으로 편성한다. 각 팀은 **Team Lead**가 멤버 에이전트들의 토론을 주관하고, 합의를 종합하여 Orchestrator에 반환한다.

| 팀 | Team Lead 역할 | 멤버 에이전트 | 관점 | 핵심 질문 |
|----|---------------|-------------|------|-----------|
| **Team-A (구현/품질)** | 구현 타당성 종합 | Worker + Reviewer + Tester + Performance | 구현 가능성, 코드 품질, 엣지케이스, 성능 | "구현할 수 있는가? 품질과 성능은 보장되는가?" |
| **Team-B (설계/데이터)** | 설계 정합성 종합 | Architect + Data + UX/API Designer + Librarian | 아키텍처 일관성, 데이터 모델링, API 경험, 문서화 | "설계적으로 올바른가? 데이터와 API가 직관적인가?" |
| **Team-C (안정/보안)** | 위험 평가 종합 | Security/DevOps + Compliance + Chaos + Integration | 보안, 규정 준수, 장애 회복력, 연동 안정성 | "안전한가? 장애에 견디는가? 규정을 준수하는가?" |
| **Team-D (운영/진화)** | 운영 전망 종합 | Manager + Migrator + Optimizer + Mentor | 조율, 마이그레이션, 비용, 지식 전수 | "운영 가능한가? 진화할 수 있는가? 비용은 적절한가?" |
| **Team-E (전략/대안)** | 대안 비교 종합 | Pragmatist + Visionary + Innovator | 실용성, 확장성, 제3의 대안 | "더 나은 방법은? 현실적인가? 혁신적 대안은?" |

## 실행 아키텍처: 2-Depth Spawn 구조

```
Orchestrator (최상위)
  ├── Team-A Lead spawn ─── 멤버 토론 주관 ─── 합의 종합 ─── 반환 → terminate
  ├── Team-B Lead spawn ─── 멤버 토론 주관 ─── 합의 종합 ─── 반환 → terminate  ── 5개 팀 병렬
  ├── Team-C Lead spawn ─── 멤버 토론 주관 ─── 합의 종합 ─── 반환 → terminate
  ├── Team-D Lead spawn ─── 멤버 토론 주관 ─── 합의 종합 ─── 반환 → terminate
  └── Team-E Lead spawn ─── 멤버 토론 주관 ─── 합의 종합 ─── 반환 → terminate
        ↓
  Orchestrator: 5개 팀 결과 수신 → 종합 비교표 → 사용자 확인
```

**라이프사이클:**
- Orchestrator → 5개 Team Lead Agent를 **병렬 spawn**
- 각 Team Lead → 소속 멤버 에이전트의 관점에서 내부 토론 수행 및 합의 도출
- Team Lead → Orchestrator에 합의 결과 반환 → **terminate**
- Orchestrator → 5개 팀 결과 종합 → 비교표 작성 → 사용자 확인

## 실행 절차

```
1. [Trigger Detection] — 사용자 입력이 질문 유형인지 판별
2. [Question Framing] — 질문의 핵심 쟁점을 1~2문장으로 정리
3. [User Confirmation] — 사용자에게 토론 진행 여부를 확인한다.
   "이 질문에 대해 에이전트 팀 토론을 진행할까요?"
   → 승인 시: Step 4로 진행
   → 거부 시: Debate 없이 직접 답변
   승인 없이 토론을 시작하는 것은 지침 위반이다.
4. [Parallel Team Spawn] — 5개 Team Lead를 병렬로 동시 spawn한다.
   각 Team Lead는 다른 팀의 결과를 전달받지 않으며, 오직 원본 질문만을 입력으로 독립 토론한다.
   - Team-A Lead spawn — 멤버(Worker, Reviewer, Tester, Performance) 토론 주관 → 팀 합의 반환 → terminate
   - Team-B Lead spawn — 멤버(Architect, Data, UX/API Designer, Librarian) 토론 주관 → 팀 합의 반환 → terminate
   - Team-C Lead spawn — 멤버(Security/DevOps, Compliance, Chaos, Integration) 토론 주관 → 팀 합의 반환 → terminate
   - Team-D Lead spawn — 멤버(Manager, Migrator, Optimizer, Mentor) 토론 주관 → 팀 합의 반환 → terminate
   - Team-E Lead spawn — 멤버(Pragmatist, Visionary, Innovator) 토론 주관 → 팀 합의 반환 → terminate
   ⚠️ 팀 간 Injected_Context 전달 금지 — 의견 독립성 보장을 위해 각 팀은 원본 질문과 자체 관점만으로 토론한다.
5. [Synthesis] — Orchestrator가 5개 팀 반환 결과를 종합하여 비교표 작성
6. [User Checkpoint] — 사용자에게 종합 의견 제시 후 의견 확인 요청
7. [Final Answer] — 사용자 의견 반영 후 최종 답변 도출
```

## Team Lead Spawn Prompt 구성

각 Team Lead Agent spawn 시 다음 구조로 prompt를 구성한다:

```
Task_Goal: "Team-{X} Lead로서 [{관점}] 관점에서 아래 질문에 대해 팀 내부 토론을 수행하라."
Question: "{원본 질문}"
Team_Members: "{멤버 에이전트 목록 및 각 역할 정의}"
Core_Question: "{팀 핵심 질문}"
Authority_Level: "읽기 전용 (분석/토론만 수행, 코드 변경 금지)"
Output_Format: "팀 내부 토론 → 팀 내 쟁점 → 팀 합의 (근거 포함)"
```

**Effort/Model 할당 기준:**
- Team-A~D: `Max` / `opus` — 깊은 추론과 다각적 분석이 필수
- Team-E: `Max` / `opus` — 대안 제시에 창의적 추론 필요
- 경량 질문(단순 비교, 사실 확인에 가까운 질문): Orchestrator 판단으로 `High` / `sonnet`으로 하향 가능

## 출력 형식

```
## 질문 분석
> {질문의 핵심 쟁점 요약}

---

### Team-A (구현/품질): Worker + Reviewer + Tester + Performance
**내부 토론:**
- Worker: {구현 관점 의견 + 근거}
- Reviewer: {품질 관점 의견 + 근거}
- Tester: {테스트/엣지케이스 관점 의견 + 근거}
- Performance: {성능 관점 의견 + 근거}
**팀 내 쟁점:** {의견이 갈린 부분}
**팀 합의:** {합의 내용 + 근거(Why)}

---

### Team-B (설계/데이터): Architect + Data + UX/API Designer + Librarian
**내부 토론:**
- Architect: {아키텍처 관점 의견 + 근거}
- Data: {데이터 모델링 관점 의견 + 근거}
- UX/API Designer: {API 소비자 경험 관점 의견 + 근거}
- Librarian: {문서화/명확성 관점 의견 + 근거}
**팀 내 쟁점:** {의견이 갈린 부분}
**팀 합의:** {합의 내용 + 근거(Why)}

---

### Team-C (안정/보안): Security/DevOps + Compliance + Chaos + Integration
**내부 토론:**
- Security/DevOps: {보안/인프라 관점 의견 + 근거}
- Compliance: {규정 준수 관점 의견 + 근거}
- Chaos: {장애 회복력 관점 의견 + 근거}
- Integration: {연동 안정성 관점 의견 + 근거}
**팀 내 쟁점:** {의견이 갈린 부분}
**팀 합의:** {합의 내용 + 근거(Why)}

---

### Team-D (운영/진화): Manager + Migrator + Optimizer + Mentor
**내부 토론:**
- Manager: {조율/일관성 관점 의견 + 근거}
- Migrator: {마이그레이션/호환성 관점 의견 + 근거}
- Optimizer: {비용 최적화 관점 의견 + 근거}
- Mentor: {지식 전수/온보딩 관점 의견 + 근거}
**팀 내 쟁점:** {의견이 갈린 부분}
**팀 합의:** {합의 내용 + 근거(Why)}

---

### Team-E (전략/대안): 3-Consultants
**내부 토론:**
- Pragmatist: {실용적 대안 + 근거 + 장점/리스크}
- Visionary: {이상적 대안 + 근거 + 장점/리스크}
- Innovator: {제3의 대안 + 근거 + 장점/리스크}
**팀 내 쟁점:** {의견이 갈린 부분}
**팀 합의:** {합의 내용 + 근거(Why)}

---

### 종합 비교표

| 관점 | Team-A | Team-B | Team-C | Team-D | Team-E |
|------|--------|--------|--------|--------|--------|
| 핵심 주장 | ... | ... | ... | ... | ... |
| 장점 | ... | ... | ... | ... | ... |
| 리스크 | ... | ... | ... | ... | ... |
| 핵심 변수 | ... | ... | ... | ... | ... |
| 권고 | ... | ... | ... | ... | ... |

---

### 의견 확인
> 위 5개 에이전트 팀의 토론 결과를 바탕으로, 사용자의 의견을 기다립니다.
> 특정 팀의 방향에 동의하시거나, 추가 고려사항이 있으시면 말씀해 주세요.
```

## 가드레일

- 각 팀은 **자신의 관점에서만** 의견을 제시한다. 타 팀의 영역을 침범하지 않는다.
- 5개 팀은 **병렬 독립 실행**된다. 팀 간 결과를 Injected_Context로 전달하지 않는다. 각 팀은 원본 질문만으로 토론하여 의견 독립성을 보장한다.
- 모든 의견은 **근거(Why)**를 반드시 포함한다. 근거 없는 주장은 지침 위반이다.
- 각 팀의 내부 토론에서 **팀 내 쟁점**(의견이 갈린 부분)을 반드시 식별하고 명시한다. 만장일치만 보고하는 것은 분석 깊이 부족이다.
- 종합 비교표 제시 후 **반드시 사용자 의견을 확인**한다. 자의적으로 최종 답변을 도출하지 않는다.
- Team Lead는 반환 후 즉시 **terminate**된다. 추가 토론이 필요하면 Orchestrator가 새 Team Lead를 spawn한다.

---

## 자가 검증 체크리스트

토론 결과 제시 전 Orchestrator가 반드시 확인:

### 프로토콜 준수
- [ ] 사용자 입력이 트리거 조건(질문 유형)에 해당하는지 판별했는가
- [ ] 질문의 핵심 쟁점을 1~2문장으로 프레이밍했는가
- [ ] 토론 시작 전 **사용자 확인을 수신**했는가 (승인 없는 토론 시작은 지침 위반)
- [ ] 5개 Team Lead를 **단일 메시지에서 병렬 spawn** 했는가 (순차 spawn 금지)

### 팀 간 독립성
- [ ] 각 Team Lead의 prompt에 **원본 질문만** 포함되어 있는가 (다른 팀의 결과를 Injected_Context로 전달하지 않았는가)
- [ ] 5개 팀 모두 결과를 반환했는가 (누락된 팀이 없는가)
- [ ] 각 팀이 자신의 관점에서만 의견을 제시했는가 (타 팀 영역 침범 없는가)

### 출력 품질
- [ ] 각 팀의 모든 멤버 에이전트 의견에 **근거(Why)**가 포함되어 있는가
- [ ] 각 팀에서 **팀 내 쟁점**(의견이 갈린 부분)이 식별되어 있는가 (만장일치만 보고는 분석 깊이 부족)
- [ ] 각 팀의 **팀 합의**에 합의 내용 + 근거(Why)가 포함되어 있는가
- [ ] **종합 비교표**가 5개 팀 × 5개 관점(핵심 주장, 장점, 리스크, 핵심 변수, 권고)을 포함하는가
- [ ] 출력 형식이 §출력 형식의 템플릿을 정확히 따르는가

### 사용자 확인
- [ ] 종합 비교표 제시 후 **사용자 의견 확인을 요청**했는가 (자의적 최종 답변 도출 금지)
- [ ] Orchestrator가 특정 팀의 의견을 편향적으로 채택하지 않았는가
