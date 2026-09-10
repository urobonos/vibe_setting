---
description: 리뷰 단계 진입 — Self-Critique 체크리스트(unified 골격 10항목) 채움 + cold 리뷰 루프(2인 병렬·클린까지) + simplify 스킬 보조 호출. 코드 재사용성·가독성·효율성 검토.
allowed-tools: Bash, Edit, Write, Read, Glob, Grep, Skill, Agent
argument-hint: "[작업명]  # 생략 시 진행 중 working/ 문서 식별"
---

리뷰 단계 진입 — working/ §실행 §Self-Critique 체크리스트를 채우고 `simplify` 스킬로 코드 품질 리뷰를 수행한다.

## 인자

- `$ARGUMENTS` = (선택) 작업명 kebab-case. 생략 시 가장 최근 working/ 파일 자동 식별.

## 참조 범위 (사전 전수 조사, 필수)

진입 즉시 CLAUDE.md §4.3 "참조 범위 전수 조사" 절차(3 출처 전수 조사)를 수행하고, §4.4 위치 표기로 참조 결과 표를 화면 출력한 뒤 다음 단계로 진입한다. 3 출처 표·가시화 표 양식·`해당 없음` 행 생략 금지·직전 단계 sweep 재사용 규칙 = 모두 §4.3 SSOT.

- **등급 비례:** S = ② index 스캔만 / M·L = ①②③ 전수.

## 동작 3단계

| 단계 | 동작 | 결과 |
|------|------|------|
| ① Self-Critique 채움 | working/ §실행 §Self-Critique 체크리스트 채움 (보안 / 로직 / 코드 품질 / 테스트 커버리지 / 이전 단계 검증). **개수 SSOT = `unified-template.md` §체크리스트** — unified 골격 10항목, 게이트는 문서 **총합 ≥ 30**(V4 `unified) MIN=30`)이라 섹션별 하한이 따로 없다 | 미체크 항목 처리 또는 잔여 이슈 기록 |
| **①.5 cold 리뷰 루프 (코드 변경 시)** | `reviewer-correctness` · `reviewer-design` 을 **병렬 spawn** → 지적을 본체가 수정 → 재리뷰. `Critical`·`High`·`Medium` 이 모두 0이 될 때까지, 그 뒤 **적대적 검증 게이트** (아래 §"cold 리뷰 루프"). 코드 변경 0 이면 skip | 라운드 로그 + 최종 `VERDICT` |
| ② simplify 스킬 호출 | 변경 파일에 대해 simplify 스킬 실행 (재사용성·가독성·효율성 리뷰) | 리뷰 결과 요약 |
| ③ working/ § 리뷰 섹션 기록 | simplify 결과 + Self-Critique 보강 항목 § 리뷰 (Review) 섹션에 기록 | 표 + 본문 |

> **비필수 사이드이펙트 백로그 격리:** Self-Critique·simplify 가 짚은 항목이 (① 필수요소 아님 + ② 문제·버그 아님 + ③ 사이드이펙트급) 3조건을 모두 충족하면 즉시 픽스하지 말고 backlog 메모리에만 기록. **보안·로직 결함 등 실제 문제는 경미해도 backlog 가 아니라 정상 처리** (②가 안전장치). SSOT = CLAUDE.md §4.5 "비필수 사이드이펙트 백로그 격리".

## cold 리뷰 루프 (단계 ①.5 — 코드 변경이 있을 때만, 2026-07-31~ / 2026-08-27 루프 승격)

**spawn 규약은 `watch.md` §"코드 축 — 변경분 리뷰" 가 SSOT 다** — 리뷰어 구성(`reviewer-correctness`·`reviewer-design` 2인 병렬)·입력 조립·판정축 7개 분담·반환 양식. 여기서 다시 적지 않는다. 입력 = 변경분 diff + 그 작업의 §계획·DoD.

**루프 제어는 `code.md` 가 SSOT 다** — 종료 조건(C·H·M 0)·캡(5회)·`Low` 처리·반박 판정·**적대적 검증 게이트**(`taskflow:adversary` · 캡 2회)·라운드 이력 형식·두 리뷰어 합본. 이것도 여기서 다시 적지 않는다.

**왜 self-critique 만으로 끝내지 않는가.** ① 은 자기가 쓴 코드를 자기가 보는 것이고, 그때 안 보이는 것이 있다. "사람이 결과를 즉시 보니 cold 가 불필요하다" 는 판단이 앞서 있었으나, 실제로 사용자는 **결과 요약을 보지 diff 전체를 읽지 않는다** — 그래서 사람 경로에도 독립 판정이 필요하다 (근거 실측 = `tick.md` §2-bis 2, 테스트 green 인 채 통과한 [Critical]).

