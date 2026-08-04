---
description: 태스크 감시 루프 1-iteration — working/ 문서를 스냅샷 대비 diff 해서 **변경분만** 검증한다. 코드 작업이면 코드리뷰, 문서 작업이면 정합성 검증. `ReadyToMerge` 는 **반려 이력과 무관하게 리뷰를 먼저 돌린 뒤** 대조해서, 클린이면 머지 사다리(ff-only→범위 cherry-pick→non-merge 개별)로 끝까지 정착시키고 지적이 있으면 `Pending` 복귀시켜 재작업 대상으로 되돌린다. **1시간 이상 무진행인 문서는 tick 이 왜 못 잡는지 게이트를 특정해 병목을 제거한다** — 죽은 `active` claim 해제 · step `In Progress` → `Pending` 복귀 (사용자 판단 대기건은 제외). 변경 없으면 1줄로 종료(no-op). `/loop 5m /taskflow:watch` 로 무인 반복. 짝 = `/taskflow:control`(대기 큐) · `/taskflow:tick`(생산)
allowed-tools: Bash, Read, Glob, Grep, Skill, Edit, Agent
argument-hint: "[product|all — 생략 시 all. `sessions` = 다른 세션 진행 관측]"
---

주기 감시의 1-iteration. **주기 반복은 harness `/loop`** 가 담당한다 — `/loop 5m /taskflow:watch`.

전건을 매번 재검증하지 않는다. 지난 iteration 스냅샷과 **diff 해서 바뀐 것만** 본다 (working/ 77건 기준 diff 0.5초 실측).

**신선도 필터 (기본 5분, `WATCH_MIN_AGE_SEC`).** 최종 수정된 지 5분이 안 된 문서는 diff/검증 대상에서 제외한다 — 방금 다른 세션이 저장 중인 문서를 watch 가 바로 잡아채 검증하지 않기 위함. `find` 로 잘라내지 않고 `watch_scan_now`(watch-snapshot.sh) 가 그 문서의 값을 **이전 스냅샷 값 그대로** 낸다(신규면 이번 라운드 자체를 스킵) — 그래야 D(삭제) 오판이 안 나고, 5분이 지나면 자연히 실제 값으로 갱신되며 M/A 로 잡힌다.

## 1-iteration 흐름

**세 트랙이 독립으로 돈다.** 변경 감지(A)·머지 해소(B)·정체 해소(C)는 서로의 결과를 기다리지 않는다.

```
A. 변경 트랙 (diff 기반)
  A1. diff   : watch_diff {scope} → A(신규) / M(상태·내용 변경) / D(사라짐)
               └ 0건 → 이 트랙만 skip (B·C 는 계속 — 종료하지 않는다)
  A2. 분류   : 변경 항목마다 코드 축 / 문서 축 판별 (§"코드·문서 판별")
  A3. 검증   : 상태 전이·완료 게이트 공통 + 축별 —
               코드 축 → 변경분 코드리뷰 Agent / 문서 축 → 정합성 검증

B. 해소 트랙 (상태 기반 — diff 와 무관하게 매 iteration 실행)
  B1. 수집   : working_scan 으로 ReadyToMerge 전건 (변경 여부 안 봄)
  B2. 리뷰   : **무조건 먼저 실행** — 코드 축 → 변경분 리뷰 / 문서 축 → 정합성 검증
  B3. 대조   : 리뷰 결과 ↔ 기존 반려 블록 file:line 대조 → 재등장분만 살린다
  B4. 해소   : 잔존 0건 → 머지 사다리 + Done / 1건 이상 → Pending 복귀

C. 정체 트랙 (경과 기반 — 1시간 무진행. diff·상태 어느 쪽도 안 잡는 축)
  C1. 수집   : working_stalled {scope} → 결정 대기·종결·ReadyToMerge 제외 후보
  C2. 병목   : tick claim 게이트를 순서대로 물어 **첫 실패 게이트** 특정 (G1~G4 / OK)
  C3. 해소   : G3-orphan → registry_mark_stale · G4 → step `Pending` 복귀
               G1·G2 = 사용자 영역 보고 / OK = 병목 없음(루프 미가동) 1줄 집계

D. 보고 + commit
  D1. 보고   : 문제 있는 것만. 세 트랙 모두 조용하면 "변동 없음"
  D2. commit : watch_commit {scope} — A·B·C 를 마친 뒤에만 스냅샷 확정
```

**B 를 A 에 종속시키면 안 된다.** `ReadyToMerge` 문서는 이미 그 상태로 스냅샷에 박혀 있어 `M` 으로 잡히지 않는다 — B 가 A1 뒤에 오면 머지 대상이 **영원히 0건**이 된다 (2026-07-28 실측: diff 0건인데 미해소 ReadyToMerge 2건 방치). 사용자 요구는 "**상태가** ReadyToMerge 면 해소" 지 "ReadyToMerge 로 **바뀌면** 해소" 가 아니다.

**C 도 같은 이유로 독립이다.** 정체는 정의상 **아무 변화가 없는 상태**라 A 의 diff 에는 영원히 안 걸리고, 상태가 `ReadyToMerge` 도 아니라 B 도 안 본다. 두 트랙 모두의 사각지대다.

### D2 순서 — 검증 뒤에 스냅샷

검증 전에 스냅샷을 갱신하면 그 변경분은 영영 A 트랙 대상에서 빠진다.

## cwd 에 국한되지 않는다 (무인 계열 cwd 규약 SSOT)

**watch 는 호출된 위치와 무관하게 전 프로젝트를 본다.** 스캔도, 머지도, 상태 변경도 cwd 를 따르지 않는다. **본 절이 무인 계열(`tick`·`tick-loop`·`watch`) 공통 cwd 규약의 SSOT 다** — 각 커맨드는 자기 축 표만 갖고 `cd` 금지 근거는 여기를 가리킨다.

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

