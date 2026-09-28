---
description: 분리 루프 1회 — 지금 이 요청을 `step-developer` 가 worktree 안에서 구현하고 `reviewer-correctness`(기능 정합) · `reviewer-design`(설계 정합) 두 콜드 리뷰어가 병렬로 판정한다. 짠 쪽과 본 쪽을 갈라놓는 것이 값이다. 문서·상태 전이 없음, 머지 안 함(§3). **클린 뒤엔 `adversary` 가 그 클린을 깨보고 못 깨야 끝난다.** 짝 = `/taskflow:tick`(문서 기반 무인) · `/taskflow:execute`(계획 기반 대화형)
allowed-tools: Bash, Read, Glob, Grep, Agent, Skill, PowerShell
argument-hint: "{구현 요청} — 필수. 생략 시 진행 중 working/ step 을 쓰려면 /taskflow:tick 을 쓴다"
---

**짠 쪽과 본 쪽을 갈라놓는 루프**를 지금 이 요청에 1회 돌린다. 페르소나가 값이 아니다 — 본체는 이미 같은 사고방식을 갖고 있고(CLAUDE.md §0 상속), 그럼에도 자기가 방금 쓴 코드에서는 과설계가 안 보인다 (근거 실측 = `tick.md` §2-bis 2).

## 무엇을 하지 않는가

**대상을 고르지 않는다.** claim·의존 판정·Status 분기가 없다 — 지금 받은 요청이 대상이다. 그게 `/taskflow:tick` 과의 유일한 실질 차이다.

**문서를 만들지 않는다.** working/ 문서·§실행·상태 전이가 없다. 결과는 응답으로 보고한다. 문서가 필요한 규모면 `/taskflow:plan` → `/taskflow:tick` 이 맞다.

**머지·push 하지 않는다 (§3).** worktree 와 커밋만 남기고 정착은 사용자가 한다.

## 흐름

**착수 전 `~/.claude/custom-plugin/taskflow/references/review-contract.md` 를 Read 한다 (필수).** 1단계 대조 기준·크기 게이트·종료 조건·적대적 게이트·기준선 교차 확인·반박 판정·합본·정착 규칙이 전부 거기 있다 — 이 파일에는 흐름만 남았다.

```
1. 범위 확인 : 요청 → 대상 파일 · 성공 기준 · 테스트 범위 · 비목표 · 커밋 type·scope 확정
              성공 기준 4개 이상이면 여기서 정지 → /taskflow:plan 안내
2. worktree  : git -C {repo} worktree add ~/.claude/worktrees/{sid8}-{slug} -b wip/{sid8}-{slug}
              composer.lock 있는 PHP 레포면: bash ~/.claude/bin/vendor-pool.sh ensure {worktree 절대경로}
              (신규 worktree 는 vendor 없이 시작 — pool 있으면 하드링크 클론 수 초, 없으면
              최초 1회 composer install 후 pool 화. 없는 PHP 레포는 자동 skip)
              vendor 를 junction·symlink 로 링크하지 않는다 · worktree 삭제는 `git worktree remove` 만
              (링크된 vendor 는 remove --force 가 따라가 원본을 지운다 — ISS-285)
3. 개발      : subagent_type: taskflow:step-developer
              (요청 + 성공 기준 + 테스트 범위 + 비목표 + worktree 경로)
              → 반환 BASELINE 전·후 명령 동일성 교차 확인 (§"기준선을 교차 확인한다")
4. 리뷰 루프 : subagent_type: taskflow:reviewer-correctness · taskflow:reviewer-design 병렬 스폰
              (라운드마다 새로 + 이전 라운드 이력 + BASELINE · spawn 규약 = `review-contract.md` §"코드 축")
              → 지적을 합쳐 개발 Agent 에 SendMessage → 재리뷰
              → C·H·M 이 모두 0이 될 때까지, 5회
              → REBUTTED 가 오면 본체가 수용·기각을 판정하고 다음 리뷰어에게 이력으로 넘긴다
4-bis. 게이트 : C·H·M 0 도달 시 taskflow:adversary 스폰 — 클린 판정 반증 (재현 없으면 UPHELD)
4-ter. 정리  : 개발 Agent 가 매 라운드 돌리므로(§"기계 검사를 앞으로 당긴다") 보통 no-op.
              누락분만 린터 --fix 1회. 보고에 한 줄
5. 보고      : 변경 요약 + 라운드 로그 + 잔여 핸드오프. 커밋만 남기고 정지
```

각 단계 계약은 전부 기존 SSOT 를 그대로 쓴다 — **에이전트 계약을 여기서 재정의하지 않는다. 루프 제어(종료 조건·캡·반박 판정·적대적 검증 게이트)만 여기 소관이다.**

