---
name: workflow-enforcer
description: >
  CLAUDE.md에 정의된 3-Team 워크플로우 승인 규칙을 체크리스트로 강제하는 게이트.
  모든 작업 시작 시 자동 적용되며, 사용자 승인 없이 다음 팀으로 진입하는 것을 방지한다.
triggers:
  - 모든 작업 요청 시 자동 적용 (CLAUDE.md §4 3-Team Workflow와 연동)
  - "워크플로우 체크", "workflow check"
mandatory: true
version: 2.0.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Workflow Enforcer Skill

모든 작업 요청 수신 시, 실행 전에 아래 체크리스트를 완료하고 사용자에게 제시해야 한다.
**체크리스트 미제시 상태에서 변경/실행 도구(Edit, Write, Bash, Agent)를 사용하는 것은 지침 위반이다.**
Team 1(Analyze) 단계에서 Read-only 도구(Read, Grep, Glob)는 분석 목적으로 허용된다.

---

## 1. 승인 게이트 레지스트리

### 작업 규모 분류 (Task Sizing)

| 등급 | 기준 | Gate 적용 | 비고 |
|------|------|-----------|------|
| **S (Small)** | 단일 파일, 단일 함수, 기존 패턴 반복 | Gate-1만 (Gate-2와 통합 보고) | Orchestrator 직접 실행 가능 (3-Team 생략 옵션) |
| **M (Medium)** | 2~4파일, 기존 아키텍처 내 변경 | Gate-1 + Gate-2 | 3-Team 전체 |
| **L (Large)** | 5파일 이상 또는 아키텍처 변경 | Gate-1 + Gate-2 | 3-Team 전체 |

### S등급 경량 경로

S등급 작업은 다음 두 가지 경로 중 하나를 선택한다:

- **경량 경로 (기본):** Orchestrator가 직접 분석 + 계획을 체크리스트로 보고 → 승인 → 직접 실행. 3-Team spawn 없음.
- **정식 경로:** 사용자가 "팀으로 분석해줘" 등 요청 시 M등급과 동일하게 3-Team 실행.

### Vibe Coding 경로

사용자가 "바이브코딩" 지시 시 활성화. 3-Team 대신 도메인별 Lead가 미니 사이클을 자체 완결하는 경량 모드.

- **Gate 적용:** Gate-V1(분석 보고 → 승인 1회) + Gate-3(Checkpoint) + Gate-7(Result)
- **Gate-1/Gate-2 미적용:** 3-Team 순차 구조가 아니므로 별도 Analyze/Plan 승인 불필요.
- **전환 조건:** Group 간 충돌 2건+ 또는 Critical 3회 미해소 시 3-Team으로 전환. 상세는 `orchestration` 스킬 Part 5 참조.

### Gate 참조 인덱스

| Gate | 참조 | 조건 요약 | 승인 키워드 |
|------|------|-----------|-------------|
| Gate-V1 | `orchestration` §5 | Vibe Coding 분석 보고 → 승인 1회 후 실행 | "진행", "ok", "yes", "ㄱㄱ" 등 |
| Gate-1 | `orchestration` 스킬 §4.1 | Team 1(Analyze) 완료 → analyze.md 보고 후 승인 대기 | "진행", "ok", "yes", "ㄱㄱ" 등 |
| Gate-2 | `orchestration` 스킬 §4.2 | Team 2(Plan) 완료 → plan.md 보고 후 승인 대기 | 동일 |
| Gate-3 | CLAUDE.md §3 | Checkpoint — 비가역적 작업, 광범위 영향, 요구사항 상충, 외부 연동 | 즉시 중단 + 승인 |
| Gate-4 | `debate` 스킬 | 질문 유형 입력 → 토론 진행 여부 확인 | 사용자 확인 |
| Gate-5 | `orchestration` 스킬 §2.2 | 트레이드오프 감지 → 3-Consultants 온디맨드 소환 (팀 내부) | Lead가 판단 |
| Gate-6 | `orchestration` 스킬 §4.3 | Team 3 Feedback Loop — Medium/Low ≥ 6건 → 추가 수정 여부 확인 | 사용자 확인 |
| Gate-7 | `orchestration` 스킬 §4.3 | Team 3 완료 → result.md 보고 후 사용자 확인 | 사용자 확인 |

