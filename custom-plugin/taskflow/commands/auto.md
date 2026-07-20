---
description: 묶음 승인 모드 진입 — 잔여 액션 또는 인자 작업 전체 자동 진행 + 외부 참조 문서 존재 시 QA 게이트(/taskflow:execute §QA 재사용 — 변경분↔외부문서 단일 subagent, fail-closed, sentinel 부착 직전) (CLAUDE.md §4 자동 위임 정책 명시 진입점)
allowed-tools: Bash, Edit, Write, MultiEdit, Read, Glob, Grep, Skill, Agent, Task, WebFetch, WebSearch, PowerShell
argument-hint: "[작업 내용 — 선택]"
---

자동 진행

## 인자

- `$ARGUMENTS` = (선택) 자동 진행할 작업 내용

## 동작

### 인자 비어있음 (`/taskflow:auto`)
- 현재 세션의 **잔여 액션 전체 자동 진행**.
- 대상 = 직전 응답의 후속 권고 / self-critique 미해결 항목 / 사용자 결정 보류 영역 / 작업 미완료 task.
- 직전 응답이 Echo-Back Confirm 펜딩 상태이면 = 그 작업의 진행 승인으로 해석.

### 인자 있음 (`/taskflow:auto {내용}`)
- `{내용}` = 작업 범위. 해당 작업을 묶음 승인 모드로 끝까지 자동 진행.
- 진입 즉시 Echo-Back Confirm 1회 의도 정리 생략 (본 slash 자체가 명시 묶음 승인 신호).

## 직병렬 실행 지침

**원칙:** 할당된 하위 태스크는 의존성을 먼저 판단 → 독립 태스크는 단일 응답 내 병렬(multi tool_use / Agent spawn), 의존 태스크는 직렬. 동일 파일 mutation·순서 의존 시 직렬 fallback (race 방지). 강제 병렬 modifier = `/taskflow:parallel`.

| 태스크 | 직렬·병렬 | 방법 |
|--------|----------|-----|
| 다모듈·다파일 독립 작업 | **조건부 병렬** | `/taskflow:parallel /taskflow:auto` 결합 시 Agent 동시 spawn (race 가드 적용) |
| Backlog 토론 위임 | **본질적 병렬** | `/taskflow:debate` 16 Agent 풀-병렬 (§"Backlog 토론 spawn 정책" 참조, 1회 cap) |
| worktree 생성 → 코드 변경 → self-critique → QA 게이트(외부문서 시) → **verify+review(코드 변경 시 필수)** → 정착 | **직렬 필수** | 순서 강제 (§worktree-first 정책 / §"QA 게이트" / §정착 절차). QA=단일 subagent. verify+review 필수화 = `execute.md` §"코드 변경 = verify+review 필수 체인" SSOT (코드 시 `[AUTO-ITERATE-DONE]` 전 필수) |
| 결정 요구 발생 → 분류 → (정보 부족형) analyze → plan bounded 재진입 → 실행 복귀 | **직렬 필수** | 흐름 중단 지점에서 삽입. 권한형·판정 불확실 = 즉시 `[AUTO-ITERATE-USER-DECISION]` (ladder 미진입). 절차 = `execute.md` §"결정 escalation ladder" SSOT |

## worktree-first 정책 (필수, 2026-05-20 재정의)

본 slash 진입 시 Claude 본체는 **항상 worktree 생성 후 작업한다**. cwd 영역 무관 — `~/.claude/` 영역 (claude-harness) 포함 모든 영역 적용. 구 (2026-05-13) "cwd 분기 판단" 폐기.

> **터미널 제목 설정 (진입 직후):** worktree SLUG(작업명) 확정 후 PowerShell 도구로 `$Host.UI.RawUI.WindowTitle = "#{작업명}"` 실행 (예: `#commerce-price-audit`). 방식·전제·OS·실패 처리 = `custom-plugin/taskflow/commands/load.md` §"터미널 제목 설정 (SSOT)".

