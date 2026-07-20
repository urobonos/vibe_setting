---
description: 계획 단계 진입 — working/ §계획 채움 + step-01~nn 평면 파일 분해 생성 + 계획 재검토 1회 + 전체 점검. Status: Plan Complete 부착.
allowed-tools: Bash, Edit, Write, Read, Glob, Grep, Skill, Agent
argument-hint: "[작업명]  # 생략 시 진행 중 working/ 문서 식별"
---

계획 단계 진입 — working/ §분석 완료 후 §계획 섹션을 표준 양식으로 채우고, 계획을 **step-01~nn 순차 실행 단위로 분해**하여 각 step 을 평면 파일로 생성한 뒤, **재검토 1회 + 전체 점검**을 거쳐 확정한다.

## 인자

- `$ARGUMENTS` = (선택) 작업명 kebab-case. 생략 시 가장 최근 working/ 파일 자동 식별.

## 참조 범위 (사전 전수 조사, 필수)

진입 즉시 CLAUDE.md §4.3 "참조 범위 전수 조사" 절차(3 출처 전수 조사)를 수행하고, §4.4 위치 표기로 참조 결과 표를 화면 출력한 뒤 다음 단계로 진입한다. 3 출처 표·가시화 표 양식·`해당 없음` 행 생략 금지·직전 단계 sweep 재사용 규칙 = 모두 §4.3 SSOT.

- **등급 비례:** S = ② index 스캔만 / M·L = ①②③ 전수.

## 동작 6단계

| 단계 | 동작 | 결과 |
|------|------|------|
| ① working/ 문서 식별 | 인자 매칭 또는 가장 최근 working/ 파일 | 대상 파일 경로 |
| ② §계획 섹션 채움 | 작업 목표 / 수정 대상 표 / Blueprint / 작업 분해 (WBS) / 실행 계획 | 계획 체크리스트 = 작업 등급 비례 (CLAUDE.md §4.3 "doc-unified-check.sh V4 임계" SSOT) 충족 |
| ③ **step 분해 + 평면 파일 생성** | WBS 를 step-01~nn 순차 단위로 분해. 각 step 을 `working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}-step-NN-{slug}.md` **평면 파일**로 Write. unified §계획에 **Step 분해 인덱스 표** 추가 | step 파일 N개 + 인덱스 표 |
| ④ **계획 재검토 1회 (Plan Self-Review)** | 생성한 step 분해의 정합성을 1회 자체 검토 (누락 / 순서 / 의존 / 원자성 / 중복) | 재검토 통과 또는 보강 |
| ⑤ **전체 계획 점검 (Plan Audit)** | 생성된 전체 step 집합을 통합 점검 (의존 그래프 무순환 / DoD 명확성 / 인덱스↔파일 정합 / 커버리지) | 점검 표 기록 |
| ⑥ Status 마커 부착 | 시작 라인 또는 파일 끝 `Status: Plan Complete` | 다음 단계 = `/taskflow:execute` 진입 신호 |

> **비필수 사이드이펙트 백로그 격리:** §계획 수립 중 발견한 (① 필수요소 아님 + ② 문제·버그 아님 + ③ 사이드이펙트급) 3조건 충족 항목은 step·WBS 로 끌어올리지 말고 backlog 메모리에만 기록. 하나라도 불충족 = 정상 계획 반영. SSOT = CLAUDE.md §4.5 "비필수 사이드이펙트 백로그 격리".

## step 파일 양식 (보완형 — unified 마스터, step 파생)

> **모델:** unified 통합 문서가 마스터 SSOT, step 파일은 파생 실행 레이어. 진행 중에는 step 파일을 working/ 직속에 **평면 파일명**으로 두어 `output-naming-check.sh` working/ DEPTH=1 강제를 통과한다. 완료(`Status: Done` + `## Self-Critique`) 시 `working-lifecycle.sh` 가 unified 를 `tasks/.../{작업명}/{yyyy-mm-dd}-{작업명}-unified.md` 로, step 파일들을 `tasks/.../{작업명}/steps/NN-{slug}.md` 로 분배 이동한다.

