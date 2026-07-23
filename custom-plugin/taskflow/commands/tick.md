---
description: 무인 loop 1-iteration 러너 — cwd 최신 task 1건 claim → Status 분기(analyze/plan/auto) → 판단 필요 시 문서 기록 후 마감, 아니면 worktree + `Status: ReadyToMerge` 로 완주 정지(머지·push 안 함). harness `/loop <interval> /taskflow:tick` 로 주기 반복. 로직 재구현 0 — 기존 조각 순차 호출.
allowed-tools: Bash, Edit, Write, Read, Glob, Grep, Skill, Agent, PowerShell
argument-hint: "[작업명|#tag — 선택. 생략 시 cwd 최신 1건 자동 claim]"
---

무인 1-iteration 러너. **주기 반복은 이 커맨드가 아니라 harness `/loop` 가 담당** — `/loop 30m /taskflow:tick` 처럼 감싸 호출한다. tick 자체는 **task 1건**만 잡아 완료대기(ReadyToMerge)까지 진행하고 멈춘다.

## 핵심 원칙

- **로직 재구현 0.** claim=`/taskflow:load`, 실행=`/taskflow:auto`, 마감=escalation ladder, 정지=`Status: ReadyToMerge`. 전부 기존 조각 순차 호출.
- **머지·push 안 함.** 무인이므로 완주해도 정착(머지)하지 않고 ReadyToMerge 에서 정지한다. 정착은 사용자가 나중에 `/taskflow:save` 로 승인 (§3/§4.3 — Claude 자동 머지·push 금지).
- **판단 필요 = 즉시 마감.** 권한형 결정(§3 매칭)에 걸리면 문서에 판단 필요사항을 적고 `[AUTO-ITERATE-USER-DECISION]` 로 그 iteration 을 끝낸다.

## 1-iteration 흐름

```
1. claim   : /taskflow:load {인자|latest}   (배타 claim, dispatch lock 재사용)
              └ 진행 가능 task 0건 → "진행 가능 task 없음" 출력 후 종료 (loop 다음 주기 대기)
2. 분기    : working 문서 Status 판정 →
              (없음/raw)      → /taskflow:analyze → /taskflow:plan → /taskflow:auto
              (Plan Complete) → /taskflow:auto
              (In Progress)   → /taskflow:auto  (이어서)
2-bis.step하강: unified §계획에 Step 인덱스 표가 있으면 unified 통짜로 잡지 않고
              다음 진행 가능한 step(Pending + 선행 Done)부터 step 파일 단위로 진행
              (execute.md step-01~nn 순차 소비 재사용). step 없으면 unified 전체 진행.
3. 실행    : /taskflow:auto 가 worktree 생성 → 개발 → QA → verify(e2e 5점) → review 관통
              (step 단위면 각 step 파일 §실행/§QA 기록 + 인덱스 표 Pending→In Progress→Done 갱신)
              └ P1~P4 권한형/판정 불확실 → §실행 `## 결정 Escalation 로그` 기록
                + 판단 필요사항 명시 → [AUTO-ITERATE-USER-DECISION] 마감 (iteration 종료)
4. 완주정지: 결정 없이 통과 시 →
              worktree 유지 (정착 안 함)
              + working 문서 Status: ReadyToMerge
              + REGISTRY status=ready-to-merge
              + ## 머지 전 리뷰 포인트 기록
              → [AUTO-ITERATE-USER-DECISION] 마감 (머지 승인이 사용자 결정 영역)
