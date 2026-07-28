---
description: 무인 loop 1-iteration 러너 — **cwd 무관 전체 스캔**으로 진행 가능 step 1건 claim → Status 분기 → 개발+verify+review → 그 step 에 `Status: ReadyToMerge`(머지 준비) 부착. 머지·push 안 함(§3). 판단 필요 시 unified `NeedsDecision` 마감. 모든 step ReadyToMerge 되면 정지(사용자 step 머지 대기). harness `/loop <interval> /taskflow:tick` 로 반복. 로직 재구현 0.
allowed-tools: Bash, Edit, Write, Read, Glob, Grep, Skill, Agent, PowerShell
argument-hint: "[작업명|#tag — 생략 시 자동 claim] | allow [작업명] | deny [작업명]"
---

무인 1-iteration 러너. **주기 반복은 harness `/loop`** 가 담당 — `/loop 30m /taskflow:tick`. tick 자체는 **다음 진행 가능한 step 1개**를 `ReadyToMerge`(머지 준비)까지 올리고 멈춘다.

## 핵심 원칙

- **로직 재구현 0.** claim=`working_scan` 선택 + `registry_claim` 원자 점유, 실행=`/taskflow:auto`, 마감=escalation ladder, step 스캔=`hooks/lib/working-scan.sh`.
- **머지·push 안 함 (§3).** step 완료 → 그 step `Status: ReadyToMerge`(머지 준비)까지. **tick 은 어떤 경우에도 머지하지 않는다.** 실제 step 머지는 사용자가 `control`→`/taskflow:save` 로, 또는 `/taskflow:watch` 가 코드리뷰 클린 판정 시 자동 해소한다 (`watch.md` §"ReadyToMerge 해소"). **task 완료(Done)는 사용자 전용** — 어느 경로도 task 를 Done 으로 올리지 않는다.
- **`ReadyToMerge` 는 step 단위 상태 — "완료대기"가 아니다.** task(unified)엔 ReadyToMerge 가 없다. task 는 모든 step 머지 + 완료 게이트 통과 후에만 `Done`.
- **판단 필요 = 즉시 마감.** 권한형 결정(§3)에 걸리면 unified 에 `NeedsDecision` 부착 + 판단사항 기록 후 그 iteration 종료.

## 1-iteration 흐름

```
0. 필터   : unified frontmatter `tick: allow` 마커 없는 task 는 후보에서 제외 (화이트리스트)
              └ 허용 task 0건 → "무인 허용 대상 없음" 출력 후 종료
1. claim   : working_scan 전체 스캔(cwd 무관) → 진행 가능 항목 선택 → registry_claim 로 원자 배타 점유
              단위: 평면(step 분해) task = 다음 진행 가능 step slug / 통(경량) task = task slug
              (타 sid active 면 skip → 다음 후보)
              └ 진행 가능 0건 → "없음" 출력 후 종료 (loop 다음 주기)
2. 분기    : unified Status 판정 (아래 표)
2-bis 하강 : working-scan 으로 다음 진행 가능한 step(Pending + 선행 Done) 선택
2-ter 환경 : dev-stack.sh up (검증 환경 보장 — §"dev 스택 보장". 실패 시 NeedsDecision)
3. step 실행: 개발 → verify(e2e 5점) → review → 그 step 파일에 Status: ReadyToMerge 부착
              (머지 안 함. §계획 인덱스 표 상태도 ReadyToMerge 로 갱신)
              └ P1~P4 권한형/판정 불확실 → unified Status: NeedsDecision + §결정 로그 → 마감
4. 반복/정지: 다음 tick = 다음 step. 모든 step ReadyToMerge → tick 정지
              (사용자가 control 로 보고 step별 머지 + 완료 게이트 → task Done)
```

## 1단계 — 무인 허용 필터 + task/step 배타 claim (cwd 무관, 세분 점유)