### worktree 적용 절차 (Claude 본체 책임)

진입 직후 다음 절차로 worktree 생성:

```bash
# 1) 원본 repo 정보 확보
SOURCE_BRANCH=$(git rev-parse --abbrev-ref HEAD)          # 예: production / vibe_setting
SLUG="{작업명 kebab-case}"                                  # 예: api-impact-analysis
SESSION_ID="{현재 세션 ID 앞 8자}"                            # 예: 631cd229
WORKTREE_PATH="$HOME/.claude/worktrees/${SESSION_ID}-${SLUG}"
WIP_BRANCH="wip/${SESSION_ID}-${SLUG}"

# 2) worktree + wip 분기 생성 (원본 repo 에서)
git worktree add "$WORKTREE_PATH" -b "$WIP_BRANCH"

# 3) worktree 안에서 작업 수행 (self-critique 루프 포함)
#    - Edit/Write/MultiEdit 으로 코드 변경
#    - git add + git commit 으로 wip/* 분기에 진행 누적
#    - 매 단계 완료 후 산출물·hook 결과·실행 출력 self-critique
```

**hook 강제:** `worktree-enforce.sh` PreToolUse 가 cwd 또는 FILE_PATH ∉ worktree 시 exit 2. functional exemption (CLAUDE.md §4.3 (c) 목록 — 건수는 SSOT 참조, 본문 하드코딩 금지) 만 통과.

### 정착 절차 (sentinel `[AUTO-ITERATE-DONE]` 부착 직전)

self-critique(+QA) 통과 후 **사용자 명시 결정**으로 진입점 분기:
- 신규 feature 정착 = `/git:create`
- 기존 feature 머지 = `/git:merge`

**실행 주체 = Claude 본체 자동** (2026-06-04~, CLAUDE.md §4.3 (f)). 사용자 승인은 "정착할 것인가" 결정에만 필요하고, 승인 후 명령 실행은 Claude 가 직접 수행한다 — `! ` prefix 안내로 사용자에게 떠넘기지 않는다 (§4.2 실행 책임).

**절차 본문 = `/git:create` · `/git:merge` SSOT** (명령 순서 / 개별 Bash 호출 강제 / ff-only 실패 시 cherry-pick fallback). 본 섹션에 재기술하지 않는다 — SSOT 분기 방지.

**제약:**
- **source = main / master 면 정착 절대 금지** — `branch-enforce.sh` §(1.5) 가 checkout/switch/merge 를, §(1.6) 이 master/main HEAD cherry-pick 을 차단. PR 절차로 대체.
- **정착 명령 결합 금지** — `dangerous-ops-guard.sh` 의 `git branch -D wip/…` 면제는 **단일 라인만** 매칭한다 (`git-guard.py`). `&&`/`;` 결합 시 면제 실패 → 차단. 각 명령을 개별 Bash 호출로.
- **정착 후 `git push` = 사용자 직접.** 어떤 분기·옵션에서도 Claude 자동 push 금지 (§4.3 (d)).

## 4축 자동화 (CLAUDE.md §4 자동 위임 정책 정합)

본 slash 호출 시 `gate-approve.sh` 가 본문 "자동 진행" 키워드를 매칭해 `/tmp/claude_gate_${SESSION_ID}` = 2 + mtime 갱신. 이후 60분 동안 다음 자동화가 활성:

