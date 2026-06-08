---
name: orchestration
description: >
  3-Team Orchestration (Analyze→Plan→Execute) 통합 스킬. 9-Core + 3-Consultants 페르소나,
  Effort/Model/Task Sizing, Communication Protocol, Team 상세 구조, Vibe Coding Group을 정의한다.
triggers:
  - "Effort 할당"
  - "작업 등급"
  - "3-Team"
  - "Analyze→Plan→Execute"
  - "/orchestration"
version: 2.1.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Orchestration Skill

3-Team 순차 실행 (Analyze → Plan → Execute) 구조의 멀티 에이전트 오케스트레이션.

> **[신규 산출물 정책 2026-05-12]** 3-Team 산출물 = **단일 통합 문서 (`-unified.md`) 1개**로 영구 보존. 기존 3종 분리 (`analyze.md` / `plan.md` / `result.md`) 는 **역소급 면제** (생성일 < 2026-05-12 보존). 신규 작업은 `~/.claude/docs/working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md` 단일 파일 안에 `## 분석` + `## 계획` + `## 실행` 섹션을 통합 작성하며, Team 완료 시 `working-lifecycle.sh` hook 이 `~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-unified.md` 로 자동 이동한다. **본 SKILL.md 본문의 `analyze.md` / `plan.md` / `result.md` 언급은 통합 문서의 `## 분석` / `## 계획` / `## 실행` 섹션을 가리키는 의미적 등가물로 해석한다** (3-Team 실행 흐름·Lead 책임·Worktree 격리 등 본 SKILL.md 의 모든 규칙은 그대로 적용). 상세 정합·작성 절차 = `~/.claude/skills/task-docs/SKILL.md` §"working/ 단일 통합 워크플로우" + `~/.claude/skills/task-docs/references/unified-template.md`.

---

# Part 0. Agent-First Default (필수)

본 스킬은 **모든 작업의 default 진입점**이다. Lead = Claude 본체, 멤버는 Agent 도구로 cold context spawn. 위임 default 원칙은 CLAUDE.md §4 "에이전트 우선 위임" 과 정합한다.

## 0.1. 자동 위임 트리거 (위임 default)

| 작업 유형 | 진입 모드 | Effort/Model | 사유 |
|-----------|-----------|--------------|------|
| 코드베이스 탐색 (3쿼리+) | `Explore` agent | 시스템 기본 | 메인 컨텍스트 오염 방지 |
| 다파일 영향 분석 | Team 1 (Analyze) | Lead+멤버 페르소나별 | 다각적 검증 |
| 다단계 구현 (M/L 등급) | 3-Team 전체 (Analyze→Plan→Execute) | Part 1 표 준수 | Worktree 격리 |
| 설계 결정 (아키텍처·스키마·API) | `Plan` agent + Architect 페르소나 | Max/opus | 근거 기반 판단 |
| 단일 도메인 깊은 조사 | `general-purpose` agent | High/opus | 답변 1회 분리 |
| API 추가·엔드포인트 디버깅 | `api-team` 스킬 (FE/BE/인프라 3-멤버) | api-team SSOT | 풀스택 병렬 |
| 의견 갈림·트레이드오프 | `debate` 스킬 | debate SSOT | 다관점 비교 |
| 보안 검토·OWASP 매핑 | `security-audit` 스킬 | security-audit SSOT | 전문 도메인 분리 |
| 스킬 생성·수정·최적화 | `skill-creator` 스킬 | skill-creator SSOT | 강제 진입점 (CLAUDE.md §4) |

## 0.2. 직접 작업 허용 (위임 제외)

다음 3가지에 한해 Claude 본체가 직접 처리한다. 직접 작업 결정 시 **한 줄로 사유 보고** (trivial / 단발 조회 / cost).

- **단일 파일 trivial 수정** — 오타 수정·1~3줄 패치·명백한 typo·import 한 줄 추가
- **단발성 조회 1회** — 단일 `git status` / `git log -n 1` / 단일 grep / 단일 cat
- **위임 비용 > 작업 비용 명백** — 답변 1문장으로 끝나는 사실 확인 질문, 메모리 단순 조회

## 0.3. 판정 기준

> **"이 작업이 cold context 로 분리해서 검증할 가치가 있나?"**
>
> - 예 → 위임 (Agent spawn)
> - 아니오 → 직접 (사유 보고)