# 문서에 쓰기를 하기 직전에만 그 문서를 잠근다 (B 트랙 해소 / C 트랙 G4)
for DOC in $대상; do
  watch_doc_lock_acquire "$DOC" || { echo "  ↳ 타 인스턴스 처리 중 — 이 문서만 skip"; continue; }
  # … 리뷰·머지·상태 전이 …
  watch_doc_lock_release "$DOC"
done

watch_commit "${1:-all}"      # 스냅샷 확정
```

### 문서 단위 lock (필수)

**인스턴스를 통째로 직렬화하지 않는다** — 그러면 서로 다른 문서를 보는 watch 까지 막혀 한 번에 하나씩밖에 못 푼다. 잠그는 단위는 **watch 가 쓰기를 하는 문서**다. 두 세션이 같은 문서를 동시에 처리하면 깨지는 이유는 **B 트랙의 ff머지 → `worktree remove` → `branch -D` 가 멱등이 아니어서**다 (C 트랙 조치는 멱등이지만 같은 lock 을 쓰는 편이 단순하다).

- **`registry_claim` 을 쓰지 않는다.** 그건 tick 의 점유를 뺏어 정작 일할 주체를 막는다. lock 은 watch 전용 공간(`state/watch/locks/`)이다.
- **못 잡으면 그 문서만 건너뛴다** — 한 문서 때문에 나머지를 세우지 않는다.
- lock 키 = **문서 경로**(sanitize). `mkdir` 원자성 + mtime TTL stale 회수(`WATCH_LOCK_TTL_MIN`, 기본 30분, `registry_lock_acquire` 와 같은 형태) — acquire 후 프로세스가 죽으면 영구히 잠기므로 회수가 필요하다.
- **쓰기 직전에 잡고 끝나면 바로 푼다.** iteration 전체를 감싸면 통째 lock 과 다를 게 없어진다.

> **처리 중 문서는 스냅샷에서 이전 값으로 유지된다** — 인스턴스 A 가 검증 중인 문서를 B 가 `watch_commit` 으로 확정하면 A 의 변경분이 영영 diff 에서 빠진다(§"D2 순서" 와 같은 종류). `watch_scan_now` 가 lock 걸린 문서를 **신선한 문서와 같게** 다뤄 막는다 — 신선도 필터의 값-유지 경로 재사용, 새 장치 0. `watch_commit` 의 tmp 파일명에 PID 가 붙는 것도 같은 이유다(고정 이름이면 서로의 쓰기를 덮어쓴다).

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

### 코드·문서 판별 — worktree ↔ 문서 대응

같은 `ReadyToMerge` 라도 코드 작업과 문서 작업은 검증할 게 전혀 다르다. **문서 본문 파싱으로 판별하지 않고 git 에 직접 묻는다** — `머지 전 리뷰 포인트` 의 worktree 경로 보유율이 2026-07-28 전수 실측 **20건 중 0건**이라, 이 축으로 판별하면 전건이 오분류된다 (`## 변경 파일` 을 거부한 것과 같은 이유).

```bash
# 후보 수집만 — 매칭은 하지 않는다. wip/{sid8}-{slug} 규약 SSOT = git/commands/merge.md
working_scan all | awk -F'\t' '$5=="ReadyToMerge" {print $1"\t"$4}'          # 해소 대상
for REPO in $(grep -vE '^\s*(#|$)' ~/.claude/state/watch/repos.txt); do      # 살아있는 wip
  git -C "$REPO" worktree list --porcelain 2>/dev/null \
    | awk -v r="$REPO" '/^worktree /{w=$2} /^branch refs\/heads\/wip\//{print r"\t"$2"\t"w}'
done
```

- **`wip/` 필터가 핵심이다.** `hongcafe_global_backend` 의 worktree 3개는 전부 `worktree-agent-*`(하니스 Agent isolation 용)라 taskflow 와 무관하다 — 필터 없이 열거하면 남의 worktree 를 리뷰한다.
- worktree 실체는 `~/.claude/worktrees/` 에 있지만 `worktree list` 는 **소유 repo 에서** 조회해야 나온다. 감시 repo 를 순회한다.

**문서에 worktree 가 적혀 있으면 그게 1순위다** — base 브랜치·머지 순서까지 함께 적히는 경우가 있고 그건 git 추론으로 못 얻는다 (`base=wip/e294a6aa-… @ f55e9eed` · `머지 순서: f55e9eed → 본 브랜치, 뒤집으면 단언이 어긋난다`). 보유율이 고르지 않을 뿐이라 **있으면 쓰고 없을 때만 아래로 내려간다.**

**기록이 없으면 문자열 매칭으로 정하지 않는다 (필수).** slug 는 사람이 자유롭게 짓고, 한 sid 가 여러 task 를 거치며, 한 task 가 worktree 를 여럿 쓴다 — 2026-07-28 실측에서 **기계적 정확 매칭 0건**이었고(`7f1eebc3-mod02-priceoptions` ↔ `mod-02-advisor-readback-gaps` 류), REGISTRY sid 축도 다대다라 판정이 안 선다. 그래서 **기계는 후보만 뽑고 대응은 Claude 가 내용으로 판단한다** — 그 문서의 `## 변경 파일`·§실행 기록과 **worktree diff 의 실제 파일 목록**을 대조한다. 이름이 아니라 **무엇을 건드렸는지**가 근거다.

| 판정 | 축 | 동작 |
|------|-----|------|
| worktree diff 가 그 문서의 서술과 일치 | **코드** | 리뷰 → 해소 |
| 대응 worktree 없음 + repo HEAD 변동도 없음 | **문서** | 정합성 검증 → 해소 |
| **대응이 불확실 / 후보 2개 이상** | — | **머지 금지.** 후보를 나열해 사용자에게 확인 요청 |

변경 파일이 전부 `.md` 면 git 변경분이 있어도 **문서 축**이다 (`is_hard_code_file` 재사용, `hooks/lib/path-utils.sh`).