1. **후속 권고 자동 채택** — 옵션 분기 시 기본 옵션(가장 안전한 첫 번째) 즉시 채택.
2. **self-critique 루프 (Claude 본체 책임)** — 산출물·코드·실행 결과 직접 검증, FAIL/WARN 0건일 때까지 반복 (최대 5회). **통과 후 코드 변경 + 외부 참조 문서 존재 시 QA 게이트(아래 §"QA 게이트") 진입(없으면 skip).**
3. **종료 sentinel 자동 부착** — 작업 완료 후 응답 마지막에 `[AUTO-ITERATE-DONE]` (잔여 0건) 또는 `[AUTO-ITERATE-USER-DECISION]` (사용자 결정 영역 잔여) 부착. **QA 활성 시 = QA PASS/skip 후에만 `[AUTO-ITERATE-DONE]` 부착 (게이트 불변식).** **`[AUTO-ITERATE-USER-DECISION]` 은 결정 escalation ladder 통과 후에만 부착한다** — 분류가 정보 부족형(I1~I3)이면 bounded `/taskflow:analyze` → `/taskflow:plan` 재진입으로 자체 해소를 먼저 시도하고, 권한형(P1~P4)·판정 불확실일 때만 즉시 부착. 절차·판별식 = `execute.md` §"결정 escalation ladder" SSOT (본 섹션 재기술 금지).
4. **Stop 자동 차단 + 재진입** — 작업 미완료 + sentinel 미부착 시 `auto-iterate-stop-guard.sh` 가 차단해 자동 재진입.

