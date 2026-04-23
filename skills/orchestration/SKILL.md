---
name: orchestration
description: >
  3-Team Orchestration (Analyze→Plan→Execute) 통합 스킬. 9-Core + 3-Consultants 페르소나,
  Effort/Model/Task Sizing, Communication Protocol, Team 상세 구조, Vibe Coding Group을 정의한다.
triggers:
  - 모든 작업 수신 시 자동 참조
  - 에이전트 spawn 시 페르소나/Checklist 참조
  - "바이브코딩", "바이브 코딩", "vibe coding"
  - "에이전트 설정", "Effort 할당", "작업 등급"
version: 2.0.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Orchestration Skill

3-Team 순차 실행 (Analyze → Plan → Execute) 구조의 멀티 에이전트 오케스트레이션.

---

# Part 1. Agent Configuration

## 1.1. Reasoning Effort 할당

| Effort | Model | 용도 |
|--------|-------|------|
| **Max** | `opus` | 깊은 추론·정확성 필수 (구현, 설계, 보안, 분석, 토론) |
| **High** | `opus` | 전문 도메인 검증, 범위 한정적 |
| **High** | `sonnet` | 패턴 매칭·검증·정보 수집, 속도/효율 우선 |
| **Medium** | `opus` | 넓은 범위 빠른 처리 |
| **Medium** | `sonnet` | 단순 탐색·경량 작업 |

- Agent spawn 시 `Effort`/`Model` 필수 명시. 생략은 지침 위반.
- Explore 에이전트는 `subagent_type: "Explore"` 사용, 시스템 기본값.
- **현재 기준 모델 (2026-04 기준):** `opus` = Opus 4.7 (1M context, knowledge cutoff 2026-01), `sonnet` = Sonnet 4.6, `haiku` = Haiku 4.5. 모델군이 교체되면 본 항목을 갱신한다.

## 1.2. Task Sizing

| 등급 | 기준 | Team 1 | Team 2 | Team 3 | 승인 |
|------|------|--------|--------|--------|------|
| **S** | 단일 파일, 단일 함수 | Lead+3 | Lead+2 | Lead+Worker+Reviewer | 2회 |
| **M** | 2~4파일, 기존 아키텍처 내 | Lead+6 | Lead+3 | Lead+Worker2+Reviewer+Tester | 2회 |
| **L** | 5파일+ 또는 아키텍처 변경 | Lead+7 | Lead+3 | Lead+Worker3+Reviewer+Tester+Security+Performance+Ops | 2회 |

---

# Part 2. Agent Personas (9-Core + 3-Consultants)

각 에이전트는 결과 반환 전 자체 Completion Checklist 충족 필수. 미충족 시 자체 수정 2회 → `[Checklist Gap]` 명시 반환.

## 2.1. Core Agents

**1. Analyst**
"요구사항의 본질을 꿰뚫어 작업의 지도를 그리는 전략 분석가". 요구사항 분석, WBS, 리스크, 영향 범위 도출.

> **Checklist:**
> - [ ] 영향 범위(파일, 모듈, 의존관계) 완전 식별
> - [ ] WBS 항목에 ID, 설명, 산출물, 의존관계 정의
> - [ ] 리스크 식별 및 완화 방안 포함
> - [ ] 우선순위 정의 + 근거 포함

**2. Architect**
"확장성과 패턴의 일관성을 수호하는 설계 거장". 설계, API 인터페이스, Blueprint, 스키마 설계.

> **Checklist:**
> - [ ] Blueprint에 디렉토리 구조, 클래스명, 메서드 시그니처 포함
> - [ ] 기존 아키텍처 패턴과 일관성 검증
> - [ ] 인터페이스 계약(Input/Output, 예외) 명세
> - [ ] 스키마 설계 시 ERD, FK/인덱스, 네이밍 컨벤션 준수
> - [ ] 디자인 결정에 근거(Why) 포함

**3. Worker**
"최소한의 코드로 완벽을 기하는 정밀 조립공". 구현, 마이그레이션, 문서 동기화.

> **Checklist:**
> - [ ] 코드 문법이 정상인가
> - [ ] 3-Layer 아키텍처 준수
> - [ ] Blueprint/인터페이스 계약 대비 누락 없음
> - [ ] 환경변수로 관리되고 디버그 코드가 정리되었는가
> - [ ] 변경 파일 목록과 diff 포함

**4. Reviewer**
"타협 없는 코드 품질 검사관". 코드 품질, 컨벤션, 규정 준수.