`/taskflow:load latest`(cwd 라우팅 + read-only)를 쓰지 않는다 — 그건 조회지 점유가 아니다. tick 은 `working_scan` 으로 **전체** 진행 가능 항목을 훑고, **무인 허용 마커가 박힌 task 만** 남긴 뒤 **claim 단위로 배타 점유**한다.

0. **무인 허용 마커 필터 (필수, 화이트리스트)** — 마커가 없는 문서는 후보에서 제외한다. tick 은 **명시적으로 허용된 문서만** 잡는다.

   ```bash
   # unified frontmatter 에 마커가 있어야 그 task 전체가 무인 대상
   tick_allowed() { grep -qE '^(tick|무인):[[:space:]]*(allow|허용)' "$1" 2>/dev/null; }
   ```

   - **판정 대상 = unified 문서** (step 파일 개별이 아니라 task 단위 허용). step 은 소속 unified 의 마커를 상속한다.
   - 마커 없음 = **skip** (경고 아님 — 정상 동작). `deny` 명시도 skip.
   - `tick:` / `무인:` 둘 다 인식한다 (`Status:`/`상태:` 이중 인식 관례 동일). 값은 `allow` / `허용`.
   - **줄 시작 앵커라 frontmatter 밖 본문에 `tick: allow` 를 줄 첫머리로 적으면 잡힌다.** 실측상 인용·설명 중 매칭은 안 됐지만(`본문에 tick: allow …` = skip), 문서 안에서 이 마커를 예시로 쓸 때는 들여쓰거나 코드블록에 넣는다.
   - `working_scan` 출력 컬럼을 늘리지 않는다 — 6컬럼을 `read -r … is_step` 로 받는 소비자가 4곳이라 7번째를 붙이면 `is_step` 이 오염된다. 후보에 대해서만 grep 한다 (진행 가능 후보는 실측 11건 규모라 fork 비용 무시 가능).

   ```markdown
   ---
   Status: In Progress
   tick: allow          # 이 줄이 있어야 무인 tick·watch 가 이 task 를 처리한다
   ---
   ```

### 마커 관리 — `allow` / `deny` 서브명령

`/taskflow:tick` 의 첫 인자가 `allow`/`deny` 면 **iteration 을 돌지 않고 마커만 조작하고 끝난다** (claim·실행 없음).

| 호출 | 동작 |
|------|------|
| `/taskflow:tick allow {작업명}` | 그 task 의 unified 에 `tick: allow` 삽입 (이미 있으면 값 교체) |
| `/taskflow:tick deny {작업명}` | `tick: deny` 로 교체 — 무인 대상에서 뺀다 |
| `/taskflow:tick allow` (인자 없음) | 현재 허용된 task 목록 조회 (mutation 0) |

대상 unified 탐색은 `working_scan` 재사용 — **`is_step=0` 인 행만** 잡는다 (step 파일에 박아도 무시되므로 애초에 대상에서 뺀다).

```bash
source ~/.claude/hooks/lib/working-scan.sh
working_scan all | awk -F'\t' -v t="$TASK" '$4==t && $6==0 {print $1}'   # unified 경로
```

찾은 파일은 **Edit 도구로** 수정한다 (`sed -i` 는 PostToolUse 를 우회해 검증 hook 이 안 돈다). 삽입 위치 = `Status:`/`상태:` 줄 바로 뒤.

- 작업명이 **여러 건 매칭**되면 목록을 내고 정지한다 — 아무거나 고르지 않는다.
- **0건 매칭**이면 오타 가능성을 보고하고 정지한다 (working/ 에 없는 작업명).
- 인자 없는 조회는 허용 목록 + `working/` 전체 건수를 같이 낸다 (몇 건 중 몇 건이 무인 대상인지가 실질 정보다).

