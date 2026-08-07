---
description: 분석 단계 진입 — working/ 단일 통합 문서 §분석 섹션 채움 (관점별 요약 / Critical~Low 4분류 / 우선순위 권고 / 타당성 검토 / 장기 영향). task-docs SKILL.md thin wrapper
allowed-tools: Bash, Edit, Write, Read, Glob, Grep, Skill, Agent
argument-hint: "[작업명]  # 생략 시 진행 중 working/ 문서 식별"
---

분석 단계 진입 — working/ 단일 통합 문서의 §분석 섹션을 표준 양식으로 채운다. task-docs SSOT 의 thin wrapper.

## 인자

- `$ARGUMENTS` = (선택) 작업명 kebab-case. 생략 시 `~/.claude/docs/working/YYYYMMDD/` 가장 최근 파일 자동 식별.

## 참조 범위 (사전 전수 조사, 필수)

진입 즉시 CLAUDE.md §4.3 "참조 범위 전수 조사" 절차(3 출처 전수 조사)를 수행하고, §4.4 위치 표기로 참조 결과 표를 화면 출력한 뒤 다음 단계로 진입한다. 3 출처 표·가시화 표 양식·`해당 없음` 행 생략 금지·직전 단계 sweep 재사용 규칙 = 모두 §4.3 SSOT.

- **등급 비례:** S = ② index 스캔만 / M·L = ①②③ 전수.

## 동작 4단계

| 단계 | 동작 | 결과 |
|------|------|------|
| ① working/ 문서 식별 | 인자 있음 = 파일명 매칭 / 없음 = 가장 최근 working/ 파일 | 대상 파일 경로 |
| ② 양식 골격 prepend | `~/.claude/skills/task-docs/references/unified-template.md` SSOT 골격 prepend (파일 미존재 시) | `## 분석` 헤더 + 하위 표 |
| ③ §분석 섹션 채움 | 분석 관점별 요약 / Critical~Low 4분류 / 트레이드오프 / 우선순위 권고 + § 공통 (타당성 검토 / 변경 영향 기록 / 장기 영향 / 재발 방지 / SSOT 일관성) | 분석 체크리스트 = `unified-template.md` §체크리스트 골격 소진 (게이트는 **문서 총합 ≥ 30**, 섹션별·등급별 하한 없음) |
| ③-2 **변경 표면 인벤토리** | 수정 대상 ≥ 1건이면 호출부·read 경로 / 회귀 기준선 / 재사용 자산 / 테스트 커버 4종을 `git grep` 실측 (아래 §"변경 표면 인벤토리") | plan 이 step §파급면·§결함면·DoD 검증을 채울 원재료 |
| ④ Status 마커 부착 | 단독 라인 `Status: Analysis Complete` (아래 §"종료 마커") | tick 이 분석 재실행하지 않고 `/taskflow:plan` 부터 진입 |

> **비필수 사이드이펙트 백로그 격리 (Critical~Low 분류 전 사전 필터):** ③ 에서 발견한 항목이 **① 필수요소 아님 + ② 실제 문제·버그 아님 + ③ 사이드이펙트급** 3조건을 **모두** 충족하면 Critical~Low 등급 행을 **부여하지 말고** backlog 메모리(`docs/working/backlog/{yyyy-mm-dd}-{slug}.md` + MEMORY.md `## Backlog`)에만 기록 후 현재 분석을 계속한다. 하나라도 불충족 = 정상 4분류. **실제 버그는 경미해도 미루지 않음.** §3 매칭 항목은 사용자 보고. SSOT = CLAUDE.md §4.5 "비필수 사이드이펙트 백로그 격리".

## 변경 표면 인벤토리 (수정 대상 ≥ 1건일 때 필수)

§분석은 판정(Critical~Low)을 만들지만, `/taskflow:plan` 이 step §파급면·§결함면·재사용·DoD 검증을 채우려면 **심볼 단위 실측**이 있어야 한다. 없으면 plan 은 추측으로 쓰거나 `해당 없음` 으로 넘긴다 — 2026-08-05 실측에서 파급면 누락 step 이 정확히 그 경로였다 (`plan.md` §"§파급면을 계획 시점에 적는 이유").

| 항목 | 무엇을 실측하는가 | plan 의 소비처 |
|------|-----------------|--------------|
| **호출부·read 경로** | 변경 대상 심볼·컬럼을 `git grep` 전건. write 쪽만이 아니라 그 값을 **읽어 응답하는** EP·포맷터·DTO 까지 | step §파급면 |
| **회귀 기준선** | 바꾸려는 동작의 **현재** 값·형식·응답 (before). 코드 인용 또는 실행 결과 | step §결함면 회귀 축 — `cold-reviewer` 의 "그게 의도인가" 판정 근거 |
| **재사용 자산** | 같은 판정·변환을 이미 하는 기존 함수·lib·SSOT | step §작업 내용 (두 벌 만들지 않게) |
| **테스트 커버** | 이 영역을 덮는 기존 테스트 파일·필터 명령. 없으면 `없음` 명시 | step DoD 검증 명령 |