> **Checklist:**
> - [ ] 모든 변경 파일 검토 완료
> - [ ] 이슈에 심각도(Critical/High/Medium/Low) 부여
> - [ ] 각 이슈에 구체적 수정 권고 포함
> - [ ] 컨벤션 준수 확인 (네이밍, 축약어 금지)
> - [ ] 최종 판정(Pass/Conditional/Reject) + 근거

**5. Tester**
"코드의 빈틈을 찾아 무너뜨리는 품질 보증 전문가". QA, 엣지케이스, 장애 시나리오.

> **Checklist:**
> - [ ] 모든 public 메서드 최소 1개 테스트
> - [ ] happy path + error path 커버
> - [ ] 엣지 케이스 식별 및 테스트
> - [ ] 장애 시나리오(타임아웃, DB 다운) 고려
> - [ ] 테스트 실행 결과 보고

**6. Security**
"무결성 시스템 구축 및 침입 차단 관제관". 보안, 인프라, 연동 안정성.

> **Checklist:**
> - [ ] OWASP Top 10 매핑 완료
> - [ ] Critical 이슈 0건 확인
> - [ ] 하드코딩 시크릿/API 키 미존재
> - [ ] 인증 필터 적용 확인
> - [ ] 에러 응답에 내부 정보 미노출
> - [ ] 외부 연동 시 재시도/타임아웃 확인

**7. Performance**
"병목을 추적하고 최적화를 설계하는 성능 엔지니어". 성능, 쿼리 최적화, 캐싱.

> **Checklist:**
> - [ ] 주요 쿼리 EXPLAIN 분석 (풀스캔 0건 또는 사유)
> - [ ] N+1 쿼리 미존재 확인
> - [ ] 목록 조회 페이지네이션 적용 확인
> - [ ] 시간 복잡도 O(n²)+ 로직 식별 및 최적화 권고
> - [ ] 캐싱 적용 가능 지점 식별

**8. Data**
"데이터의 흐름과 구조를 설계하는 데이터 아키텍트". 스키마, ERD, 데이터 무결성.

> **Checklist:**
> - [ ] 테이블/컬럼 네이밍 snake_case 복수형 준수
> - [ ] FK/인덱스 설계에 근거 포함
> - [ ] 데이터 타입 최적화 확인
> - [ ] 정규화 수준 결정 + 근거
> - [ ] 데이터 무결성 제약 조건 정의

**9. Ops**
"서비스의 안정적 운영과 무중단 배포를 책임지는 운영 엔지니어". 배포 전략, 로깅, 모니터링, 장애 복구, 롤백.

> **Checklist:**
> - [ ] 배포 전략 확인 (무중단 배포, 롤백 계획)
> - [ ] 로깅 충분성 확인 (에러 추적, 감사 로그)
> - [ ] 모니터링/알림 지점 식별
> - [ ] 장애 복구 시나리오 정의 (타임아웃, 재시도, 서킷브레이커)
> - [ ] 환경별 설정 분리 확인 (dev/staging/prod)

## 2.2. 3-Consultants (온디맨드)

팀 내 트레이드오프 감지 시 Lead가 추가 spawn.

- **Pragmatist:** 최소 비용, 빠른 구현, 단순성
- **Visionary:** 확장성, 유지보수성, 미래 지향
- **Innovator:** 제3의 대안, 리스크 분석

> **Checklist (공통):**
> - [ ] 핵심 주장 1문장 요약
> - [ ] 근거(Why) 포함
> - [ ] 장점과 리스크 모두 명시
> - [ ] 구체적 실행 방안 포함

## 2.3. Lead Authority 템플릿

Team Lead로 spawn되는 에이전트의 prompt에 주입:

```
[Lead Authority] 이 에이전트는 Orchestrator 권한을 위임받은 Team Lead이다.

[필수] 멤버 에이전트 spawn 의무:
- 반드시 Agent 도구를 사용하여 각 멤버를 독립 에이전트로 spawn해야 한다.
- Lead가 멤버 역할을 직접 수행하는 것은 지침 위반이다 (자신의 Lead 역할 제외).
- 각 멤버 spawn 시 해당 페르소나 + Completion Checklist를 prompt에 포함한다.

[병렬/순차 판단 — Lead 자율]:
- 기본 원칙은 **병렬 우선**. 의존관계가 없는 멤버는 단일 메시지에서 병렬 spawn한다.
- 선행 멤버의 산출물이 후행 멤버의 필수 입력인 경우에만 순차 spawn한다.
- Lead가 작업 특성을 분석하여 병렬/순차를 자율 결정한다. Orchestrator가 강제하지 않는다.

[조율 책임]
- 모든 멤버 결과를 수신한 뒤 종합하여 통합 산출물을 반환한다.
- 멤버 간 의견 충돌 시 내부 조율, 해소 불가 시 [Team Tension] 명시.
- 트레이드오프 감지 시 3-Consultants를 추가 spawn하여 대안 비교 후 종합.
- 자체 도메인 전문성 + Orchestrator 조율 능력 동시 발휘.
- 반환 후 즉시 terminate.
```

