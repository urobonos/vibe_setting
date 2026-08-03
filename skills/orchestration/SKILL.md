---
name: orchestration
description: >
  3-Team Orchestration (Analyze→Plan→Execute) 통합 스킬. 9-Core + 3-Consultants 페르소나,
  Model 통일 정책/Task Sizing, Communication Protocol, Team 상세 구조, Vibe Coding Group을 정의한다.
triggers:
  - "Model 할당"
  - "작업 등급"
  - "3-Team"
  - "Analyze→Plan→Execute"
  - "/orchestration"
version: 2.2.0
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

본 스킬은 **모든 작업의 default 진입점**이다. Lead = Claude 본체, 멤버는 Agent 도구로 cold context spawn.
**위임 트리거·직접작업 예외·판정 기준("cold context 분리 가치")·Concise Reporting = CLAUDE.md §4.2 "에이전트 우선 위임" + §4.4 "응답 간결" SSOT** (재기술 회피 — 본문 중복 폐기). 본 스킬 고유분(작업 유형별 Model 할당 + Lead 책임)만 아래 유지.

## 0.1. 작업 유형별 진입 모드·Model (본 스킬 고유)

| 작업 유형 | 진입 모드 | Model |
|-----------|-----------|-------|
| 코드베이스 탐색 (3쿼리+) | `Explore` agent | 시스템 기본 |
| 다파일 영향 분석 | Team 1 (Analyze) | opus |
| 다단계 구현 (M/L 등급) | 3-Team 전체 (Analyze→Plan→Execute) | opus 통일 (Part 1.1) |
| 설계 결정 (아키텍처·스키마·API) | `Plan` agent + Architect 페르소나 | opus |
| 단일 도메인 깊은 조사 | `general-purpose` agent | opus |
| API 추가·엔드포인트 디버깅 | `hongcafe:api-team` 스킬 | hongcafe:api-team SSOT |
| 의견 갈림·트레이드오프 | `taskflow:debate` 스킬 | debate SSOT |
| 보안 검토·OWASP 매핑 | `security-audit` 스킬 | security-audit SSOT |
| 스킬 생성·수정·최적화 | `skill-creator` 스킬 | 강제 진입점 |

## 0.2. Lead 책임 (위임 시에도 유지)

- Agent 호출은 Lead = Claude 본체 책임. Agent 결과만 raw 패스 금지.
- Lead 가 멤버 결과를 종합하여 사용자에게 통합 보고한다.
- §3 Checkpoint 우선 적용 — Checkpoint 발동 변경은 위임 여부와 무관하게 사용자 승인 필수.

**Why:** 메인 컨텍스트 오염 방지 + 다각적 검증 + 병렬 처리. 위임 default 가 깨지면 단일 컨텍스트에 검증이 집중되어 페르소나 오염·검증 누락·응답 지연이 동시 발생한다.

---

# Part 1. Agent Configuration

## 1.1. Model 할당 정책

**기본값 = opus 통일.** 한 오케스트레이션 단위(팀) 안의 모든 멤버는 동일하게 `opus` 로 spawn 한다. Agent 도구에서 `model` 을 생략하면 부모(opus) 를 상속하므로, 기본 케이스는 별도 명시 없이 통일이 보장된다.

| 멤버 성격 | Model | 비고 |
|----------|-------|------|
| 추론·검증·구현·분석 (대부분) | `opus` | 기본값. 생략 시 부모(opus) 상속과 동일 |
| 단발 조회·기계적 패턴 매칭 (경량) | `sonnet` (선택) | Lead 재량 — 추론 깊이가 결과에 영향 없을 때만 |

- **팀 내 모델 통일 (핵심):** 한 팀 멤버 간 모델을 섞지 않는다. 멤버별 추론 깊이가 다르면 가설·우선순위 비교가 무의미해지기 때문이다 (`hongcafe:api-team` SKILL §[실행 주체] 근거 정합).
- **effort 파라미터 없음:** Agent 도구는 `model` 만 지정한다 — reasoning effort 파라미터가 없다. effort 차등이 필요하면 Workflow `agent()` 경로에서만 가능하다.
- **sonnet 예외는 강제 아님:** 경량 멤버에 sonnet 을 쓸지는 Lead 판단. 정확성 우선이면 opus 유지가 안전한 기본값이다.
- Explore 에이전트는 `subagent_type: "Explore"` 사용, 시스템 기본값.
- **현재 기준 모델 (2026-06 기준):** `opus` = Opus 4.8 (1M context, knowledge cutoff 2026-01), `sonnet` = Sonnet 4.6, `haiku` = Haiku 4.5. 모델군이 교체되면 본 항목을 갱신한다.

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
| **Model 할당** | 기본 opus 통일 (Part 1.1). 경량 멤버 sonnet 은 Lead 재량. |