1. `working_scan all`(cwd 무관 — cwd product 0건이어도 타 product 진행) → **0단계 통과분에 한해** 진행 가능 후보 산출:
   - **평면(step 분해) task** = 다음 진행 가능 step(2-bis 의존 판정) → claim 단위 = **step slug** `{작업명}-step-NN`.
   - **통(경량·step 없음) task** = unified 전체 → claim 단위 = **task slug** `{작업명}`.
2. 배타 claim — `registry_claim`(lock 안에서 확인+add 원자 수행, TOCTOU race 차단 — 병렬 워커 필수):
   ```bash
   source ~/.claude/hooks/lib/registry-utils.sh
   RESULT=$(registry_claim "{slug}" "{product}" "{sid8}" "{cwd}" "{working_file}")
   case "$RESULT" in
     CLAIMED:*|ALREADY:*) ;;                                  # 점유 성공 → 진행
     TAKEN:*)  echo "타 sid 점유 → 다음 후보"; continue ;;      # 타 세션 → skip
   esac
   ```
   - 평면 task 는 slug 가 **step 단위**라 다른 tick 이 **같은 task 의 다른 독립 step 을 병렬** claim 가능.
   - 통 task 는 task slug 라 task 전체 배타 점유.
3. 진행 가능 후보 0(전부 타 sid 점유거나 완료) → "진행 가능 없음" 출력 후 종료.

> **점유 해제:** step 완료(ReadyToMerge)/task Done 시 `working-lifecycle.sh`·`working-release.sh` 가 REGISTRY entry 를 정리(기존 lifecycle 재사용). 인자(`{작업명}`/`#tag`) 명시 시 그 대상만 claim.
>
> **인자 명시 호출은 0단계 마커 필터를 면제한다.** `/taskflow:tick {작업명}` 은 사용자가 그 task 를 직접 지목한 것이라 이미 명시적 허가다. 마커는 **무인 자동 선택**(인자 없는 loop 호출)에서 아무거나 잡히지 않게 하는 장치지, 수동 실행을 막는 게 아니다.

## 2단계 — unified Status 분기

| unified Status | 진입 | 사유 |
|------------|------|------|
| 없음 / `초안` / raw | `/taskflow:analyze` → `/taskflow:plan` → `/taskflow:auto` | 분석부터 |
| `Analysis Complete` | `/taskflow:plan` → `/taskflow:auto` | **분석 완료·계획 미수립 — 분석 재실행 금지** (마커 SSOT = `analyze.md` §"종료 마커") |
| `Plan Complete` | `/taskflow:auto` (2-bis step 하강) | 계획 완료 → step 실행 |
| `In Progress` | `/taskflow:auto` (다음 step) | 이어감 |
| `NeedsDecision` | **skip** | 사용자 판단 대기 — 결정 입력 전 재잡이 금지(무한 방지). 결정 후 `In Progress` 복귀 시 재개 |
| **모든 step `ReadyToMerge`** | **skip** | step 머지 대기 (control→/save 또는 watch 자동 해소) |
| `Done` | **skip** | 종결 |

## 2-bis단계 — step 하강 (working-scan)

unified §계획에 **Step 분해 인덱스 표**가 있으면 unified 통짜가 아니라 **step 파일 단위**로 진행한다.

1. `hooks/lib/working-scan.sh` 의 `working_scan {product}` 로 step 상태를 읽어 **다음 진행 가능한 step** 선택 — 인덱스 표 `Pending` + **그 step 의 직접 의존 선행(인덱스 표 '의존' 컬럼)이 전부 완료(`ReadyToMerge`/`Done`)**.
   - **우회 (필수):** 앞 step 이 막혀 있어도 **그 step 에 의존하지 않는 독립 step 은 계속 진행**한다 ("앞이 막히면 뒤도 전혀 진행 안 함" 방지). 진행 가능 여부는 전체 순번이 아니라 **직접 의존 선행**만으로 판단한다.
   - **필수 블로커:** 직접 의존 선행이 `NeedsDecision`/`In Progress` 면 그 step 은 **진행 불가** (선행 결과에 실제로 의존하므로).
   - 진행 가능 step **0** → 전부 `ReadyToMerge`/`Done` 이면 **4단계 정지** / 블록(의존 선행 미해결)만 남으면 **task 정지**(사용자 판단 필요).
