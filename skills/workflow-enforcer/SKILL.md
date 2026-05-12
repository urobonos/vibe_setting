---
name: workflow-enforcer
description: >
  orchestration 스킬의 3-Team 워크플로우 승인 규칙과 CLAUDE.md §3 Checkpoint / §4 Guardrails를 체크리스트로 강제하는 게이트.
  모든 작업 시작 시 자동 적용되며, 사용자 승인 없이 다음 팀으로 진입하는 것을 방지한다.
triggers:
  - "워크플로우 체크"
  - "workflow check"
  - "Gate-0"
  - "Gate-1"
  - "Gate-2"
  - "Gate-3"
  - "체크리스트 제시"
  - "승인 게이트"
  - "/workflow-enforcer"
version: 2.0.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Workflow Enforcer Skill

모든 작업 요청 수신 시, 실행 전에 아래 체크리스트를 완료하고 사용자에게 제시해야 한다.
**체크리스트 미제시 상태에서 변경/실행 도구(Edit, Write, Bash, Agent)를 사용하는 것은 지침 위반이다.**
**Why:** 체크리스트는 Gate-1(분석 보고) 통과의 객관 증거이며, 미제시 상태의 변경 도구 사용은 사용자 승인 없는 무단 진입과 동일해 롤백 추적이 불가능해진다.
Team 1(Analyze) 단계에서 Read-only 도구(Read, Grep, Glob)는 분석 목적으로 허용된다.

---

## 1. 승인 게이트 레지스트리

### 작업 유형 분류 — 코드 vs 비코드

작업 규모 판정 전에 먼저 **작업 유형**을 판별한다. 비코드 작업은 Gate-1만으로 실행 가능.

| 유형 | 대상 경로 | Gate 요구 | ~/.claude/docs/{product}/tasks 산출물 |
|------|----------|----------|-------------------|
| **비코드** | `docs/`, `.claude/`, `.agent-logs/`, `CLAUDE.md`, `scripts/pipeline/`, `memory/` | Gate >= 1 | 면제 |
| **코드** | `app/`, `components/`, `store/`, `hooks/`, `lib/`, `public/`, `messages/` 등 | Gate >= 2 | 필수 |

**비코드 작업 예시:** 스킬 수정, 훅 추가, 지침서 갱신, 메모리 저장, 파이프라인 스크립트 수정, 분석 문서 작성

**비코드 작업 워크플로우:**
1. 분석 방향 제시 → 사용자 승인 (Gate 0→1)
2. 비코드 파일 수정 실행 (Gate >= 1에서 즉시 가능)
3. Gate-2 불필요, ~/.claude/docs/{product}/tasks/ 산출물 불필요

### 작업 규모 분류 (Task Sizing) — 코드 작업 전용

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
**Why:** 이 3개 Gate 는 비가역 작업·잔여 결함·결과 검증의 마지막 안전망이라 작업 규모와 무관하게 생략하면 사용자가 결과 적합성을 확인할 기회 자체가 사라진다.

### Gate 0→2 묶음 승인 Fast-Track (M/L 코드 작업 입력 절감)

`gate-approve.sh` (UserPromptSubmit hook) 가 묶음 승인 키워드를 매칭하면 Gate 0 또는 1 에서 곧장 Gate 2 로 점프한다. analyze.md 와 plan.md 를 한 응답에 묶어 보고한 뒤 사용자가 한 번에 승인하는 패턴을 지원하기 위함이다.

**매칭 키워드 (정규식):**

| 언어 | 패턴 |
|------|------|
| 한국어 | `분석.{0,3}계획`, `계획.{0,3}분석`, `둘.?다`, `한.?번에`, `한꺼번에`, `묶어서`, `통째`, `모두.{0,3}(진행\|승인\|ok\|확인)`, `전체.{0,3}(진행\|승인\|ok\|확인)` |
| 영어 | `(all\|both)\s+(ok\|okay\|yes\|approve\|go\|proceed\|lgtm)` |