> **불확실하면 멈춘다.** 잘못 짝지어 머지하면 남의 작업이 엉뚱한 feature 에 들어간다 — 되돌리기 비싼 실수다. 무인 진행보다 보고가 낫다.
>
> **앞으로의 매칭 비용을 줄이려면** tick 이 step 완료 시 `머지 전 리뷰 포인트` 에 worktree 경로를 실제로 적어야 한다 (tick.md 4단계 3에 이미 명시돼 있으나 실측 보유율 0/20). 그게 지켜지면 이 판정은 기계화된다.

### 코드 축 — 변경분 리뷰 (무인 코드리뷰 계약 SSOT)

**본 절이 무인 코드리뷰 계약의 SSOT 다 — `/taskflow:tick` 의 리뷰 루프도 같은 계약을 쓴다** (`tick.md` §"step 코드리뷰 루프" 는 여기 포인터). 계약이 두 곳에 복붙되면 갈라지고, 갈라지는 순간 tick 이 통과시킨 것을 watch 가 **다른 기준으로** 반려해 왕복이 되살아난다.

**`cold-reviewer` Agent 1개**를 spawn 해 **변경분만** 리뷰한다 (`subagent_type: taskflow:cold-reviewer` — 플러그인 agent 는 `plugin:name` 형식이다. 정의 = `custom-plugin/taskflow/agents/cold-reviewer.md`). 전체 코드베이스 감사가 아니다.

- **본체가 조립하는 것은 입력뿐이다** — worktree diff(또는 커밋 범위) + 그 step 문서의 §계획·DoD.
- 리뷰 관점(**기능 오류 → 보안 → 품질** 7축, 순서가 곧 우선순위)·판정 등급·"코드 수정 금지"·반환 양식은 **전부 agent 정의에 박혀 있다**. 여기서 다시 적지 않는다.
- 반환 = `VERDICT: CLEAN | FINDINGS` + Critical~Low 지적의 `file:line` (양식 SSOT = agent 정의).

**왜 프롬프트가 아니라 agent 정의인가.** 계약을 매번 프롬프트로 조립하면 라운드마다 문구가 달라지고 그 편차가 곧 리뷰 편차다(아래 §"watch 의 리뷰는 재확인이다" 가 인정하는 그 편차). 정의에 박아두면 spawn 마다 변하는 것이 diff 하나뿐이 된다.

**리뷰어는 코드를 고치지 않는다.** `cold-reviewer` 에 Edit·Write 도구가 없는 것이 그 강제다 (`dev-team` FE 멤버를 `Explore` 로 두는 것과 같은 기계적 차단 — 지시문은 어길 수 있어도 없는 도구는 못 쓴다). `simplify` 처럼 수정까지 하는 경로를 타지 않는다 — 무인 루프가 리뷰하면서 코드를 바꾸면 리뷰 대상 자체가 움직인다.

> **카탈로그 미등재 fallback** = `tick.md` §"카탈로그 미등재 fallback" SSOT.

### watch 의 리뷰는 재확인이다 (2026-07-30~)

tick 이 그 step 안에서 이미 이 계약으로 지적 0건까지 루프를 돌린 뒤 `ReadyToMerge` 를 붙이므로, 여기서 나오는 지적은 **리뷰어 편차로 새로 드러난 것**이다. 그래도 반려 처리는 그대로 한다 — 편차로 드러난 실결함이 실재하고(`BoardController.php:947` 사례), 두 번째 눈이 이 트랙의 값이다. 대신 반려 빈도가 높게 유지되면 tick 쪽 루프가 형식적으로 도는 신호라 보고에 남긴다.

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

### 반려는 리뷰로 소진한다 — 리뷰를 건너뛰지 않는다 (필수)

**`ReadyToMerge` 면 미해소 반려가 남아 있어도 리뷰를 먼저 돌린다.** 반려 블록은 "지난번에 이런 지적이 있었다" 는 이력이지 현재 코드의 상태가 아니다 — 그 사이 tick 이 고쳤을 수 있고, 체크박스를 안 지운 것뿐일 수 있다. 리뷰 없이 되돌리면 **이미 고쳐진 작업이 영원히 왕복**한다.

```bash
source ~/.claude/hooks/lib/working-scan.sh
working_rejections "$DOC"          # 미해소 반려 지적 수 — 차단이 아니라 대조 입력으로 쓴다
```

리뷰 결과와 기존 반려를 **`file:line` 으로 대조**해서 잔존 여부를 정한다.

| 기존 반려 | 이번 리뷰 | 판정 |
|-----------|----------|------|
| 있음 | 같은 `file:line` 재등장 | **잔존** — 체크박스 유지, Pending 복귀 |
| 있음 | 재등장 안 함 | **해소** — 그 체크박스를 `- [x]` 로 소진 + 소진 근거 1줄 |
| — | 신규 지적 | **잔존** — 새 반려 블록 append, Pending 복귀 |
| 있음 | 리뷰 전건 클린 | 전건 소진 → 머지 사다리 진행 |

**소진은 리뷰가 근거일 때만 한다.** 리뷰를 안 돌렸거나 Agent 가 실패했으면 체크박스를 건드리지 않는다 — 그 경우는 판정 불가라 상태 유지 후 보고다.

> **지적 증발 위험은 대조가 받는다.** 리뷰어가 달라져 클린이 나오는 편차는 실재하지만, 그걸 이유로 리뷰 자체를 막으면 고쳐진 작업까지 무한 반려된다. `file:line` 대조 + 소진 근거 기록으로 어느 지적이 왜 사라졌는지 추적 가능하게 남긴다.

> 왜 상태가 아니라 체크박스가 근거인가 — `working_gate_blockers` 는 step 파일에서 **`상태:` 만** 본다(미체크박스 검사는 `is_step=0` 전용). 그래서 step 의 반려 체크박스는 완료 게이트를 전혀 막지 못한다. watch 가 이 축을 보는 유일한 주체다.

> **마커(`tick: allow`)를 요구하지 않는다.** 그 화이트리스트는 `/taskflow:tick` 이 **무인으로 아무 task 나 잡지 않게** 하는 장치다. watch 의 해소는 `ReadyToMerge` 라는 상태 자체가 이미 "개발·verify·review 를 통과해 머지만 남았다" 는 명시 신호이므로 별도 게이트를 겹치지 않는다.

