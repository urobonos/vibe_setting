---
description: 작업 저장 — worktree 정착 + working/ 문서 마무리 + 잔여 판정 후 working/ 기록(Partial) 또는 tasks/ 이동(Done) + DISPATCH 태그 정리 + **즉시 이동 모드(구 done 흡수, 2026-07-16)**. 짝 슬래시 = `/taskflow:load`
allowed-tools: Bash, Edit, Read, Glob, Grep, PowerShell
argument-hint: "[작업명|now]  # 생략=전체 저장(판정 동반) / now=즉시 이동(판정 생략, 구 done 흡수)"
---

세션 종료 직전 호출하는 통합 저장 슬래시. `save now` (단순 이동) 과 `/taskflow:auto` (실행 모드 진입) 의 중간 — **세션 마감 저장** 역할. 짝 슬래시 = **`/taskflow:load`** (다음 세션 시작 시 잔존 작업 불러오기). **+ 본 세션이 `/taskflow:load #tag` 로 claim 한 DISPATCH 태그 작업도 working 문서 Done/Partial 판정에 연동해 함께 정리** (완료 → `dispatch_done` / 이어감 → claimed 유지 / 포기 → `dispatch_release`).

## 동작 4단계

| 단계 | 동작 | 결과 |
|------|------|------|
| ① worktree 정착 | `git worktree list` 스캔 → `~/.claude/worktrees/` 존재 시 정착 여부 승인 요청 | 승인 후 Claude 직접 실행 (`/git:create`·`/git:merge`) |
| ② working/ 문서 마무리 | working/ 스캔 → 각 파일 잔여 작업 판정 | Status 결정 (Done / Partial) |
| ③ 잔여 작업 기록 / 이동 | 잔여 0건 = `Status: Done` 부착 → tasks/ 이동 (미이동 시 `save now`) / 잔여 ≥ 1 건 = `Status: Partial` + `## 잔여 작업` 섹션 추가 → working/ 유지 (다음 세션 `/taskflow:load` 진입점) | 분기 처리 |
| ④ 분배 태그 정리 | 본 세션 sid 가 claim 한 DISPATCH 태그 조회 → 완료판정 연동 (완료 `dispatch_done` / 이어감 claimed 유지 / 포기 `dispatch_release`) | 분배 풀 정합 |

## 호출 방식

| 인자 | 동작 |
|------|------|
| 인자 없음 (`/taskflow:save`) | worktree 전체 스캔 + working/ 전체 일괄 저장 |
| `{작업명}` (`/taskflow:save auth-refactor`) | 파일명 매칭 → 특정 작업만 저장 |

## ① worktree 정착

진입 즉시 다음 확인:

```bash
git worktree list 2>/dev/null
```

`~/.claude/worktrees/{session_id}-{slug}` 패턴 worktree 존재 시 → **정착 여부를 사용자에게 승인 요청** (§3 비가역). 승인 후 진입점 분기:

| 상황 | 진입점 |
|------|-------|
| 신규 feature 분기 생성 | `/git:create` |
| 기존 feature 분기 머지 | `/git:merge` |

**실행 주체 = Claude 본체 자동** (2026-06-04~, CLAUDE.md §4.3 (f)). 승인 게이트는 "정착할 것인가"에만 걸리고, 명령 실행은 Claude 가 직접 수행한다. **절차 본문(명령 순서 / 개별 Bash 호출 강제 / ff-only 실패 시 cherry-pick fallback) = `/git:create`·`/git:merge` SSOT** — 본 슬래시는 재기술하지 않는다.

**제약:**
- source = `main` / `master` 시 정착 절대 금지 — `branch-enforce.sh` §(1.5)(1.6) 차단. PR 생성 안내로 대체.
- 정착 명령은 `&&`/`;` 결합 금지 (`git branch -D wip/…` 면제가 단일 라인만 매칭).
- 정착 후 `git push` 는 사용자 직접 (§4.3 (d) — Claude 자동 push 전면 금지).
- worktree 없으면 본 단계 SKIP.

## ② working/ 문서 마무리

`~/.claude/docs/working/YYYYMMDD/` 스캔. 인자 매칭 시 해당 파일만.

각 파일에 대해:

