---
description: 태스크 감시 루프 1-iteration — working/ 문서를 스냅샷 대비 diff 해서 **변경분만** 검증한다. 코드 작업이면 코드리뷰, 문서 작업이면 정합성 검증. `ReadyToMerge` 는 리뷰가 클린이면 ff머지로 해소하고, 지적이 있으면 `Pending` 복귀시켜 재작업 대상으로 되돌린다. 변경 없으면 1줄로 종료(no-op). `/loop 5m /taskflow:watch` 로 무인 반복. 짝 = `/taskflow:control`(대기 큐) · `/taskflow:tick`(생산)
allowed-tools: Bash, Read, Glob, Grep, Skill, Edit, Agent
argument-hint: "[product|all — 생략 시 all. `sessions` = 다른 세션 진행 관측]"
---

주기 감시의 1-iteration. **주기 반복은 harness `/loop`** 가 담당한다 — `/loop 5m /taskflow:watch`.

전건을 매번 재검증하지 않는다. 지난 iteration 스냅샷과 **diff 해서 바뀐 것만** 본다 (working/ 77건 기준 diff 0.5초 실측).

## 1-iteration 흐름

**두 트랙이 독립으로 돈다.** 변경 감지(A)와 머지 해소(B)는 서로의 결과를 기다리지 않는다.

```
A. 변경 트랙 (diff 기반)
  A1. diff   : watch_diff {scope} → A(신규) / M(상태·내용 변경) / D(사라짐)
               └ 0건 → 이 트랙만 skip (B 는 계속 — 종료하지 않는다)
  A2. 분류   : 변경 항목마다 코드 축 / 문서 축 판별 (§"코드·문서 판별")
  A3. 검증   : 상태 전이·완료 게이트 공통 + 축별 —
               코드 축 → 변경분 코드리뷰 Agent / 문서 축 → 정합성 검증

B. 해소 트랙 (상태 기반 — diff 와 무관하게 매 iteration 실행)
  B1. 수집   : working_scan 으로 ReadyToMerge 전건 (변경 여부 안 봄)
  B2. 리뷰   : 코드 축 → 변경분 리뷰 / 문서 축 → 정합성 검증
  B3. 해소   : 지적 0건 → ff머지 + Done / 지적 1건 이상 → Pending 복귀

C. 보고 + commit
  C1. 보고   : 문제 있는 것만. 양 트랙 모두 조용하면 "변동 없음"
  C2. commit : watch_commit {scope} — A·B 를 마친 뒤에만 스냅샷 확정
```

**B 를 A 에 종속시키면 안 된다.** `ReadyToMerge` 문서는 이미 그 상태로 스냅샷에 박혀 있어 `M` 으로 잡히지 않는다 — B 가 A1 뒤에 오면 머지 대상이 **영원히 0건**이 된다 (2026-07-28 실측: diff 0건인데 미해소 ReadyToMerge 2건 방치). 사용자 요구는 "**상태가** ReadyToMerge 면 해소" 지 "ReadyToMerge 로 **바뀌면** 해소" 가 아니다.

**C2 순서도 중요하다.** 검증 전에 스냅샷을 갱신하면 그 변경분은 영영 A 트랙 대상에서 빠진다.

## cwd 에 국한되지 않는다 (필수)

**watch 는 호출된 위치와 무관하게 전 프로젝트를 본다.** 스캔도, 머지도, 상태 변경도 cwd 를 따르지 않는다.

| 축 | 범위 | 근거 |
|----|------|------|
| 문서 스캔 | `working_scan all` — 전 product | 인자 생략 시 기본 `all` (`control` 이 cwd product 기본인 것과 반대) |
| repo 감시 | `state/watch/repos.txt` 전건 | cwd 와 무관한 목록 파일 |
| **머지·상태 변경** | **`git -C {repo}` 로 원격 조작** | 프로세스 cwd 를 바꾸지 않는다 |

**`cd` 를 쓰지 않는다.** `git -C` 로만 다른 repo 를 조작한다 — `cd` 는 이후 hook 의 판정 컨텍스트를 바꾸고, 무인 루프가 지금 어느 repo 에 서 있는지 추적을 어렵게 만든다. 2026-07-28 실측: `~/.claude` cwd 에서 `git -C /c/Works/hongcafe_global_docs` 로 브랜치 생성·체크아웃·ff머지·worktree remove·`branch -D` 를 전부 수행했고 `worktree-enforce`·`branch-enforce` 를 통과했다.