**판단 애매한 경우 default = 위임.** 사용자가 매번 "에이전트 써" 라고 지시해야 하는 상황은 지침 위반이다.

## 0.4. Lead 책임 (위임 시에도 유지)

- Agent 호출은 Lead = Claude 본체 책임. Agent 결과만 raw 패스 금지.
- Lead 가 멤버 결과를 종합하여 사용자에게 통합 보고한다.
- §3 Checkpoint 우선 적용 — Checkpoint 발동 변경은 위임 여부와 무관하게 사용자 승인 필수.

**Why:** 메인 컨텍스트 오염 방지 + 다각적 검증(Reviewer/Security/Performance 페르소나) + 병렬 처리로 응답 시간 단축. 위임 default 가 깨지면 단일 컨텍스트에 모든 검증이 집중되어 페르소나 상호 오염·검증 누락·응답 지연이 동시 발생한다.

## 0.5. Concise Reporting (필수)

Lead 가 사용자에게 보고할 때 **결론 + 표/diff 위주**로 압축한다. 사족·진행 서술·중복 요약 제거.

| 항목 | 기본 양식 | 예외 |
|------|----------|------|
| 보고 시작 | 결론 1~2줄 | — |
| 본문 | 표 1개 또는 diff/패치 | — |
| 마무리 | 잔여 액션 1줄 | — |
| 면제 영역 | "Before/After 대조" / "타당성 검토" / "변경 영향 기록" / `tasks/` 산출물 | 양식 강제 — 그대로 유지하되 진행 서술만 제거 |
| 상세 풀이 | 사용자 명시 질문 시에만 | "더 자세히", "왜 그래", "근거는" |

**Why:** 멤버 결과를 통합한 Lead 보고가 길어지면 사용자가 핵심을 골라내야 하는 비용이 발생하고, "보고 행위 자체 = 작업 완료 신호" 로 변질된다. 본 룰은 CLAUDE.md §4 "응답 간결" 의 멀티 에이전트 보고 영역 매핑이며 SSOT 는 CLAUDE.md.

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
- **Why:** Effort/Model 미명시 시 시스템 기본값으로 폴백되어 작업 난이도와 무관한 모델이 배정되며, 비용·정확성·응답 시간이 모두 통제 불능 상태가 된다.
- Explore 에이전트는 `subagent_type: "Explore"` 사용, 시스템 기본값.
- **현재 기준 모델 (2026-05 기준):** `opus` = Opus 4.8 (1M context, knowledge cutoff 2026-01), `sonnet` = Sonnet 4.6, `haiku` = Haiku 4.5. 모델군이 교체되면 본 항목을 갱신한다.

## 1.2. Task Sizing

| 등급 | 기준 | Team 1 | Team 2 | Team 3 | 승인 |
|------|------|--------|--------|--------|------|
| **S** | 단일 파일, 단일 함수 | Lead+3 | Lead+2 | Lead+Worker+Reviewer | 2회 |
| **M** | 2~4파일, 기존 아키텍처 내 | Lead+6 | Lead+3 | Lead+Worker2+Reviewer+Tester | 2회 |
| **L** | 5파일+ 또는 아키텍처 변경 | Lead+7 | Lead+3 | Lead+Worker3+Reviewer+Tester+Security+Performance+Ops | 2회 |

**Why:** S/M/L 등급별 멤버 수 차등은 단일 함수 수정에 7명 페르소나를 spawn하는 토큰 낭비와 L등급 아키텍처 변경에 3명만 투입하는 검증 누락을 동시에 방지한다. 등급 무시 시 작업 비용·검증 깊이가 모두 어긋난다.

---

# Part 2. Agent Personas (9-Core + 3-Consultants)

각 에이전트는 결과 반환 전 자체 Completion Checklist 충족 필수. 미충족 시 자체 수정 2회 → `[Checklist Gap]` 명시 반환.

**Why:** Checklist는 cold context에서 spawn된 멤버가 해당 페르소나의 책임 범위를 빠짐없이 검증하는 유일한 수단이며, 누락 시 Lead가 "어디까지 검증되었는지" 알 수 없어 후행 팀이 빈틈을 안고 진행한다.

## 2.1. Core Agents (9-Core)