| 조각 | SSOT |
|------|------|
| 개발 Agent 계약 (코드 기준·반박 근거 3종·`git add -N`·반환 양식·`model: sonnet`) | `custom-plugin/taskflow/agents/step-developer.md` |
| 기능 정합 리뷰어 (§1 경계값·예외·회귀·동시성 · §5 호출부 전수 · §6 실행 검증) | `custom-plugin/taskflow/agents/reviewer-correctness.md` |
| 설계 정합 리뷰어 (§2 보안 · §3 단순성 · §4 재사용 · §7 범위) | `custom-plugin/taskflow/agents/reviewer-design.md` |
| **적대적 검증 red-team** (반환 BROKEN/UPHELD·공격면 5축·재현 강제·`model: opus`) | `custom-plugin/taskflow/agents/adversary.md` |
| **리뷰어 spawn 규약** (구성 2인·입력 조립·판정축 분담·반환 합본) | `custom-plugin/taskflow/references/review-contract.md` §"코드 축 — 변경분 리뷰" |
| 개발 Agent 운영 (warm 유지·`isolation` 금지·변경 실재 확인) | `custom-plugin/taskflow/references/review-contract.md` §"step 개발" |
| worktree 생성·정착 절차 | `custom-plugin/git/commands/{create,merge}.md` |
| **신규 worktree vendor 채우기** (`ensure` — pool 하드링크 클론 · 없으면 composer install 후 pool 화) | `bin/vendor-pool.sh` |

## 대조 기준 — 1단계를 건너뛰지 않는다

= `custom-plugin/taskflow/references/review-contract.md` §"대조 기준 — 1단계를 건너뛰지 않는다" SSOT (루프 계약 — `code`·`code-loop`·에이전트 공유).

## 루프 종료 조건

= `custom-plugin/taskflow/references/review-contract.md` §"루프 종료 조건" SSOT (루프 계약 — `code`·`code-loop`·에이전트 공유).

## 적대적 검증 게이트 (2026-08-31~)

= `custom-plugin/taskflow/references/review-contract.md` §"적대적 검증 게이트" SSOT (루프 계약 — `code`·`code-loop`·에이전트 공유).

## 기준선을 교차 확인한다

= `custom-plugin/taskflow/references/review-contract.md` §"기준선을 교차 확인한다" SSOT (루프 계약 — `code`·`code-loop`·에이전트 공유).

## 기계 검사를 앞으로 당긴다

리뷰어가 **읽어서 판정하던 축 중 도구가 확정할 수 있는 것**은 개발 Agent 가 반환 전에 돌린다 (계약·명령 = `step-developer.md` §"반환 전 기계 검사"). 여기 소관은 **왜 앞에 두는가** 하나다.

**같은 지적도 늦게 잡히면 비싸다.** 리뷰어가 잡으면 ① 리뷰어가 diff·원본을 읽고 ② 지적을 쓰고 ③ 본체가 합쳐 넘기고 ④ 개발자가 고치고 ⑤ 다음 라운드가 재확인한다 — 다섯 번의 토큰이다. 도구가 잡으면 개발자가 명령 1회로 끝낸다. **라운드 수가 이 루프의 비용 전부이므로 여기서 한 라운드를 없애는 것이 가장 싸다.**

**실측 (2026-09-10 · hongcafe_local_athena):** `Low` 지적이 거의 매 라운드 1건씩 나오는데 4-ter 린터는 **린터가 설치돼 있지 않아 항상 건너뛰어지고 있었다.** 기계가 처리하기로 한 축이 실제로는 매 라운드 사람 손을 거치고 있었던 셈이다. phpstan 을 넣자 `variable.undefined` 244 · `method.notFound` 196 · `property.notFound` 89(= PHP 8.5 Fatal 축) 가 나왔다 — 전부 리뷰어가 읽어서 찾던 축이다.

**도구가 없는 레포면 이 단계는 no-op 이고 4-ter 가 원래대로 동작한다.** 도구 도입 자체는 이 커맨드 소관이 아니다 — 레포의 일이다.

**`code-loop.sh` 자동 러너는 이 기계 검사를 개발 Agent 반환 직후 셸이 다시 돌린다 (2026-09-22~, `verify_mechanical`).** 개발 Agent 가 "돌렸다" 고 적은 것과 실제로 그 파일이 통과하는지는 별개다 — 셸이 `FILES` 목록의 `.php` 파일에 php -l·cs-fixer·phpstan 을 독립 재실행해 자기신고를 대체하고, 불일치면 리뷰 전에 재보고를 요청한다.

## 반박 판정은 본체가 한다

= `custom-plugin/taskflow/references/review-contract.md` §"반박 판정은 본체가 한다" SSOT (루프 계약 — `code`·`code-loop`·에이전트 공유).

## 두 리뷰어를 합친다

= `custom-plugin/taskflow/references/review-contract.md` §"두 리뷰어를 합친다" SSOT (루프 계약 — `code`·`code-loop`·에이전트 공유).

