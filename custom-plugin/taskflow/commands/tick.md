---
description: 무인 loop 1-iteration 러너 — cwd 최신 task 1건 claim → Status 분기 → 다음 진행 가능한 step 개발+verify+review → 그 step 에 `Status: ReadyToMerge`(머지 준비) 부착. 머지·push 안 함(§3). 판단 필요 시 unified `NeedsDecision` 마감. 모든 step ReadyToMerge 되면 정지(사용자 step 머지 대기). harness `/loop <interval> /taskflow:tick` 로 반복. 로직 재구현 0.
allowed-tools: Bash, Edit, Write, Read, Glob, Grep, Skill, Agent, PowerShell
argument-hint: "[작업명|#tag — 선택. 생략 시 cwd 최신 1건 자동 claim]"
---

무인 1-iteration 러너. **주기 반복은 harness `/loop`** 가 담당 — `/loop 30m /taskflow:tick`. tick 자체는 **다음 진행 가능한 step 1개**를 `ReadyToMerge`(머지 준비)까지 올리고 멈춘다.

## 핵심 원칙

- **로직 재구현 0.** claim=`working_scan` 선택 + `registry_add` 배타 점유, 실행=`/taskflow:auto`, 마감=escalation ladder, step 스캔=`hooks/lib/working-scan.sh`.
- **머지·push 안 함 (§3).** step 완료 → 그 step `Status: ReadyToMerge`(머지 준비)까지. **실제 step 머지 + task 완료(Done)는 사용자**가 `control`→`/taskflow:save` 로 수행.
- **`ReadyToMerge` 는 step 단위 상태 — "완료대기"가 아니다.** task(unified)엔 ReadyToMerge 가 없다. task 는 모든 step 머지 + 완료 게이트 통과 후에만 `Done`.
- **판단 필요 = 즉시 마감.** 권한형 결정(§3)에 걸리면 unified 에 `NeedsDecision` 부착 + 판단사항 기록 후 그 iteration 종료.

## 1-iteration 흐름

```
1. claim   : working_scan 전체 스캔(cwd 무관) → 진행 가능 항목 선택 → registry_add 로 배타 점유
              단위: 평면(step 분해) task = 다음 진행 가능 step slug / 통(경량) task = task slug
              (타 sid active 면 skip → 다음 후보)
              └ 진행 가능 0건 → "없음" 출력 후 종료 (loop 다음 주기)
2. 분기    : unified Status 판정 (아래 표)
2-bis 하강 : working-scan 으로 다음 진행 가능한 step(Pending + 선행 Done) 선택
3. step 실행: 개발 → verify(e2e 5점) → review → 그 step 파일에 Status: ReadyToMerge 부착
              (머지 안 함. §계획 인덱스 표 상태도 ReadyToMerge 로 갱신)
              └ P1~P4 권한형/판정 불확실 → unified Status: NeedsDecision + §결정 로그 → 마감
4. 반복/정지: 다음 tick = 다음 step. 모든 step ReadyToMerge → tick 정지
              (사용자가 control 로 보고 step별 머지 + 완료 게이트 → task Done)
```

## 1단계 — task/step 배타 claim (cwd 무관, 세분 점유)

`/taskflow:load latest`(cwd 라우팅 + read-only)를 쓰지 않는다 — 그건 조회지 점유가 아니다. tick 은 `working_scan` 으로 **전체** 진행 가능 항목을 훑고 **claim 단위로 배타 점유**한다.

1. `working_scan all`(cwd 무관 — cwd product 0건이어도 타 product 진행) → 진행 가능 후보 산출:
   - **평면(step 분해) task** = 다음 진행 가능 step(2-bis 의존 판정) → claim 단위 = **step slug** `{작업명}-step-NN`.
   - **통(경량·step 없음) task** = unified 전체 → claim 단위 = **task slug** `{작업명}`.