2. **착수 전 반려 검사 (필수)** — `Pending` 은 "미착수" 만 뜻하지 않는다. `/taskflow:watch` 가 리뷰 지적으로 반려한 step 도 `Pending` 이라, 구분 없이 `/taskflow:auto` 를 태우면 **이미 커밋된 작업을 백지에서 재수행**한다.

   ```bash
   source ~/.claude/hooks/lib/working-scan.sh
   working_rejections "$STEP"        # 미해소 반려 지적 수 (판정식 SSOT = 그 lib)
   ```

   **> 0 이면 반려 소비 모드**로 진입한다 (신규 개발 아님):
   - **worktree 를 새로 만들지 않는다.** `## 머지 전 리뷰 포인트` 의 worktree 경로·wip 브랜치를 **재사용**한다 (`auto.md` §worktree 적용 절차 skip). 그 경로가 `git worktree list` 에 없으면 진행하지 말고 보고 — 커밋을 잃은 상태라 판단이 필요하다.
   - 작업 범위 = **미해소 체크박스 그것뿐**. 해소한 항목은 `- [x]` 로 소진하고 §실행에 대응 커밋을 기록한다.
   - 전건 소진 후에만 `ReadyToMerge` 재부착. 하나라도 남으면 `Pending` 유지.
   - 지적이 §3 매칭이거나 계획 자체를 바꾸면 개발하지 말고 `NeedsDecision` 마감 (escalation ladder).

3. **착수 표시** — claim 직후 그 step 파일 `상태: Pending → In Progress` + 인덱스 표 갱신 (control·다른 tick 이 "진행 중" 을 봄). 이어서 그 step 을 진행 단위로 `/taskflow:auto` 실행 (execute.md step 순차 소비 재사용).
4. step DoD 충족 → 그 step 파일 `상태: ReadyToMerge`(머지 준비) + 인덱스 표 갱신 → 다음 step (막히거나 전부 ReadyToMerge 까지). 전이·SSOT = 아래 §"step 상태 라이프사이클".
5. step 도중 판단 필요 → **3단계 마감** (unified NeedsDecision, 다음 tick 이 그 step 부터 재개).

> step 분해 없는 경량 unified = unified 전체를 1 진행 단위로 처리하고 완료 시 unified 자체에 `Status: ReadyToMerge`.

## cwd 에 국한되지 않는다 (필수)

**스캔도 작업도 호출된 위치를 따르지 않는다.** tick 은 `working_scan all` 로 전 product 를 훑고, 잡은 step 의 **product 가 작업 repo 를 결정**한다 — cwd 가 무엇이든 무관하다.

| 축 | 무엇이 결정하나 |
|----|----------------|
| 문서 스캔 | `working_scan all` — 전 product (cwd 미참조) |
| **작업 repo** | **claim 한 step 의 product** (cwd 아님) |
| worktree 생성 | 그 product repo 에서 `git -C {repo} worktree add` |

**`cd` 로 옮겨다니지 않는다.** `git -C` 로만 대상 repo 를 조작한다 — `cd` 는 이후 hook 의 판정 컨텍스트(product 판정·worktree 면제)를 바꾸고, 무인 루프가 지금 어디에 서 있는지 추적을 어렵게 만든다. `watch.md` 가 같은 규약을 쓴다(2026-07-28 실측으로 `git -C` 경유 브랜치 생성·ff머지·worktree remove 가 전부 hook 통과 확인).

> **러너 쪽도 cwd 를 고정한다.** `tick-loop.sh` 는 `claude` 를 띄우기 전에 `~/.claude` 로 이동한다. 그러지 않으면 부모 셸의 cwd 를 그대로 상속해 product 판정이 호출 위치에 좌우된다 — 실측으로 `~/.claude/docs/...` 하위에서 돈 세션들이 남았고, 그 부작용을 막은 것이 `product-resolver` 의 self-nesting 가드다.

