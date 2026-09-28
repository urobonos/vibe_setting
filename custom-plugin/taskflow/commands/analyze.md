---
description: 분석 단계 진입 — working/ 단일 통합 문서 §분석 섹션 채움 (관점별 요약 / Critical~Low 4분류 / 우선순위 권고 / 타당성 검토 / 장기 영향). task-docs SKILL.md thin wrapper
allowed-tools: Bash, Edit, Write, Read, Glob, Grep, Skill, Agent
argument-hint: "[작업명]  # 생략 시 진행 중 working/ 문서 식별"
---

분석 단계 진입 — working/ 단일 통합 문서의 §분석 섹션을 표준 양식으로 채운다. task-docs SSOT 의 thin wrapper.

## 인자

- `$ARGUMENTS` = (선택) 작업명 kebab-case. 생략 시 `~/.claude/docs/working/YYYYMMDD/` 가장 최근 파일 자동 식별.

## 실행 방식 — subagent 위임 (2026-09-22~)

**아래 §"참조 범위"~§"종료 마커" 전체 절차는 main 세션이 직접 수행하지 않는다.** main 세션은 인자를 해석해 대상 working/ 문서 경로만 확정한 뒤(로컬 파일 조회), `Agent` 도구로 `taskflow:analyzer` 서브에이전트를 호출해 나머지 전부를 위임한다. 서브에이전트가 돌아오면 그 출력(참조범위 표 / Critical~Low 표 / 변경 표면 인벤토리 / T2 판정 / 최종 Status 라인 / §3 매칭 목록)을 그대로 화면에 낸다. **T1(autoiter 마커) 판정 + `/taskflow:plan` 전이 여부(§"단계 전이")는 main 세션이 직접 수행한다** — 세션 상태·다음 슬래시 호출은 위임 범위 밖이다.

**위임 이유:** subagent 위임 자체는 `taskflow:planner`(`plan.md`, 2026-09-22)와 동일 이유(호출 단위로 고정되는 에이전트 정의를 통해 turn-scope 모델 문제를 원천 차단). **모델 등급은 다르다** — Critical~Low 판정은 `reviewer-correctness`/`reviewer-design`(둘 다 sonnet)과 같은 급이라 `taskflow:analyzer` 는 sonnet 이다. 절차 SSOT = 본 파일(아래 섹션들), 위임 절차 자체의 SSOT = `custom-plugin/taskflow/agents/analyzer.md`.

## 참조 범위 (사전 전수 조사, 필수)

진입 즉시 3 출처를 전수 조사하고, §4.4 위치 표기로 참조 결과 표를 화면 출력한 뒤 다음 단계로 진입한다 (`/taskflow:{analyze,plan,execute,verify,review}` 공통 — 본 절이 SSOT, CLAUDE.md §4.3 에서 이관 2026-09-28).

- **3 출처:** ① `~/.claude/docs/참조문서/*` ② `~/.claude/docs/indexing/{product}.md` 스캔 후 관련 항목만 정독 ③ 현재 레포 레거시.
- **표:** `| 출처 | 파일 | 참조 위치 | 관련성 |` 4열. **없는 출처도 `해당 없음` 행 유지** (행 생략 = 단계 skip 오해).
- **등급 비례:** S = ② 만 / M·L = ①②③.

**직전 단계 sweep 재사용 (본 파일이 SSOT):** 같은 working/ 문서에 대해 직전 단계(analyze→plan→execute→verify 연속 전이)에서 본 세션 내 수행한 sweep 이 있으면 재조사하지 않고 직전 결과 표를 재사용한다. 단 ① 참조문서 / ② indexing 에 그 이후 신규·변경 파일이 있으면 해당 출처만 재조사한다. 재사용 시 표 상단에 `(직전 단계 sweep 재사용)` 1줄을 명시한다.

- **등급 비례:** S = ② index 스캔만 / M·L = ①②③ 전수.

## 동작 4단계