| 축 | 검증 결과 | 동작 |
|----|-----------|------|
| 코드 | 지적 0건 (기존 반려 전건 소진 포함) | **머지 사다리 L1~L3** → step `상태: Done` |
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
| 후보 2개 이상 (모호) | **좁히기 재시도** — worktree diff ↔ 문서 대조(§"코드·문서 판별")로 1개로 줄면 진행. 그래도 2개 이상이면 보고 |
| 후보 0개 | **착지 브랜치 정책으로 생성 후 진행** — 정책에 없는 repo 만 보고 |

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

base 가 확정되면 절차는 `/git:merge` 를 그대로 탄다 (재구현 0). 4개 명령 **개별 Bash 호출**, `&&`/`;` 결합 금지 — 결합하면 `dangerous-ops-guard.sh` 의 `git branch -D wip/…` 면제가 매칭에 실패해 차단된다.

### ff-only 가 깨지면 사다리를 내려간다 — 멈추지 않는다 (필수)

**여러 wip 을 같은 착지 브랜치로 순차 머지하면 두 번째부터 ff-only 가 반드시 깨진다** (첫 머지로 착지가 전진해 두 번째 wip 이 그 후손이 아니게 된다). 예외가 아니라 정상 경로다 — 여기서 멈추면 대기 물량이 영영 안 빠진다.

| 단계 | 조건 | 동작 |
|------|------|------|
| L1 | ff-only 성공 | 완료 |
| L2 | ff-only 실패 + wip 범위에 머지 커밋 0건 | `/git:merge` 범위 cherry-pick (`${BASE}..wip/…`) |
| L3 | ff-only 실패 + 머지 커밋 1건 이상 | **non-merge 커밋만 하나씩 개별 cherry-pick** — 머지 커밋은 브랜치 구조의 산물이라 착지에 재현할 필요가 없고, 섞인 범위는 통째로 안 집힌다 |
| L4 | 위 전부 실패 / 충돌 | `cherry-pick --abort` 후 보고. **상태는 `ReadyToMerge` 유지** |

```bash
BASE=$(git -C "$REPO" merge-base "$LANDING" "wip/$SLUG")
git -C "$REPO" rev-list --merges "${BASE}..wip/$SLUG"              # 비었으면 L2, 아니면 L3
git -C "$REPO" rev-list --no-merges --reverse "${BASE}..wip/$SLUG" # L3 대상 커밋 목록
```

**충돌은 자동 해결하지 않는다.** 즉시 `--abort` 하고 충돌 파일 목록과 함께 보고한다 (`/git:merge` §충돌 시 그대로). 무인 루프가 충돌을 푸는 건 되돌리기 비싼 실수다.

**L4 로 빠져도 `Pending` 반려가 아니다.** 리뷰는 통과했고 정착 방법만 못 찾은 상태이므로 `ReadyToMerge` 를 유지한 채 사용자에게 넘긴다. wip worktree·브랜치도 그대로 보존한다.

머지 후 그 step 파일 `상태: ReadyToMerge → Done` + unified §계획 인덱스 표 상태 컬럼 동기화 + 정착 후 reachable 해시 기록 (`git rev-parse {feature}` — wip 해시를 인용하면 orphan 이 된다).

**task 를 `Done` 으로 올리지는 않는다.** step 머지까지가 watch 의 경계고, 완료 게이트 판정 + task 종결은 `/taskflow:save` 몫이다 (`working_gate_blockers` 0건이면 "완료 가능" 으로 보고만 한다).

### 반려 — Pending 복귀

`상태: ReadyToMerge → Pending` 으로 되돌린다. **`In Progress` 가 아니다** (근거 SSOT = `tick.md` §"결정 수용" — 재잡이 조건이 `Pending` 이다).

그 step 파일 `머지 전 리뷰 포인트` 섹션 아래에 반려 블록을 append 한다 — **본 양식이 tick·watch 공용 SSOT 다** (`working_rejections` 가 `^#+ 반려 [0-9]+회` 블록 안의 `- [ ]` 만 센다. 헤더 레벨은 `##`/`###` 둘 다 실재하므로 `^#+ 머지 전 리뷰 포인트` 로 찾고, 섹션이 없으면 문서 끝에 `## 머지 전 리뷰 포인트` 로 신설):

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

복귀 시 보고에 **그 작업의 cwd** 를 같이 낸다 (REGISTRY entry 의 cwd). **B 트랙은 REGISTRY 를 건드리지 않는다** — 재잡이하는 쪽이 `registry_claim` 으로 새로 점유하면 그만이다.

> **C 트랙 G3 만 예외다.** 거기서는 `active` entry 자체가 `TAKEN` 을 반환해 **재잡이를 영구히 막는** 상태라, 손대지 않으면 아무도 못 잡는다. B 의 `paused`·`none` 은 claim 을 막지 않으므로 그 예외가 필요 없다 (`registry-utils.sh:169`).

**재작업 주체는 마커로 갈린다 — "다음 tick 이 재잡이한다" 고 뭉뚱그려 보고하지 않는다.** watch 는 `tick: allow` 없이도 해소하지만 tick 은 마커 없으면 그 task 를 **영원히 안 잡는다**(`tick.md` §1단계 0 화이트리스트). 실측 보유율 7/26 unified 라 대부분이 여기 걸린다.

```bash
grep -qE '^(tick|무인):[[:space:]]*(allow|허용)' "$UNIFIED" && echo tick || echo user
```

| 마커 | 보고 문구 | 실제 |
|------|----------|------|
| 있음 | `↳ 다음 tick 이 반려 소비 모드로 재작업` | tick 이 worktree 재사용해 지적만 처리 |
| **없음** | `↳ 재작업 필요 (무인 대상 아님 — 사용자 또는 /taskflow:tick {작업명})` | 인자 명시 호출은 마커 면제라 수동 진입은 가능하다 |

**마커를 자동으로 붙이지 않는다.** 무인 허용 범위를 넓히는 건 사용자 결정이다 (§3).