2. 배타 claim — claim 전 `registry_find "{slug}"` 로 점유 확인:
   ```bash
   source ~/.claude/hooks/lib/registry-utils.sh
   [ -n "$(registry_find "{slug}" | awk -F"$REGISTRY_FS" -v s="{sid8}" '$7=="active" && $4!=s')" ] && SKIP   # 타 sid active → skip
   registry_add "{slug}" "{product}" "{sid8}" "{cwd}" "{working_file}"                                       # 본 sid 점유
   ```
   - 평면 task 는 slug 가 **step 단위**라 다른 tick 이 **같은 task 의 다른 독립 step 을 병렬** claim 가능.
   - 통 task 는 task slug 라 task 전체 배타 점유.
3. 진행 가능 후보 0(전부 타 sid 점유거나 완료) → "진행 가능 없음" 출력 후 종료.

> **점유 해제:** step 완료(ReadyToMerge)/task Done 시 `working-lifecycle.sh`·`working-release.sh` 가 REGISTRY entry 를 정리(기존 lifecycle 재사용). 인자(`{작업명}`/`#tag`) 명시 시 그 대상만 claim.

## 2단계 — unified Status 분기

| unified Status | 진입 | 사유 |
|------------|------|------|
| 없음 / `초안` / raw | `/taskflow:analyze` → `/taskflow:plan` → `/taskflow:auto` | 분석부터 |
| `Plan Complete` | `/taskflow:auto` (2-bis step 하강) | 계획 완료 → step 실행 |
| `In Progress` | `/taskflow:auto` (다음 step) | 이어감 |
| `NeedsDecision` | **skip** | 사용자 판단 대기 — 결정 입력 전 재잡이 금지(무한 방지). 결정 후 `In Progress` 복귀 시 재개 |
| **모든 step `ReadyToMerge`** | **skip** | 사용자 step 머지 대기 (control→/save) |
| `Done` | **skip** | 종결 |

## 2-bis단계 — step 하강 (working-scan)

unified §계획에 **Step 분해 인덱스 표**가 있으면 unified 통짜가 아니라 **step 파일 단위**로 진행한다.

1. `hooks/lib/working-scan.sh` 의 `working_scan {product}` 로 step 상태를 읽어 **다음 진행 가능한 step** 선택 — 인덱스 표 `Pending` + **그 step 의 직접 의존 선행(인덱스 표 '의존' 컬럼)이 전부 완료(`ReadyToMerge`/`Done`)**.
   - **우회 (필수):** 앞 step 이 막혀 있어도 **그 step 에 의존하지 않는 독립 step 은 계속 진행**한다 ("앞이 막히면 뒤도 전혀 진행 안 함" 방지). 진행 가능 여부는 전체 순번이 아니라 **직접 의존 선행**만으로 판단한다.
   - **필수 블로커:** 직접 의존 선행이 `NeedsDecision`/`In Progress` 면 그 step 은 **진행 불가** (선행 결과에 실제로 의존하므로).
   - 진행 가능 step **0** → 전부 `ReadyToMerge`/`Done` 이면 **4단계 정지** / 블록(의존 선행 미해결)만 남으면 **task 정지**(사용자 판단 필요).
2. **착수 표시** — claim 직후 그 step 파일 `상태: Pending → In Progress` + 인덱스 표 갱신 (control·다른 tick 이 "진행 중" 을 봄). 이어서 그 step 을 진행 단위로 `/taskflow:auto` 실행 (execute.md step 순차 소비 재사용).
3. step DoD 충족 → 그 step 파일 `상태: ReadyToMerge`(머지 준비) + 인덱스 표 갱신 → 다음 step (막히거나 전부 ReadyToMerge 까지). 전이·SSOT = 아래 §"step 상태 라이프사이클".
4. step 도중 판단 필요 → **3단계 마감** (unified NeedsDecision, 다음 tick 이 그 step 부터 재개).

> step 분해 없는 경량 unified = unified 전체를 1 진행 단위로 처리하고 완료 시 unified 자체에 `Status: ReadyToMerge`.