| 단계 | 동작 | 결과 |
|------|------|------|
| ① working/ 문서 식별 | 인자 있음 = 파일명 매칭 / 없음 = 가장 최근 working/ 파일 | 대상 파일 경로 |
| ② 양식 골격 prepend | `~/.claude/skills/task-docs/references/unified-template.md` SSOT 골격 prepend (파일 미존재 시) | `## 분석` 헤더 + 하위 표 |
| ③ §분석 섹션 채움 | 분석 관점별 요약 / Critical~Low 4분류 / 트레이드오프 / 우선순위 권고 + § 공통 (타당성 검토 / 변경 영향 기록 / 장기 영향 / 재발 방지 / SSOT 일관성) | 분석 체크리스트 = `unified-template.md` §체크리스트 골격 소진 (게이트는 **존재 강제** — 하한 숫자는 hook SSOT, 섹션별·등급별 하한 없음) |
| ③-2 **변경 표면 인벤토리** | 수정 대상 ≥ 1건이면 호출부·read 경로 / 회귀 기준선 / 재사용 자산 / 테스트 커버 4종을 `git grep` 실측 (아래 §"변경 표면 인벤토리") | plan 이 step §파급면·§결함면·DoD 검증을 채울 원재료 |
| ④ Status 마커 부착 | 단독 라인 `Status: Analysis Complete` (아래 §"종료 마커") | tick 이 분석 재실행하지 않고 `/taskflow:plan` 부터 진입 |

> **비필수 사이드이펙트 백로그 격리 (Critical~Low 분류 전 사전 필터):** ③ 에서 발견한 항목이 **① 필수요소 아님 + ② 실제 문제·버그 아님 + ③ 사이드이펙트급** 3조건을 **모두** 충족하면 Critical~Low 등급 행을 **부여하지 말고** backlog 메모리(`docs/working/backlog/{yyyy-mm-dd}-{slug}.md` + `memory/BACKLOG.md` 인덱스 1줄)에만 기록 후 현재 분석을 계속한다. 하나라도 불충족 = 정상 4분류. **실제 버그는 경미해도 미루지 않음.** §3 매칭 항목은 사용자 보고. SSOT = CLAUDE.md §4.5 "비필수 사이드이펙트 백로그 격리".

## 변경 표면 인벤토리 (수정 대상 ≥ 1건일 때 필수)

§분석은 판정(Critical~Low)을 만들지만, `/taskflow:plan` 이 step §파급면·§결함면·재사용·DoD 검증을 채우려면 **심볼 단위 실측**이 있어야 한다. 없으면 plan 은 추측으로 쓰거나 `해당 없음` 으로 넘긴다 — 2026-08-05 실측에서 파급면 누락 step 이 정확히 그 경로였다 (`plan.md` §"§파급면을 계획 시점에 적는 이유").

| 항목 | 무엇을 실측하는가 | plan 의 소비처 |
|------|-----------------|--------------|
| **호출부·read 경로** | 변경 대상 심볼·컬럼을 `git grep` 전건. write 쪽만이 아니라 그 값을 **읽어 응답하는** EP·포맷터·DTO 까지 | step §파급면 |
| **회귀 기준선** | 바꾸려는 동작의 **현재** 값·형식·응답 (before). 코드 인용 또는 실행 결과 | step §결함면 회귀 축 — `reviewer-correctness` 의 "그게 의도인가" 판정 근거 |
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
| 의도 | T1 | `/tmp/claude_autoiter_{sid}` 마커 존재·60분 이내 (묶음 승인 활성) | 자동진행을 명시 요청한 상태에서만 — gate=2 는 세션 시작마다 켜지므로 판정에 쓰지 않는다 |
| 성격 | T2 | §분석에 **수정 대상 ≥ 1건** 도출 | 진단(audit)이면 0건 |

- **T1 ∧ T2 → `/taskflow:plan` 자동 진입.** 전이 사유 1줄을 반드시 보고한다 (침묵 전이 금지).
- **T1 미충족 → 정지.** §분석 마치고 "plan 진입할까요?" 1줄 (침묵 종료 금지).
- **T2 미충족 (진단성 분석) → 자동 전이 금지.** CLAUDE.md §4.2 "audit 결과 자동 수정 금지" 를 준수한다 — 진단은 현황 보고이지 수정 계획을 낳는 task 가 아니다. 사용자 명시 수정 요청 시에만 plan 진입.