### 평면 파일명 (working/ 진행 중)
```
working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md              ← unified 마스터(SSOT)
working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}-step-01-{slug}.md  ← step 평면 (DEPTH=1 통과)
working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}-step-02-{slug}.md
...
```
> `NN` = 2자리 0-pad (01, 02, …). `{slug}` = step 제목 kebab-case. 작업명 자체에 `-step-NN-` 패턴 사용 금지 (lifecycle glob 충돌 회피).

### step 파일 본문 골격 (경량 / 풀사이클 2형)

**경량 골격 (기본 — S·단일 step·순수 실행 단위):**
```markdown
---
step: NN
작업명: {작업명}
제목: {step 제목}
의존: {선행 step 번호 목록 또는 없음}
상태: Pending
---

# step-NN: {제목}

## 목표
{이 step 에서 달성할 단일 결과}

## 작업 내용
- [ ] {구체 작업 1}
- [ ] {구체 작업 2}

## 완료 기준 (DoD)
- [ ] {검증 가능한 완료 조건}

## 변경 파일
- `{파일 경로}` — {변경 요약}
```

**풀사이클 골격 (L·독립 다단위 M — 각 step 이 자기완결 미니 사이클):** 경량 골격에 `## 분석 (국소)` · `## 계획 (접근)` · `## QA (자체 점검)` · `## 검증 (국소 동작)` 4 섹션을 더해 각 step 이 [분석→계획→개발→QA→검증] 을 자기완결한다. 상세 골격·발동 조건·부모 게이트 분담 = 아래 §"풀사이클 step".

### unified §계획 Step 분해 인덱스 표
```markdown
## Step 분해 (순차 실행 단위)
| step | 제목 | step 파일 | 의존 | 병렬그룹 | 완료 기준(DoD) | 상태 |
|------|------|----------|------|---------|---------------|------|
| 01 | {제목} | `...-step-01-{slug}.md` | - | - | {DoD} | Pending |
| 02 | {제목} | `...-step-02-{slug}.md` | 01 | A | {DoD} | Pending |
| 03 | {제목} | `...-step-03-{slug}.md` | 01 | A | {DoD} | Pending |
```
> `/taskflow:execute` 이 이 인덱스를 step-01 부터 의존 순서대로 순차 소비하며 상태를 `Pending → In Progress → Done` 으로 갱신한다.
> **병렬그룹 열 (2026-07-16, dispatch 흡수):** 같은 그룹 문자(A/B/…)를 단 step 은 **상호 독립(의존 0, 파일 충돌 없음)** — 단일 세션은 인라인 병렬 소비, **다세션이면 아래 §"병렬 그룹 다세션 분배"가 DISPATCH 풀에 자동 등록**한다. `-` = 순차 전용(분배 비대상). 독립성 판정 = `/taskflow:survey` 재사용.

### 병렬 그룹 다세션 분배 (dispatch 흡수, 2026-07-16)

병렬그룹이 지정된 step 을 **다세션/에이전트가 나눠 처리**할 때, plan 이 해당 그룹 step 들을 DISPATCH 풀에 자동 등록한다 (구 `/taskflow:dispatch` 슬래시 흡수 — 별도 슬래시 호출 불요). 단일 세션 순차 처리면 등록 생략.

```bash
source ~/.claude/hooks/lib/dispatch-utils.sh
source ~/.claude/hooks/lib/product-resolver.sh
PRODUCT=$(resolve_product "$PWD")
# 병렬그룹 지정 step 마다 (독립 = 의존 0, 자기완결 풀사이클 step 파일이 곧 분배 문서)
dispatch_add "{작업명}-step-NN" "{작업명}" "$PRODUCT" "{step 평면 파일 절대경로}"
```