> **진단성 분석(수정 대상 0건)은 생략한다** — 고칠 게 없으면 표면도 없다 (§"단계 전이" T2 와 동일 조건).
> **등급 비례:** S = 호출부·read 경로만 / M·L = 4종 전부.
> **`해당 없음` 은 실측 후에만 쓴다.** grep 을 안 돌리고 비운 칸과 돌려서 0건인 칸을 구분하는 것이 이 표의 값 전부다.

## 종료 마커

```markdown
Status: Analysis Complete
```

§분석을 채운 뒤 unified 에 **단독 라인**으로 부착한다 (`Status: Done` 과 동일하게 뒤에 설명·구분자를 붙이지 않는다 — `unified-template.md` §규칙).

- **의미:** 분석 완료 / 계획 미수립. `/taskflow:plan` 이 `Status: Plan Complete` 로 덮어쓴다 (단일 축 — 단계별 필드를 따로 두지 않는다).
- **소비처:** `/taskflow:tick` 2단계 분기가 이 값을 보고 **분석을 재실행하지 않고 `/taskflow:plan` 부터** 진입한다. `report-work` 는 진행률 30% 로 집계한다.
- **코드 변경은 여전히 차단** — `gate-enforce.sh` 는 `Plan Complete|In Progress|Done|Partial` 만 통과시킨다 (분석만 끝난 상태에서 코드 mutation 금지, 의도된 제외).
- **자동 전이(T1∧T2)로 plan 까지 이어가는 경우** 이 마커는 `Plan Complete` 로 즉시 대체되므로 중간 상태로만 남는다.

## 단계 전이 (→ plan)

§분석 완료 후 `/taskflow:plan` 으로 **자동 전이할지**를 아래 두 축으로 판정한다. **본 섹션이 순방향 전이 조건의 단일 SSOT** — CLAUDE.md·`auto-iterate-reminder.sh` 는 여기를 포인터로 참조한다.

| 축 | 코드 | 조건 | 근거 |
|---|------|------|------|
| 의도 | T1 | `gate=2` (묶음 승인 활성) | 자동진행을 명시 요청한 상태에서만 |
| 성격 | T2 | §분석에 **수정 대상 ≥ 1건** 도출 | 진단(audit)이면 0건 |

- **T1 ∧ T2 → `/taskflow:plan` 자동 진입.** 전이 사유 1줄을 반드시 보고한다 (침묵 전이 금지).
- **T1 미충족 → 정지.** §분석 마치고 "plan 진입할까요?" 1줄 (침묵 종료 금지).
- **T2 미충족 (진단성 분석) → 자동 전이 금지.** CLAUDE.md §4.2 "audit 결과 자동 수정 금지" 를 준수한다 — 진단은 현황 보고이지 수정 계획을 낳는 task 가 아니다. 사용자 명시 수정 요청 시에만 plan 진입.

> **적용 범위 = `/taskflow:analyze` 한정.** `/hongcafe:api-spec-audit` · `/security-audit` 등 audit 슬래시는 본 전이의 대상이 아니다 (§4.2 가 직접 금지).
> **역방향과의 관계:** `/taskflow:execute` 중 결정이 막혀 analyze 로 되돌아온 경우(= `execute.md` §"결정 escalation ladder" L1)는 이미 bounded cap 을 소모한 상태이므로, 해소 후 **execute 로 복귀**하지 본 전이로 plan 을 다시 부르지 않는다 (순환 차단).

## 직병렬 실행 지침

**원칙:** 할당된 하위 태스크는 의존성을 먼저 판단 → 독립 태스크는 단일 응답 내 병렬(multi tool_use / Agent spawn), 의존 태스크는 직렬. 동일 파일 mutation·순서 의존 시 직렬 fallback (race 방지). 강제 병렬 modifier = `/taskflow:parallel`.

| 태스크 | 직렬·병렬 | 방법 |
|--------|----------|-----|
| ③ 내부: 다파일·다관점 분석 | **병렬 가능** | 여러 파일 Read 단일 응답 묶음 / 관점별(보안·성능·구조) Explore Agent 동시 spawn. 다모듈 = `/taskflow:parallel /taskflow:analyze` |
| ① → ② → ③ 골격 | **직렬** | 문서 식별 → 골격 prepend → 섹션 채움 (이전 단계 출력에 의존) |

## 자연어 trigger (task-docs 기존 호환)

- `분석해줘` / `분석 문서 작성` / `코드 분석 문서` / `영향 범위 조사 문서`

## 강제 hook