> **적용 범위 = `/taskflow:analyze` 한정.** `/backend:api-spec-audit` · `/security-audit` 등 audit 슬래시는 본 전이의 대상이 아니다 (§4.2 가 직접 금지).
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
| `doc-unified-check.sh V5` | **e2e 5점** (env / 함수·클래스 / DB 스키마 / 프로덕션 curl / mock) — working+unified 둘 다. 해당 없는 축도 **"해당 없음 + 근거"** 로 적어야 통과한다 | **exit 2** |
| `doc-unified-check.sh V2` | `## 참조 출처` + `[참조: ...]` ≥ 1건 | **exit 2** |
| `doc-unified-check.sh V4` | unified 체크리스트 **존재 강제** — 하한 숫자는 적지 않는다 (hook 이 SSOT). 평면값이라 등급 스케일이 없다 (CLAUDE.md §4.3 "단계 고정, 등급 무관") | exit 2 |
| `doc-unified-check.sh V1` | unified §분석 헤더 (분석 관점별 / Critical~Low / 우선순위 권고 / 장기 영향 / 재발 방지 / SSOT 일관성) | **경고** — tasks/ 하위 + `Status: Done\|Partial` 은 차단이 아니라 **강등** 조건이다 |
| `doc-unified-check.sh V6` | §타당성 검토 헤더 존재 시 `[Source:...]` ≥ 1건 | 경고 |
| `doc-unified-check.sh V3` | §변경 영향 + 3열 표 | 경고 |

> **차단하는 것을 위에 둔다.** 구 표는 경고인 V1 을 맨 위에 "exit 2" 로 적고 실제로 막는 V5·V2 를 아예 빼놨다 — 따라가면 안 막힐 것에 대비하고 막히는 것에 놀란다. **임계값 숫자는 여기 복사하지 않는다**: 구 `≥ 30` 을 복사해 뒀다가 2026-09-04 인하를 이 계열 4개 커맨드가 통째로 놓쳤다 (CLAUDE.md §4.4 "신규 룰 작성 관습" — 값은 hook 에 위임).

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
| `~/.claude/hooks/doc-unified-check.sh` V4 `v_checklist_count` | unified 체크리스트 임계 — **값은 그 함수의 `MIN` 이 정한다** (여기 복사하지 않는다. 하드 줄번호도 안 쓴다 — 둘 다 hook 이 바뀌면 조용히 낡는다) |
| `~/.claude/hooks/doc-unified-check.sh V6` | 타당성 검토 인용 강제 |
| **본 파일 §"단계 전이 (→ plan)"** | **순방향 전이 조건 (T1 autoiter 마커 / T2 수정 대상 ≥1) SSOT** — CLAUDE.md·reminder hook 이 참조 |
| **본 파일 §"변경 표면 인벤토리"** | **plan 원재료 4종 SSOT** — 소비처 = `plan.md` §"파급면·결함면 — 골격 무관 공통" + DoD 검증 행 |
| **본 파일 §"종료 마커"** | **`Status: Analysis Complete` 부착 규약 SSOT** — 소비처 = `tick.md` 2단계 분기 / `working-scan.sh` 파싱 / `report-work` 진행률 |
| `~/.claude/custom-plugin/taskflow/commands/execute.md` §"결정 escalation ladder" | 역방향 분류 판별식 SSOT — 본 슬래시의 짝 (execute 중 결정 막힘 시 L1 재진입 대상) |
| **`~/.claude/custom-plugin/taskflow/agents/analyzer.md`** | **분석 생성 본체 위임 대상 (2026-09-22~) — 절차는 본 파일이 SSOT, 에이전트 정의는 model: sonnet(판정 계열 컨벤션) + 프롬프트 계약(T2 보고까지, T1·전이 판단은 main 세션 소관)만** |

## §3 Checkpoint 우선 적용

분석 단계는 read-only 우선 (Read/Glob/Grep). working/ 문서 Edit 은 Gate-0 면제. 단 분석 결과가 광범위 (3 파일+ 아키텍처 변경 권고) 시 사용자 명시 승인 키워드 대기 후 §계획 진입.

**worktree 적용 (CLAUDE.md §4.3 (a)):** 본 슬래시 = `working/` 단일 통합 문서 §분석 채움. `working/` = functional exemption #5 (`*/.claude/docs/*`) → `worktree-enforce.sh` 자동 통과 (worktree 필수 아님). 단 분석 결과 적용 (§계획·§실행) 시 코드 mutation = worktree 강제.