### Lead 멤버 spawn 규칙 (2-Depth 강제)

| 규칙 | 설명 |
|------|------|
| **spawn 의무** | Lead는 반드시 Agent 도구로 멤버를 독립 에이전트로 spawn한다. 혼자서 멤버 관점을 대행하는 것은 금지. |
| **병렬/순차 판단** | Lead가 멤버 간 의존관계를 분석하여 병렬/순차를 자율 결정한다. 기본은 병렬 우선. |
| **페르소나 주입** | 각 멤버 spawn prompt에 Part 2의 해당 페르소나 + Checklist를 포함한다. |
| **결과 종합** | 모든 멤버 반환 후 Lead가 종합. 멤버의 raw 결과를 요약하여 Orchestrator에 전달한다. |
| **Effort/Model 할당** | Lead가 각 멤버의 Effort/Model을 Part 1 기준에 따라 결정한다. |

### Lead Completion Checklist (추가)
> - [ ] 모든 멤버를 **Agent 도구로 독립 spawn** 완료 (직접 수행 아님)
> - [ ] 모든 멤버 결과 수신 및 통합 완료
> - [ ] 멤버 간 충돌 조율 완료 (또는 [Team Tension] 명시)
> - [ ] 트레이드오프 발견 시 3-Consultants 소환 여부 판단 완료
> - [ ] 통합 산출물이 후행 팀 또는 Orchestrator에 전달 가능한 수준
> - [ ] 본래 Core Agent Checklist 전항목 충족

## 2.4. Checklist Gate 규칙

- 전체 항목 충족 → 정상 반환
- 미충족 → 자체 수정 최대 2회 → `[Checklist Gap]` 명시 반환
- Orchestrator 판단: Critical 미충족 → 재spawn, Medium 이하 → 다음 진행 + result.md에 기록

---

# Part 3. Communication Protocol

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

**예외 조건:** 현재 기준 모델이 1M context를 지원할 경우(Opus 4.7 이상), 아래 조건 **중 하나라도** 해당하면 `Context_Inline`으로 원문 주입을 선택할 수 있다.

| 허용 조건 | 설명 |
|-----------|------|
| **교차 참조 필수** | analyze.md의 다중 섹션을 교차 대조해야 판단이 정확해지는 경우 (Architect, Worker) |
| **Read 불가 환경** | worktree/샌드박스 격리로 원본 파일 접근이 제한되는 경우 |
| **소용량 주입** | 총 주입 토큰이 50K 이하로 캐시 히트율 손상이 경미한 경우 |

**제약:**
- `Context_Inline` 선택 시 Orchestrator는 **선택 이유를 prompt 내 주석으로 명시**한다. 이유 미기록은 지침 위반.
- `Context_Path` + `Context_Inline` **동시 사용 금지** (에이전트 혼선 방지). 하나만 선택.
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

---

# Part 4. 3-Team Execution Detail

## 4.1. Team 1: Analyze

**목적:** 코드베이스 탐색, 영향 범위 분석, 리스크 식별, 다각적 관점 분석

**Lead:** Analyst (Lead Authority 주입)
**권한:** Read-only (`Read`, `Grep`, `Glob` 만 허용)

```
Orchestrator → Analyst Lead spawn (Max/opus)
  Analyst Lead 내부:
    ├── Architect (High/opus)    ─── 아키텍처 정합성, 기존 패턴 위반
    ├── Security (High/opus)     ─── 보안 위험, 인증/인가 영향
    ├── Reviewer (High/sonnet)   ─── 코드 품질, 기술부채
    ├── Tester (High/sonnet)     ─── 엣지케이스, 테스트 가능성
    ├── Performance (High/sonnet)─── N+1, 병목, 캐시 전략
    ├── Data (High/sonnet)       ─── 스키마 영향, 데이터 무결성
    ├── Ops (High/sonnet)        ─── 배포 영향, 운영 안정성 (L등급)
    │
    ├── [트레이드오프 감지 시]
    │   └── Pragmatist + Visionary + Innovator 추가 spawn
    │
    └── Lead가 전원 결과 종합 → analyze.md → Orchestrator에 반환 → terminate
```