**예시:** "분석/계획 진행", "둘다 ok", "한번에 승인", "묶어서 진행", "all ok", "both approve"

**적용 조건:**
- Claude 는 analyze + plan 을 동일 응답에 함께 보고해야 fast-track 입력이 의미를 가진다. plan 미보고 상태에서 사용자가 "한번에 진행"을 입력해도 hook 은 Gate 2 로 올리지만, **task-docs 단계 문서 검증** (analyze.md / plan.md / result.md 중 1종 이상 존재) 을 통과하지 못하면 Edit/Write 가 차단된다.
- §3 Checkpoint 5조건은 본 fast-track 으로 우회되지 않는다 (`dangerous-ops-guard` 별도 hook).
  **Why:** Fast-Track 은 절차 단축용이지 비가역 작업 승인 권한까지 포괄하지 않으며, 단일 키워드로 Checkpoint 까지 통과시키면 사용자가 위험 작업 인지 없이 실행돼 복구 불가능한 변경이 발생한다.
- Gate-V1, Gate-3, Gate-6, Gate-7 는 동일하게 적용된다 (fast-track 은 Gate-1·Gate-2 통합 효과만 제공).

**보안:** Gate 0→2 점프 시에도 task-docs 검증 조건은 동일 (`gate-approve.sh` 의 `[ "$CURRENT" -lt 2 ] && [ "$NEW_LEVEL" -eq 2 ]`). 단계 문서 누락 시 차단되어 산출물 우회는 불가능하다.

### 산출물 유연성 (Flexible Deliverables) 예외 — 2026-05-12 갱신

CLAUDE.md §4 Guardrails "Flexible Deliverables" 와 정합. 신규 정책 (2026-05-12~) = 단일 통합 (`-unified.md`) 1개로 전환. 기존 3종 분리는 역소급 면제 (생성일 < 2026-05-12 보존). 작업 규모와 무관하게 단일 파일 안에서 필요한 섹션만 채울 수 있다. 단 Gate-3/6/7 은 항상 유지.

| 정책 | 작성 산출물 | 적용 Gate |
|-----|-----------|----------|
| **신규 Unified (2026-05-12~)** | (진행) `working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md` → (완료) `tasks/.../{yyyy-mm-dd}-{작업명}-unified.md` | Gate-1 + Gate-2 (M/L) / Gate-1 만 (S 경량 + 분석 단독) |
| **역소급 분석 단독** (생성일 < 2026-05-12) | `analyze.md` 만 | Gate-1 만 |
| **역소급 소규모 단발** (S 경량 경로) | `result.md` 만 | Gate-1 (Gate-2 통합) |
| **역소급 표준 다단계** (M/L) | analyze + plan + result 3종 | Gate-1 + Gate-2 |

**신규 정책 적용 판단:** "작업 시작일이 2026-05-12 이후인가?" 예 = 단일 통합 (`working/` → `tasks/` unified), 아니오 = 기존 3종 보존 (수정 시 변경 로그만 추가, 통합 변환 금지).

**Gate 진행 시 working/ 인지:**
- `working/` 경로는 `gate-enforce.sh` Gate-0 면제 (`output/` 와 동일 정책) — 분석 단계부터 즉시 작성 가능
- 단 코드 mutation (Edit/Write tasks/ 외 파일) 은 종전대로 Gate ≥ 2 필요. working/ 문서 작성 자체는 분석/계획 단계라 Gate-0 통과 OK
- Gate-1 / Gate-2 승인 자체는 working/ 단일 문서 안에 `## 분석` / `## 계획` 섹션 채워졌는지 확인 후 진행 (산출물 SSOT = `~/.claude/skills/task-docs/references/unified-template.md`)