1. **Self-Critique 섹션 확인** — 미존재 시 Claude 본체가 직접 작성 (template 보강)
2. **잔여 작업 판정** — 다음 신호 종합:
   - 본문 미체크 박스 (`- [ ]`) 개수
   - 사용자 명시 잔여 (인자 또는 직전 응답 후속 권고 잔여)
   - `## TODO` / `## 잔여` / `## Follow-up` 섹션 존재 + 비어있지 않음
   - Self-Critique 항목 중 FAIL/WARN 미해결

## ③ 잔여 작업 기록 / 이동

> **먼저 step ReadyToMerge / NeedsDecision 확인 (분기 C 우선):** task 의 step 파일에 `Status: ReadyToMerge`(=`/taskflow:tick` 이 올린 머지 준비 step)가 있거나 unified 가 `Status: NeedsDecision` 이면 분기 A(Done) 직행 금지 — 아래 **분기 C**(step 개별 머지 + 완료 게이트)로 처리한다. `NeedsDecision` 은 **Partial 로 덮지 말고 보존**(사용자 결정 대기, tick 이 결정 후 `In Progress` 복귀로 재개). **ReadyToMerge 는 step 단위 "머지 준비"이지 task "완료대기"가 아니다.**

### 분기 A — 잔여 0건

```markdown
Status: Done
```

(시작 라인) 부착 + `## Self-Critique` 보강 → `working-lifecycle.sh` PostToolUse hook 발동 → `~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-unified.md` 이동.

> **코드 변경 동반 시 verify+review 필수 (2026-07-14):** 마감 대상 작업이 **코드 파일(php/js/ts/py/sql)** 을 변경했다면 `Status: Done` 부착 **전** `/taskflow:verify`(e2e 5점)·`/taskflow:review` 체인 완료를 확인한다 (CLAUDE.md §4.3 "코드 라이프사이클 게이트", `execute.md:112-117` 동일 문구). 미완료 시 verify+review 먼저 수행 후 Done 판정 — QA-after 규율이 `/taskflow:save` 의 Done 경로로 우회되지 않도록. 코드 변경 없는 문서·분석 작업은 비대상.

> **이동 확인 필수 (2026-07-09):** PostToolUse hook 자동 트리거가 미작동한 실측 사례가 있다 (memory `backlog_backlog-lifecycle-posttooluse-nomove` — 수동 호출은 정상). `Status: Done` 부착 직후 **working/ 에 파일이 잔류하는지 확인**하고, 잔류 시 `save now` 로 명시 이동한다. 잔류 방치 = 다음 세션 `/taskflow:load` 노이즈 + REGISTRY orphan 누적.

### 분기 B — 잔여 ≥ 1건 (`/taskflow:load` 진입점)

```markdown
Status: Partial
```

(시작 라인) + 본문 끝에 `## 잔여 작업` 섹션 자동 부착:

```markdown
## 잔여 작업

- [ ] {잔여 항목 1} — 사유 / 다음 단계 1줄
- [ ] {잔여 항목 2} — 사유 / 다음 단계 1줄
...

**다음 세션 진입점:**
- `/taskflow:load` — 본 잔존 작업 자동 식별 + 재진입 안내
- `/taskflow:load {작업명}` — 본 작업만 불러오기
- `/taskflow:auto {요약}` — 잔여 일괄 처리 (`/taskflow:load` 후 결정)
```

→ working/ 원본 유지 (이동 SKIP). 다음 세션에서 `/taskflow:load` 호출 → 잔여 항목 본문 표시 → 처리 후 다시 `/taskflow:save` 시 잔여 0건이면 자동 이동.

### 분기 C — step ReadyToMerge → step 개별 머지 + 완료 게이트 (`/taskflow:tick` 산출)

`/taskflow:tick` 이 무인으로 각 step 을 `Status: ReadyToMerge`(머지 준비)로 올려둔 task. **task 자체엔 ReadyToMerge Status 가 없다** — ReadyToMerge 는 step 단위다. 완료(Done)는 2단계:

**① step 개별 머지 (사용자 승인)**
- 각 step 파일 `## 머지 전 리뷰 포인트` 확인 후, `ReadyToMerge` step 을 feature 에 **개별 머지**. worktree = task 1개, **step별 커밋 단위**로 순차 머지 (`/git:merge`). 머지한 step 파일 `Status: ReadyToMerge` → `Status: Done`.
- source = main/master 정착 금지 (PR 대체) · 정착 후 `git push` = 사용자 직접 (§4.3 (d)).