9-Core 페르소나 상세 (역할·트리거·산출물·Completion Checklist) 는 [`references/team-personas.md`](references/team-personas.md) 를 참고.

**요약 매트릭스:**

| # | 페르소나 | 역할 1줄 | 주요 트리거 |
|---|---------|---------|-----------|
| 1 | Analyst | 요구사항 분석·WBS·리스크·영향 범위 도출 | 분석 진입, Team 1/2 Lead |
| 2 | Architect | 설계·API 인터페이스·Blueprint·스키마 설계 | 아키텍처 결정, Blueprint 수립 |
| 3 | Worker | 구현·마이그레이션·문서 동기화 | Team 3 Lead, 코드 작성 |
| 4 | Reviewer | 코드 품질·컨벤션·규정 준수 검사 | 코드 리뷰, 컨벤션 검증 |
| 5 | Tester | QA·엣지케이스·장애 시나리오 | 테스트 작성/실행 |
| 6 | Security | 보안·인프라·연동 안정성 (OWASP) | 보안 검토, 인증/인가 영향 |
| 7 | Performance | 성능·쿼리 최적화·캐싱·N+1 | 병목 추적, EXPLAIN 분석 |
| 8 | Data | 스키마·ERD·데이터 무결성 | 스키마 설계, FK/인덱스 |
| 9 | Ops | 배포 전략·로깅·모니터링·롤백 | 운영 안정성, L등급 진입 |

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

**Why:** Lead가 멤버 페르소나를 직접 대행하면 단일 컨텍스트에서 역할 간 결론이 상호 오염되어 다각적 검증이 무력화되며, Agent 도구 spawn만이 cold context와 페르소나 분리를 보장한다.

### Lead 멤버 spawn 규칙 (2-Depth 강제)

| 규칙 | 설명 |
|------|------|
| **spawn 의무** | Lead는 반드시 Agent 도구로 멤버를 독립 에이전트로 spawn한다. 혼자서 멤버 관점을 대행하는 것은 금지. |
| **병렬/순차 판단** | Lead가 멤버 간 의존관계를 분석하여 병렬/순차를 자율 결정한다. 기본은 병렬 우선. |
| **페르소나 주입** | 각 멤버 spawn prompt에 Part 2의 해당 페르소나 + Checklist를 포함한다. |
| **결과 종합** | 모든 멤버 반환 후 Lead가 종합. 멤버의 raw 결과를 요약하여 Orchestrator에 전달한다. |
| **Effort/Model 할당** | Lead가 각 멤버의 Effort/Model을 Part 1 기준에 따라 결정한다. |

**Why:** Lead가 멤버 결과를 raw 그대로 패스하면 Orchestrator가 다시 종합해야 해 2-depth 위계가 무너지고, 종합 책임이 분산되어 후행 팀이 어떤 결론을 신뢰해야 할지 판단할 수 없게 된다.

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

Input/Output Protocol, Status 코드, Decision Request 형식 상세는 [`references/communication-protocol.md`](references/communication-protocol.md) 를 참고. 본문에서는 진입 절차만 요약.

- **§3.1 Input:** Agent prompt = `Task_Goal` + `Context_Path` (선행 팀 산출물 경로) + `Authority_Level` + `Output_Format`. **§3.1.1 1M Context 예외:** 1M context 지원 모델에서 교차 참조 필수 / Read 불가 환경 / 50K 이하 소용량 시 `Context_Inline` 원문 주입 허용 — `Context_Path` 와 동시 사용 금지.
- **§3.2 Output:** `[Analyze Report]` / `[Plan Report]` / `[Execute Report]` + `[Status]`. **§3.3 Status:** `Analyze Complete` / `Plan Complete` / `Progress` / `Done` / `Failed`. **§3.4 Decision Request:** 트레이드오프 발생 시 `[Issue Summary]` + `[Pragmatist]` / `[Visionary]` / `[Innovator]` 대안 + `[Request]` 형식으로 사용자 선택 요청.
- **§3.5 장기 관점 추천 (필수):** Decision Request 대안 제시 시 단기 효율 (Pragmatist 즉시 동작) 만 보지 말고 **장기 누적 비용·복잡도·유지보수성** 가중. (1) "(추천)" 표시는 6~12개월 후 시점 best 옵션에. (2) 단기 OK / 장기 부담 옵션 = "장기 SSOT 분기·hook 복잡도 누적" 명시 경고. (3) 신설 hook / 스킬 / SSOT 권고 = "6개월 후에도 필요한가" 자가 점검. (4) 기존 시스템 폐기 권고 시 = "검증 안 됨 / 사용 빈도 낮음 / 누적 복잡도 vs 가치" 천칭에서 폐기 우선 고려. (5) 임시 우회·hardcode·feature flag = 거의 항상 비추천. SSOT: CLAUDE.md §4.4 "장기 관점 추천".

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