인자로 좁히고 싶을 때만 `/taskflow:watch {product}` 를 쓴다. 기본은 항상 전체다.

## 스캔 (Bash — lib 재사용, 인라인 재작성 금지)

```bash
source ~/.claude/hooks/lib/working-scan.sh
source ~/.claude/hooks/lib/watch-snapshot.sh

watch_diff "${1:-all}"        # 변경분만 — 스냅샷은 안 건드림
# … 검증 후 …
watch_commit "${1:-all}"      # 스냅샷 확정
```

스냅샷 = `~/.claude/state/watch/{scope}.tsv` — 문서 행(path/mtime/size/status) + **repo 행**(`repo:{경로}`/HEAD/미커밋수/브랜치). **scratchpad 가 아니라 state/** 에 둔다 — 세션이 죽어도 남아야 다음 세션 loop 가 이어서 diff 한다.

### 감시 repo 목록

`~/.claude/state/watch/repos.txt` — **1줄 1경로, 사용자가 소유하는 목록 파일.** 최초 1회만 "최근 14일 내 커밋" repo 로 시딩하고 이후 자동 갱신하지 않는다. 불필요한 repo 는 직접 지운다.

> **전 repo 자동 감시는 안 한다.** 2026-07-27 실측 — 로컬 repo 14개 중 대부분이 몇 달째 잠든 레거시고, `hongcafe3_upgrade` 는 dirty 35,972건이라 그대로 감시하면 노이즈가 신호를 덮는다. 시딩 후 7건으로 좁혀졌다.
>
> git 조회는 repo 당 `git status --porcelain=v2 --branch` **1회**로 HEAD·브랜치·미커밋 수를 모두 얻는다 (rev-parse+status+branch 3회 호출은 13 repo 에 6.7초였다 → 1.0초).

**`git pull`·`fetch` 는 하지 않는다.** watch 는 read-only 이고 pull 은 로컬 상태를 바꾼다 — 무인 루프가 남의 미커밋 작업을 stash 하거나 rebase 충돌을 만드는 사고가 실재한다. 최신화가 필요하면 사용자가 직접 하거나 `--pull` 을 명시한다 (기본 비활성).

## A3 — 변경 항목 검증 (변경 유형별)

| 유형 | 무엇을 보나 | 판정 |
|------|-----------|------|
| **M: 상태 전이** | `Pending→In Progress→ReadyToMerge` 순서가 맞나. `NeedsDecision` 이 새로 붙었나 | 역행(`ReadyToMerge→Pending` 등)이면 보고. NeedsDecision 신규 = **최우선 보고** |
| **M: 내용 갱신** | 체크박스 소진·§실행 기록·verify/review 결과가 실제로 채워졌나 | 상태만 올라가고 근거가 비면 보고 |
| **A: 신규** | 양식 골격·Status 마커가 있나 | 골격 없는 raw 문서면 보고 |
| **D: 사라짐** | `tasks/` 로 정상 이동인가, 그냥 없어졌나 | `docs/{product}/tasks/` 에서 확인. 못 찾으면 **보고** |
| **M: repo 커밋** | 새 커밋이 어느 문서의 진행과 대응하나 | 대응 문서가 안 바뀌었으면 **미기록 커밋** 보고 |
| **M: repo 미커밋** | dirty 건수가 계속 쌓이나 | 증가만 하고 커밋이 없으면 보고 |
| **M: repo 브랜치** | 감시 중 브랜치가 바뀌었나 | 보고 (worktree 이탈·체크아웃 흔적) |

완료 게이트는 `working_gate_blockers {product} {작업명}` 을 그대로 쓴다 (판정 재구현 0).

### 문서 ↔ git 교차 판정 (핵심)

두 축을 따로 보는 게 아니라 **어긋남**을 찾는다. 한 축만 보면 못 잡는 것들이다.

| 어긋남 | 신호 | 의미 |
|--------|------|------|
| **거짓 진행** | 문서 `ReadyToMerge` 인데 해당 repo HEAD 불변 | 문서만 앞서갔다 — 커밋 없이 완료 선언 |
| **미기록 커밋** | repo 새 커밋 vs 대응 문서 변경 0 | 작업은 했는데 기록이 없다 |
| **정체** | 문서 `In Progress` 유지 + dirty 증가 + 커밋 0 | 진행 중이나 미확정 누적 |

> **문서의 `## 변경 파일` 을 파싱해 대조하지 않는다.** 그 섹션 보유율이 **35/77건(45%)** 이라 절반이 사각지대다 (2026-07-27 실측). repo HEAD 축은 문서 형식에 의존하지 않는다.

### 코드·문서 판별

같은 `ReadyToMerge` 라도 코드 작업과 문서 작업은 검증할 게 전혀 다르다.

**문서 본문을 파싱해 판별하지 않는다 — git 에 직접 묻는다.** `## 머지 전 리뷰 포인트` 에 worktree 경로가 적힌 문서는 **20건 중 0건**이다 (2026-07-28 전수 실측). tick.md 가 기록을 명시했지만 실제 보유율은 0% 라, 이 축으로 판별하면 전건이 오분류된다. `## 변경 파일` 을 거부한 것과 같은 이유다.

```bash
# taskflow 소유 worktree 만 — wip/{sid8}-{slug} 규약 (SSOT = git/commands/merge.md)
# 출력: worktree경로 \t sid8 \t slug   (sid8 prefix 를 벗겨야 문서 작업명과 매칭된다)
git -C "$REPO" worktree list --porcelain \
  | awk '/^worktree /{w=$2}
         /^branch refs\/heads\/wip\//{
           sub("refs/heads/wip/","",$2)
           i = index($2,"-")
           print w"\t"substr($2,1,i-1)"\t"substr($2,i+1)
         }'
# 예: C:/Users/PV/.claude/worktrees/46299ae3-mirror-sync  46299ae3  mirror-sync
```

`wip/` 로 필터하는 게 핵심이다. 실측상 `hongcafe_global_backend` 의 worktree 3개는 전부 `worktree-agent-*` (하니스 Agent isolation 용)라 taskflow 와 무관하다 — 필터 없이 열거하면 남의 worktree 를 리뷰하게 된다.

worktree 는 그 repo 안이 아니라 `~/.claude/worktrees/` 에 생기고 `worktree list` 는 **소유 repo 에서 조회**해야 나온다 (위 예시도 `hongcafe_global_docs` 에서 조회했다). 감시 repo 를 순회하며 찾는다.

### worktree ↔ 문서 대응 — 문서 기록이 1순위, 없으면 내용 대조

**문서의 `머지 전 리뷰 포인트` 에 worktree 가 적혀 있으면 그게 가장 정확하다.** base 브랜치와 머지 순서까지 함께 적히는 경우가 있고, 그건 git 추론으로는 얻을 수 없는 정보다.

```
- worktree: `~/.claude/worktrees/7f1eebc3-mod02-priceoptions`
  (branch `wip/7f1eebc3-mod02-priceoptions`, base=`wip/e294a6aa-mod02-qnafcmuse` @ `f55e9eed`)
- 머지 순서: `f55e9eed`(qnaFcmUse) → 본 브랜치. 뒤집으면 forSelf 키 카운트 단언이 어긋난다
```

**단 보유율이 고르지 않다** — 2026-07-28 실측에서 20건 중 0건이었다가 같은 날 새로 생성된 문서엔 적혀 있었다. 그러니 **있으면 쓰고, 없을 때만 아래 추론으로 내려간다.** 기록이 있는데 무시하고 git 으로 추론하면 base·순서 정보를 버리게 된다.

### 기록이 없을 때 — 문자열 매칭으로 정하지 않는다 (필수)

**slug 도 sid 도 1:1 규약이 아니다.** 2026-07-28 실측:

```
worktree                        문서 작업명
7f1eebc3-mod02-priceoptions  ↔  mod-02-advisor-readback-gaps   (문자열 불일치)
e294a6aa-mod02-qnafcmuse     ↔  mod-02-advisor-readback-gaps   (한 문서에 worktree 2개)
e294a6aa-mod-04-viewer-role  ↔  mod-04-chat-viewer-role        (sid 하나가 두 task)
```

slug 는 사람이 자유롭게 짓고, 한 세션(sid)이 여러 task 를 거치며, 한 task 가 여러 worktree 를 쓴다. **기계적 정확 매칭은 0건**이고, REGISTRY sid 축도 다대다라 판정이 안 선다.

그래서 이렇게 한다 — **기계는 후보만 뽑고, 대응은 Claude 가 내용으로 판단한다.**

```bash
# 후보 수집만 — 매칭은 하지 않는다
working_scan all | awk -F'\t' '$5=="ReadyToMerge" {print $1"\t"$4}'          # 해소 대상
for REPO in $(grep -vE '^\s*(#|$)' ~/.claude/state/watch/repos.txt); do      # 살아있는 wip
  git -C "$REPO" worktree list --porcelain 2>/dev/null \
    | awk -v r="$REPO" '/^worktree /{w=$2} /^branch refs\/heads\/wip\//{print r"\t"$2"\t"w}'
done
```

대응 판정 = 그 문서의 `## 변경 파일`·§실행 기록·`머지 전 리뷰 포인트` 와 **worktree diff 의 실제 파일 목록**을 대조한다. 이름이 아니라 **무엇을 건드렸는지**가 근거다.

| 판정 | 축 | 동작 |
|------|-----|------|
| worktree diff 가 그 문서의 서술과 일치 | **코드** | 리뷰 → 해소 |
| 대응 worktree 없음 + repo HEAD 변동도 없음 | **문서** | 정합성 검증 → 해소 |
| **대응이 불확실 / 후보 2개 이상** | — | **머지 금지.** 후보를 나열해 사용자에게 확인 요청 |

변경 파일이 전부 `.md` 면 git 변경분이 있어도 **문서 축**이다 (`is_hard_code_file` 재사용, `hooks/lib/path-utils.sh`).

> **불확실하면 멈춘다.** 잘못 짝지어 머지하면 남의 작업이 엉뚱한 feature 에 들어간다 — 되돌리기 비싼 실수다. 무인 진행보다 보고가 낫다.
>
> **앞으로의 매칭 비용을 줄이려면** tick 이 step 완료 시 `머지 전 리뷰 포인트` 에 worktree 경로를 실제로 적어야 한다 (tick.md 4단계 3에 이미 명시돼 있으나 실측 보유율 0/20). 그게 지켜지면 이 판정은 기계화된다.

### 코드 축 — 변경분 리뷰

`general-purpose` Agent 1개를 spawn 해 **변경분만** 리뷰한다 (전체 코드베이스 감사 아님).

- 입력 = worktree diff 또는 커밋 범위 + 그 step 문서의 §계획·DoD.
- 판정 = Critical / High / Medium / Low + 각 지적의 `file:line`.
- 리뷰 관점은 `/taskflow:review` 와 같다 — 재사용성·가독성·효율성 + DoD 충족 여부. 보안 냄새가 있으면 `security-audit` 스킬로 넘긴다.

**리뷰는 코드를 고치지 않는다.** `simplify` 처럼 수정까지 하는 경로를 타지 않는다 — 무인 루프가 리뷰하면서 코드를 바꾸면 리뷰 대상 자체가 움직인다.

### 문서 축 — 정합성 검증

3축으로 본다. 전부 기존 SSOT 재호출이라 재구현이 없다.

| 축 | 무엇 | 호출 |
|----|------|------|
| **양식** | 필수 §섹션·체크리스트 개수·참조 출처·작성 정보 | `doc-unified-check.sh` (stdin JSON, exit 2 = 위반) |
| **원본 drift** | `/taskflow:draft` 로 만든 문서의 원본 지문(sha256) 변동 | `/taskflow:draft check` |
| **내용 정합** | 문서가 서술한 대상(API 명세·스펙)과 실제가 맞나 | api-docs = `hongcafe:mirror-be-claude verify` / 그 외 = Agent 대조 |

```bash
printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$DOC" | bash ~/.claude/hooks/doc-unified-check.sh
# exit 2 = 차단 사유 stderr 전량 / exit 0 = 통과 또는 역소급 면제
```

> `doc-unified-check.sh` 는 **통과와 면제를 구분해서 알려주지 않는다** (둘 다 exit 0). 그래서 양식 축 단독으로 "정합함" 을 선언하지 않는다 — 내용 정합 축이 실질 판정이다.

## B 트랙 — ReadyToMerge 해소 (상태 기반)

**diff 를 보지 않는다.** 매 iteration 마다 `working_scan` 으로 `ReadyToMerge` 전건을 새로 훑는다.

```bash
source ~/.claude/hooks/lib/working-scan.sh
working_scan all | awk -F'\t' '$5=="ReadyToMerge" {print $1"\t"$4"\t"$6}'   # 경로 / 작업명 / is_step
```

`ReadyToMerge` 가 아닌 상태(In Progress·NeedsDecision·Pending)는 A 트랙에서 검증·보고만 하고 손대지 않는다.

> **마커(`tick: allow`)를 요구하지 않는다.** 그 화이트리스트는 `/taskflow:tick` 이 **무인으로 아무 task 나 잡지 않게** 하는 장치다. watch 의 해소는 `ReadyToMerge` 라는 상태 자체가 이미 "개발·verify·review 를 통과해 머지만 남았다" 는 명시 신호이므로 별도 게이트를 겹치지 않는다.

| 축 | 검증 결과 | 동작 |
|----|-----------|------|
| 코드 | 지적 0건 | ff머지(**base 판별 통과 시**) → step `상태: Done` |
| 코드 | **지적 ≥ 1건** (severity 무관) | step `상태: Pending` 복귀 + 반려 사유 기록 — 머지 안 함 |
| 문서 | 정합성 위반 0건 | 머지 대상 없음 → step `상태: Done` (머지 단계만 skip) |
| 문서 | 위반 ≥ 1건 | step `상태: Pending` 복귀 + 반려 사유 기록 |

> **`Done` 은 step 파일에만 붙인다.** 경량 task(step 없이 unified 자체가 `ReadyToMerge`)는 검증을 통과해도 **Done 으로 올리지 않고 "완료 가능" 으로 보고만** 한다 — unified 에 `Status: Done` 을 붙이는 순간 `working-lifecycle.sh` 가 tasks/ 로 자동 이동시켜 task 종결이 되고, 그건 사용자 몫이다. step 파일은 `working-lifecycle.sh:330` 이 `-step-NN-` 패턴의 `상태: Done` 을 마스터 완료 마커에서 제외하는 이중 가드를 이미 갖고 있어 안전하다.

### 통과 — ff머지

**머지 전에 base 분기를 먼저 판별한다.** `/git:merge` 는 사용자가 `feature/{이름}` 을 알고 있다고 전제하지만 무인 watch 는 모른다. wip 브랜치에 upstream 이 설정돼 있지 않아서(실측 확인) `@{u}` 로는 못 얻는다.

```bash
# wip 의 base 후보 — merge-base 가 잡히는 비-wip 브랜치를 열거
for b in $(git -C "$REPO" branch --format='%(refname:short)' | grep -vE '^wip/'); do
  mb=$(git -C "$REPO" merge-base "$b" "wip/$SLUG" 2>/dev/null) || continue
  echo "$b $mb"
done
```

| base 판별 결과 | 동작 |
|----------------|------|
| `feature/*` 단일 | ff머지 진행 |
| **`master`/`main` 뿐** | **repo별 착지 브랜치 정책**(아래) 적용 |
| 후보 2개 이상 (모호) | 머지 금지 — 후보 목록과 함께 보고. 상태 유지 |
| 후보 0개 | 머지 대상 없음으로 보고 |

### repo별 착지 브랜치 (master 회피)

base 가 master/main 뿐이어도 **master 에 직접 머지하지는 않는다**. repo 마다 착지 지점이 정해져 있다.

| repo | 착지 브랜치 | 비고 |
|------|------------|------|
| `hongcafe_global_docs` | **`working_docs`** — 없으면 `master` 에서 생성 후 거기로 머지 | master 불변 |
| `~/.claude` (claude-harness) | **현재 브랜치 그대로** (`vibe_setting`) | 기본 작업 브랜치가 master/main 이 아니라 그냥 머지 |
| 그 외 | `feature/*` 가 있으면 그쪽 / 없으면 **머지 금지 → PR 보고** | 상태는 `ReadyToMerge` 유지 |

```bash
# hongcafe_global_docs — 착지 브랜치 확보 (idempotent, 리다이렉트 없이 --quiet)
git -C "$REPO" show-ref --verify --quiet refs/heads/working_docs || git -C "$REPO" branch working_docs master
git -C "$REPO" checkout working_docs
```

**master 로 checkout·머지하지 않는 한 `branch-enforce.sh` 는 통과한다** — `working_docs` 는 8 target ref 에 없다. master 에서 분기만 뜨는 것은 master 를 변경하지 않는다.

**PR 보고로 빠지는 경우엔 상태를 되돌리지 않는다.** 코드 자체엔 문제가 없으므로 `Pending` 반려가 아니라 `ReadyToMerge` 를 유지한 채 사용자에게 넘긴다.

> **여러 wip 을 같은 착지 브랜치로 순차 머지하면 두 번째부터 ff-only 가 깨진다** (첫 머지로 착지 브랜치가 전진하므로 두 번째 wip 이 그 후손이 아니게 된다). 그때는 `/git:merge` 의 cherry-pick fallback 을 탄다 — **범위 cherry-pick 전에 `git rev-list --merges` 로 머지 커밋 유무를 먼저 확인**하고, 1건이라도 있으면 시작하지 않고 보고한다.

base 가 확정되면 절차는 `/git:merge` 를 그대로 탄다 (재구현 0). 4개 명령 **개별 Bash 호출**, `&&`/`;` 결합 금지 — 결합하면 `dangerous-ops-guard.sh` 의 `git branch -D wip/…` 면제가 매칭에 실패해 차단된다.

머지 후 그 step 파일 `상태: ReadyToMerge → Done` + unified §계획 인덱스 표 상태 컬럼 동기화 + 정착 후 reachable 해시 기록 (`git rev-parse {feature}` — wip 해시를 인용하면 orphan 이 된다).

**task 를 `Done` 으로 올리지는 않는다.** step 머지까지가 watch 의 경계고, 완료 게이트 판정 + task 종결은 `/taskflow:save` 몫이다 (`working_gate_blockers` 0건이면 "완료 가능" 으로 보고만 한다).

### 반려 — Pending 복귀

`상태: ReadyToMerge → Pending` 으로 되돌린다. **`In Progress` 가 아니다** — tick 의 진행 가능 조건이 `Pending` + 선행 완료라, `In Progress` 로 두면 tick 이 그 step 을 **영원히 다시 잡지 않는다** (근거 SSOT = `tick.md` §"결정 수용").

그 step 파일 `머지 전 리뷰 포인트` 섹션 아래에 반려 블록을 append 한다 (**헤더 레벨은 `##`/`###` 둘 다 실재하므로 `^#+ 머지 전 리뷰 포인트` 로 찾는다** — 2026-07-28 실측 3:3. 섹션 자체가 없으면 문서 끝에 `## 머지 전 리뷰 포인트` 로 신설):

```markdown
### 반려 1회 (2026-07-28 · watch 자동 리뷰)
- [ ] [High] `app/Modules/Call/Services/CallService.php:142` — N+1 쿼리
- [ ] [Low] `…:88` — 미사용 import
```

**무엇이 실제로 게이트를 막는지는 step 과 경량 task 가 정반대다** (`working_gate_blockers` 구현 실측):

| 대상 | 게이트 차단 근거 | 체크박스 역할 |
|------|-----------------|--------------|
| step 파일 | **`상태: Pending`** → `미처리 step` 으로 blocker 판정 | 재작업 목록 (게이트는 안 봄 — 미체크박스 검사는 `is_step=0` 분기 전용) |
| 경량 task(unified) | **미체크박스 `- [ ]`** → `미체크박스 잔존` 으로 blocker 판정 | **게이트 그 자체** |

어느 쪽이든 반려가 남아 있으면 task 는 `Done` 으로 못 넘어간다. 새 게이트를 만들 필요는 없지만, **step 에 체크박스만 적고 상태를 안 되돌리면 게이트가 뚫린다** — 상태 전이가 필수다.

경량 task 는 unified `Status: In Progress` 로 되돌린다 (unified 에는 `Pending` 이 없다 — tick 2단계 분기표 기준 재진입 상태가 `In Progress`). 이 경우 상태만으로는 게이트가 안 걸리므로 **체크박스를 반드시 남긴다.**

복귀 시 보고에 **그 작업의 cwd** 를 같이 낸다 (REGISTRY entry 의 cwd). 사용자가 바로 그 자리에서 이어받거나, 다음 tick 이 재잡이한다. REGISTRY 는 건드리지 않는다 — 다음 tick 이 `registry_claim` 으로 새로 점유한다.

## mutation 경계 (필수)

watch 의 쓰기는 **딱 두 가지**다. 그 밖은 전부 보고만 한다.

1. 자기 스냅샷 (`state/watch/{scope}.tsv`)
2. **B 트랙** `ReadyToMerge` 해소 — ff머지 + step `상태:` 전이 (Done / Pending) + 인덱스 표 동기화 + 반려 블록

**A 트랙은 진단 전용이다.** 상태 역행 · 근거 누락 · 문서 실종 · 미기록 커밋 · dirty 정체 · 문서 정합성 위반은 **보고만** 하고 고치지 않는다 (CLAUDE.md §4.2 "audit 결과 자동 수정 금지"). 수정은 `/taskflow:execute` 로.

**절대 안 하는 것:** `git push` · master/main 머지·checkout·switch (§4.3(d)(e) — `branch-enforce.sh` 가 hook 레벨로도 차단) · 코드 파일 직접 수정 · task `Status: Done` 전이.

## loop·tick 임의 중지 금지 (필수)

watch 는 다른 세션의 `/loop`·tick·cron 을 정지·삭제·kill 하지 않는다.

**"변동 없음" 이 여러 번 연속돼도 그것은 정지 근거가 아니다.** 감시 루프는 원래 조용할 때 아무것도 보고하지 않는 게 정상 동작이다. no-op streak 을 무익함의 증거로 삼지 않는다. 정지는 사용자 몫 — 요청 시에만 수단을 안내한다. SSOT = 메모리 `feedback_no-autonomous-loop-kill`.

## `sessions` 모드 — 다른 세션 진행 관측

`/taskflow:watch sessions [sid8 ...]` 는 문서가 아니라 **다른 세션 transcript** 를 본다. REGISTRY 에 안 잡히는 무인 loop 세션이 실재하기 때문이다 (2026-07-27 실측 — 132MB/96MB 로 돌던 두 세션이 REGISTRY·lock 어디에도 없었다).

```bash
python3 ~/.claude/hooks/lib/transcript-tail.py 77af0d0f 346c3c39   # sid 지정
python3 ~/.claude/hooks/lib/transcript-tail.py --top=5             # 최신 5개
```

신호 4개 = 생존(mtime) / 현재 도구(마지막 `tool_use`) / **판단 대기**(`AUTO-ITERATE-USER-DECISION`) / 반복 횟수. 파일 끝 256KB 만 seek 하므로 132MB 파일도 상수 비용(두 개 동시 0.6초 실측).

## 출력 예

```
[watch — scope=all]  변경 5건 (문서 4 / repo 1)

⚠️ 판단 필요 (신규)
  commerce-audit / step-02-rounding   상태 In Progress→NeedsDecision

✅ 머지 해소 (리뷰 클린)
  auth-refactor / step-01-token       [코드] 리뷰 0건 → ff머지 → Done
                                       feature/auth-refactor 79a79787

🔁 반려 → Pending 복귀
  commerce-audit / step-01-price-calc [코드] 리뷰 2건 (High 1·Low 1) → 머지 보류
                                       ↳ CallService.php:142 N+1 쿼리 · :88 미사용 import
                                       ↳ 재작업 cwd: C:\Works\hongcafe_global_backend

📄 문서 정합성
  mod-03-call-connect-docs-fix        [문서] 양식 통과 · api-docs 3-way 정합 ✓

🚫 머지 불가 (상태 유지)
  mirror-sync                          base 후보가 master 뿐 → PR 필요 (§4.3(e))

❓ 확인 필요
  legacy-cleanup                       사라짐 — tasks/ 에서 못 찾음
  hongcafe_global_backend              커밋 d504e63e→79a79787; 미커밋 0→1건
                                       ↳ 대응 문서 변경 없음 — 미기록 커밋 의심

스냅샷 갱신: 84건 (문서 77 / repo 7)
```

A·B 양 트랙 모두 조용할 때만 `[watch — scope=all] 변동 없음` 1줄. **diff 0건이어도 B 트랙에 미해소 `ReadyToMerge` 가 있으면 "변동 없음" 이 아니다.**

## SSOT

| 조각 | 역할 | SSOT |
|------|------|------|
| **변경 감지** | 스냅샷 diff (A/M/D) — 문서 축 + repo 축 | **`hooks/lib/watch-snapshot.sh`** |
| 감시 repo 목록 | 사용자 소유 목록 (자동 갱신 안 함) | `~/.claude/state/watch/repos.txt` |
| working/ 스캔 + 완료 게이트 | `working_scan` · `working_gate_blockers` | `hooks/lib/working-scan.sh` |
| 세션 관측 | transcript tail 신호 4개 | `hooks/lib/transcript-tail.py` |
| 주기 반복 | `/loop <interval> /taskflow:watch` | harness `/loop` 스킬 |
| **ff머지 절차** | checkout→ff-only→worktree remove→branch -D | **`custom-plugin/git/commands/merge.md`** |
| **문서 양식 검증** | V1~V8 통합 validator (stdin JSON) | **`hooks/doc-unified-check.sh`** |
| 원본 drift | 원본 지문(sha256) 대조 | `custom-plugin/taskflow/commands/draft.md` (`check`) |
| api-docs 정합 | 3-way 미러 검증 | `hongcafe:mirror-be-claude` (`verify`) |
| 코드/문서 파일 판정 | `is_hard_code_file` | `hooks/lib/path-utils.sh` |
| 대기 큐 상세 | NeedsDecision·ReadyToMerge 처리 진입 | `custom-plugin/taskflow/commands/control.md` |
| 상태 라이프사이클 + Pending 복귀 근거 | Pending→In Progress→ReadyToMerge | `custom-plugin/taskflow/commands/tick.md` |
| 정지 금지 | loop·cron 임의 종료 차단 | 메모리 `feedback_no-autonomous-loop-kill` |

## `/taskflow:control` 과의 차이

control 은 **지금 쌓여 있는 것**(대기 큐 전체)을 보여준다. watch 는 **지난번 이후 바뀐 것**(A 트랙) + **상태가 `ReadyToMerge` 인 것**(B 트랙)을 본다. 무인 loop 에는 watch, 사람이 앉아서 훑을 땐 control 이다.

**기본 범위도 반대다** — control 은 cwd product, watch 는 전 product. watch 는 무인이라 사람이 어디 서 있는지와 무관해야 한다.

해소 주체도 다르다 — control 은 read-only 라 목록만 내고 머지는 사용자가 `/taskflow:save` 로 하지만, watch 는 리뷰가 클린인 `ReadyToMerge` 를 직접 ff머지한다. 그래서 watch loop 가 돌고 있으면 control 대기 큐에는 **리뷰에서 반려됐거나 판단이 필요한 것**만 남는다.

## 호출 예

```
/loop 5m /taskflow:watch                    ← 5분마다 working/ 변경 감시 (무인)
/taskflow:watch                             ← 1회 수동 점검
/taskflow:watch hongcafe_global_backend     ← 특정 product 만
/taskflow:watch sessions 77af0d0f 346c3c39  ← 다른 세션 진행 관측
```

## Changelog

- 2026-07-28: repo별 착지 브랜치 정책 (`hongcafe_global_docs` → `working_docs` / `~/.claude` → 현재 브랜치 직접 / 그 외 feature 또는 PR) + cwd 비종속 명문화 (`git -C` 만, `cd` 금지)
- 2026-07-28: **해소를 diff 에서 분리해 독립 B 트랙으로** — 변경 감지(A)와 상태 기반 해소(B)가 서로 기다리지 않는다. 해소를 A 하위 단계로 뒀더니 `ReadyToMerge` 가 스냅샷에 이미 박혀 있어 diff 0건 → 머지 대상 영구 0건이 됐다 (실측). watch 해소의 무인 허용 마커 요구도 철회 — 그 마커는 tick 전용이다
- 2026-07-28: 축별 검증(코드=리뷰 / 문서=정합성) + `ReadyToMerge` 자동 해소 — 리뷰 클린이면 ff머지→Done, 지적 ≥1건이면 Pending 복귀. read-only 계약 해제 (mutation 경계 = §"mutation 경계")
- 2026-07-27: 신설 — 스냅샷 diff 기반 변경분 검증 + sessions 관측 모드