```

## 2단계 — Status 자동 분기

claim 한 working 문서의 시작부 `Status:` 라인으로 진입 단계를 정한다 (이미 계획된 task 재분석 금지 — 중복 작업 0).

| 현재 Status | 진입 | 사유 |
|------------|------|------|
| 없음 / `초안` / raw | `/taskflow:analyze` → `/taskflow:plan` → `/taskflow:auto` | 분석부터 |
| `Plan Complete` | `/taskflow:auto` | 계획 완료 → 실행부터 |
| `In Progress` / `Partial` | `/taskflow:auto` (이어서) | 잔여 이어감 |
| `NeedsDecision` | **skip** | 사용자 판단 대기 — 결정 입력 전 재잡이 금지(무한 방지). 사용자 결정 후 `In Progress` 복귀 시 재개 |
| `ReadyToMerge` | **skip** | 이미 완료대기 — 사용자 머지 대기, tick 대상 아님 |
| `Done` | **skip** | 종결 |

## 2-bis단계 — step 하강 (unified 내 step 분해가 있을 때)

unified §계획에 **Step 분해 인덱스 표**(step-01~nn)가 존재하면 unified 를 통짜로 잡지 않고 **step 파일 단위로 내려가 진행**한다 (사용자 원의도 = "task-step" 단위). unified Status(Plan Complete / In Progress)는 진입점만 정하고, 실제 진행 단위는 step 이다.

1. §계획 Step 인덱스 표에서 **다음 진행 가능한 step** 선택 — 상태 `Pending` + 선행 step 전부 `Done`(의존 충족). 진행 가능 step 이 없고 전부 `Done` 이면 → **4단계 완주 정지**로.
2. 그 step 파일 `{yyyy-mm-dd}-{product}-{작업명}-step-NN-{slug}.md` 을 진행 단위로 `/taskflow:auto` 실행 (execute.md 의 "step-01 부터 의존 순서대로 순차 소비, 상태 `Pending→In Progress→Done`" 로직 그대로 재사용).
3. step DoD 충족 → 인덱스 표 상태 `Done` 갱신 → 다음 진행 가능 step 으로 계속 (막히거나 전부 완주까지).
4. **step 도중 판단 필요(P1~P4)** → 그 step 파일 §실행 `## 결정 Escalation 로그` 기록 + `[AUTO-ITERATE-USER-DECISION]` 마감. 다음 tick 이 **그 step 부터 재개**한다 (인덱스 표 상태로 재개 지점 판별).

> step 분해가 없는 경량 unified 는 본 단계 skip — unified 전체를 1 진행 단위로 처리한다.

## 3단계 — 판단 필요 시 문서 기록 후 마감

`/taskflow:auto` 실행 중 결정 요구 발생 시 분류·마감은 **`execute.md` §"결정 escalation ladder" SSOT** 를 그대로 따른다 (본 커맨드 재기술 안 함). 요지:

- **권한형 P1~P4 (§3 매칭 / 사업 판단 / 외부 상태 변경 / 하니스 룰) · 판정 불확실** → 즉시 §실행 `## 결정 Escalation 로그` 표에 **무엇을 결정해야 하는지** 기록 + working 문서 시작부 **`Status: NeedsDecision`** 부착 + `registry_update {작업명} {sid8} needs-decision` + `[AUTO-ITERATE-USER-DECISION]` 마감. 무인이라 사용자가 나중에 이 기록만 보고 판단할 수 있어야 하므로 **선택지·트레이드오프·추천을 문서에 남긴다.**
  - `NeedsDecision` 은 `ReadyToMerge` 와 대칭 — 종결 정규식(`Done|완료|폐기|Abandoned`) 비대상이라 자동이동 안 되고 working/ 에 잔류한다. tick 은 이 문서를 **skip**(재잡이 무한 방지)하고, SessionStart 배너가 `⚠️ 판단 필요` 로 최우선 노출한다.
  - **재개:** 사용자가 결정을 입력하면 working 문서 `Status: In Progress` 로 되돌리고 (`registry_update … active`) 막혔던 지점(step 단위면 인덱스 표의 그 step)부터 이어간다.
- **정보 부족형 I1~I3** → bounded `/taskflow:analyze`→`/taskflow:plan` 자체 해소 시도, 미해소 시 조사결과 첨부 후 마감.

## 4단계 — 완주 정지 (`Status: ReadyToMerge`)

결정 요구 없이 **(step 분해 시) 인덱스 표의 모든 step 이 `Done`**, 또는 (경량) unified 전체가 개발→QA→verify→review 를 통과하면:

1. **worktree 유지** — 정착(`/git:create`·`/git:merge`) **하지 않는다**. wip/* 분기·worktree 그대로 둔다.
2. **working 문서** 시작부 `Status: ReadyToMerge` 부착.
   - ⚠️ ReadyToMerge 는 `working-lifecycle.sh` 종결 정규식(`Done|완료|폐기|Abandoned`)에 **없다** → 자동 이동 안 됨 = working/ 에 남아 사용자 리뷰 대기 (의도된 동작).
3. **REGISTRY** status 를 `ready-to-merge` 로 갱신:
   ```bash
   source ~/.claude/hooks/lib/registry-utils.sh
   registry_update "{작업명}" "{sid8}" ready-to-merge
   ```
   (`registry_update` 는 status 자유 문자열 수용 — 코드 변경 불필요. `registry_list_active` 는 active 만 잡으므로 완료대기는 active 목록에서 제외 = 의도.)
4. **`## 머지 전 리뷰 포인트`** 섹션 기록 (무인 특화 — 사용자 리뷰 진입점):
   ```markdown
   ## 머지 전 리뷰 포인트
   - worktree: `~/.claude/worktrees/{sid8}-{slug}` (wip/{sid8}-{slug})
   - 핵심 변경: {1~3줄 요약}
   - verify: e2e 5점 {PASS/부분} / review: Self-Critique {통과/잔여}
   - 미결 결정: {없음 | 사용자 판단 필요 항목}
   - 정착: `/taskflow:save {작업명}` → 승인 → /git:merge (머지·push 는 사용자)
   ```
5. `[AUTO-ITERATE-USER-DECISION]` 마감 — 머지 승인이 사용자 결정 영역이므로 DONE 아님.

## step 문서 상세 기록 (무인 필수)

무인이라 기록이 유일한 리뷰 근거다. task 1건이면 working 통합 문서 §실행에, 여러 step 으로 쪼개졌으면 각 `step-NN` 평면 파일 §실행/§QA 에 **생략 없이** 기록한다 (기존 §4.1 강제 재사용, 신규 룰 0):

- `## 변경 영향 기록` — 무엇을 / 개선점 / 수행 이유
- `## Before/After 대조` — 제안 0건이면 "없음 — 지시 그대로"
- `§ 검증` e2e 5점 + `§ 리뷰` Self-Critique 결과
- `## 결정 Escalation 로그` — 판단 필요로 걸린 항목 (= 사용자가 머지 전 볼 것)

## §3 Checkpoint 우선 적용

- tick 은 §3 보호 우회 통로가 아니다. 무인 실행 중 권한형 결정(P1~P4)·비가역·외부 시스템 변경은 `dangerous-ops-guard.sh`/`branch-enforce.sh` 가 hook 레벨에서 별도 차단하고, escalation ladder 가 즉시 USER-DECISION 마감한다.
- **완주해도 정착(머지)하지 않는다** — 정착은 사용자 명시 승인 게이트(`save.md:33`)이므로 무인 tick 은 ReadyToMerge 에서 정지. master/main 머지·push 는 어떤 경우도 사용자 직접.

## SSOT (재사용 조각 — 본 커맨드는 순차 호출 래퍼)

| 조각 | 역할 | SSOT |
|------|------|------|
| 주기 반복 | `/loop <interval> /taskflow:tick` | harness `/loop` 스킬 |
| claim | cwd 최신 1건 / #tag 배타 claim | `custom-plugin/taskflow/commands/load.md` |
| 실행 관통 | worktree → 개발 → QA → verify → review | `custom-plugin/taskflow/commands/auto.md` |
| 결정 마감 | escalation ladder P1~P4 / I1~I3 | `custom-plugin/taskflow/commands/execute.md` §"결정 escalation ladder" |
| step 순차 소비 | step-01~nn 의존 순서 `Pending→In Progress→Done` | `custom-plugin/taskflow/commands/execute.md` (step 순차 실행) + `plan.md` §"step 파일 양식" |
| 완주 정지 | ReadyToMerge = 종결 정규식 비대상(자동이동 안 됨) | `hooks/working-lifecycle.sh:54` |
| REGISTRY | status 자유 문자열 | `hooks/lib/registry-utils.sh` |
| 정착 (사용자) | ReadyToMerge → 승인 → Done | `custom-plugin/taskflow/commands/save.md` |

## 호출 예

```
/loop 30m /taskflow:tick        ← 30분마다 cwd 최신 task 1건 자율 진행 (무인 백로그 소진)
/taskflow:tick                  ← 1회분만 수동 실행 (cwd 최신 1건)
/taskflow:tick #auth-jwt        ← 특정 분배 태그 1건
```

무인 loop 흐름 예시:

```
[loop tick 진입]
  1) /taskflow:load latest → 2026-07-23-...-commerce-price-audit (Status: Plan Complete)
  2) 분기 → Plan Complete → /taskflow:auto 진입
  3) worktree 생성 → 개발 → QA → verify(e2e 5/5) → review(통과)
     결정 요구 없음
  4) worktree 유지 + Status: ReadyToMerge + REGISTRY ready-to-merge
     + ## 머지 전 리뷰 포인트 기록
  → [AUTO-ITERATE-USER-DECISION]  (사용자가 /taskflow:save 로 머지 승인 대기)
[loop 다음 주기 → 다음 task claim]
```

## Changelog

- 2026-07-23: 신설 (무인 loop 1-iteration 러너)