**모든 등급 공통:** Gate-3 (Checkpoint), Gate-6 (Feedback Loop), Gate-7 (Result) 항상 적용.

---

## 2. 작업 수신 시 필수 체크리스트

```
## Workflow Enforcer Checklist

### 1. 요청 재진술 (Restate)
> {사용자의 요청을 1~2문장으로 정확히 재진술}

### 1-1. 작업 규모 판정 (Task Sizing)
- **등급:** {S / M / L}
- **근거:** {파일 수, 영향 범위, 아키텍처 변경 여부}
- **실행 경로:** {S경량 / S정식 / M정식 / L정식}

### 2. 적용 프로토콜 식별 (Protocol Match)
| Gate | 해당 여부 | 근거 |
|------|-----------|------|
| Gate-1: Team 1 Analyze | O/X | {S경량은 Orchestrator 직접, M/L은 Team spawn} |
| Gate-2: Team 2 Plan | O/X | {S경량은 Gate-1과 통합} |
| Gate-3: Checkpoint | O/X | {해당 조건 명시} |
| Gate-4: Debate Protocol | O/X | {질문 유형 여부} |
| Gate-5: 3-Consultants | — | (팀 내부에서 Lead가 판단) |
| Gate-6: Feedback Loop | — | (실행 후 판단) |
| Gate-7: Result | — | (실행 후 판단) |

### 3. 분석 요약 (Gate-1 해당 시)
1. {분석 항목 1}
2. {분석 항목 2}

**수정 대상 파일:** {파일 목록}
**예상 영향 범위:** {범위 설명}

### 4. 타당성 검토 (Feasibility Review)
| # | 권고/결정 사항 | 공식 근거 | 출처 |
|---|--------------|----------|------|
| 1 | {항목} | {근거} | {출처} |

> 공식 문서(앤트로픽, 프레임워크, RFC, IEEE, OWASP 등) 근거 필수. 근거 없는 권고는 지침 위반.

### 5. 변경 영향 기록 (Change Impact Log)
| # | 변경 사항 | 개선점 | 수행 이유 (Why) |
|---|----------|--------|----------------|
| 1 | {무엇이 변경되는가} | {어떤 개선이 있는가} | {왜 해야 하는가} |

> 이유 생략은 지침 위반.

### [Status] `Analyze Complete` — 사용자 승인 대기
```

---

## 3. 예외 규칙

아래 경우에는 체크리스트 없이 즉시 실행 가능:
- 단순 오타(철자) 수정
- 사용자가 명시적으로 "바로 진행"을 지시한 경우 (승인 게이트는 여전히 적용)
- `/help`, `/context` 등 시스템 명령 응답

---

## 4. 위반 감지 및 자가 교정

실행 중 다음 상황 발생 시 **즉시 중단** 후 사용자 보고:
- Gate 해당 여부를 잘못 판정하여 승인 없이 진행한 경우
- 체크리스트 없이 변경/실행 도구를 사용한 경우
- 승인 범위를 초과하는 작업을 수행한 경우

```
Workflow Violation Detected
- 위반 Gate: {Gate 번호}
- 위반 내용: {설명}
- 자가 교정: {중단 후 올바른 절차로 복귀}
```

---

## 5. Context Persistence 검증

워크플로우 실행 중 다음을 검증한다:

- **조기 중단 금지:** 토큰 예산 우려로 작업을 인위적으로 중단하지 않았는지 확인
- **압축 대비:** 대규모 에이전트 보고 수신 후, 현재 단계·완료 산출물·미완료 작업·핵심 결정사항이 메모리에 저장되었는지 확인
- **산출물 참조:** 에이전트 결과를 메인 컨텍스트에 전문 보관하지 않고, 요약 + 파일 경로 참조로 대체했는지 확인