**② 완료 게이트 (Done 이동 전 필수 검증)**

```bash
source ~/.claude/hooks/lib/working-scan.sh
working_gate_blockers "{product}" "{작업명}"
```

- **출력(미해결)이 1줄이라도 있으면 `Done` 차단** — 미처리 step(인덱스 `Pending`/`In Progress`) · `NeedsDecision` · 미체크박스 `- [ ]` · `## 잔여` 섹션 · verify/review FAIL. 목록 제시 후 해소 요청.
- blocker **0 줄** → unified `Status: Done` 부착 → `working-lifecycle.sh` tasks/ 이동 + 전파(history·summary·인덱스·REGISTRY·step 분배).

> **ReadyToMerge 는 "완료대기"가 아니다** (step 머지 준비). task 완료는 **완료 게이트가 판정** — 잔여·미해결이 하나라도 있으면 넘어가지 않는다. tick 은 step 을 ReadyToMerge 로 올리는 데까지만 하고, 머지·게이트·Done 은 본 분기(사용자)가 담당한다.

### 즉시 이동 모드 (`save now` — 구 done 흡수, 2026-07-16)

`now` 인자 = 잔여 판정·Self-Critique 보강을 **생략하고 working/ → tasks/ 즉시 이동** (구 `/taskflow:done`). 긴급 정리·다중 파일 일괄 이동용. `working-lifecycle.sh` 를 done.md 와 동일한 UserPromptSubmit 경로로 직접 호출 → 이동 + **DISPATCH done 문서 일괄 정리**(`dispatch_purge_done`)까지 포함:

```bash
# 인자 없음 — 전체 일괄 즉시 이동 (판정 생략)
bash ~/.claude/hooks/working-lifecycle.sh <<< '{"hook_event_name":"UserPromptSubmit","prompt":"/taskflow:done"}'
# 특정 작업만
bash ~/.claude/hooks/working-lifecycle.sh <<< '{"hook_event_name":"UserPromptSubmit","prompt":"/taskflow:done {작업명}"}'
```

> **`save` (판정) vs `save now` (즉시):** 기본 `save` = 잔여 판정 → Done/Partial 분기 (분기 A/B 위). `save now` = 판정 없이 강제 이동 (Status 무관, 긴급). 자연어 `작업 완료`·`tasks 이동`·`done` 키워드도 `working-lifecycle.sh` UserPromptSubmit 경로가 직접 처리 (부정문 가드·확인 스텝 = hook 내장).

### REGISTRY 갱신 (2026-05-15 신설)

본 슬래시 ② working/ 문서 마무리 직후 `~/.claude/docs/working/REGISTRY.md` 갱신:

| 분기 | REGISTRY 처리 | 갱신 주체 |
|------|--------------|----------|
| 분기 A (Done) | entry 자동 제거 + state/sessions/{slug}/ lock 제거 | `working-lifecycle.sh` 가 mv 직후 자동 호출 (별도 액션 불필요) |
| 분기 B (Partial) | entry status=paused 명시 갱신 | `source ~/.claude/hooks/lib/registry-utils.sh && registry_update {slug} {sid} paused` 명시 호출 |

**충돌 정책:** 본 세션 외 다른 세션이 동일 slug 점유 (active) 중일 시 status=paused 갱신은 본 세션 sid entry 만 영향 — 다른 세션 active entry 는 보존.

## ④ 분배 태그 정리 (DISPATCH, 2026-06-15 신설)

② working/ 문서 Done/Partial 판정과 **대칭**으로, 본 세션이 `/taskflow:load #tag` 로 claim 한 DISPATCH 태그를 세션 마감 시 정리한다. **본 세션 claim 분만 대상** — 분배만 하고 미claim된 `available` 태그는 비대상 (풀 유지, 타 세션용). 타 세션이 claim 한 태그는 건드리지 않는다.

### 본 세션 claim 태그 식별 (sid 기반)

```bash
source ~/.claude/hooks/lib/dispatch-utils.sh
# 본 세션 sid — REGISTRY 갱신과 동일 체계 (환경 미노출 시 Claude 본체 기입)
SID8="${CLAUDE_SESSION_ID:0:8}"
[ -z "$SID8" ] && SID8="<현재 세션 sid 8자 — Claude 본체 기입>"

# 본 세션 claim 태그 = claimed_by == SID8 (claimed_by 는 표 6번째 컬럼)
dispatch_list claimed | awk -F"$DISPATCH_FS" -v s="$SID8" '
  $2!="tag" && $2!="" && $6==s { printf "%s\t%s\n", $2, $9 }
'
# (보강) lock 파일 교차 확인 — state/dispatch/{tag}/{SID8}.lock 보유분
for d in ~/.claude/state/dispatch/*/; do
  [ -f "$d$SID8.lock" ] && basename "$d"
done
```