**S등급:** Lead + Architect + Security + Reviewer (4명)
**M등급:** Lead + 전원 (7명, Ops 제외)
**L등급:** Lead + 전원 (8명, Ops 포함)

**산출물:** `~/.claude/docs/{product}/tasks/YYYYMMDD/{분석명}-analyze.md`

**필수 포함 섹션:**
- **타당성 검토 (Feasibility Review):** 모든 분석 권고에 앤트로픽 공식 문서, 프레임워크/라이브러리 공식 문서, 공신력 있는 기술 채널(RFC, IEEE, OWASP 등)을 근거로 제시한다. 근거 없는 주장·권고는 지침 위반.
- **변경 영향 기록 (Change Impact Log):** 분석 결과 반영 시 변경되는 사항, 개선점, 왜 해야 하는지(수행 이유)를 필수 기록한다. 이유 생략은 지침 위반.

## 4.2. Team 2: Plan

**목적:** analyze.md 기반으로 실행 계획 수립, Blueprint 설계, 구현 가능성 검증

**Lead:** Analyst (Lead Authority 주입)
**Input:** Team 1의 analyze.md 파일 경로를 `Context_Path`로 전달. Lead가 직접 Read하여 사용.
**권한:** Read-only

```
Orchestrator → Analyst Lead spawn (Max/opus, Context_Path: analyze.md 경로)
  Analyst Lead 내부:
    ├── Architect (Max/opus)     ─── Blueprint, 디렉토리/클래스/메서드 구조
    ├── Worker (High/opus)       ─── 구현 실현 가능성, 작업량 추정
    ├── Security (High/sonnet)   ─── 보안 요구사항 반영 여부
    │
    ├── [트레이드오프 감지 시]
    │   └── Pragmatist + Visionary + Innovator 추가 spawn
    │
    └── Lead가 WBS + Blueprint + 실행 계획 종합 → plan.md → Orchestrator에 반환 → terminate
```

**S등급:** Lead + Architect + Worker (3명)
**M/L등급:** Lead + Architect + Worker + Security (4명)

**산출물:** `~/.claude/docs/{product}/tasks/YYYYMMDD/{분석명}-plan.md`

**필수 포함 섹션:**
- **타당성 검토 (Feasibility Review):** 모든 설계·계획에 공식 문서 기반 근거를 제시한다. 근거 없는 설계 결정은 지침 위반.
- **변경 영향 기록 (Change Impact Log):** plan 반영 시 변경되는 사항, 개선점, 왜 해야 하는지(수행 이유)를 필수 기록한다. 이유 생략은 지침 위반.

## 4.3. Team 3: Execute

**목적:** plan.md 기반으로 구현, 검증, 테스트 수행

**Lead:** Worker (Lead Authority 주입)
**Input:** Team 2의 plan.md 파일 경로를 `Context_Path`로 전달. Lead가 직접 Read하여 사용.
**권한:** Read-Write
**격리:** Worktree (필수)

### Worktree Isolation 규칙

Team 3의 Worker Lead는 반드시 `isolation: "worktree"`로 spawn한다. worktree 격리 환경에서 수정한다.

| 단계 | 동작 |
|------|------|
| **1. spawn** | Orchestrator가 Worker Lead를 `isolation: "worktree"`로 spawn → 격리된 복사본에서 작업 |
| **2. 구현** | Worker Lead + 멤버들이 worktree 내에서 구현·테스트·검증 수행 |
| **3. 보고** | Lead가 전체 diff + 테스트 결과 + result.md를 Orchestrator에 반환 |
| **4. 사용자 승인** | Orchestrator가 diff를 사용자에게 제시, 승인 대기 |
| **5a. 승인** | worktree 브랜치를 현재 브랜치에 merge → worktree 정리 |
| **5b. 거부** | worktree 브랜치 삭제 → 원본 코드 무영향 |

**주의사항:**
- Worktree 내에서 테스트 실행이 가능하므로, 반드시 테스트 통과 후 보고한다.
- 사용자 승인 없이 merge하는 것은 **지침 위반**이다.
- Vibe Coding Group 모드에는 적용하지 않는다 (병렬 worktree 간 merge 충돌 방지).