> **다세션 필요 판정:** 사용자가 다세션 병렬을 명시하거나 작업 규모가 커 분산이 필요할 때만 등록. 등록된 그룹은 `/taskflow:load #tag` 가 자동 claim 해 이어받는다 (claim 흡수). 기본(단일 세션)은 등록 없이 execute 가 병렬그룹을 인라인 병렬 소비.
> **원자성:** 병렬그룹 step 은 **풀사이클 골격**(자기완결)이어야 분배 대상 — step 파일이 곧 자립 분배 문서라 별도 분배 문서 생성 불요. 경량 골격(순차 의존)은 병렬그룹 `-`.
> **§3 매칭 그룹:** 특정 병렬그룹 step 이 §3(비가역·외부) 이면 등록하되 분배 문서 `## 참고` 에 "§3 — claim 후 사용자 명시 승인 필수" 명시 (claim 세션이 승인 흐름 재진입).

## 풀사이클 step (L·독립 다단위 M — 자기완결 단위)

큰 작업을 **독립 단위**로 쪼갤 때, 각 step 평면 파일이 [분석→계획→개발→QA→검증] 미니 사이클을 자기완결한다. 다세션 분배(§"병렬 그룹 다세션 분배")·재개 시 step 파일만으로 컨텍스트가 자립한다.

### 발동 조건 (과설계 회피)

| 조건 | 골격 |
|------|------|
| **L 또는 M 이면서 step 이 2개+ 상호 독립** (파일 충돌·의존 없음 — `/taskflow:survey` 독립성 판정 재사용) | **풀사이클** |
| S / 단일 step / step 간 강결합 | 경량 (또는 unified 단일, step 분해 생략) |

> 무조건 발동 아님 — 오타·단발 수정에 6섹션은 과설계. 독립 다단위에서만 격리·자기완결 ROI 발생.

### 풀사이클 step 골격

```markdown
---
step: NN
작업명: {작업명}
제목: {제목}
의존: {선행 또는 없음}
상태: Pending
---

# step-NN: {제목}

## 분석 (국소)
{이 step 범위의 원인·영향·제약. 전체 분석은 부모 unified §분석}

## 계획 (접근)
{이 step 구현 접근 1~3줄}

## 작업 내용 (개발)
- [ ] {구체 작업}

## 변경 파일
- `{경로}` — {변경 요약}

## QA (자체 점검)
- [ ] 이 step 이 자기 §계획·DoD 를 충족하는가 (self-check, subagent 없음)
- [ ] (외부문서 관련 step) 해당 요구 반영 — 통합 대조는 부모 QA 게이트

## 검증 (국소 동작)
- [ ] 이 step 산출물 동작 확인 (문법/컴파일/국소 실행). 통합 e2e 는 부모 /taskflow:verify

## 완료 기준 (DoD)
- [ ] {검증 가능한 완료 조건}
```

### 부모(통합) vs 자식(국소) 게이트 분담 — 오버헤드 회피

| 관심사 | 위치 | 이유 |
|--------|------|------|
| 타당성 / 장기영향 / 재발방지 / SSOT | **부모 unified 1회** | 공통 — step 반복 = DRY 위반 |
| QA(외부문서 대조, subagent) | **부모 unified 1회** (`execute.md` ③.5) | step마다 spawn = 토큰 N배. 전 변경분 1회가 정확 |
| e2e 5점 (`/taskflow:verify`) | **부모 unified 1회** | step 은 부분기능 → 프로덕션 curl·DB 스키마 통합 검증 불가 |
| Self-Critique / simplify (`/taskflow:review`) | **부모 unified 1회** | 통합 품질 리뷰 |
| §분석(국소)·§계획(접근)·§QA(self-check)·§검증(국소동작) | **자식 step** | 경량·subagent 0. 이 step 자체 완결만 |