**완료 시 자동 이동:**
- working/ 단일 통합 문서에 `^Status:\s*Done` + `## Self-Critique` 마커 동시 존재 → `working-lifecycle.sh` PostToolUse hook 자동으로 `tasks/` 이동
- 사용자 명시 키워드 (`/working-done` / `작업 완료` / `tasks 이동` 자연어) → 동일 이동 발동
- 이동 후 `doc-template-guard.sh` (`*-unified.md` 패턴) / `checklist-count-check.sh` (≥ 50) / `change-impact-section-check.sh` / `feasibility-section-check.sh` 사후 검증 1회

> **Why:** 단일 통합 정책은 파일 분리로 인한 컨텍스트 스왑·중복 메타데이터·summary 매핑 복잡도를 제거하면서, 단일 파일 안에서 필요한 섹션만 채우는 유연성은 그대로 보장한다. Gate 적용은 작업 규모 기준 (M/L 은 분석+계획 양쪽 승인, S 는 통합 1회 승인) 그대로 유지한다.

---

## 2. 작업 수신 시 필수 체크리스트

```
## Workflow Enforcer Checklist

### 1. 요청 재진술 (Restate)
> {사용자의 요청을 1~2문장으로 정확히 재진술}

### 1-1. 작업 유형 및 규모 판정

- **유형:** {비코드 / 코드}
- **비코드 판정 시:** Gate-1 승인 후 즉시 실행 (아래 규모 판정 생략)
- **등급:** {S / M / L} *(코드 작업만)*
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

### 4. 타당성 검토 (Feasibility Review) — **CLAUDE.md §4 5영역 해당 시에만 작성**

> 적용 영역: (1) 분석/설계 산출물 (2) 라이브러리·프레임워크 선택 (3) 아키텍처 결정 (4) API 설계·계약 변경 (5) 보안·인증 패턴. 일반 코드 수정·버그 픽스·리팩토링·명명·주석·typo 는 본 섹션 자동 생략.

| # | 권고/결정 사항 | 공식 근거 | 출처 |
|---|--------------|----------|------|
| 1 | {항목} | {근거} | {출처} |

> 적용 영역에서는 공식 문서(앤트로픽, 프레임워크, RFC, IEEE, OWASP 등) 근거 필수. 근거 없는 권고는 지침 위반.
> **Why:** 아키텍처·라이브러리·보안 결정은 retrofitting 비용이 크고 복구가 어려워, 공식 근거 없이 "통상적" 추정으로 진행하면 사용자가 사후에 결정 적합성을 검증할 수 없게 된다.

### 5. 변경 영향 기록 (Change Impact Log)
| # | 변경 사항 | 개선점 | 수행 이유 (Why) |
|---|----------|--------|----------------|
| 1 | {무엇이 변경되는가} | {어떤 개선이 있는가} | {왜 해야 하는가} |

> 이유 생략은 지침 위반.

### 6. 장기 관점 검증 (Long-term Perspective) — **CLAUDE.md §4.1 강제**

> 본 룰은 분석/계획 산출물(`analyze.md` / `plan.md`) 의 **"장기 영향 / 재발 방지 / SSOT 일관성"** 3섹션 작성 여부를 검증한다. 누락 시 Gate-1 / Gate-2 차단.

| 항목 | 작성 여부 | 핵심 내용 (1~2줄) |
|------|---------|-------------------|
| 장기 영향 (Long-term Impact) | O/X | {3~12개월 누적·전이·재발 시나리오} |
| 재발 방지 (Regression Prevention) | O/X | {hook/lint/test 등 차단 수단 + 차단 강도} |
| SSOT 일관성 (SSOT Consistency) | O/X | {본 작업과 어긋나는 룰/템플릿/hook 갱신 항목} |

> **S(단발) 작업** = 각 항목 1줄 + `"해당 없음 (사유)"` 허용. **M·L** = 실질 시나리오 1건+ 필수.
> **Why:** 단기 fix 누적은 SSOT 분기·산출물 정합성 붕괴 + 동일 문제 재발의 구조적 빚을 만든다 (CLAUDE.md §4.1 SSOT).

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