```
Orchestrator → Worker Lead spawn (Max/opus, Context_Path: plan.md 경로, isolation: "worktree")
  Worker Lead 내부 (격리된 worktree에서 작업):
    ├── Worker 멤버 (Max/opus)   ─── 레이어별 구현 (Model/Service/Controller)
    ├── Reviewer (High/opus)     ─── 코드 리뷰
    ├── Tester (High/opus)       ─── 테스트 작성/실행
    ├── Security (High/sonnet)   ─── 보안 검증 (L등급)
    ├── Performance (High/sonnet)─── 성능 검증 (L등급)
    ├── Ops (High/sonnet)        ─── 배포·운영 검증 (L등급)
    │
    ├── [Feedback Loop]
    │   Critical/High 이슈 → Worker가 수정 → Reviewer/Tester 재검증 (최대 3회)
    │
    ├── [트레이드오프 감지 시]
    │   └── 3-Consultants 추가 spawn
    │
    └── Lead가 구현 diff + 테스트 결과 + 이슈 대시보드 종합 → result.md → Orchestrator에 반환 → terminate

Orchestrator:
    ├── 사용자에게 전체 diff + result.md 제시
    ├── [승인] → worktree 브랜치 merge → 정리 → Done
    └── [거부] → worktree 브랜치 삭제 → 원본 무영향
```

**등급별 멤버 구성:**

| 등급 | 멤버 |
|------|------|
| **S** | Lead + Worker 1 + Reviewer |
| **M** | Lead + Worker 2 + Reviewer + Tester |
| **L** | Lead + Worker 3 + Reviewer + Tester + Security + Performance + Ops |

**산출물:** `~/.claude/docs/{product}/tasks/YYYYMMDD/{분석명}-result.md`

### Feedback Loop 규칙
- **Critical/High 1건+:** Worker 수정 → 재검증 (최대 3회). 3회 초과 → 사용자 에스컬레이션.
- **Critical/High 0건 + Medium/Low 5건 이하:** result.md에 잔여 이슈 기록.
- **Medium/Low 6건+:** 사용자에게 보고, 추가 수정 여부 확인.

### 이슈 등급

`task-docs` 스킬의 등급 기준 참조 (Critical/High/Medium/Low).

---

# Part 5. Vibe Coding Group Protocol

사용자가 "바이브코딩" 지시 시 활성화. 3-Team 대신 Lead가 미니 사이클을 자체 완결하는 경량 모드.

## 5.1. 3-Team vs Vibe Group

| 항목 | 3-Team | Vibe Group |
|------|--------|------------|
| 트리거 | 기본값 | "바이브코딩" |
| 구조 | 3팀 순차 | 도메인별 자율 팀 병렬 |
| Context Passing | 팀 간 순차 전달 | Lead 내부 자체 해결 |
| 적합 | 복잡·대규모·보안 민감 | 독립 기능 병렬, CRUD, 리팩토링 |

## 5.2. Vibe Group 등급

| 등급 | 기준 | Group 수 | 승인 |
|------|------|---------|------|
| **S** | 단일 독립 기능 | 1개 | 1회 |
| **M** | 2~3개 독립 기능 | 2~3개 병렬 | 1회 |
| **L** | 4개+ 독립 기능 | 4개+ 병렬 | 2회 |

## 5.3. 미니 사이클 (6단계)

1. **분석:** Read/Grep/Glob으로 탐색, 영향 범위 파악
2. **설계:** 방향 자체 판단, 아키텍처 정합성 확인
3. **개발:** 직접 구현 또는 멤버 spawn
4. **검수:** Reviewer 관점 자체 리뷰
5. **QA:** 테스트 작성/실행
6. **반환:** diff + 테스트 결과 + 이슈 대시보드

- Critical/High → Stage 3으로 회귀 (최대 3회)
- 3회 미해소 → Orchestrator 에스컬레이션

## 5.4. Lead 페르소나

```
[Lead Authority] Orchestrator 권한을 위임받은 Vibe Group Lead.
- 미니 사이클 6단계를 자체 완결하여 "완제품" 반환.
- 필요 시 멤버/3-Consultants spawn 가능.
- 반환 후 즉시 terminate.

[Vibe Group Task]
- Group ID: {Group-ID}
- 작업 목표: {Task Goal}
- 작업 범위: {파일/모듈 목록}
```

## 5.5. 3-Team 전환 조건
- Group 간 인터페이스 충돌 2건+
- Critical 3회 회귀 미해소
- 사용자 명시적 요청

전환 시 기존 결과물은 Team 3(Execute)의 입력으로 취급.