**Why:** Lead가 멤버 결과를 raw 그대로 패스하면 Orchestrator가 다시 종합해야 해 2-depth 위계가 무너지고, 종합 책임이 분산되어 후행 팀이 어떤 결론을 신뢰해야 할지 판단할 수 없게 된다.

### 병렬 fan-out 갯수 = 효율 상한 제안 (필수)

독립 태스크를 병렬 spawn 할 때 Lead 는 소극적 부분집합이 아니라 **최대 효율적으로 호출 가능한 갯수**를 제안한다:

`N = min(독립 작업 항목 수, 동시성 상한 min(16, cores−2))`

- **상한 초과** spawn = 큐잉만 유발 → wall-clock 이득 0 (낭비). **상한 미만** = 슬롯 유휴 → 비효율. 그 사이 최댓값이 "효율 상한".
- 등급 캡(§1.2)은 **작업 범위**를, 본 룰은 그 범위 내 **병렬 폭**을 규정 — 상충 아님. 작업 항목이 등급 멤버 수보다 적으면 항목 수가 상한.
- **'제안'이 기본값** — §3 Checkpoint·트레이드오프·동일 파일 mutation race 감지 시 사용자 승인/직렬 fallback 우선.

**Why:** 독립 작업을 소극적으로 직렬화하면 병렬 하니스의 wall-clock 이득을 버리고, 상한을 넘겨 spawn 하면 큐잉으로 되레 느려진다 — 효율 상한이 두 낭비의 교점이다.

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
- **§3.5 장기 관점 추천 (필수 — CLAUDE.md §4.4 의 전개 본문 carrier):** 제안·추천·옵션 제시 시 단기 효율보다 **장기 누적 비용·복잡도·유지보수성** 우선. **Why:** 단기 OK 옵션 누적 = SSOT 분기·hook 복잡도·기능 graveyard 증가, 6~12개월 후 유지보수 폭증. **방향성 (2026-06-01 16-Agent 패널 정밀화):** 장기 관점 = "복잡도 무조건 최소화·전부 SSOT 강제"가 아니라 방향성 — 실제 부담 = **(변동성 × 읽힘빈도 × 수명 × 경계-핫스팟 정렬)의 곱**이다.
  - **(a) 비가역** (사라지는 암묵지·미계측 트래픽 상태·폐기 대안의 '왜'·모듈 직접참조) = 사전 투자 **비대칭 집중** 추천.
  - **(b) 가역** (가독성·정적 복제·일반 부채) = 자동 GC·데이터 가시화로 사후 처리, 선제 강제 비추천.
  - **(c) 변동성 낮은 사실은 강제 말 것** — "무엇을 강제하지 *말아야* 하는가"가 강제 여부보다 비싼 판단 (정적 SSOT 강제·speculative 추상 = 비용 안 청구될 곳에 유연성 낭비).
  - **How to apply:** (1) "(추천)" = 장기 관점 best 옵션에 부착. (2) 단기 OK / 장기 부담 큰 옵션 = "단기 OK, 장기 SSOT 분기·복잡도 누적 가능" 명시 경고. (3) 신설 hook/슬래시/SSOT 권고 = "6개월 후에도 필요한가" + "이 사실이 실제로 변하는가(변동성)" 2질문 통과 후 추천 (변동성 낮으면 강제 말고 중복 허용). (4) 기존 시스템 폐기 권고 = "검증 안 됨 / 사용 빈도 낮음 / 누적 복잡도 vs 가치" 천칭에서 폐기 우선 고려. (5) 임시 우회·hardcode·feature flag = 거의 항상 비추천 — 단 자동 만료·GC 동반(가역화) 시 예외 (제거 비용 ≈ 0, `PUSH_EXCEPTION_UNTIL` 패턴). (6) 메모리·hook·skill 추가 = "지금 만들면 유지보수 책임" 인지 후 신설.
  - SSOT: CLAUDE.md §4.4 "장기 관점 추천" (원칙 요약) + 본 절 (전개 본문).

---

# Part 4. 3-Team Execution Detail

## 4.1. Team 1: Analyze

**목적:** 코드베이스 탐색, 영향 범위 분석, 리스크 식별, 다각적 관점 분석

**Lead:** Analyst (Lead Authority 주입)
**권한:** Read-only (`Read`, `Grep`, `Glob` 만 허용)