## 라운드 이력을 넘긴다

본체가 조립해 넘기는 형식은 이렇다.

```
ROUND {N-1}: - [등급] {file:line} — {지적} → 처리: FIXED | REBUTTED-ACCEPTED | DEFERRED
```

코드 판단은 여전히 cold 다. **지우는 것은 이미 닫힌 판정뿐이고**, 없으면 §1(경계값 방어 요구)과 §단순성(과설계 금지)이 라운드를 넘나들며 **진동한다** — 앞 라운드가 요구해 넣은 가드를 다음 라운드가 과설계로 잡는 형태다.

**적대적 검증 게이트(§흐름 4-bis)에는 이 이력을 통째로 넘긴다.** 리뷰어에게 이력이 프레임이 되는 것과 반대로, `adversary` 에게는 이력이 **공격 대상**이다 — 무엇을 방어했는지 모르면 깰 것을 못 고른다.

## 라운드를 소진하면

C·H·M 이 남은 채로 정지하고 보고한다. **클린이 아닌 것을 클린으로 만들지 않는다.** worktree 는 그대로 두므로 이어서 `/taskflow:code` 를 다시 부르거나 직접 고치면 된다.

지적이 §3(비가역·외부 시스템·광범위 아키텍처)에 걸리거나 요청 범위 자체를 바꿔야 풀리면 고치지 말고 정지 + 보고한다 (`execute.md` §"결정 escalation ladder" 정합).

## 보고 — 라운드 로그를 남긴다

**클린으로 끝나도 남긴다.** 잘 돌아간 케이스에서 데이터가 안 나오면 루프를 튜닝할 수가 없다.

```
ROUND 1: correctness 5 (C0/H2/M3) · design 4 (M2/L2) · 채택 7 · 반박수용 1 · 유예 1 · 근거실행 4/9
ROUND 2: correctness 1 (M1) · design 0 · 채택 1 · C·H·M 0 도달
FINAL  : 무이력 재검증 → FINDINGS 1건 (M1) · 잔여로 종료
LINT   : --fix 3파일 정리
```

| 지표 | 읽는 법 |
|------|------|
| 등급 분포 | `Medium` 80% 이상이면 요청 단위가 너무 작다 — 묶어서 받는다 |
| 채택률 (수정/전체 지적) | 30% 미만이면 라운드 주기가 아니라 **비목표·대조 기준이 부실한 것이다** |
| 근거 실행 비율 | 낮으면 리뷰어가 테스트를 못 돌리고 있다 — 환경·빌드를 먼저 본다 |
| 게이트 반증율 | `BROKEN` 이 자주 나오면 라운드 리뷰어가 대조 기준 안에서만 돌고 있다 — 1단계의 테스트 범위·비목표가 실제 위험면을 덮는지 다시 본다 |
| `UPHELD` 시도 축 | 5축 중 매번 같은 축만 시도되면 입력에 넘긴 대조 기준이 얇다는 신호다 |
| correctness/design 비율 | design 이 압도적이면 요청이 너무 작다 |

## 잔여를 남긴다 — 응답에만 두지 않는다

**잔여 0으로 끝나면 이 절은 발동하지 않는다.** 잔여 ≥1 일 때만이다.

`/taskflow:tick` 은 판단이 필요하면 unified 문서에 `NeedsDecision` 을 박고 끝나서 잔여가 문서로 남는다. 여기엔 문서가 없어서 잔여가 응답 텍스트로만 남고 세션과 함께 사라진다 — **worktree 는 남는데 무엇이 왜 남았는지가 안 남는다.** 그 비대칭만 막는다.

**분석·계획을 여기서 쓰지 않는다.** 리뷰어가 이미 등급·`file:line`·`{무엇이 왜 틀렸는지} → {어떻게 고쳐야 하는지}` 를 준다 (두 정의 §"반환 양식"). 원재료는 다 있고 없는 건 **왜 이번 루프가 못 고쳤나** 하나뿐 — 그건 루프를 돌린 본체만 안다. 그것만 덧붙여 넘긴다.