반려된 step 의 wip worktree·커밋은 **그대로 보존한다.** tick 반려 소비 모드가 그 경로를 재사용하므로, `worktree remove`·`branch -D` 는 머지 성공 경로에서만 수행한다.

## C 트랙 — 정체 해소 (1시간 무진행)

**A 도 B 도 못 보는 사각지대를 메운다.** 정체는 아무것도 안 바뀐 상태라 diff(A)에 안 걸리고, `ReadyToMerge` 가 아니라 B 도 안 본다. 그대로 두면 문서가 몇 날이고 방치된다 — 2026-07-29 실측에서 `be-fe-full-qa` step 2건이 **5.8일**, `mod-04-chatconnect-…-hermes` step 이 **25시간** 멈춰 있었다.

```bash
source ~/.claude/hooks/lib/working-scan.sh
working_stalled "${1:-all}"        # 기본 1시간(WORKING_STALL_SEC=3600)
# 출력(9열): 경과분 \t status \t is_step \t claim \t gate \t 처리 \t product \t 작업명 \t 경로
#   처리 = stale(claim 해제) / pending(상태 복귀) / report(보고) / none(손대지 않음)
```

**빈 필드가 없다는 게 계약이다.** `IFS=$'\t' read` 는 탭이 IFS 공백류라 **연속 탭을 하나로 합친다** — 빈 칸 하나가 뒤 필드를 통째로 밀어버린다. 실측에서 `claim_sid` 가 비자 `task` 가 밀려 비었고, 그 빈 값으로 unified 를 조회하니 **전건이 "마커 없음"(G1)으로 오판**됐다. 없는 값은 `-` 로 채운다.

### 왜 멈추는가 — 근본 원인

**`working-release.sh`(Stop hook)는 REGISTRY 만 `paused` 로 풀고 문서의 `상태:` 는 건드리지 않는다.** 세션 종료 시 step 이 `In Progress` 였으면 문서에 그대로 남고, tick 재잡이 조건이 `Pending`(`tick.md` §2-bis)이라 **영영 안 잡힌다** (2026-07-29 실측 — REGISTRY `active` 0건 ↔ 문서 `In Progress` 5건).

**Stop hook 을 고치는 것으로는 부족하다** — crash·kill 이면 Stop 자체가 안 돈다. 해소 주체가 사후 관측자인 watch 여야 하는 이유다.

### 대상에서 빠지는 것 (필수)

판정은 `working_stalled` 가 SSOT 다. 여기 복붙하지 않는다.

- **사용자 판단 대기 = 제외** — 문서 `상태: NeedsDecision` **과** REGISTRY `claim=needs-decision` **두 축 모두**. 상태 축만 보면 실측 2건(문서 `Pending` ↔ claim `needs-decision`)을 정체로 오분류해 건드리게 된다.
- **종결·사용자 마감 = 제외** — `Done`/`완료`/`폐기`/`Abandoned`/`Partial`. step `Done` 은 task 종결을 기다리는 정상 상태지 정체가 아니다.
- **`ReadyToMerge` = 제외** — B 트랙 소관. 여기서도 잡으면 매 iteration 중복 보고된다.

이 제외가 없으면 실측 `Done` 32 + `Partial` 8 + `NeedsDecision` 5 = **45건**이 매번 정체로 잡혀 노이즈가 신호를 덮는다.

### 정체를 나열하지 않는다 — 병목을 특정한다 (핵심)

물어야 할 것은 "1시간 안 움직였다" 가 아니라 **"지금 tick 이 이걸 잡을 수 있나, 없다면 무엇이 막나"** 다. `working_stalled` 가 tick 의 claim 게이트를 **순서대로** 물어 첫 실패 게이트를 낸다 — 순서가 오조작을 막는다 (실측: step 이 `In Progress`(G4 처럼 보임)인데 unified 가 `NeedsDecision` 이라 G2 에서 걸린 건이 있었다. G4 를 먼저 봤으면 결정 대기 중인 task 를 건드릴 뻔했다).

| 게이트 | 막는 것 | 처리 |
|--------|--------|------|
| **G1 마커** | `tick: allow` 없음 → tick 화이트리스트 밖 | `report` — 자동 부착 금지(§3) |
| **G2 사용자** | unified 가 `NeedsDecision`/`Done` → tick 2단계에서 task 통째 skip | `report` + **사전조사 첨부** |
| **G3 claim** | REGISTRY `active` → `registry_claim` 이 `TAKEN` 반환 | 세션 생존 시 `none`(진행 중) / **죽었으면 `stale`** |
| **G4 상태** | step 이 `Pending` 이 아님 → tick 진행 조건 밖 | **`pending` 복귀** |
| **OK** | 아무것도 안 막음 | `none` — **병목 없음. 루프가 안 돌 뿐** |

**`OK` 를 정체로 보고하지 않는 게 중요하다.** 2026-07-29 실측 13건 중 **11건이 OK** 였다 — 병목이 아니라 "도는 tick 이 없다" 는 가동 상태 보고다. 정체로 내면 매 iteration 같은 목록이 반복돼 진짜 병목 2건이 묻힌다.

### G2 — 사용자 결정은 조사해서 넘긴다 (필수)

"사용자 대기" 라고만 적어 넘기지 않는다. CLAUDE.md §4.4 (3-2) escalation ladder 상 **정보 부족형(I1~I3)은 먼저 자체 해소**하고, 못 풀 때만 **조사 결과를 첨부해서** 올린다. 권한형(P1~P4)만 즉시 올린다.

보고에 최소한 이 세 가지를 붙인다 — 사용자가 문서를 열어보지 않고 결정할 수 있어야 한다.

| 붙일 것 | 어디서 |
|---------|--------|
| 무엇을 묻는가 (선택지 + 트레이드오프) | 그 문서 `## 결정 Escalation 로그` |
| 권한형/정보 부족형 분류 | `execute.md` §"결정 escalation ladder" 판별식 |
| 막고 있는 범위 | 그 결정에 걸린 step 수 · 의존 후속 수 |