```
Orchestrator → Analyst Lead spawn (opus)
  Analyst Lead 내부:
    ├── Architect (opus)    ─── 아키텍처 정합성, 기존 패턴 위반
    ├── Security (opus)     ─── 보안 위험, 인증/인가 영향
    ├── Reviewer (opus)     ─── 코드 품질, 기술부채
    ├── Tester (opus)       ─── 엣지케이스, 테스트 가능성
    ├── Performance (opus)  ─── N+1, 병목, 캐시 전략
    ├── Data (opus)         ─── 스키마 영향, 데이터 무결성
    ├── Ops (opus)          ─── 배포 영향, 운영 안정성 (L등급)
    │
    ├── [트레이드오프 감지 시]
    │   └── Pragmatist + Visionary + Innovator 추가 spawn
    │
    └── Lead가 전원 결과 종합 → analyze.md → Orchestrator에 반환 → terminate
```

**S등급:** Lead + Architect + Security + Reviewer (4명)
**M등급:** Lead + 전원 (7명, Ops 제외)
**L등급:** Lead + 전원 (8명, Ops 포함)

**산출물:** working/ 통합 문서 `~/.claude/docs/working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md` 의 **§분석** 섹션 (완료 시 `-unified.md` 로 자동 이동). **`-analyze.md` 를 새로 만들지 않는다** — 역소급 열람 전용이다 (`task-docs/SKILL.md` §"단계별 산출물").

**필수 포함 섹션:**
- **타당성 검토 (Feasibility Review):** 모든 분석 권고에 앤트로픽 공식 문서, 프레임워크/라이브러리 공식 문서, 공신력 있는 기술 채널(RFC, IEEE, OWASP 등)을 근거로 제시한다. 근거 없는 주장·권고는 지침 위반.
  **Why:** "통상적", "일반적으로" 같은 표현으로 검토를 대체하면 분석이 LLM 환각·과거 학습 편향에 묶이고, 공식 근거 인용은 6개월 후 권고가 여전히 유효한지 추적 가능한 단일 매체를 만든다.
- **변경 영향 기록 (Change Impact Log):** 분석 결과 반영 시 변경되는 사항, 개선점, 왜 해야 하는지(수행 이유)를 필수 기록한다. 이유 생략은 지침 위반.
  **Why:** 변경 사항만 나열하면 6개월 후 "왜 이렇게 바꿨지?" 추적이 불가능해 회귀 시 원상 복구 근거가 사라지고, 동일 결정을 매번 처음부터 재논의하는 비용이 누적된다.

## 4.2. Team 2: Plan

**목적:** analyze.md 기반으로 실행 계획 수립, Blueprint 설계, 구현 가능성 검증

**Lead:** Analyst (Lead Authority 주입)
**Input:** Team 1 이 채운 **working/ 통합 문서 경로**를 `Context_Path` 로 전달. Lead 가 직접 Read 하여 §분석 을 사용.
**권한:** Read-only

```
Orchestrator → Analyst Lead spawn (opus, Context_Path: working/ 통합 문서 경로)
  Analyst Lead 내부:
    ├── Architect (opus)     ─── Blueprint, 디렉토리/클래스/메서드 구조
    ├── Worker (opus)        ─── 구현 실현 가능성, 작업량 추정
    ├── Security (opus)      ─── 보안 요구사항 반영 여부
    │
    ├── [트레이드오프 감지 시]
    │   └── Pragmatist + Visionary + Innovator 추가 spawn
    │
    └── Lead가 WBS + Blueprint + 실행 계획 종합 → plan.md → Orchestrator에 반환 → terminate
```

**S등급:** Lead + Architect + Worker (3명)
**M/L등급:** Lead + Architect + Worker + Security (4명)

**산출물:** 같은 working/ 통합 문서의 **§계획** 섹션 (+ step 분해 시 `-step-NN-{slug}.md` 평면 파일). **`-plan.md` 를 새로 만들지 않는다.**

**필수 포함 섹션:**
- **타당성 검토 (Feasibility Review):** 모든 설계·계획에 공식 문서 기반 근거를 제시한다. 근거 없는 설계 결정은 지침 위반.
  **Why:** 설계 결정은 한번 코드에 반영되면 수정 비용이 분석 단계의 10배 이상이며, 공식 문서 근거 없이 "통상적 패턴" 으로 결정 내리면 6개월 후 더 적합한 대안 발견 시 이미 의존 코드가 누적되어 마이그레이션이 불가능해진다.
- **변경 영향 기록 (Change Impact Log):** plan 반영 시 변경되는 사항, 개선점, 왜 해야 하는지(수행 이유)를 필수 기록한다. 이유 생략은 지침 위반.
  **Why:** Plan 의 변경 사유는 Execute 단계에서 멤버가 구현 결정을 내릴 때 권한 위임의 근거가 되며, 누락 시 멤버가 Plan 의도와 다른 구현으로 분기하거나 매번 Lead 재확인을 요청해 자율성이 무너진다.

## 4.3. Team 3: Execute

**목적:** plan.md 기반으로 구현, 검증, 테스트 수행