| 잔여 등급 | 처리 |
|------|------|
| `Critical`·`High` (= 캡 소진) | 리뷰 결과 전문 + 미수정 사유 + **라운드 로그 + 게이트 결과(`BROKEN` 재현물 포함)**를 `~/.claude/docs/{product}/output/verification/{YYYY-MM-DD}-{slug}-code-review/{YYYY-MM-DD}-{slug}-residual.md` 로 저장 → 그 파일을 원본으로 `/taskflow:draft` 호출. §분석·§계획은 draft 가 만든다 |
| `Medium` · 게이트 잔여 (= 캡 2회 소진 `BROKEN` 재현물) | 3건 이상이면 위 residual 문서, 2건 이하는 응답 핸드오프 — 지적 원문 + 미수정 사유 + 다음 진입점 1개 |
| `Low` ①②③ | 응답에 목록만. 파일·문서 없음. 4-ter 린터가 처리했으면 그것도 안 적는다 |
| `Low` ④ `[범위밖]` | **건수 무관 `residual.md` 에 `## 범위 밖 발견` 섹션으로 저장.** `Medium` 으로 이미 residual 이 생성됐으면 그 문서에 섹션으로 붙이고, 아니면 이것만으로 문서를 만든다. `/taskflow:draft` 는 부르지 않는다 |
| §3 매칭·요청 범위 변경 필요 | 등급 무관 정지 + 사용자 결정 (§"라운드를 소진하면" 그대로). draft 도 부르지 않는다 |

**`[범위밖]` 은 나머지 `Low` 3종과 성격이 다르다.** 앞 셋은 "사소해서 `Low`" 지만 이건 **"의도적으로 이번 범위에서 뺀 결함"** 이다 — 비목표가 없었으면 `High`·`Medium` 으로 나왔을 건이 대부분이다. 개수 임계를 걸지 않는 이유가 그것이고, 1건이라도 남긴다.

`{slug}` 는 2단계에서 만든 worktree 이름(`wip/{sid8}-{slug}`)의 그것을 그대로 쓴다 — 잔여 문서와 worktree 가 같은 이름으로 묶여야 나중에 짝이 찾아진다. 폴더·파일 양쪽에 날짜 prefix 가 붙는 것은 `output-naming-check.sh` 가 둘 다 강제하기 때문이다 (평면 파일·무날짜 폴더는 exit 2 — 2026-08-06 실측).

`/taskflow:plan` 을 직접 부르지 않는다 — 그건 §분석이 끝난 working/ 문서를 전제하고 인자가 작업명뿐이라, 문서가 없는 이 경로에서는 "가장 최근 working/ 자동 식별" 이 **남의 문서를 잡는다.** 원본 파일에서 §분석·§계획을 만드는 계약을 가진 것은 `/taskflow:draft` 다 (`draft.md` §"생성 모드 — 동작 5단계").

backlog 메모리로 밀지 않는다. §4.5 격리는 **"② 실제 문제·버그 아님"** 을 요구하는데 리뷰어 지적은 정의상 결함이라 그 조건을 통과할 수 없다.

## 언제 이걸 쓰고 언제 다른 걸 쓰나

| 상황 | 진입점 |
|------|--------|
| 지금 이 요청을 분리 루프로 맡기고 싶다 (성공 기준 ≤3) | **`/taskflow:code`** |
| 성공 기준이 4개 이상이거나 호출부 전수가 걸려 있다 | `/taskflow:plan` → `/taskflow:tick` |
| working/ 문서의 step 을 진행하고 싶다 | `/taskflow:tick {작업명}` |
| 무인으로 계속 돌리고 싶다 | `/taskflow:tick-loop` |
| 대화하며 같이 짜고 싶다 | `/taskflow:execute` |

## §3 Checkpoint 우선 적용

- 본 커맨드는 §3 우회 통로가 아니다. 개발 Agent 의 Write·Bash 에도 `worktree-enforce`·`dangerous-ops-guard`·`branch-enforce` 가 그대로 걸린다 (`review-contract.md` §"하니스 자동 상속" 실측).
- **머지·push·master/main 접근은 하지 않는다.** worktree 정착은 사용자 명시 승인 후 `/git:create`·`/git:merge`.

## 정착은 1커밋으로

= `custom-plugin/taskflow/references/review-contract.md` §"정착은 1커밋으로" SSOT (루프 계약 — `code`·`code-loop`·에이전트 공유).

## 호출 예

```
/taskflow:code MemberService 의 코인 차감을 트랜잭션으로 묶어라
  성공 기준: (1) 차감·이력 기록이 한 트랜잭션 (2) 실패 시 잔액 원복 (3) 기존 테스트 41개 green 유지
  테스트 범위: 잔액 부족 · 동시 차감 2건 · 이력 insert 실패 롤백 3케이스
  비목표: 인증·권한(상위 필터 소관) · 재시도·멱등성(이번 범위 아님) · 성능 최적화
```

```
/taskflow:code BoardRepository 에 소프트 삭제 필터를 추가하고 호출부 전건 반영
  → 크기 게이트에 걸린다. 성공 기준이 4개 이상(필터 추가 · 호출부 전건 반영 ·
    read 경로 회귀 · 기존 삭제 데이터 처리)이고 호출부 전수가 걸려 있다
  → 정지 + /taskflow:plan 안내
```

## Changelog

> 변경 이력 = `custom-plugin/taskflow/CHANGELOG.md` §`commands/code.md` (2026-09-28 분리 — 실행 시 로드 불요)