## 3단계 — 판단 필요 시 문서 기록 후 마감

분류·마감은 **`execute.md` §"결정 escalation ladder" SSOT**. 요지:

- **권한형 P1~P4 · 판정 불확실** → 그 **step 파일** `Status: NeedsDecision` + §실행 `## 결정 Escalation 로그`(결정 사항 + 선택지·트레이드오프·추천). **task(unified)는 진행 가능한 독립 step 이 남아있으면 `In Progress` 유지** — tick 이 다음 iteration 에 그 독립 step 을 진행한다 (막힌 step 하나가 task 전체를 세우지 않는다). **모든 진행 가능 step 이 0** 이면 unified `Status: NeedsDecision` + `registry_update {작업명} {sid8} needs-decision`. `[AUTO-ITERATE-USER-DECISION]` 마감.
  - `NeedsDecision` 은 종결 정규식(`Done|완료|폐기|Abandoned`) 비대상 → 자동이동 안 되고 working/ 잔류. tick 은 skip(재잡이 무한 방지). SessionStart 배너·`/taskflow:control` 이 `⚠️ 판단 필요` 로 최우선 노출.
  - **재개:** 사용자 결정 입력 → unified `Status: In Progress` + `registry_update … active` → 막혔던 step 부터 이어감.
- **정보 부족형 I1~I3** → bounded `/taskflow:analyze`→`/taskflow:plan` 자체 해소, 미해소 시 조사결과 첨부 후 마감.

## 4단계 — step ReadyToMerge (머지 준비, 정지)

step 이 개발→verify→review 를 통과하면:

1. **머지 안 함** — 정착(`/git:merge`) 하지 않는다. wip/* worktree 그대로. 커밋만 누적.
2. 그 step 파일 frontmatter 상태를 **`상태: ReadyToMerge`** 로 갱신 (plan.md step 규약 = 한글 `상태:` 라벨. unified 는 `Status:`. working-scan 은 `Status`/`상태` 둘 다 인식하므로 어느 쪽이든 잡힌다). 인덱스 표 상태 컬럼도 갱신.
3. `## 머지 전 리뷰 포인트`(step 파일) 기록 — worktree 경로 + 핵심 변경 + verify/review 결과.
4. 다음 진행 가능 step 으로 계속. **모든 step 이 ReadyToMerge 면 tick 정지** — `[AUTO-ITERATE-USER-DECISION]`(사용자 step 머지 대기).

> `ReadyToMerge` 는 종결 정규식 비대상이라 step 파일도 working/ 에 잔류한다 (자동이동 안 됨 = 의도).

## 완료 게이트 (task Done — tick 이 아니라 save 담당)

**task 를 `Done`(tasks/ 이동)으로 넘기는 것은 tick 이 하지 않는다.** 사용자가 control→`/taskflow:save` 로:

1. ReadyToMerge step 들을 feature 에 **개별 머지** (worktree=task 1개, step별 커밋 단위).
2. **완료 게이트 검증** = `working-scan.sh::working_gate_blockers {product} {작업명}` — 출력(미해결)이 있으면 **Done 차단**:
   - 미처리 step (인덱스 `Pending`/`In Progress`) · NeedsDecision · 미체크박스 `- [ ]` · `## 잔여` 섹션 · verify/review FAIL.
3. blocker 0 → unified `Status: Done` → `working-lifecycle.sh` tasks/ 이동 + 전파.

tick 은 이 게이트에 **관여하지 않는다** — step 을 ReadyToMerge 로 올리는 데까지만.

## step 상태 라이프사이클 (SSOT = step 파일 `상태:`)

각 평면 step 파일 frontmatter `상태:` 가 진행 SSOT 다. unified §계획 인덱스 표 상태 컬럼은 사람이 보는 미러 — tick 이 step 파일 갱신 시 함께 동기화한다 (working-scan 은 step 파일 `상태:` 를 읽는다).

| 상태 | 시점 | 전이 주체 |
|------|------|----------|
| `Pending` | plan 이 step 분해 생성 | `/taskflow:plan` |
| `In Progress` | tick 이 그 step claim + 착수 | `/taskflow:tick` |
| `ReadyToMerge` | 개발+verify+review 완료 (머지 준비) | `/taskflow:tick` |
| `NeedsDecision` | 판단 필요로 마감 (그 step 한정) | `/taskflow:tick` |
| `Done` | 사용자가 그 step 머지 | `/taskflow:save` |

- **동기화:** tick 은 step 파일 `상태:` 변경 시 unified 인덱스 표 상태 컬럼도 같은 값으로 갱신 (불일치 시 step 파일이 우선 — working-scan 이 파일을 읽으므로).
- **다세션 상보:** step 파일 `상태: In Progress` = 문서 레벨 진행 표시 / REGISTRY active(step slug claim) = 배타 lock. 둘이 함께 control·다른 tick 에 진행 중 step 을 가시화한다.

## step 상세 기록 (무인 필수)

무인이라 기록이 유일한 리뷰 근거다. 각 step 파일 §실행/§QA 에 생략 없이 (기존 §4.1 강제 재사용, 신규 룰 0): `## 변경 영향 기록`(무엇/개선점/왜) · `## Before/After 대조` · verify 5점 + review Self-Critique · `## 결정 Escalation 로그`(판단 걸린 것).

## §3 Checkpoint 우선 적용

- tick 은 §3 우회 통로가 아니다. 권한형 결정·비가역·외부 변경은 `dangerous-ops-guard.sh`/`branch-enforce.sh` 가 hook 레벨 차단 + escalation ladder 가 즉시 NeedsDecision 마감.
- **머지 절대 안 함** — step ReadyToMerge 까지만. step 머지·task 완료·master/main·push 는 전부 사용자 직접.

## SSOT (재사용 조각)

| 조각 | 역할 | SSOT |
|------|------|------|
| 주기 반복 | `/loop <interval> /taskflow:tick` | harness `/loop` 스킬 |
| claim | cwd 최신 1건 / #tag | `custom-plugin/taskflow/commands/load.md` |
| 실행 관통 | worktree → 개발 → QA → verify → review | `custom-plugin/taskflow/commands/auto.md` |
| 결정 마감 | escalation ladder P1~P4 / I1~I3 | `execute.md` §"결정 escalation ladder" |
| step 순차 소비 | step-01~nn 의존 순서 | `execute.md` + `plan.md` §"step 파일 양식" |
| **step 스캔 + 완료 게이트** | working/ 훑기 · `working_gate_blockers` | **`hooks/lib/working-scan.sh`** |
| ReadyToMerge = 비종결 | 자동이동 안 됨 | `hooks/working-lifecycle.sh:54` |
| step 머지 + 완료 판정 | 사용자 | `custom-plugin/taskflow/commands/save.md` |
| 대기 큐 리뷰 | step ReadyToMerge + NeedsDecision | `custom-plugin/taskflow/commands/control.md` |

## 호출 예

```
/loop 30m /taskflow:tick        ← 30분마다 다음 step 을 ReadyToMerge 로 진행 (무인)
/taskflow:tick                  ← 1 step 만 수동 진행
```

무인 흐름 예시:

```
[tick] load → commerce-audit (Plan Complete, step 3개)
  2-bis → step-01 (Pending, 선행 없음) 선택
  3 → 개발·verify 5/5·review 통과 → step-01 Status: ReadyToMerge (머지 X)
  → [AUTO-ITERATE-DONE]  (다음 tick 이 step-02)
[tick] → step-02 ReadyToMerge …
[tick] → step-03 ReadyToMerge → 모든 step ReadyToMerge → 정지
  → [AUTO-ITERATE-USER-DECISION]  (사용자: control 로 보고 step 머지 + 완료 게이트)
```

## Changelog

- 2026-07-23: 신설 → step 단위 ReadyToMerge + 완료 게이트 재설계