**Lead:** Worker (Lead Authority 주입)
**Input:** Team 2가 채운 **working/ 통합 문서 경로**(step 분해 시 그 step 파일 경로)를 `Context_Path` 로 전달. Lead 가 직접 Read 하여 §계획 을 사용.
**권한:** Read-Write
**격리:** Worktree (필수)

### Worktree Isolation 규칙

Team 3의 Worker Lead는 반드시 `isolation: "worktree"`로 spawn한다. worktree 격리 환경에서 수정한다.

**Why:** worktree 없이 원본 브랜치에서 직접 수정하면 사용자 승인 전에 코드가 이미 변경되어 거부 시 롤백 비용이 커지고, 테스트 실패·중간 산출물이 작업 트리를 오염시켜 재현성과 안전한 머지 경로가 모두 사라진다.

| 단계 | 동작 |
|------|------|
| **1. spawn** | Orchestrator가 Worker Lead를 `isolation: "worktree"`로 spawn → 격리된 복사본에서 작업 |
| **2. 구현** | Worker Lead + 멤버들이 worktree 내에서 구현·테스트·검증 수행 |
| **3. 보고** | Lead 가 전체 diff + 테스트 결과 + **§실행 기록**을 Orchestrator 에 반환 |
| **4. 머지 위임** | Orchestrator 는 **머지 절차를 여기서 재정의하지 않는다** — `/git:merge` 에 위임한다 (분기·정착·worktree 정리·차단 경계 전부 그쪽 SSOT) |
| **5. 거부** | worktree 브랜치 삭제 → 원본 코드 무영향 |

**주의사항:**
- **Checkpoint §3 5조건**(비가역 작업·3파일+ 광범위 변경·요구사항 상충 트레이드오프·외부 시스템 연동·권한 외 파일 접근) **해당 시 사용자 승인 대기 필수 — 승인 없이 merge 는 지침 위반이다.** 위임 대상(`/git:merge`)도 같은 승인을 요구하지만, 이 문장은 위임 경로를 안 타는 경우까지 덮는 안전 기본값이라 본문에 남긴다 (CLAUDE.md §4.4 "안전 기본값을 거스르는 룰은 BLOCK-path 여도 본문 산문 유지").
- Worktree 내에서 테스트 실행이 가능하므로, 반드시 테스트 통과 후 보고한다.
- **구현 제안 반영은 별도 승인 대기 없이 진행한다** (CLAUDE.md §4.2 "실행 책임 (1) 승인 대기 떠넘기기"). 단 **정착(머지)은 그 룰의 대상이 아니다** — 브랜치·worktree·push·머지 경계는 CLAUDE.md §4.3 + `worktree-enforce.sh`·`branch-enforce.sh`·`git-guard.py` 가 판정하며, 본 스킬은 그 판정을 우회하거나 요약해 옮기지 않는다.
- Vibe Coding Group 모드에는 적용하지 않는다 (병렬 worktree 간 merge 충돌 방지).

```
Orchestrator → Worker Lead spawn (opus, Context_Path: working/ 통합 문서(또는 step 파일) 경로, isolation: "worktree")
  Worker Lead 내부 (격리된 worktree에서 작업):
    ├── Worker 멤버 (opus)   ─── 레이어별 구현 (Model/Service/Controller)
    ├── Reviewer (opus)      ─── 코드 리뷰
    ├── Tester (opus)        ─── 테스트 작성/실행
    ├── Security (opus)      ─── 보안 검증 (L등급)
    ├── Performance (opus)   ─── 성능 검증 (L등급)
    ├── Ops (opus)           ─── 배포·운영 검증 (L등급)
    │
    ├── [Feedback Loop]
    │   Critical/High 이슈 → Worker가 수정 → Reviewer/Tester 재검증 (최대 3회)
    │
    ├── [트레이드오프 감지 시]
    │   └── 3-Consultants 추가 spawn
    │
    └── Lead가 구현 diff + 테스트 결과 + 이슈 대시보드 종합 → result.md → Orchestrator에 반환 → terminate

Orchestrator:
    ├── [채택] → 정착은 `/git:merge` 위임 (머지 가부·절차 판정 = 그쪽 + branch-enforce)
    └── [거부] → worktree 브랜치 삭제 → 원본 무영향
```

**등급별 멤버 구성:**

| 등급 | 멤버 |
|------|------|
| **S** | Lead + Worker 1 + Reviewer |
| **M** | Lead + Worker 2 + Reviewer + Tester |
| **L** | Lead + Worker 3 + Reviewer + Tester + Security + Performance + Ops |

**산출물:** 같은 working/ 통합 문서의 **§실행** 섹션 (+ `## Self-Critique`). **`-result.md` 를 새로 만들지 않는다.**

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