정보 부족형인데 조사가 안 돼 있으면 **watch 가 그 자리에서 조사한다** (bounded — 파일 읽기·grep 수준. 코드 수정이나 `/taskflow:plan` 재진입은 안 한다). 조사해도 안 풀리면 그 결과를 첨부해 올린다.

> **결정을 대신 내리지 않는다.** 조사는 선택지를 좁히는 데까지고, 고르는 건 사용자다.

### G2 판정은 문서 전체를 본다 — frontmatter 만 믿지 않는다 (필수)

`working_scan` 은 **첫 `Status:`/`상태:` 줄만** 읽는데, frontmatter 와 본문이 어긋난 문서가 실재한다 (2026-07-29 실측 3건). **어느 줄에라도 `NeedsDecision`/`Done` 이 있으면 막는 쪽으로 채택한다** — 첫 줄만 믿으면 결정 대기건을 무인 진행시킨다.

**어느 쪽이 정본인지는 판정하지 않는다.** 형식 추론이고 틀렸을 때 대가가 크다. 정정은 보고만 하고 사람이 한다.

### G3 — `active` orphan (claim 이 영구히 물려 있는 경우)

`registry_claim` 은 **`active` 일 때만** `TAKEN` 을 반환한다(`registry-utils.sh:169`) — `paused`·`ready-to-merge`·`stale` 은 claim 을 안 막으므로 병목으로 세면 안 된다. 문제는 crash·kill 로 Stop hook 이 못 돌아 entry 가 `active` 로 남은 경우다.

```bash
working_session_alive "$CLAIM_SID"    # transcript mtime < WORKING_SESSION_DEAD_SEC(기본 3600)
```

죽었으면 `registry_mark_stale {slug} {sid}` — **lock 보호 lib 함수를 쓴다.** 수동 awk+mv 는 race orphan 을 만든다 (메모리 `feedback_shared-pool-lib-first`).

### G4 — step `In Progress` → `Pending`

원인은 위 §"왜 멈추는가" 그대로다. 새 mutation 종류를 만들지 않는다 — B 트랙 반려가 쓰는 전이와 **같은 것**이고 근거도 같다(`tick.md` §"결정 수용").

```bash
working_rejections "$STEP"     # >0 이면 반려 트랙 소관 — 정체로 다루지 않는다
```

- `### 정체 복귀 (YYYY-MM-DD · watch)` 1줄을 `머지 전 리뷰 포인트` 아래 남긴다 — **체크박스가 아니라 서술로.** `- [ ]` 로 적으면 경량 task 완료 게이트(`미체크박스 잔존`)를 막아버린다.
- unified 인덱스 표 상태 컬럼 동기화 (step 파일이 SSOT, 표는 미러).
- **worktree·커밋 보존.** tick 이 반려 소비 모드처럼 그 경로를 재사용한다.

**연쇄 해소가 이 게이트의 진짜 값이다.** `tick.md` §2-bis 상 직접 의존 선행이 `In Progress` 면 그 step 에 의존하는 **후속 전부가 막힌다.** 죽은 `In Progress` 하나를 되돌리면 체인이 함께 풀린다.

> **인덱스 표 '의존' 컬럼은 파싱하지 않는다.** 선행이 막는 유일한 해소 가능 사유가 "선행이 죽은 `In Progress`" 이고 그건 그 선행 자신이 G4 로 잡히므로, G4 를 고치면 의존 판정 없이도 체인이 풀린다. 형식 편차 큰 표를 파싱하면 파서가 곧 깨진다 — `## 변경 파일` 을 거부한 것과 같은 이유다.

### orphan lock 정리 (게이트 밖 — 매 iteration)

REGISTRY 에 매칭 entry 가 없는 session lock 은 판정이 필요 없다. 세션이 비정상 종료하며 남긴 잔재고, 남겨둘 이유가 없다.

```bash
source ~/.claude/hooks/lib/registry-utils.sh
registry_orphan_locks | while IFS=$'\t' read -r slug sid _; do
  session_lock_remove "$slug" "$sid"
done
```

`/taskflow:ps cleanup` 이 하던 것과 **같은 판정식**이다(`registry_orphan_locks` 가 SSOT). 차이는 ps 가 사용자 명시 호출 전용인 반면 watch 는 무인이라 매번 돈다는 것뿐이다.

> **REGISTRY entry 는 건드리지 않는다.** 여기서 지우는 건 매칭 entry 가 **없는** lock 파일뿐이다. entry 가 있는 lock 은 그 세션 소유다.

### 죽은 `tick: pause` 회수 (게이트 밖 — 매 iteration)

`/taskflow:load {작업명}` 은 그 task 를 직접 처리하는 동안 마커를 `tick: pause (by {sid8}, {날짜})` 로 내리고 `/taskflow:save` 가 `allow` 로 되돌린다. **세션이 crash·kill 로 죽으면 그 복원이 안 돌아** `pause` 가 영구히 남고, 그 task 는 무인 대상에서 영영 이탈한다 — C 트랙이 다루는 "세션이 남긴 거짓 표기" 와 정확히 같은 종류다(G4 의 `In Progress` 잔존과 동형).

```bash
source ~/.claude/hooks/lib/working-scan.sh
# unified 에서 pause 마커 + 그 sid 추출 → 세션 생존 판정
working_session_alive "$PAUSE_SID"    # 죽었으면 tick: allow 로 복원
```

- **죽은 세션의 `pause` 만** 되돌린다. 살아 있으면 그 세션이 지금 처리 중이므로 손대지 않는다.
- `deny`·마커 없음은 대상이 아니다. 복원 목적지는 언제나 `allow` 뿐이다.

> **이건 "마커를 붙이지 않는다" 예외가 아니다.** `pause` 는 정의상 `allow` 에서만 만들어지므로(전이 폐쇄성 = `tick.md` §`pause`), 되돌린 결과는 **사용자가 이미 허용해 둔 값**이다. 새로 무인 대상을 넓히는 게 아니라 중단된 왕복을 완결시키는 것이라 §3 에 걸리지 않는다. 마커가 **없던** 문서에 `allow` 를 붙이는 것은 여전히 금지다.