**산출물:** `~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-analyze.md`

**필수 포함 섹션:**
- **타당성 검토 (Feasibility Review):** 모든 분석 권고에 앤트로픽 공식 문서, 프레임워크/라이브러리 공식 문서, 공신력 있는 기술 채널(RFC, IEEE, OWASP 등)을 근거로 제시한다. 근거 없는 주장·권고는 지침 위반.
  **Why:** "통상적", "일반적으로" 같은 표현으로 검토를 대체하면 분석이 LLM 환각·과거 학습 편향에 묶이고, 공식 근거 인용은 6개월 후 권고가 여전히 유효한지 추적 가능한 단일 매체를 만든다.
- **변경 영향 기록 (Change Impact Log):** 분석 결과 반영 시 변경되는 사항, 개선점, 왜 해야 하는지(수행 이유)를 필수 기록한다. 이유 생략은 지침 위반.
  **Why:** 변경 사항만 나열하면 6개월 후 "왜 이렇게 바꿨지?" 추적이 불가능해 회귀 시 원상 복구 근거가 사라지고, 동일 결정을 매번 처음부터 재논의하는 비용이 누적된다.

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

**산출물:** `~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-plan.md`

**필수 포함 섹션:**
- **타당성 검토 (Feasibility Review):** 모든 설계·계획에 공식 문서 기반 근거를 제시한다. 근거 없는 설계 결정은 지침 위반.
  **Why:** 설계 결정은 한번 코드에 반영되면 수정 비용이 분석 단계의 10배 이상이며, 공식 문서 근거 없이 "통상적 패턴" 으로 결정 내리면 6개월 후 더 적합한 대안 발견 시 이미 의존 코드가 누적되어 마이그레이션이 불가능해진다.
- **변경 영향 기록 (Change Impact Log):** plan 반영 시 변경되는 사항, 개선점, 왜 해야 하는지(수행 이유)를 필수 기록한다. 이유 생략은 지침 위반.
  **Why:** Plan 의 변경 사유는 Execute 단계에서 멤버가 구현 결정을 내릴 때 권한 위임의 근거가 되며, 누락 시 멤버가 Plan 의도와 다른 구현으로 분기하거나 매번 Lead 재확인을 요청해 자율성이 무너진다.

## 4.3. Team 3: Execute

**목적:** plan.md 기반으로 구현, 검증, 테스트 수행

**Lead:** Worker (Lead Authority 주입)
**Input:** Team 2의 plan.md 파일 경로를 `Context_Path`로 전달. Lead가 직접 Read하여 사용.
**권한:** Read-Write
**격리:** Worktree (필수)

### Worktree Isolation 규칙

Team 3의 Worker Lead는 반드시 `isolation: "worktree"`로 spawn한다. worktree 격리 환경에서 수정한다.

**Why:** worktree 없이 원본 브랜치에서 직접 수정하면 사용자 승인 전에 코드가 이미 변경되어 거부 시 롤백 비용이 커지고, 테스트 실패·중간 산출물이 작업 트리를 오염시켜 재현성과 안전한 머지 경로가 모두 사라진다.