## dev 스택 보장 (step 실행 전, 필수)

**step 개발에 착수하기 전에 검증 환경을 먼저 확보한다.**

```bash
bash ~/.claude/bin/dev-stack.sh up     # idempotent — 이미 떠 있으면 즉시 반환
```

e2e 5점의 4번이 "실제 엔드포인트 curl 200 확인" 이라(`hongcafe:php8` §e2e 검증), 살아 있는 환경 없이는 verify 가 애초에 완결되지 않는다. 코드를 다 고친 뒤 검증 단계에서 스택이 없다는 걸 발견하면 그 iteration 이 통째로 낭비되므로 **착수 전**에 세운다.

- **`up` 은 병렬에서도 안전하다.** `docker compose up -d` 가 idempotent 라 슬롯 N 개가 동시에 불러도 이미 떠 있으면 아무 일도 일어나지 않는다. 최초 기동만 mkdir 락으로 직렬화된다.
- **기동 실패 시 그 step 은 `NeedsDecision`** 으로 마감한다 (검증 불가 = 완료 판정 불가). 코드를 고쳐놓고 verify 를 건너뛰는 것보다 낫다.
- **`down` 은 절대 호출하지 않는다.** 슬롯 하나가 내리면 같은 스택을 쓰는 다른 슬롯의 검증이 깨진다. 내리는 것은 사람이 `dev-stack.sh down` 으로 명시할 때만이다.
- 대상은 **로컬 docker** 다. EC2 dev 는 공유 자원이라 무인 루프가 건드리지 않는다 (CLAUDE.md §4.3 "서버 우선 디버그" = 사용자 명시 승인 영역).

**`/taskflow:tick-loop` 과 `/taskflow:tick-team` 은 별도 처리가 없다** — 둘 다 결국 tick 을 호출하므로 이 규약을 그대로 상속한다. 세 곳에 각각 넣으면 drift 가 생긴다.

## 3단계 — 판단 필요 시 문서 기록 후 마감

분류·마감은 **`execute.md` §"결정 escalation ladder" SSOT**. 요지:

- **권한형 P1~P4 · 판정 불확실** → 그 **step 파일** `Status: NeedsDecision` + §실행 `## 결정 Escalation 로그`(결정 사항 + 선택지·트레이드오프·추천). **task(unified)는 진행 가능한 독립 step 이 남아있으면 `In Progress` 유지** — tick 이 다음 iteration 에 그 독립 step 을 진행한다 (막힌 step 하나가 task 전체를 세우지 않는다). **모든 진행 가능 step 이 0** 이면 unified `Status: NeedsDecision` + `registry_update {작업명} {sid8} needs-decision`. `[AUTO-ITERATE-USER-DECISION]` 마감.
  - `NeedsDecision` 은 종결 정규식(`Done|완료|폐기|Abandoned`) 비대상 → 자동이동 안 되고 working/ 잔류. tick 은 skip(재잡이 무한 방지). SessionStart 배너·`/taskflow:control` 이 `⚠️ 판단 필요` 로 최우선 노출.
  - **재개:** 아래 §"결정 수용 (사용자 결정 → tick 재잡이)" 절차.
- **정보 부족형 I1~I3** → bounded `/taskflow:analyze`→`/taskflow:plan` 자체 해소, 미해소 시 조사결과 첨부 후 마감.

## 결정 수용 (사용자 결정 → tick 재잡이)

사용자가 `NeedsDecision` 항목에 결정을 입력하면 **그 턴에 Claude 본체가 직접** 아래 3개를 수행한다 (별도 슬래시 없음 — hook 이 합성할 수 없는 sentinel 턴이므로 본체 책임. CLAUDE.md §4.1 "결정 기록" (b)).