**왜 1회에서 루프로 올렸는가 (2026-08-27).** 1회 판정의 근거는 "사람이 결과를 보고 다음을 정한다" 였는데, 그건 **바로 위 문단이 실측으로 부정한 그 전제다.** cold 를 도입한 근거와 루프를 막던 근거가 같은 전제였고, 전제가 죽었으면 종료 조건도 같이 움직여야 했다. 그대로 두는 동안 사람 경로만 리뷰어 1인·1회로 남아 **코드를 제대로 검증하려면 `/taskflow:tick`·`/taskflow:code` 로 새는** 구조가 됐다. 코드 작업의 리뷰 강도가 호출 경로마다 다를 이유가 없다.

**`code.md` 와 다른 것은 수정 주체 하나다.** 거기는 `step-developer` 가 고치고 **여기는 본체가 고친다** — 사람 경로엔 개발 Agent 가 없고 이미 본체가 그 코드를 썼다. 리뷰의 값은 **본 쪽이 cold** 라는 데 있지 짠 쪽이 서브에이전트라는 데 있지 않다. 따라서 `code.md` 의 `SendMessage` 전달·`REBUTTED` 반환은 여기 해당하지 않고, 반박이 필요하면 본체가 근거 3종을 직접 확인해 판정한다. **게이트가 `BROKEN` 을 내면 그것도 본체가 고친다** — 재현물이 붙어 있으므로 고쳤는지는 그 명령을 다시 돌려 확인한다.

**`simplify` 는 루프가 끝난 뒤 돈다.** `simplify` 는 **고치는** 스킬이라(`then apply the fixes`) 루프 안에 두면 리뷰 대상이 리뷰 중에 움직인다. 순서는 루프 클린 → **적대적 검증 게이트** → `simplify` 로 품질 정리다. 게이트도 같은 이유로 `simplify` 앞이다 — 반증 대상이 반증 중에 움직이면 재현이 무의미해진다.

- 지적은 **본체가** 고친다. 리뷰어는 Edit·Write 가 없어 고칠 수 없다.
- 수정 범위 = 지적 항목 + 그 심볼의 호출부 전건 (부분 적용이 가장 위험하다).
- 지적이 §3 매칭이거나 계획 자체를 바꾸면 고치지 말고 사용자에게 보고한다 — 루프를 계속 돌리지 않는다.
- 캡을 소진하고 C·H·M 이 남으면 **클린으로 만들지 않는다.** 잔여를 §리뷰 섹션에 남기고 보고한다.

> **무인 경로와 겹치지 않는다.** `/taskflow:tick` 은 `/taskflow:review` 를 타지 않는다 (`tick.md` §"step 코드리뷰 루프"). 겹쳐 돌리면 같은 코드를 cold 로 두 번 본다.

> **카탈로그 미등재 fallback** = `tick.md` §"카탈로그 미등재 fallback" SSOT.

## 직병렬 실행 지침

**원칙:** 할당된 하위 태스크는 의존성을 먼저 판단 → 독립 태스크는 단일 응답 내 병렬(multi tool_use / Agent spawn), 의존 태스크는 직렬. 동일 파일 mutation·순서 의존 시 직렬 fallback (race 방지). 강제 병렬 modifier = `/taskflow:parallel`.

| 태스크 | 직렬·병렬 | 방법 |
|--------|----------|-----|
| ① Self-Critique 채움 + **①.5 cold 리뷰 루프** | **병렬 가능** | 체크리스트 작성과 리뷰어 spawn 은 독립 → 동시 진행 |
| ①.5 → ② simplify | **직렬 필수** | `simplify` 는 코드를 고치므로 리뷰 루프보다 뒤여야 한다 (리뷰 대상이 움직이면 판정이 무의미) |
| ③ § 리뷰 기록 | **직렬** | ①·①.5·② 결과 종합 후 기록 |

## 자연어 trigger

- `리뷰해줘` / `Self-Critique` / `코드 리뷰` / `code review`

## 보조 스킬 호출

| 스킬 | 역할 |
|------|------|
| `simplify` | 변경된 코드의 재사용·품질·효율성 리뷰 후 이슈 픽스 |

## Self-Critique 영역 (항목 SSOT = `unified-template.md` §체크리스트)