| 단계 | 동작 |
|------|------|
| **1. spawn** | Orchestrator가 Worker Lead를 `isolation: "worktree"`로 spawn → 격리된 복사본에서 작업 |
| **2. 구현** | Worker Lead + 멤버들이 worktree 내에서 구현·테스트·검증 수행 |
| **3. 보고** | Lead가 전체 diff + 테스트 결과 + result.md를 Orchestrator에 반환 |
| **4. 머지 분기 판정** | Orchestrator가 변경 내용을 Checkpoint §3 5조건(비가역/광범위/트레이드오프/외부/권한외) 에 대조 → 5a / 5b / 5c 중 하나로 분기 |
| **5a. Checkpoint 해당 → 승인 대기** | diff + result.md 제시 → 사용자 승인 시 merge → worktree 정리 / 거부 시 worktree 브랜치 삭제 |
| **5b. Checkpoint 무관 + 일반 개선** | Default Accept 적용 → 별도 승인 대기 없이 merge → worktree 정리 (CLAUDE.md §4 "실행 책임 (1) 승인 대기 떠넘기기" 정합) |
| **5c. 거부** | worktree 브랜치 삭제 → 원본 코드 무영향 |

**주의사항:**
- Worktree 내에서 테스트 실행이 가능하므로, 반드시 테스트 통과 후 보고한다.
- **머지 정책 (CLAUDE.md §4 Default Accept 정합):**
  - **Checkpoint §3 5조건 해당** (비가역 작업·3개 이상 파일 광범위 변경·요구사항 상충 트레이드오프·외부 시스템 연동·권한 외 파일 접근) → 사용자 승인 대기 필수. 승인 없이 merge 는 지침 위반.
  - **그 외 일반 개선** (리팩토링·명명 개선·누락 처리·방어 코드 등 사용자가 diff 로 즉시 검증 가능한 변경) → Default Accept 적용. 별도 승인 대기 없이 자동 merge 진행.
  - **Why:** 모든 Team 3 결과를 무조건 승인 대기로 묶으면 CLAUDE.md §4 "Default Accept" 와 정면 충돌하고, Worktree 사용 여부에 따라 같은 변경이 다르게 처리되는 모순이 생긴다. Worktree 격리의 가치(테스트 오염 방지·롤백 안전성)는 자동 머지 분기에서도 동일하게 유지된다.
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
    ├── [Checkpoint §3 5조건 해당] → 사용자에게 diff + result.md 제시
    │     ├── [승인] → worktree 브랜치 merge → 정리 → Done
    │     └── [거부] → worktree 브랜치 삭제 → 원본 무영향
    └── [Checkpoint 무관 + 일반 개선] → Default Accept → worktree 브랜치 merge → 정리 → Done
```

**등급별 멤버 구성:**

| 등급 | 멤버 |
|------|------|
| **S** | Lead + Worker 1 + Reviewer |
| **M** | Lead + Worker 2 + Reviewer + Tester |
| **L** | Lead + Worker 3 + Reviewer + Tester + Security + Performance + Ops |

**산출물:** `~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-result.md`

### Feedback Loop 규칙
- **Critical/High 1건+:** Worker 수정 → 재검증 (최대 3회). 3회 초과 → 사용자 에스컬레이션.
- **Critical/High 0건 + Medium/Low 5건 이하:** result.md에 잔여 이슈 기록.
- **Medium/Low 6건+:** 사용자에게 보고, 추가 수정 여부 확인.

### 이슈 등급

`task-docs` 스킬의 등급 기준 참조 (Critical/High/Medium/Low).

---

# Part 5. Vibe Coding Group Protocol

사용자가 "바이브코딩" 지시 시 활성화. 3-Team 대신 Lead 가 미니 사이클을 자체 완결하는 경량 모드.

Vibe Coding Group 상세 (등급·미니 사이클·Lead 페르소나·3-Team 전환 조건) 는 [`references/vibe-coding-group.md`](references/vibe-coding-group.md) 를 참고.

- **§5.1 vs 3-Team:** 독립 기능 병렬·CRUD·리팩토링 등 빠른 반복 / 소규모 작업용. **§5.2 등급:** S (1개 Group, 1회 승인) / M (2~3 병렬, 1회) / L (4개+ 병렬, 2회).
- **§5.3 미니 사이클:** 분석 → 설계 → 개발 → 검수 → QA → 반환 (6단계). Critical/High → Stage 3 회귀 최대 3회.
- **§5.4 Lead 페르소나:** Orchestrator 권한 위임받은 Vibe Group Lead, 자체 완결 후 즉시 terminate.
- **§5.5 3-Team 전환 조건:** Group 간 인터페이스 충돌 2건+ / Critical 3회 회귀 미해소 / 사용자 명시 요청 → 기존 결과물은 Team 3(Execute) 입력으로 취급.