### 태그별 완료 판정 → 동작

각 본 세션 claim 태그에 대해 — 연결된 working 통합 문서의 Done/Partial 또는 분배 문서 DoD 체크박스로 완료 판정:

| 판정 | 동작 | 명령 |
|------|------|------|
| **완료** (working Done / DoD 전부 `[x]`) | status=done + lock 정리 | `dispatch_done "{tag}" "$SID8"` |
| **이어감** (working Partial / 잔여 ≥1) | claimed 유지 (다음 세션 `/taskflow:load #tag` 으로 재개) | (mutation 없음 — 유지) |
| **명시 포기** (이 세션 더 안 함, 타 세션 이양) | available 복귀 | `dispatch_release "{tag}" "$SID8"` |

> **세션 완전 종료 일괄 release (2026-06-15):** 이어갈 태그 없이 세션을 마칠 때는 본 세션 claim 전체를 한 번에 풀 수 있다 — `dispatch_release_session "$SID8"` (claim 태그 전부 `available` + dispatch lock 제거) + `registry_release_session "$SID8" paused` (REGISTRY entry + session lock). **Stop hook (`working-release.sh`) 이 세션 종료 시 동일 동작을 자동 수행**하므로, 슬래시 없이 종료해도 orphan claim/lock 은 남지 않는다 (본 ④ = 명시 정리 진입점, Stop = 안전망).

**안전장치 (필수):** **완료 판정이 명확한 태그만 자동 `dispatch_done`.** 모호하거나 외부 게이트 대기 (예: `claimed` 인데 DoD 미충족·SES/DB 등 외부 차단) 는 자동 done 금지 — 목록 제시 후 사용자 확인. 미완료를 done 처리하면 종결 신호가 거짓이 되어 추적성이 손상된다.

### 보고

```
[Claude] ④ 분배 태그 정리 (본 세션 claim N건):
  - #auth-jwt    → done (working Done 연동)
  - #auth-routes → claimed 유지 (working Partial, 다음 세션 이어감)
  - #auth-test   → [확인 필요] DoD 미충족 — 자동 done 보류
```

## 터미널 제목 원복 (세션 마감)

세션 마감이므로 진행 중 설정됐던 `#{작업명}` 터미널 제목을 현재 폴더명으로 리셋한다 — PowerShell 도구로 `$Host.UI.RawUI.WindowTitle = (Split-Path -Leaf $PWD)` 실행. 방식·전제 = `custom-plugin/taskflow/commands/load.md` §"터미널 제목 설정 (SSOT, claim.md 이전 2026-07-16)". 비-Windows·실패 시 무시.

## §3 Checkpoint 우선 적용

