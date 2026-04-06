---
name: workflow-enforcer
description: >
  CLAUDE.md에 정의된 모든 승인 규칙을 체크리스트로 강제하는 워크플로우 게이트.
  모든 작업 시작 시 자동 적용되며, 사용자 승인 없이 실행 단계로 진입하는 것을 방지한다.
triggers:
  - 모든 작업 요청 시 자동 적용 (CLAUDE.md §4 PAEV Loop와 연동)
  - "워크플로우 체크", "workflow check"
mandatory: true
version: 1.1.0
depends_on: []
conflicts_with: []
min_claude_md_version: "3.2"
---

# Workflow Enforcer Skill

모든 작업 요청 수신 시, 실행 전에 아래 체크리스트를 완료하고 사용자에게 제시해야 한다.
**체크리스트 미제시 상태에서 변경/실행 도구(Edit, Write, Bash, Agent)를 사용하는 것은 지침 위반이다.**
Pre-Plan 단계에서 Read-only 도구(Read, Grep, Glob)는 분석 목적으로 허용된다. (CLAUDE.md §4 단계 1 참조)

---

## 1. 승인 게이트 레지스트리

### 작업 규모 분류 (Task Sizing)

작업 요청 수신 시, 체크리스트 작성 전에 먼저 작업 규모를 판정한다. 분류 기준이 모호한 경우 상위 등급을 적용한다.

| 등급 | 기준 | Gate 적용 | 비고 |
|------|------|-----------|------|
| **S (Small)** | 단일 파일, 단일 함수, 기존 패턴 반복 | Gate-1만 적용 (Gate-2 생략) | Post-Audit 약식 보고 |
| **M (Medium)** | 2~4파일, 기존 아키텍처 내 변경 | Gate-1 + Gate-2 통합 1회 보고 | 통합 보고 후 1회 승인 |
| **L (Large)** | 5파일 이상 또는 아키텍처 변경 | 전체 Gate 적용 | Full PAEV |

**모든 등급 공통:**
- Gate-3 (Checkpoint), Gate-6 (Feedback Loop), Gate-7 (Post-Audit)은 등급과 무관하게 항상 적용
- Verification Phase(검증)는 모든 등급에서 수행 — S등급에서는 내부 검증 후 Post-Audit에 포함
- Gate-4 (Debate Protocol), Gate-5 (3-Consultants)는 작업이 아닌 질문에 적용되므로 등급 분류와 독립

아래는 CLAUDE.md에서 정의된 승인 규칙의 **참조 인덱스**이다. 상세 규칙은 해당 섹션을 따른다.

| Gate | 참조 | 조건 요약 | 승인 키워드 |
|------|------|-----------|-------------|
| Gate-1 | CLAUDE.md §4 단계 1 | 모든 멀티 스텝 작업 → Pre-Plan 보고 후 승인 대기 | "진행", "ok", "yes", "ㄱㄱ" 등 |
| Gate-2 | CLAUDE.md §4 단계 2 | 에이전트 spawn 필요 시 → Agent Flow Plan 보고 후 승인 대기 | 동일 |
| Gate-3 | CLAUDE.md §3 | 비가역적 작업, 광범위 영향, 요구사항 상충, 외부 연동, 권한 외 접근 | 즉시 중단 + 승인 요청 |
| Gate-4 | `debate-protocol` 스킬 | 질문 유형 입력 → 20개 페르소나 5그룹 토론 진행 여부 확인 | 사용자 확인 후 진행 |
| Gate-5 | CLAUDE.md §4 Decision Support | 트레이드오프 발생 → 3-Consultants spawn | 사용자 선택 대기 |
| Gate-6 | CLAUDE.md §4 단계 3-c | Critical/High 0건 + Medium/Low ≥ 6건 → 추가 수정 여부 확인 | 사용자 확인 |
| Gate-7 | CLAUDE.md §4 단계 4 | Post-Audit 4항목 보고 후 사용자 확인 | 사용자 확인 |

---

## 2. 작업 수신 시 필수 체크리스트

사용자로부터 작업 요청을 수신하면, **실행 전에** 아래 체크리스트를 완성하여 제시한다.

```
## Workflow Enforcer Checklist

### 1. 요청 재진술 (Restate)
> {사용자의 요청을 1~2문장으로 정확히 재진술}

### 1-1. 작업 규모 판정 (Task Sizing)
- **등급:** {S / M / L}
- **근거:** {파일 수, 영향 범위, 아키텍처 변경 여부}

### 2. 적용 프로토콜 식별 (Protocol Match)
| Gate | 해당 여부 | 근거 |
|------|-----------|------|
| Gate-1: PAEV Pre-Plan | O/X | {판단 근거 — S등급 이상 해당} |
| Gate-2: Agent Flow Plan | O/X | {판단 근거 — M등급은 Gate-1과 통합, S등급은 생략} |
| Gate-3: Checkpoint | O/X | {해당 조건 명시} |
| Gate-4: Debate Protocol | O/X | {질문 유형 여부} |
| Gate-5: 3-Consultants | O/X | {트레이드오프 여부} |
| Gate-6: Feedback Loop | — | (실행 후 판단) |
| Gate-7: Post-Audit | — | (실행 후 판단) |

### 3. Pre-Plan (Gate-1 해당 시)
1. {단계 1: ...}
2. {단계 2: ...}
3. {단계 3: ...}

**수정 대상 파일:** {파일 목록}
**예상 영향 범위:** {범위 설명}

### [Status] `Execution Ready` — 사용자 승인 대기
```

---

## 3. 예외 규칙

아래 경우에는 체크리스트 없이 즉시 실행 가능:
- 단순 오타(철자) 수정
- 사용자가 명시적으로 "체크리스트 생략" 또는 "바로 진행"을 지시한 경우 (Pre-Plan 및 승인 게이트는 여전히 적용됨. 체크리스트 출력만 생략)
- `/help`, `/context` 등 시스템 명령 응답

---

## 4. 위반 감지 및 자가 교정

실행 중 다음 상황이 발생하면 **즉시 중단**하고 사용자에게 보고:
- Gate 해당 여부를 잘못 판정하여 승인 없이 진행한 경우
- 체크리스트 없이 변경/실행 도구를 사용한 경우
- 승인 범위를 초과하는 작업을 수행한 경우

보고 형식:
```
Workflow Violation Detected
- 위반 Gate: {Gate 번호}
- 위반 내용: {설명}
- 자가 교정: {중단 후 올바른 절차로 복귀}
```