## Skip 조건

| 등급 | 진행 여부 |
|------|----------|
| S | 압축 (Critical 만 / 트레이드오프·우선순위 권고 생략 가능) |
| M / L | **필수** — 관점별 요약 + Critical~Low 4분류 + 우선순위 권고 모두 채움 |

## 짝 슬래시

앞 = `/taskflow:draft`(원본 파일 기반 시작 시) / 뒤 = `/taskflow:plan` — **T1(autoiter 마커) ∧ T2(수정 대상 ≥1) 충족 시 본 슬래시가 자동 전이**(§"단계 전이"). `/taskflow:feasibility` 는 §분석 도중 병행. 전체 맵 = `execute.md` §"워크플로우 맵" SSOT.

## Changelog

- 2026-09-23: T1 판정을 `gate=2` → `/tmp/claude_autoiter_{sid}` 마커로 교체. gate-init 이 매 세션 gate=2 로 시작해 T1 이 항상 참이었다(자동진행 미요청에도 plan 자동 전이)
- 2026-09-22: **모델 등급 정정 — `taskflow:analyzer` opus → sonnet, 본 파일 frontmatter `model: opus` 제거.** 직전 위임 커밋에서 `plan.md`→`taskflow:planner`(opus) 패턴을 그대로 유추 적용했는데, 근거가 없었다 — Critical~Low 판정은 `reviewer-correctness`/`reviewer-design`(둘 다 sonnet)과 같은 급이고, 사용자의 opus 명시 요구도 planning 에 한정됐지 analyze 에는 없었다. 사용자 질문("analyze가 opus가 필요함?")이 계기
- 2026-09-22: **분석 생성 본체를 `taskflow:analyzer` 서브에이전트로 위임** (신규 `custom-plugin/taskflow/agents/analyzer.md`, model: opus 고정) + frontmatter `model: opus` 추가(main 세션 몫인 인자 해석·위임·relay 용, belt-and-suspenders). 근거 = 본 커맨드가 원래 model 지정이 없어 항상 세션 기본 모델을 탔다는 점 — `plan.md`→`taskflow:planner` 위임(같은 날)과 동일 이유. T1(gate=2)·`/taskflow:plan` 전이 판단은 main 세션에 남긴다(세션 상태·다음 슬래시 호출은 위임 범위 밖)
- 2026-09-16: **§강제 hook 표 drift 정정 (analyze·plan·execute·review 동시).** 세 갈래였다 — ① 체크리스트 임계를 `≥ 30` 으로 복사해 뒀는데 hook 은 2026-09-04 에 5 로 내렸다(`unified-template.md`·`task-docs/SKILL.md` 는 그때 같이 고쳐졌고 이 계열 4개만 남았다) ② V1 차단 강도가 정반대였다 — "tasks/ 이동 후 exit 2" 로 적었으나 그 조건이 바로 **강등** 조건이고 `v_template_guard` 는 `add_block` 0건이다 ③ 실제로 차단하는 V5(e2e 5점)·V2(참조 출처)가 표에 아예 없었다. **값과 하드 줄번호를 지우고 hook 포인터만 남긴다** — 복사해 둔 값이 이 drift 를 만들었다 (CLAUDE.md §4.4)
- 2026-08-05: `## 변경 표면 인벤토리` 신설 (호출부·read 경로 / 회귀 기준선 / 재사용 자산 / 테스트 커버 4종, 수정 대상 ≥1 조건부) + 동작 표 ③-2 행. 근거 = plan 의 §파급면·§결함면·DoD 검증이 심볼 단위 실측을 전제하는데 analyze 가 판정만 넘겨 plan 이 추측하거나 `해당 없음` 으로 비우던 경로 (`plan.md` 2026-08-05 정정과 짝)
- 2026-08-03: 구 `## 차별점` 표 → `## 짝 슬래시` 포인터로 축약 (전체 맵 SSOT = `execute.md` §"워크플로우 맵") + V4 임계를 등급 스케일로 적던 오기 정정 (당시 값 = 문서 총합 ≥ 30 평면값 — **그 값은 2026-09-04 에 인하됐다**. 현행 하한은 hook 이 SSOT) + 하드 줄번호 → 함수명
- 2026-05-15: 신설