- worktree 정착 = 비가역 (`git merge` / `git worktree remove` / `git branch -D`) → **정착 여부에 사용자 명시 승인 필수.** 승인 후 실행 주체는 Claude 자동 (§4.3 (f)) — 승인 게이트와 실행 주체는 별개다.
- working/ 문서 Status 변경 + 잔여 작업 섹션 추가 = Edit 도구 사용, `~/.claude/docs/working/` 경로는 Gate-0 면제.
- master/main 머지 절대 금지 룰 우선 — source 가 main/master 시 정착 자체 생략, PR 안내 대체.
- 정착 후 `git push` = 사용자 직접 (§4.3 (d)). Claude 자동 push 는 어떤 분기에서도 금지.
- **분배 태그 정리 (`dispatch_done`/`dispatch_release`) = DISPATCH.md + lock mutation.** 회복 가능(`dispatch_add` 재등록)이나 타 세션 가시 상태 변경 → **완료 판정 명확분만 자동, 모호분은 사용자 확인.** done/release 모두 **claim 본인 sid 만** 정상 동작 — 타 세션 claim 태그는 건드리지 않는다.

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/CLAUDE.md` §File Paths "working/ 단일 통합 문서" + §4.3 "branch·worktree·push·머지 통합 정책" | 정책 SSOT |
| `~/.claude/hooks/working-lifecycle.sh` | Status: Done 자동 이동 본체 |
| **`~/.claude/hooks/lib/dispatch-utils.sh`** | **본 세션 claim DISPATCH 태그 정리 (`dispatch_done`/`dispatch_release`/`dispatch_list claimed`) — ④ 단계** |
| **`~/.claude/custom-plugin/git/commands/{create,merge}.md`** | **① 정착 절차 정본 — 명령 순서 / 개별 Bash 호출 강제 / ff-only 실패 시 cherry-pick fallback / Claude 자동 실행 (2026-06-04~)** |
| `~/.claude/hooks/branch-enforce.sh` | push (§1) + master/main merge·checkout·switch (§1.5) + master/main HEAD cherry-pick (§1.6) 차단. **`worktree remove`·`branch -D` 는 본 hook 비대상** (`branch -D wip/*` 단독은 `git-guard.py` 면제) |
| `~/.claude/skills/task-docs/references/unified-template.md` | 양식 SSOT (잔여 작업 섹션 포함) |
| `~/.claude/hooks/working-lifecycle.sh` (즉시 이동) | `save now` = 구 `/taskflow:done` 흡수 (판정 생략 강제 이동 + dispatch_purge_done), 2026-07-16 |
| `~/.claude/custom-plugin/taskflow/commands/auto.md` | 자동진행 맥락의 ① 정착 진입점 요약 (절차 본문은 위 `git/commands/{create,merge}.md` 정본) |
| **`~/.claude/custom-plugin/taskflow/commands/load.md`** | **짝 슬래시 — Status: Partial 잔존 작업 불러오기 (다음 세션 진입점)** |
| `~/.claude/custom-plugin/taskflow/commands/save.md` (본 파일) | 세션 마감 통합 저장 — worktree + 문서 + 잔여 동시 처리 |
| **REGISTRY 갱신 책임 (audit M13 명문 2026-05-20)** | **쓰기 — entry add / Status: Partial 보관 / Status: Done 시 working-lifecycle hook 가 entry 제거** |

## 호출 예

```
/taskflow:save                            ← 전체 (worktree 스캔 + working/ 전체)
/taskflow:save auth-refactor              ← 특정 작업만
```

세션 마감 흐름 예시:

```
[사용자] /taskflow:save
   ↓
[Claude] ① worktree 스캔 → 1건 발견: 631cd229-auth-refactor (source = production)
           → "정착할까요?" 승인 요청 → 승인 시 /git:create 절차를 Claude 가 직접 실행
             (source 체크아웃 → feature 생성 → ff-only 머지 → worktree remove → wip 삭제)
        ② working/ 스캔 → 2건 발견:
           - 2026-05-14-hongcafe_global_backend-auth-refactor.md → 잔여 0건
           - 2026-05-14-claude-harness-hook-cleanup.md → 잔여 3건 (미체크 박스)
        ③ 처리:
           - auth-refactor → Status: Done 부착 → tasks/ 이동 (미이동 시 save now 명시 호출)
           - hook-cleanup → Status: Partial + ## 잔여 작업 섹션 추가 → working/ 유지
        ④ 분배 태그 정리:
           - 본 세션 claim 태그 조회 (sid 기반) → 해당 0건이면 SKIP

        보고:
           - 정착 1건 (승인 대기) / 이동 1건 / 잔여 보관 1건
           - 분배 태그 정리: 본 세션 claim 0건 (해당 없음)
           - 다음 세션 진입: /taskflow:load · 정착 후 push 는 사용자 직접
```

## 차별점 (다른 슬래시와)

| 슬래시 | 시점 | 범위 |
|--------|------|------|
| `/taskflow:auto` | 작업 시작·중간 | 묶음 승인 모드 진입 (실행) |
| `save now` | 작업 완료 직후 | working/ → tasks/ 단순 이동 (분기 A 만) |
| **`/taskflow:save`** | **세션 마감 직전** | **worktree + 문서 + 잔여 + 본 세션 claim 분배 태그 정리 (분기 A + B + worktree + DISPATCH ④)** |
| **`/taskflow:load`** | **다음 세션 시작 직후** | **Status: Partial 잔존 작업 식별 + 재진입 안내** |

## Changelog

- 2026-05-14: 신설
- 2026-06-15: 분배 정리
- 2026-07-09: 정착 주체 정정
