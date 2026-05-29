---
parent_skill: orchestration
section: communication-protocol
생성일: 2026-05-11
---

# Communication Protocol

> **부모 스킬:** [`../SKILL.md`](../SKILL.md). 본 파일은 SKILL.md §3 Communication Protocol 분리 산출물.

## 3.1. Input Protocol (에이전트 prompt 구성)

| 항목 | 설명 |
|------|------|
| `Task_Goal` | 수행할 작업의 명확한 목표 |
| `Context_Path` | 선행 팀 산출물 파일 경로(기본). 에이전트가 직접 Read하여 사용한다. |
| `Context_Inline` | (1M 컨텍스트 모델 한정 예외) 산출물 원문을 prompt에 삽입. 3.1.1 조건 충족 시에만 허용. |
| `Authority_Level` | 권한 범위 (Read-only / Read-Write) |
| `Output_Format` | 반환 결과 기대 형식 |

## 3.1.1. 1M Context 예외 — 원문 주입 허용

**기본 원칙:** `Context_Path` 방식(경로만 전달, 에이전트가 Read)을 우선한다. 이유 — 주입 토큰 최소화, 캐시 재사용, 재현성 확보.

**예외 조건:** 현재 기준 모델이 1M context를 지원할 경우(현재 기준 모델 매핑은 orchestration §1.1 참조), 아래 조건 **중 하나라도** 해당하면 `Context_Inline`으로 원문 주입을 선택할 수 있다.

| 허용 조건 | 설명 |
|-----------|------|
| **교차 참조 필수** | analyze.md의 다중 섹션을 교차 대조해야 판단이 정확해지는 경우 (Architect, Worker) |
| **Read 불가 환경** | worktree/샌드박스 격리로 원본 파일 접근이 제한되는 경우 |
| **소용량 주입** | 총 주입 토큰이 50K 이하로 캐시 히트율 손상이 경미한 경우 |

**제약:**
- `Context_Inline` 선택 시 Orchestrator는 **선택 이유를 prompt 내 주석으로 명시**한다. 이유 미기록은 지침 위반.
- `Context_Path` + `Context_Inline` **동시 사용 금지** (에이전트 혼선 방지). 하나만 선택.
- **Why:** 동일 산출물이 경로와 원문 두 채널로 동시 전달되면 에이전트가 어느 쪽을 정본으로 삼아야 할지 판단할 수 없어 분석 결과가 두 버전으로 갈라지고 종합 단계에서 결론 편향이 발생한다.
- 5개 이상의 원문을 동시에 주입해야 하는 경우, 주입 대신 선행 단계에서 요약본을 생성해 전달한다.

## 3.2. Output Protocol (Orchestrator → 사용자)

| 태그 | 내용 |
|------|------|
| `[Analyze Report]` | Team 1 분석 결과 요약 |
| `[Plan Report]` | Team 2 계획 결과 요약 |
| `[Execute Report]` | Team 3 실행 결과 요약 |
| `[Status]` | 아래 상태 중 하나 |

## 3.3. Status 코드

| 상태 | 의미 | 다음 액션 |
|------|------|-----------|
| `Analyze Complete` | Team 1 완료, 승인 대기 | 승인 → Team 2 |
| `Plan Complete` | Team 2 완료, 승인 대기 | 승인 → Team 3 |
| `Progress` | Team 3 실행 중 | 완료 후 result.md |
| `Done` | 전체 완료 + 사용자 확인 | Terminate |
| `Failed` | 오류 발생 | Recovery 최대 3회 → 에스컬레이션 |

## 3.4. Decision Request (트레이드오프 발생 시)

| 항목 | 내용 |
|------|------|
| `[Issue Summary]` | 쟁점 요약 |
| `[Pragmatist]` | 실용적 대안 + 장단점 |
| `[Visionary]` | 이상적 대안 + 장단점 |
| `[Innovator]` | 제3의 대안 + 장단점 |
| `[Request]` | "사용자의 선택을 기다립니다." |