| 영역 | 항목 |
|------|------|
| 보안 | 민감 정보 노출 / 인증·인가 / 입력값 검증 / SQL Injection·XSS |
| 로직 | 엣지 케이스 / 예외 흐름 / 사이드 이펙트 / 회귀 / NULL·빈값·기본값 / 동시성 |
| 코드 품질 | 컨벤션 / 불필요한 코드 / 네이밍 / 하드코딩 |
| 테스트 커버리지 | 신규 코드 단위 테스트 / 전체 스위트 통과 |
| 이전 단계 검증 | 분석·계획 체크리스트 전체 체크 완료 / 미체크 항목 잔여 이슈 기록 |

## 호출 예

```
/taskflow:review                                  ← 진행 중 working/ Self-Critique + simplify
/taskflow:review auth-refactor                    ← 특정 작업 리뷰
```

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/CLAUDE.md` §4.1 "Validation (No Test, No Merge)" | 정책 SSOT |
| `simplify` skill (Anthropic plugin, 글로벌 카탈로그 등재 — `~/.claude/skills/` 본체 없음) | 코드 품질 리뷰 진입점 (Skill 도구로 호출) |
| `custom-plugin/taskflow/agents/reviewer-correctness.md` · `reviewer-design.md` | **cold 리뷰 계약** — 판정축 7(기능 3 / 설계 4) · 등급 기준 · 반환 양식 · Edit/Write 부재 · `model: sonnet` |
| `custom-plugin/taskflow/agents/adversary.md` | **적대적 검증 계약** — 클린 판정 반증 · 반환 `BROKEN`/`UPHELD` · 공격면 5축 · 재현 강제 · Edit/Write 부재 · `model: opus` |
| `~/.claude/skills/task-docs/references/unified-template.md` § 실행 §Self-Critique + § 리뷰 | 양식 SSOT |

## §3 Checkpoint 우선 적용

본 슬래시는 분석·검토 위주 (read-only 우선). simplify 가 제안하는 코드 변경이 §3 5조건 매칭 시 사용자 명시 승인 후 적용.

**worktree 적용 (CLAUDE.md §4.3 (a)):** Self-Critique·simplify 진단 = read-only. simplify 권고 적용 시 코드 mutation 발생 → worktree 강제 (§실행 단계로 위임).

## Skip 조건

| 등급 | 진행 여부 |
|------|----------|
| S (단순 1~3줄 패치 / typo / 명명 변경) | 면제 — Self-Critique 인라인 1~2줄로 충분 |
| M / L | **권장** — Self-Critique 체크리스트 전건 + cold 리뷰 루프 + simplify 호출 |

## 짝 슬래시

앞 = `/taskflow:verify`(외부 환경) / 뒤 = `/taskflow:deploy`. 본 슬래시 = **내부 품질**(Self-Critique + cold 리뷰 루프 + simplify). 무인 경로에서는 `/taskflow:tick` 의 리뷰 루프가 이 자리를 대체한다. 전체 맵 = `execute.md` §"워크플로우 맵" SSOT.

## Changelog

- 2026-08-31: **①.5 루프 종료 뒤 적대적 검증 게이트 추가** (`taskflow:adversary` · 배선 SSOT = `code.md`). C·H·M 0 은 종료 후보이지 종료가 아니다 — 리뷰어는 대조 기준에 맞춰 보므로 기준의 틈은 못 본다. 여기 고유는 여전히 수정 주체(본체) 하나뿐
- 2026-08-27: **①.5 를 1회 판정 → 루프로 승격 + 리뷰어 2인 병렬.** 1회 판정의 근거("사람이 결과를 보고 정한다")는 바로 위 문단이 실측으로 부정한 그 전제였다. 그대로 두는 동안 사람 경로만 리뷰어 1인·1회로 남아, 코드를 제대로 검증하려면 `/taskflow:tick`·`/taskflow:code` 로 새는 구조였다. spawn 규약 = `watch.md` §"코드 축" / 루프 제어 = `code.md` — 여기 고유는 수정 주체(본체)뿐
- 2026-08-03: 구 `## 차별점` 표 → `## 짝 슬래시` 포인터로 축약 (전체 맵 SSOT = `execute.md` §"워크플로우 맵") + Self-Critique "≥ 20" 4곳 제거 (게이트 = 문서 총합 ≥ 30)
- 2026-07-31: **①.5 cold 판정 추가** (코드 변경 시) — self-critique 만으로는 자기가 쓴 코드의 결함이 안 보인다. `simplify` 앞에 두는 것이 필수(뒤에 두면 리뷰 대상이 리뷰 중에 움직인다). 1회 판정만 — 클린까지 반복은 무인 경로 소관
- 2026-05-15: 신설