> **4축 ↔ §4.4 매핑 보존:** 위 4축 = CLAUDE.md §4.4 (3) (a~d) 동일 구조 (L 용어 매핑). QA 게이트와 **결정 escalation ladder** 는 4축 **밖** 별도 단계 (#2 통과 ↔ #3 부착 사이 삽입, CLAUDE.md §4.4 (3-2)) — 4축 번호 구조를 깨지 않는다.

## QA 게이트 (sentinel 부착 직전, 조건부)

`/taskflow:auto` 이 코드 변경을 수행하고 **외부 참조 문서(기획·제안·`~/.claude/docs/참조문서/*`)가 존재**하면, self-critique 루프(4축 #2) 통과 후 **sentinel `[AUTO-ITERATE-DONE]` 부착 전**에 변경분 ↔ 외부 문서를 단일 subagent 가 대조한다. 외부 문서 없으면 skip(자기 §계획만 = self-critique+DoD 가 커버). **절차 본체 = `/taskflow:execute` §"QA 게이트" SSOT** (활성화 조건 / 단일 subagent 1 pass / untracked 포함 입력 / fail-closed 판정 / known-limitations 동일 재사용). 본 섹션은 자동진행 맥락 차이만 명시한다.

### 자동진행 맥락 차이

| 항목 | `/taskflow:execute` | `/taskflow:auto` |
|------|--------|------------|
| 완료 신호 (게이트) | `Status: Done` 최후 write | **sentinel `[AUTO-ITERATE-DONE]` 최후 부착** — QA PASS/skip 후에만 |
| QA 입력 | `git diff`(미커밋) + untracked | 위 + `git diff {merge-base}..HEAD`(worktree-first 루프 누적 커밋) |
| FAIL 처리 | §실행 재진입(파일 직접 수정) | self-critique 루프(4축 #2) 재진입 fix (5회 한도 **공유** — known-limitation: QA green 전 조기 종료 가능, USER-DECISION 안전 종료) |

```bash
# 자동진행 QA 입력 — 재진입 세션은 셸 변수 비영속 → SOURCE/WIP 재도출 후 BASE 계산
WIP=$(git rev-parse --abbrev-ref HEAD)                    # wip/* 분기
BASE=$(git merge-base "$SOURCE_BRANCH" "$WIP" 2>/dev/null)
[ -z "$BASE" ] && { echo "BASE 미상 — QA 입력 산출 불가, 중단(빈 diff PASS 금지)"; }   # fail-closed
git diff "${BASE}..HEAD"                                  # 누적 커밋
git diff                                                  # 미커밋
git ls-files --others --exclude-standard                  # untracked 신규 → 각 전문 첨부
```

> **FAIL 라우팅:** '구현 누락'=self-critique 루프 재진입(코드 보완), '계획이 외부 문서와 어긋남'=/taskflow:plan 재진입(재설계). 품질 패스로 요구사항 FAIL 을 해소하려 하지 말 것.

### 정착과의 순서

코드 변경 → self-critique → **QA(활성 시) PASS/skip** → §"정착 절차"(Claude 자동 머지) → sentinel. QA FAIL 상태로 정착 진입 금지.

## Backlog 토론 spawn 정책 (bounded, 2026-05-19 신설)

본 slash 진입 시 backlog 발견 (MEMORY.md `## Backlog` 섹션 + `~/.claude/projects/*/memory/backlog_*.md`) → 다음 4 안전장치 적용 후 `/taskflow:debate` (4 팀 × 4 Agent = 16 Agent 풀-병렬 spawn) 1회 호출.

### Pre-filter (토론 대상 분류)

다음 항목은 토론 대상 **제외**한다 (토론으로 dissolve 불가):

| 제외 조건 | 판정 | 사유 |
|---------|------|------|
| frontmatter `target_date` > 오늘 | 시점 트리거 | 시간 경과 필요 |
| 본문 `§3 Checkpoint` / `Claude 자동 등록 금지` / `사용자 명시 입력 시에만` 명문 | §3 매칭 | 사용자 권한 필수 |
| frontmatter `depends_on:` 또는 본문 `의존:` 명시 (의존 미해소) | 의존 대기 | 선행 작업 미완료 |
| 본문 "사용자 결정 영역" 명시 + 외부 시스템 변경 (be 프로젝트 production / staging 등) | 외부 권한 | worktree + 사용자 정착 필수 |

### Debate budget cap

- `/taskflow:auto` 1회 호출당 `/taskflow:debate` 최대 **1회** spawn.
- Pre-filter 통과한 backlog 들을 1개 묶음으로 `/taskflow:debate` 호출 (개별 호출 X).
- 토론 결과 적용 후 잔여 = 사용자 결정 영역 분류 + sentinel `[AUTO-ITERATE-USER-DECISION]` 부착.

### Debate scope = 정책 결정 only

- 토론 결과 = backlog 처리 **정책 권고**.
- 실제 적용 시 §3 매칭 재검사 — 외부 시스템 변경·protected 분기·비가역 = 사용자 명시 승인 유지.
- 토론이 §3 보호 우회 통로로 작동하지 않는다.

### 종료 조건

- 원래 ("백로그 0건까지 반복") → **"토론 대상 백로그 (pre-filter 통과분) 0건까지"** 로 재정의.
- Pre-filter 제외된 backlog 는 exclusion list 응답 표에 명시 + sentinel `[AUTO-ITERATE-USER-DECISION]` 부착.
- 무한 루프 방지: budget cap (1회) + sentinel 부착.

### 진행 순서

1. MEMORY.md `## Backlog` 섹션 + `~/.claude/projects/*/memory/backlog_*.md` 일괄 read
2. 각 backlog 본문 / frontmatter 분석 → pre-filter 적용
3. 토론 대상 분류 표 응답에 포함 (사용자에게 가시화)
4. 통과 backlog ≥ 1 건 시 `/taskflow:debate` 1회 spawn (16 Agent)
5. 토론 결과 = 정책 권고 채택 → 적용 (§3 매칭 재검사)
6. 적용 후 backlog status update (done / pending 유지)
7. Exclusion list + sentinel 부착으로 응답 마감

**Why bounded:** 원안 ("백로그 0건까지 반복") = 무한 루프·비용 폭증 위험 (대부분 backlog 가 시간/외부 권한/실작업 의존이라 토론으로 해소 불가). 4 안전장치로 종료 조건 도달 가능성 보장 + §3 보호 유지.

### 토론 결론 자동 적용 (조건부, 2026-05-19 신설)

토론 완료 후 결론 자동 적용 조건 (사용자 결정 영역 자동화 vs 무한 루프 방지 균형):

| 합의 수준 | 자동 적용 | 처리 |
|---------|---------|------|
| **≥3팀 동일 결론 또는 4팀 만장일치** | ✓ | §3 매칭 재검사 후 실행 + sentinel `[AUTO-ITERATE-DONE]` |
| **4팀 합의 분산 (각각 다른 결론)** | ✗ | USER-DECISION sentinel + 사용자 확인 (**재토론 금지**) |

**재토론 금지 원칙 (무한 루프 방지):**
- 토론 결과가 USER-DECISION 산출 시 → 동일 `/taskflow:auto` 호출 또는 다음 `/taskflow:auto` 호출 모두 재토론 트리거 X.
- 사용자 명시 답변 후에만 진행 (사용자 입력 = 재진입 유일 트리거).
- Budget cap (1회/호출) + 재토론 금지 = 무한 루프 구조적 차단.

**§3 우회 차단:**
- 자동 적용 전 §3 매칭 재검사 필수 — 외부 시스템 변경·protected 분기·비가역·"Claude 자동 등록 금지" 명문 = 사용자 명시 승인 유지.
- 토론 합의가 §3 매칭 작업이면 ≥3팀 합의여도 자동 적용 X, USER-DECISION sentinel + 사용자 확인.

**토론 대상 범위 확장:**
- backlog 발견 + USER-DECISION sentinel 발생한 사용자 결정 영역 모두 토론 대상.
- 단 위 안전장치 (≥3팀 합의 + §3 재검사 + 재토론 금지) 그대로 적용.

**Why 조건부:** "토론 결론 자동 적용" 무조건화 = 4팀 4 선택지 분산 시 결정자가 결국 또 필요 = 룰 실효성 0. ≥3팀 합의 조건 = 토론의 본래 가치 (다양한 관점 합의) 보존 + 자동화 양립.

## §3 Checkpoint 우선 적용

본 slash 가 자동 진행 모드를 활성하더라도 §3 Checkpoint 5조건(비가역·광범위·요구사항 상충·외부 시스템·권한 외)은 우선 보호된다. `dangerous-ops-guard.sh` / `sensitive-file-guard.sh` / `branch-enforce.sh` 가 hook 레벨에서 별도 차단. 본 slash 는 §3 보호 우회 통로가 아니다.

특히 worktree 정착은 비가역 (`git merge` / `git worktree remove` / `git branch -D`) → **정착 여부에 사용자 명시 승인 필수**. 승인 후 명령 실행 자체는 Claude 자동 (§"정착 절차") — 승인 게이트와 실행 주체는 별개다.

**QA 게이트 = read-only 분석 (`/taskflow:execute` §QA 정합):** 단일 subagent 는 변경분 ↔ 외부 문서 대조 진단만 (코드 수정 금지) → §3 비매칭. FAIL fix 는 self-critique 루프(worktree 안)가 수행 = §3 5조건 재검사 대상. QA 게이트가 §3 우회 통로로 작동하지 않는다.

## 중단

작업 중 사용자가 "중단" / "보류" / "멈춰" 입력 → `gate-approve.sh` 가 stop marker 생성 → `auto-iterate-stop-guard.sh` 가 통과 → Stop 정상 진입.

중단 시 wip/* 분기와 worktree 는 보존됨 — 다음 세션에서 `git worktree list` 로 확인 후 재진입 또는 폐기 가능.

## REGISTRY 자동 등록 (2026-05-15 신설)

본 slash 진입 시 working/*.md Edit/Write 가 발생하면 `working-register.sh` PreToolUse hook 가 `~/.claude/docs/working/REGISTRY.md` entry 자동 추가 + `~/.claude/state/sessions/{slug}/{sid}.lock` 생성.

**충돌 감지:** 동일 slug 다른 session_id active entry 발견 시 stderr 경고 (exit 0, 차단 X — 사용자 결정 우선).

**lifecycle:**
- PreToolUse Edit/Write working/*.md → `working-register.sh` (entry add + lock create)
- PostToolUse Edit/Write working/*.md → `working-heartbeat.sh` (last_update + lock touch)
- Stop hook → `working-release.sh` (본 세션 active entry → paused + lock 제거)
- 다음 SessionStart → `working-stale-cleanup.sh` (24h 초과 lock 자동 정리)
- working/ Done 자동 이동 → `working-lifecycle.sh` (entry + lock 일괄 제거)

## SSOT

- 본문 정책: CLAUDE.md §4 "자동 위임 정책 (Autonomous Iteration)" + §4.3 "자동진행 worktree-first 정책"
- 키워드 매칭: `hooks/gate-approve.sh` (묶음 승인 정규식 + stop marker 생성)
- Stop 차단/재진입 + 정착 reminder: `hooks/auto-iterate-stop-guard.sh`
- reminder 주입: `hooks/auto-iterate-reminder.sh`
- **정착 절차 본체: `custom-plugin/git/commands/{create,merge}.md`** (명령 순서 / 개별 Bash 호출 강제 / ff-only 실패 시 cherry-pick fallback / Claude 자동 실행 2026-06-04~ SSOT — 본 슬래시는 진입점 지목과 제약 요약만)
- worktree 면제 + 분기 정책: `hooks/branch-enforce.sh` (`~/.claude/worktrees/*` case + wip/* 분기 자동 통과)
- product 역해석: `hooks/lib/product-resolver.sh` (`resolve_origin_cwd` → working/ 단일 통합 문서 경로 정합)
- Active Task Registry: `hooks/lib/registry-utils.sh` + `working-{register,heartbeat,release,stale-cleanup}.sh` + `~/.claude/docs/working/REGISTRY.md` SSOT
- QA 게이트 절차 본체: `~/.claude/custom-plugin/taskflow/commands/execute.md` §"QA 게이트" (활성화 조건 / 단일 subagent / untracked 포함 입력 / fail-closed 판정 SSOT — 본 슬래시는 sentinel 게이트·누적 커밋 입력·FAIL 루프 차이만 명시)

**용어 매핑 (audit M12 명문 2026-05-20):** 본 슬래시의 "4축 자동화" = CLAUDE.md §4.4 (3) (a~d) 동일 구조. Echo-Back Confirm = §4.4 (1) / 권고안 자동 채택 = §4.4 (2) SSOT 정합. 본 슬래시는 §4.4 정책의 명시 진입점 wrapper, 정책 본문 SSOT 는 CLAUDE.md §4.4.

## 호출 예

```
/taskflow:auto                                  ← 현재 잔여 액션 전체 자동 진행
/taskflow:auto audit WARN 4건 모두 처리          ← 인자 작업 자동 진행
/taskflow:auto phpunit 실패 케이스 디버그        ← 인자 작업 자동 진행
```

외부 repo 에서 자동진행 호출 시 예시 흐름:

```
[사용자] /taskflow:auto commerce 모듈 가격 정합성 audit + 픽스
   ↓
[Claude] 1) worktree 생성 → ~/.claude/worktrees/631cd229-commerce-price-audit
        2) cd worktree → wip/631cd229-commerce-price-audit 분기에서 작업
        3) self-critique 통과 → 정착 여부 사용자 승인 요청 (§3 비가역)
        4) 승인 후 /git:create 절차를 Claude 가 직접 실행 (각 명령 개별 Bash 호출):
             source(production) 체크아웃 → feature/production_commerce-price-audit 생성
             → ff-only 머지 (실패 시 cherry-pick fallback) → worktree remove → wip 분기 삭제
        5) [AUTO-ITERATE-DONE] 부착. 이후 push 는 사용자 직접 (§4.3 (d))
```

## Changelog

- 2026-05-13: worktree-first 확장
- 2026-06-05: QA 게이트 연동