1. **결정 기록** — `## 결정 Escalation 로그` 해당 행의 `결과` 컬럼을 `사용자 결정: {선택} ({YYYY-MM-DD})` 으로 갱신 + 판단 근거 1줄. §공통 `## 변경 영향 기록` 표에도 (질문 → 선택) 1행 (§4.1 기존 강제 재사용).
2. **상태 복귀** — 막혔던 **step 파일** `상태: NeedsDecision → Pending`, unified `Status: NeedsDecision → In Progress`. 인덱스 표 상태 컬럼도 동기화.
3. **REGISTRY** — `registry_update {slug} {sid8} active` (needs-decision → active).

> **step 은 반드시 `Pending` 으로 되돌린다 — `In Progress` 가 아니다.** 2-bis 의 진행 가능 조건이 `Pending` + 선행 완료라 `In Progress` 로 두면 tick 이 그 step 을 **영원히 다시 잡지 않는다**. 더구나 §2-bis "필수 블로커" 상 선행이 `In Progress` 면 그 step 에 의존하는 후속 step 까지 막힌다. 착수 표시(`In Progress`)는 다음 tick 이 claim 하는 시점에 붙인다.
>
> 결정이 **여러 step 에 걸치면** 그 step 들을 전부 `Pending` 으로 되돌린다. 결정 결과가 계획 자체를 바꾸면 상태 복귀 대신 `/taskflow:plan` 재진입으로 step 을 재분해한다 (기존 step 은 `폐기` 표기).

```bash
source ~/.claude/hooks/lib/registry-utils.sh
registry_update "{작업명}" "{sid8}" active     # 3. needs-decision → active
```

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
| `Pending` (결정 복귀) | 사용자 결정 입력 → 재잡이 가능 상태로 되돌림 | Claude 본체 (§"결정 수용") |
| **`Pending` (반려 복귀)** | **watch 리뷰 지적 ≥ 1건 → 재작업 대상으로 되돌림** | **`/taskflow:watch`** (§"반려 — Pending 복귀") |
| `Done` | 사용자가 그 step 머지 | `/taskflow:save` |

> **`Pending` 은 단일 의미가 아니다 — 진입로가 셋이다** (미착수 / 결정 복귀 / 반려 복귀). 상태 값만 보고 "아직 안 한 step" 으로 단정하면 반려 재작업이 신규 개발로 뒤바뀐다. 착수 전에 **반드시** §2-bis 2 의 반려 검사를 돌린다. **상태 축을 늘려 구분하지 않는 이유:** `working_scan` KW 목록·`working_gate_blockers`·control·watch 가 전부 이 어휘를 공유해서, 값 하나 추가가 4곳 동시 개정이 된다. 문서 안 반려 블록으로 판별하는 편이 싸다.
>
> **`Pending` 을 drift 로 오판해 되돌리지 않는다.** 2026-07-28 실측 — 다른 세션이 watch 반려를 "동시 저장 역행" 으로 오인해 `ReadyToMerge` 로 복구했고, 그 결과 지적 3건이 미해소인 채 머지 대기 상태가 됐다. 커밋이 실재하고 검증 기록이 온전해도 그건 반려 사유(DoD 밖 신규 지적)와 무관하다. 되돌리기 전 `### 반려 N회` 블록을 먼저 확인한다.

- **동기화:** tick 은 step 파일 `상태:` 변경 시 unified 인덱스 표 상태 컬럼도 같은 값으로 갱신 (불일치 시 step 파일이 우선 — working-scan 이 파일을 읽으므로).
- **다세션 상보:** step 파일 `상태: In Progress` = 문서 레벨 진행 표시 / REGISTRY active(step slug claim) = 배타 lock. 둘이 함께 control·다른 tick 에 진행 중 step 을 가시화한다.

## step 상세 기록 (무인 필수)