> **핵심:** step 의 "QA/검증" = **경량 자체점검**(계획·DoD self-check, 국소 동작 확인). 외부문서 subagent·e2e 같은 **무거운 통합 게이트는 부모 1회**. step 국소 PASS ≠ 통합 PASS (층위 차이, 중복 아님).

## 계획 재검토 1회 (Plan Self-Review) — 단계 ④

step 분해 직후 **1회** 자체 재검토. task-docs SKILL.md Part 6 "3-Round 재검토" 패턴의 계획 단계 축소판.

- [ ] **누락:** §계획 "수정 대상" 표의 모든 항목이 ≥ 1개 step 에 매핑되는가
- [ ] **순서:** step 실행 순서가 기술적 의존을 위배하지 않는가 (선행 산출물 없는 step 이 먼저 오지 않는가)
- [ ] **의존:** 각 step `의존` 필드가 실제 선행 step 을 정확히 가리키는가
- [ ] **원자성:** 각 step 이 단일 책임 단위인가 (한 step 에 무관한 변경이 섞이지 않았는가)
- [ ] **중복:** 동일 변경이 둘 이상 step 에 중복 기재되지 않았는가

> 1건이라도 FAIL → step 파일·인덱스 보강 후 재검토 1회 재수행. 통과 시 단계 ⑤ 로.

## 전체 계획 점검 (Plan Audit) — 단계 ⑤

생성된 **전체 step 집합**을 통합 점검하고 결과를 unified §계획에 점검 표로 기록한다.

| 점검 항목 | 기준 | 결과 |
|----------|------|------|
| 의존 그래프 무순환 | step 의존 관계에 순환 없음 (DAG) | - |
| DoD 명확성 | 모든 step 이 검증 가능한 완료 기준 보유 | - |
| 인덱스↔파일 정합 | §계획 인덱스 표 행 수 = 생성된 step 파일 수 | - |
| 커버리지 | 수정 대상 표 전 항목이 step 에 매핑 | - |
| 평면 파일명 정합 | 모든 step 파일이 `-step-NN-{slug}.md` 패턴 + working/ DEPTH=1 | - |

> §3 Checkpoint 매칭 항목(비가역·광범위·트레이드오프·외부 시스템)이 특정 step 에 걸리면 해당 step 상태를 `Pending(승인 대기)` 로 표기하고 `/taskflow:execute` 진입 전 사용자 명시 승인을 받는다.

## 직병렬 실행 지침

**원칙:** 단계 ① → ② → ③ → ④ → ⑤ → ⑥ 은 **직렬 필수**. 단 step 파일 생성(③)은 step 간 의존 없으면 단일 응답 내 병렬 Write 가능, 사전 조사(read-only)도 병렬 가능.

| 태스크 | 직렬·병렬 | 방법 |
|--------|----------|-----|
| 사전 조사 (수정 대상 파일·영향 범위 확인) | **병렬 가능** | 영향 파일 다중 Read·Grep 단일 응답 동시 조회 |
| ③ step 평면 파일 생성 | **조건부 병렬** | 의존 없는 독립 step 파일은 단일 응답 병렬 Write |
| ① → ② → ③ → ④ → ⑤ → ⑥ 골격 | **직렬 필수** | §분석 완료 → §계획 → step 분해 → 재검토 → 점검 → Status 순차 |

## 자연어 trigger (task-docs 기존 호환)

- `계획 세워줘` / `플랜 작성` (기존 task-docs trigger 호환)

## 강제 hook

| Hook | 검증 | 차단 강도 |
|------|------|----------|
| `doc-unified-check.sh V1` | unified §계획 헤더 (작업 등급 S/M/L / Blueprint / 수정 대상 / 실행 계획 / WBS) L117~127 | exit 2 (tasks/ 이동 후) |
| `doc-unified-check.sh V4` | unified 체크리스트 = 작업 등급 비례 S≥8/M≥14/L≥20 (§4.3 SSOT) | exit 2 |
| `output-naming-check.sh` | working/ step 평면 파일 = DEPTH=1 + `{yyyy-mm-dd}-` prefix | exit 2 (위반 시) |
| `working-lifecycle.sh` | 완료 시 step 평면 파일 → `tasks/.../steps/NN-{slug}.md` 분배 mv | (lifecycle 트리거) |