| Hook | 검증 | 차단 강도 |
|------|------|----------|
| `doc-unified-check.sh V1` | unified §분석 헤더 (분석 관점별 / Critical~Low / 우선순위 권고 / 장기 영향 / 재발 방지 / SSOT 일관성) | exit 2 (working/ 경로는 면제, tasks/ 이동 후 검증) |
| `doc-unified-check.sh V4` | unified 체크리스트 **문서 전체 합산 ≥ 30** — 평면값이라 등급 스케일이 없다 (CLAUDE.md §4.3 "단계 고정, 등급 무관") | exit 2 |
| `doc-unified-check.sh V6` | §타당성 검토 헤더 존재 시 `[Source:...]` ≥ 1건 | 경고 |
| `doc-unified-check.sh V3` | §변경 영향 + 3열 표 | 경고 |

## 호출 예

```
/taskflow:analyze                      ← 진행 중 working/ 문서 §분석 채움
/taskflow:analyze auth-refactor        ← 특정 작업 §분석 채움
/taskflow:analyze commerce 가격 정합성 audit  ← 신규 분석 작업 시작
```

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/CLAUDE.md` §4.1 "장기 관점 분석·계획·실행" + §File Paths "working/ 단일 통합 문서" | 정책 SSOT |
| `~/.claude/skills/task-docs/SKILL.md` | 본 슬래시의 본체 스킬 |
| `~/.claude/skills/task-docs/references/unified-template.md` | 양식 SSOT (§ 분석 섹션 골격) |
| `~/.claude/hooks/doc-unified-check.sh` V1 `v_template_guard` → `*unified*.md` 분기 | unified §분석 헤더 강제 |
| `~/.claude/hooks/doc-unified-check.sh` V4 `v_checklist_count` (:355~) | unified 체크리스트 임계 (`unified) MIN=30` 평면값) |
| `~/.claude/hooks/doc-unified-check.sh V6` | 타당성 검토 인용 강제 |
| **본 파일 §"단계 전이 (→ plan)"** | **순방향 전이 조건 (T1 gate=2 / T2 수정 대상 ≥1) SSOT** — CLAUDE.md·reminder hook 이 참조 |
| **본 파일 §"변경 표면 인벤토리"** | **plan 원재료 4종 SSOT** — 소비처 = `plan.md` §"파급면·결함면 — 골격 무관 공통" + DoD 검증 행 |
| **본 파일 §"종료 마커"** | **`Status: Analysis Complete` 부착 규약 SSOT** — 소비처 = `tick.md` 2단계 분기 / `working-scan.sh` 파싱 / `report-work` 진행률 |
| `~/.claude/custom-plugin/taskflow/commands/execute.md` §"결정 escalation ladder" | 역방향 분류 판별식 SSOT — 본 슬래시의 짝 (execute 중 결정 막힘 시 L1 재진입 대상) |

## §3 Checkpoint 우선 적용

분석 단계는 read-only 우선 (Read/Glob/Grep). working/ 문서 Edit 은 Gate-0 면제. 단 분석 결과가 광범위 (3 파일+ 아키텍처 변경 권고) 시 사용자 명시 승인 키워드 대기 후 §계획 진입.

**worktree 적용 (CLAUDE.md §4.3 (a)):** 본 슬래시 = `working/` 단일 통합 문서 §분석 채움. `working/` = functional exemption #5 (`*/.claude/docs/*`) → `worktree-enforce.sh` 자동 통과 (worktree 필수 아님). 단 분석 결과 적용 (§계획·§실행) 시 코드 mutation = worktree 강제.

## Skip 조건

| 등급 | 진행 여부 |
|------|----------|
| S | 압축 (Critical 만 / 트레이드오프·우선순위 권고 생략 가능) |
| M / L | **필수** — 관점별 요약 + Critical~Low 4분류 + 우선순위 권고 모두 채움 |

## 짝 슬래시

앞 = `/taskflow:draft`(원본 파일 기반 시작 시) / 뒤 = `/taskflow:plan` — **T1(gate=2) ∧ T2(수정 대상 ≥1) 충족 시 본 슬래시가 자동 전이**(§"단계 전이"). `/taskflow:feasibility` 는 §분석 도중 병행. 전체 맵 = `execute.md` §"워크플로우 맵" SSOT.

## Changelog

- 2026-08-05: `## 변경 표면 인벤토리` 신설 (호출부·read 경로 / 회귀 기준선 / 재사용 자산 / 테스트 커버 4종, 수정 대상 ≥1 조건부) + 동작 표 ③-2 행. 근거 = plan 의 §파급면·§결함면·DoD 검증이 심볼 단위 실측을 전제하는데 analyze 가 판정만 넘겨 plan 이 추측하거나 `해당 없음` 으로 비우던 경로 (`plan.md` 2026-08-05 정정과 짝)
- 2026-08-03: 구 `## 차별점` 표 → `## 짝 슬래시` 포인터로 축약 (전체 맵 SSOT = `execute.md` §"워크플로우 맵") + V4 임계를 등급 스케일로 적던 오기 정정 (실제는 문서 총합 ≥ 30 평면값) + 하드 줄번호 → 함수명
- 2026-05-15: 신설