무인이라 기록이 유일한 리뷰 근거다. 각 step 파일 §실행/§QA 에 생략 없이 (기존 §4.1 강제 재사용, 신규 룰 0): `## 변경 영향 기록`(무엇/개선점/왜) · `## Before/After 대조` · verify 5점 + review Self-Critique · `## 결정 Escalation 로그`(판단 걸린 것).

## §3 Checkpoint 우선 적용

- tick 은 §3 우회 통로가 아니다. 권한형 결정·비가역·외부 변경은 `dangerous-ops-guard.sh`/`branch-enforce.sh` 가 hook 레벨 차단 + escalation ladder 가 즉시 NeedsDecision 마감.
- **tick 은 머지 절대 안 함** — step ReadyToMerge 까지만. task 완료·master/main·push 는 사용자 직접 (step 머지만 watch 자동 해소 경로가 별도로 있다).

## SSOT (재사용 조각)

| 조각 | 역할 | SSOT |
|------|------|------|
| 주기 반복 | `/loop <interval> /taskflow:tick` | harness `/loop` 스킬 |
| claim | **cwd 무관 전체 스캔** / #tag | `custom-plugin/taskflow/commands/load.md` |
| 실행 관통 | worktree → 개발 → QA → verify → review | `custom-plugin/taskflow/commands/auto.md` |
| 결정 마감 | escalation ladder P1~P4 / I1~I3 | `execute.md` §"결정 escalation ladder" |
| step 순차 소비 | step-01~nn 의존 순서 | `execute.md` + `plan.md` §"step 파일 양식" |
| **step 스캔 + 완료 게이트** | working/ 훑기 · `working_gate_blockers` · **`working_rejections`**(반려 소비 모드 판정) | **`hooks/lib/working-scan.sh`** |
| **dev 검증 환경** | 로컬 docker 스택 ensure(up) / 헬스체크 / down(사람 전용) | **`~/.claude/bin/dev-stack.sh`** |
| ReadyToMerge = 비종결 | 자동이동 안 됨 | `hooks/working-lifecycle.sh:54` |
| step 머지 + 완료 판정 | 사용자 | `custom-plugin/taskflow/commands/save.md` |
| 대기 큐 리뷰 | step ReadyToMerge + NeedsDecision | `custom-plugin/taskflow/commands/control.md` |
| **반려 생산** | 리뷰 지적 → `Pending` 복귀 + 반려 블록 append | **`custom-plugin/taskflow/commands/watch.md`** (§"반려 — Pending 복귀") |

## 호출 예

```
/loop 30m /taskflow:tick        ← 30분마다 다음 step 을 ReadyToMerge 로 진행 (무인)
/taskflow:tick                  ← 1 step 만 수동 진행
/taskflow:tick allow            ← 현재 무인 허용 목록 조회
/taskflow:tick allow commerce-audit   ← 그 task 를 무인 대상으로 등록
/taskflow:tick deny commerce-audit    ← 무인 대상에서 제외
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

- 2026-07-28: **반려 소비 모드 (2-bis 2)** — `Pending` 진입로가 셋(미착수/결정 복귀/**watch 반려**)인데 라이프사이클 표에 반려가 없어, tick 이 반려 step 을 미착수로 읽고 `/taskflow:auto` 를 태우면 새 wip 브랜치를 파 **이미 커밋된 작업을 백지 재수행**했다. 착수 전 반려 블록 검사 → worktree 재사용 + 지적만 처리. 상태 값은 늘리지 않는다(4곳 동시 개정 회피)
- 2026-07-28: **무인 허용 마커 화이트리스트 (0단계)** — unified frontmatter `tick: allow` 가 있는 task 만 무인 자동 선택 대상. 인자 명시 호출은 면제. `/taskflow:watch` 해소 게이트도 같은 마커 공유. 마커 조작 = `allow`/`deny` 서브명령
- 2026-07-23: 신설 → step 단위 ReadyToMerge + 완료 게이트 재설계