## 종료 마커

```markdown
Status: Plan Complete
```

> `Status: Plan Complete` 부착 시 사용자에게 `/taskflow:execute` 진입 신호. 부착하지 않으면 `/taskflow:execute` 진입해도 §계획 미완료 상태로 간주.

## 호출 예

```
/taskflow:plan                         ← 진행 중 working/ §계획 채움 + step 분해
/taskflow:plan auth-refactor           ← 특정 작업 §계획 채움 + step 분해
```

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/CLAUDE.md` §4.1 "장기 관점 분석·계획·실행" | 정책 SSOT |
| `~/.claude/skills/task-docs/SKILL.md` | 본 슬래시의 본체 스킬 |
| `~/.claude/skills/task-docs/references/unified-template.md` § 계획 | unified 양식 SSOT |
| **본 파일 §"step 파일 양식"** | step 분해 평면 파일·인덱스 표 양식 SSOT |
| `~/.claude/hooks/doc-unified-check.sh V1` L117~127 | unified §계획 헤더 강제 |
| `~/.claude/hooks/working-lifecycle.sh` | step 평면 파일 → steps/ 분배 이동 |

## §3 Checkpoint 우선 적용

§계획 단계의 권고가 다음 조건에 매칭되면 §실행 진입 전 사용자 명시 승인 필수:

| 조건 | 예시 |
|------|------|
| 비가역적 작업 | DB 스키마 변경 / 마이그레이션 실행 / 파일 삭제 |
| 광범위 영향 (3 파일 + 아키텍처) | 모듈 경계 재배치 / 인터페이스 계약 변경 |
| 요구사항 상충 | 성능 vs 가독성 트레이드오프 |
| 외부 시스템 연동 | 외부 API 호출 / 환경변수 변경 |

> 매칭된 변경이 특정 step 에 속하면 해당 step 인덱스 상태를 `Pending(승인 대기)` 로 표기 (단계 ⑤ 참조).

**worktree 적용 (CLAUDE.md §4.3 (a)):** 본 슬래시 = `working/` 단일 통합 문서 §계획 채움 + step 평면 파일 생성. 모두 exemption #5 (`*/.claude/docs/*`) 자동 통과. 단 §실행 진입 시 코드 mutation = worktree 강제.

## Skip 조건

| 등급 | 진행 여부 |
|------|----------|
| S | 압축 — 수정 대상 표만, step 분해 생략 가능 (또는 step 1~2개) |
| M / L | **필수** — 작업 목표 + 수정 대상 + Blueprint + WBS + step 분해 + 재검토 + 점검 모두 |

> step 0개(분해 생략) = 기존 동작과 동일 (하위 호환). step 분해는 작업이 순차 단위로 나뉘는 M/L 에서 가치.

## 차별점 (다른 슬래시와)

| 슬래시 | 시점 | 범위 |
|--------|------|------|
| `/taskflow:draft` | 원본 파일(기획서/스펙) 기반 시작 | working/ §분석·§계획 + 원본 지문(sha256) 박제 (짝 = execute) |
| `/taskflow:analyze` | 작업 시작 | working/ §분석 |
| **`/taskflow:plan`** | §분석 완료 후 | working/ §계획 + step-01~nn 분해 + 재검토 + 점검 + Status: Plan Complete |
| `/taskflow:execute` | §계획 완료 후 | step 인덱스 순차 소비 + working/ §실행 + Self-Critique |

## Changelog

- 2026-05-15: 신설
- 2026-05-29: step 스캐폴드 확장