### 하지 않는 것 (필수)

- **`tick-loop` 을 띄우지 않는다.** `OK` 건의 해법은 루프 기동이지만 그건 무인 작업 프로세스 자율 기동이라 사용자 결정이다(§3). 보고에 "claim 가능 N건 — 루프 미가동" 으로 낸다.
- **마커를 신규로 붙이지 않는다.** 무인 허용 범위 확대 = §3. 죽은 `pause` → `allow` 회수는 예외가 아니다 — 원래 `allow` 였던 값의 복원이라 범위가 넓어지지 않는다.
- **`NeedsDecision` 을 풀지 않는다.** G2 는 판단이 남은 것이지 막힌 게 아니다.

> **왜 상태를 되돌리는 것이 §4.2 "audit 자동 수정 금지" 에 안 걸리는가** — 코드나 판단을 고치는 게 아니라, 세션이 비정상 종료하며 남긴 **거짓 표기**(문서는 진행 중이라는데 아무도 안 잡고 있음)를 사실에 맞추는 것이다. 작업 내용·커밋·worktree 는 그대로고, 다음 주체가 잡을 수 있는 상태가 될 뿐이다.

## mutation 경계 (필수)

watch 의 쓰기는 **딱 세 가지**다. 그 밖은 전부 보고만 한다.

0. 자기 lock (`state/watch/locks/{문서}.lock`) — 쓰기 대상 문서에만, 조치 직전 획득·직후 해제
1. 자기 스냅샷 (`state/watch/{scope}.tsv`)
2. **B 트랙** `ReadyToMerge` 해소 — 머지 사다리(L1~L3) + step `상태:` 전이 (Done / Pending) + 인덱스 표 동기화 + 반려 블록 append **및 리뷰로 확인된 반려 체크박스 소진**(`- [x]` + 근거 1줄 — 리뷰가 실제로 돈 경우만)
3. **C 트랙** 병목 제거 — (a) G4: 죽은 claim 의 step `상태: In Progress → Pending` + 인덱스 표 동기화 + 복귀 사유 1줄 (b) G3-orphan: `registry_mark_stale` 로 죽은 `active` claim 해제(lock 보호 lib 함수만) (c) orphan lock 파일 제거(`session_lock_remove` — REGISTRY 매칭 **없는** 것만) (d) 죽은 세션이 남긴 `tick: pause` → `allow` 회수(`working_session_alive` 로 사망 판정된 sid 것만). **이 넷뿐이다** — 마커 신규 부착·`tick-loop` 기동·머지·`NeedsDecision` 해제·상태 drift 정정은 하지 않는다

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

대표 3블록 (B 통과 · B 반려 · C 병목). 나머지 블록도 같은 `라벨 / 대상 / 판정 → 조치` + `↳ 근거` 형태다.

```
[watch — scope=all]  변경 5건 (문서 4 / repo 1)

✅ 머지 해소 (리뷰 클린)
  auth-refactor / step-01-token       [코드] 리뷰 0건 → ff머지 → Done
                                       feature/auth-refactor 79a79787

🔁 반려 → Pending 복귀
  commerce-audit / step-01-price-calc [코드] 리뷰 2건 (High 1·Low 1) → 머지 보류
                                       ↳ CallService.php:142 N+1 쿼리 · :88 미사용 import
                                       ↳ 재작업 cwd: C:\Works\hongcafe_global_backend

⏳ 병목 제거 (1h+ 무진행 13건 중 2건)
  be-fe-full-qa/step-09                72m · claim active 인데 세션 죽음(G3) → stale 해제
  auth-refactor/step-03                25h In Progress · claim none(G4) → Pending 복귀
                                       ↳ 의존 후속 2건 함께 해소. 다음 tick 이 재잡이

스냅샷 갱신: 84건 (문서 77 / repo 7)
```

나머지 라벨 — `⚠️ 판단 필요(신규 NeedsDecision)` · `📄 문서 정합성` · `🚫 머지 불가(상태 유지)` · `♻️ 반려 소진(리뷰 대조)` · `❓ 확인 필요(문서 실종·미기록 커밋)` · `⏸️ 사용자 결정(§"G2 — 사용자 결정은 조사해서 넘긴다" 3요소 첨부)` · `🧹 orphan lock 정리 N건` · `▫️ 병목 없음 N건(루프 미가동)`.

A·B·C 세 트랙 모두 조용할 때만 `[watch — scope=all] 변동 없음` 1줄. **diff 0건이어도 B 에 미해소 `ReadyToMerge` 가 있거나 C 에 정체가 있으면 "변동 없음" 이 아니다.**

## SSOT

| 조각 | 역할 | SSOT |
|------|------|------|
| **변경 감지** | 스냅샷 diff (A/M/D) — 문서 축 + repo 축 | **`hooks/lib/watch-snapshot.sh`** |
| 신선도 필터 | 5분 이내 수정분 제외 (`WATCH_MIN_AGE_SEC`, 기본 300초) | `hooks/lib/watch-snapshot.sh::watch_scan_now` |
| 감시 repo 목록 | 사용자 소유 목록 (자동 갱신 안 함) | `~/.claude/state/watch/repos.txt` |
| working/ 스캔 + 완료 게이트 | `working_scan` · `working_gate_blockers` · **`working_rejections`**(미해소 반려 수) | `hooks/lib/working-scan.sh` |
| **정체 병목 판정** | `working_stalled` — 1h+ 무진행에 tick claim 게이트(G1~G4/OK) 적용, 첫 실패 게이트 + 처리 산출 (`WORKING_STALL_SEC`, 기본 3600) | **`hooks/lib/working-scan.sh`** |
| 세션 생존 판정 | `working_session_alive` — transcript mtime (`WORKING_SESSION_DEAD_SEC`, 기본 3600) | `hooks/lib/working-scan.sh` |
| **문서 단위 lock** | `watch_doc_lock_acquire`/`_release`/`watch_doc_locked` — 키=문서 경로, TTL stale 회수 (`WATCH_LOCK_TTL_MIN`, 기본 30분) | **`hooks/lib/watch-snapshot.sh`** |
| claim 차단 조건 | `active` 일 때만 `TAKEN` — paused·ready-to-merge 는 안 막음 | `hooks/lib/registry-utils.sh:169` |
| claim 해제 (lock 보호) | `registry_mark_stale` — 수동 awk+mv 금지 | `hooks/lib/registry-utils.sh` + 메모리 `feedback_shared-pool-lib-first` |
| **orphan lock 판정** | `registry_orphan_locks` — REGISTRY 매칭 없는 lock 나열 (`ps cleanup` 과 공용) | **`hooks/lib/registry-utils.sh`** |
| 결정 escalation 분류 | 권한형 P1~P4 / 정보 부족형 I1~I3 판별식 | `custom-plugin/taskflow/commands/execute.md` |
| 정체 원인(문서 상태 미복귀) | Stop 시 REGISTRY 만 paused, 문서 `상태:` 불변 | `hooks/working-release.sh` |
| 세션 관측 | transcript tail 신호 4개 | `hooks/lib/transcript-tail.py` |
| 주기 반복 | `/loop <interval> /taskflow:watch` | harness `/loop` 스킬 |
| **ff머지 절차** | checkout→ff-only→worktree remove→branch -D | **`custom-plugin/git/commands/merge.md`** |
| **문서 양식 검증** | V1~V8 통합 validator (stdin JSON) | **`hooks/doc-unified-check.sh`** |
| 원본 drift | 원본 지문(sha256) 대조 | `custom-plugin/taskflow/commands/draft.md` (`check`) |
| api-docs 정합 | 3-way 미러 검증 | `hongcafe:mirror-be-claude` (`verify`) |
| 코드/문서 파일 판정 | `is_hard_code_file` | `hooks/lib/path-utils.sh` |
| 대기 큐 상세 | NeedsDecision·ReadyToMerge 처리 진입 | `custom-plugin/taskflow/commands/control.md` |
| 상태 라이프사이클 + Pending 복귀 근거 | Pending→In Progress→ReadyToMerge · **반려 소비 모드**(worktree 재사용) | `custom-plugin/taskflow/commands/tick.md` (§2-bis 2 · §"step 상태 라이프사이클") |
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

- 2026-08-03: **681 → 601줄 감축 + SSOT 2건 이관.** `## cwd 에 국한되지 않는다` = 무인 계열 공통 cwd 규약 SSOT 로 **선언**(tick 은 포인터), `## 카탈로그 미등재 fallback` 은 반대로 **내보냄**(slash·agent 공통 — 2026-08-04 tick-team 폐기로 `tick.md` 로 재이관). 중복 제거 = worktree 판별 awk 2벌→1벌 / "보유율 0/20" 3회→1회 / 반려 블록 예시 2곳→1곳(양식 SSOT = 본 파일) / 출력 예 53줄→대표 3블록. 판정 표·계약은 전건 보존, 삭감분은 Why 산문뿐. `### D2 순서` 를 헤딩으로 승격(포인터 해결용)
- 2026-07-31: 리뷰어를 **`cold-reviewer` 전용 agent 정의로 수렴** — 리뷰 관점·판정축·반환 양식·수정 불가(Edit/Write 부재)가 정의에 박히고, 본체가 조립하는 것은 diff+DoD 뿐. 매 spawn 프롬프트 재조립이 곧 리뷰 편차라는 §"재확인" 문단의 원인을 제거
- 2026-07-30: §"코드 축 — 변경분 리뷰" 를 **무인 코드리뷰 계약 SSOT** 로 명시 (tick 리뷰 루프가 같은 계약을 포인터 참조). B 트랙 동작 무변경 — tick 이 클린을 만든 뒤의 **재확인** 성격만 명문화
- 2026-07-29: 죽은 `tick: pause` → `allow` 회수 (C 트랙 게이트 밖). mutation 경계 3→4개
- 2026-07-29: B 트랙 = 리뷰 선행 + 머지 사다리 (L1 ff-only → L2 범위 cherry-pick → L3 non-merge 개별 → L4 보고). **선행 필터(반려 있으면 리뷰 skip) 철회**
- 2026-07-29: G2 사전조사 첨부 + Status drift 보수 채택(어느 줄에라도 `NeedsDecision`/`Done` 이면 막는 쪽) + orphan lock 매 iteration 제거
- 2026-07-29: 문서 단위 lock (`state/watch/locks/`). **인스턴스 통째 직렬화 철회** — 다른 문서를 보는 watch 까지 막혔다
- 2026-07-29: `watch-snapshot.sh` lib 로드 판정을 변수 존재 → 함수 존재(`declare -F`)로 수정
- 2026-07-29: C 트랙 신설 — 1h+ 무진행에 tick claim 게이트(G1~G4/OK) 적용해 첫 실패 게이트만 제거. 나열식 보고는 채택 안 함(실측 13건 중 11건이 OK 라 진짜 병목이 묻힌다)
- 2026-07-28: 신선도 필터 5분 (`WATCH_MIN_AGE_SEC`). `find -mmin` 절단 대신 값 유지 방식
- 2026-07-28: 반려 왕복 정합 — 반려 보고를 `tick: allow` 마커로 분기, 반려 step 의 worktree·커밋 보존
- 2026-07-28: repo별 착지 브랜치 정책 + cwd 비종속 (`git -C` 만, `cd` 금지)
- 2026-07-28: 해소를 독립 B 트랙으로 분리. **A 하위 단계 배치 철회** — `ReadyToMerge` 가 스냅샷에 박혀 있어 머지 대상이 영구 0건이 됐다
- 2026-07-28: 축별 검증(코드=리뷰 / 문서=정합성) + `ReadyToMerge` 자동 해소. read-only 계약 해제
- 2026-07-27: 신설 — 스냅샷 diff 기반 변경분 검증 + sessions 관측 모드
