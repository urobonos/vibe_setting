---
description: 작업 시작 — DISPATCH.md 에서 `#tag` 를 배타적 claim(mkdir lock) 후 분배 문서를 컨텍스트로 로드 + 작업 진입 안내. **착수 전 점유 세션 선확인 — 분배·자율 진입 모두 타 세션 점유 작업 침범 차단(§0)**. 인자 없으면 available 목록, `#tag done` 으로 완료 마킹. 짝 슬래시 = `/taskflow:dispatch`
allowed-tools: Bash, Read, Glob, Grep, Edit, PowerShell
argument-hint: "[#tag | #tag done]  # 생략 시 available 분배 작업 목록"
---

`/taskflow:dispatch` 가 등록한 분배 풀(`DISPATCH.md`)에서 `#tag` 를 **배타적으로 claim** 하고, 해당 분배 문서를 현재 세션 컨텍스트로 로드해 작업을 이어받는다. 한 태그는 한 세션만 점유 — 에이전트팀 다세션 병렬 분배 시 중복 작업을 원천 차단한다. 짝 슬래시 = **`/taskflow:dispatch`**.

> **경계 — 이 슬래시는 claim + 로드(진입)까지만, 실행이 아니다.** 실제 코드 변경은 claim 후 `/taskflow:auto`·`/taskflow:execute` 에 위임한다. 계열상 `/taskflow:load` 의 **다세션·lock 판**이며 `/taskflow:execute`(내 §계획 step 실행)·`/taskflow:auto`(묶음 승인 실행)과 별개다 — 공통점은 claim 후 그 둘을 호출한다는 것뿐. 프로파일 대비: `/taskflow:claim` = 코드변경 ✗ + lock ✓ / `/taskflow:execute`·`/taskflow:auto` = 코드변경 ✓ + lock ✗ (정반대).

## §0 작업 진행 전 점유 세션 선확인 (필수 게이트 — 침범 차단)

**분배 작업이든 클로드 자율 판단 작업이든, 실제 착수(분배 문서 열람·코드 변경) 전에 점유 세션을 먼저 확인한다.** 타 세션이 점유 중이면 침범하지 않는다 — 다른 작업을 고르거나 사용자에게 보고하고 대기한다. 점유의 SSOT 는 **두 문서**다:

| 문서 | 컬럼 (조건) | 점유 의미 |
|------|------------|----------|
| `DISPATCH.md` | `claimed_by` (status=claimed) | 분배 작업(#tag) 을 점유한 세션 |
| `REGISTRY.md` | `session_id` (status=active) | 진행 중 working 작업을 점유한 세션 |

### 진입 경로별 적용

| 경로 | 점유 확인 방식 |
|------|---------------|
| **`/taskflow:claim #tag`** (명시 claim) | `dispatch_claim` 이 자동 집행 — §② `TAKEN` 거부가 곧 점유 선확인. 추가 조회 불필요 |
| **클로드 자율 판단 진입** (claim 없이 분배 문서·working 작업에 바로 착수하려 할 때) | **claim 우회 금지.** 분배 작업 = 반드시 `/taskflow:claim #tag` 로 claim 을 먼저 거친다 (claim=점유확인+lock). working 작업 = 아래 REGISTRY 조회로 타 sid active 확인 |

> **핵심:** 어떤 분배 작업을 "하기로 판단"했더라도 분배 문서를 직접 열어 작업하지 않는다. **항상 `/taskflow:claim #tag` claim 이 먼저**다 — claim 이 `TAKEN` 이면 그 작업은 타 세션 소유이므로 진행하지 않는다.

### 자율 진입 시 사전 조회 (claim 전 / working 작업 확인)

```bash
source ~/.claude/hooks/lib/dispatch-utils.sh
source ~/.claude/hooks/lib/registry-utils.sh
SID8="${CLAUDE_SESSION_ID:0:8}"
[ -z "$SID8" ] && SID8="<현재 세션 sid 8자 — Claude 본체 기입>"

# (A) 분배 #tag 점유 — status=claimed 이고 claimed_by 가 본인이 아니면 타 세션 소유
#     (정식 진입은 어차피 /taskflow:claim #tag = dispatch_claim 이 재확인 + lock)
dispatch_find "{tag}" | awk -F"$DISPATCH_FS" -v me="$SID8" '
  { st=$5; by=$6 }
  st=="claimed" && by!=me { print "[점유] #"$2" → "by" 점유 중 (침범 금지)"; next }
  st=="claimed" && by==me { print "[본인] #"$2" → 본 세션 점유 (진행 가능)"; next }
  { print "[가능] #"$2" → status="st }
'

# (B) working slug 점유 — REGISTRY active 인데 다른 sid 면 타 세션 진행 중
registry_find "{slug}" | awk -F"$REGISTRY_FS" -v me="$SID8" '
  $7=="active" && $4!=me { print "[점유] "$2" → "$4" 진행 중 (침범 금지, 보고 후 대기)"; next }
  { print "[가능] "$2" → "($4==me?"본 세션":"status="$7) }
'
```

**판정:** `[점유]` 출력 시 → "{대상} 은 {sid} 점유 중입니다. 침범하지 않습니다." 보고 후 대기. `[본인]`/`[가능]` → 진행 가능. **§3 우선:** 점유 확인을 통과해도 실제 코드 변경이 §3 매칭이면 각 guard hook + 승인 흐름이 별도 강제.

## 동작 — 인자 분기

| 인자 | 동작 |
|------|------|
| 없음 (`/taskflow:claim`) | DISPATCH.md `available` 목록 출력 (claim 가능 작업) |
| `#tag` (`/taskflow:claim #auth-jwt`) | 배타적 claim 시도 → 성공 시 분배 문서 본문 로드 + 진입 안내 |
| `#tag done` (`/taskflow:claim #auth-jwt done`) | claim 한 작업 완료 마킹 (status=done + lock 정리) |

> `#` prefix 는 선택 — `/taskflow:claim auth-jwt` 도 동일 (`dispatch_tag_sanitize` 가 `#` 제거).

## 세션 식별자 (sid)

```bash
# claim/done 주체 식별 — REGISTRY/lock 의 session_id 앞 8자와 동일 체계.
# Claude Code 가 환경에 노출하지 않으면 Claude 본체가 현재 세션 sid 8자로 치환.
SID8="${CLAUDE_SESSION_ID:0:8}"
[ -z "$SID8" ] && SID8="<현재 세션 sid 8자 — Claude 본체 기입>"
```

> 같은 세션이 일관된 sid 를 써야 `ALREADY_YOURS`/`done` 의 본인 확인이 성립한다.

## ① 인자 없음 — available 목록

```bash
source ~/.claude/hooks/lib/dispatch-utils.sh
dispatch_list available
```

출력:
```
[Claude] claim 가능한 분배 작업 (available):

  #auth-jwt    | 인증 리팩터 / JWT 분리    | be | 분배 2026-06-15 09:26
  #auth-routes | 인증 리팩터 / 라우트 가드  | be | 분배 2026-06-15 09:26

  진입: /taskflow:claim #auth-jwt
```

## ② #tag — 배타적 claim

> **§0 게이트 자동 집행:** `dispatch_claim` 의 `TAKEN` 거부 = 점유 선확인의 강제 지점. claim 경로는 이 거부로 타 세션 침범이 원천 차단된다. 자율 판단 진입도 반드시 이 claim 을 거쳐야 한다 (claim 우회 = §0 위반).

```bash
source ~/.claude/hooks/lib/dispatch-utils.sh
OUT=$(dispatch_claim "{tag}" "$SID8"); RC=$?
RESULT="${OUT%%|*}"; DOC="${OUT#*|}"
```

`dispatch_claim` 결과별 분기:

| RESULT (rc) | 의미 | 처리 |
|-------------|------|------|
| `CLAIMED` (0) | available → 점유 성공 | 분배 문서(`$DOC`) 본문 출력 + 진입 안내 |
| `ALREADY_YOURS` (0) | 본인이 이미 점유 | 분배 문서 재로드 (이어서 진행) |
| `STOLEN:<old>` (0) | stale(24h+) steal | 분배 문서 로드 + "이전 점유 {old} 24h+ 무응답 → 회수" 경고 |
| `TAKEN:<sid>` (3) | 타 세션 점유 중 | **거부** — "#{tag}는 {sid} 점유 중. 다른 태그 선택 또는 24h 후 재시도" |
| `DONE` (4) | 이미 완료 | **거부** — "#{tag}는 완료됨" |
| `NOTFOUND` (2) | 태그 없음 | available 목록 재출력 + 오타 확인 안내 |

claim 성공(`CLAIMED`/`ALREADY_YOURS`/`STOLEN`) 시:

1. **터미널 제목 설정** — PowerShell 도구로 `$Host.UI.RawUI.WindowTitle = "#{tag}"` 실행 (§"터미널 제목 설정 (SSOT)" 참조). 예: claim 태그가 `chatfile-acl` 이면 제목 = `#chatfile-acl`.
2. `$DOC` (분배 문서) 전체 본문 Read → 화면 출력 (목표·배경·작업 내용·DoD·대상 파일)
3. 진입 안내:
```
[Claude] #auth-jwt claim 완료 (점유: {sid8}).
        분배 문서: docs/working/dispatch/2026-06-15-be-auth-refactor-auth-jwt.md

        목표: JWT 발급·검증 로직 분리
        대상: app/.../AuthService.php
        작업 4건 / DoD 2건 (본문 참조)

        진입 옵션:
        ① /taskflow:auto #auth-jwt 작업 일괄 수행      ← 묶음 승인 모드
        ② /taskflow:analyze 부터 단계 진행         ← working/ 통합 문서 신규
        ③ 개별 지시

        완료 시: /taskflow:claim #auth-jwt done
```

> claim 후 실제 작업은 worktree 안에서 (CLAUDE.md §4.3 worktree 강제). 분배 문서는 작업 기준 명세 — 진행은 claim 세션이 자신의 working/ 통합 문서를 새로 만들거나(권장: `/taskflow:analyze`~`/taskflow:execute`) 분배 문서를 직접 기준으로 삼는다.

## ③ #tag done — 완료 마킹

```bash
source ~/.claude/hooks/lib/dispatch-utils.sh
dispatch_done "{tag}" "$SID8"
```

> status=done + `state/dispatch/{tag}/` lock 정리. 분배 작업 종결. (claim 세션의 실제 코드 변경 마무리·머지는 `/taskflow:save`·`/taskflow:deploy` 영역 — 본 명령은 분배 풀 상태만 종결.)

## 터미널 제목 설정 (SSOT)

작업·분배 진행 슬래시가 **진입 시 터미널 창 제목을 진행 중인 태스크 이름으로 설정**한다. 다세션 병렬 시 어느 창이 어느 작업인지 한눈에 식별하기 위함. 본 섹션이 방식·형식의 단일 SSOT — `/taskflow:execute`·`/taskflow:auto`·`/taskflow:load`·`/taskflow:consume`·`/taskflow:save` 은 **값만 다르고 방식은 본 표를 참조**한다.

| 항목 | 값 |
|------|-----|
| **방식** | **PowerShell 도구**로 `$Host.UI.RawUI.WindowTitle = "{제목}"` 실행 (Windows 콘솔 직접 접근). Bash 도구 금지 |
| **형식** | 분배(`/taskflow:claim`·`/taskflow:consume`) = `#{tag}` / 워킹(`/taskflow:execute`·`/taskflow:auto`·`/taskflow:load`) = `#{작업명}` (예: `#chatfile-acl`) |
| **원복** | 세션 마감(`/taskflow:save`) 시 현재 폴더명으로 리셋: `$Host.UI.RawUI.WindowTitle = (Split-Path -Leaf $PWD)` |
| **전제** | `settings.json` env `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` (Claude Code 자동 제목 override 차단 — 없으면 매 턴 작업요약으로 덮어써짐) |
| **OS·실패** | Windows(PowerShell) 환경 전용. 비-Windows 또는 실행 실패 시 **무시하고 진행** (제목은 부가 기능, 작업 자체 무영향) |

> **Why PowerShell 도구 (Bash 불가):** Claude Code 의 PowerShell 도구는 사용자 콘솔과 동일 콘솔을 공유해 `WindowTitle` 변경이 실제 창에 반영된다. Bash 도구는 별도 PTY(파이프 캡처, `tty` = not a tty)라 OSC 시퀀스(`\033]0;…\007`)가 터미널에 도달하지 않는다 (검증 완료).

## §3 Checkpoint 우선 적용

- claim = DISPATCH.md 인덱스 + lock mutation (비가역성 낮음, 회복 가능 — `dispatch_release` 로 available 복귀). 사용자 승인 없이 진행 가능.
- **claim 후 실제 작업**이 §3 매칭(비가역·광범위·외부 시스템)이면 그 시점에 각 guard hook + Echo-Back 이 강제 — 본 슬래시는 claim·로드까지만.
- `done` 마킹은 회복 가능(`dispatch_add` 재등록)하나 타 세션 작업 종결 신호이므로 claim 본인 sid 만 정상 동작.

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/hooks/lib/dispatch-utils.sh` | claim/done/list lib (본 슬래시 = `dispatch_claim`/`dispatch_done`/`dispatch_list` 호출) |
| `~/.claude/hooks/lib/registry-utils.sh` | REGISTRY 점유 확인 (§0 게이트 — working 작업 타 세션 active 감지, `registry_find`) |
| `~/.claude/docs/working/DISPATCH.md` | 분배 풀 인덱스 (read + lib 경유 갱신) |
| **`~/.claude/custom-plugin/taskflow/commands/dispatch.md`** | **짝 슬래시 — 청크 분해 + 분배 문서 생성 + 태그 등록** |
| `~/.claude/custom-plugin/taskflow/commands/load.md` | 단일 세션 재개 (작업시작=타 세션 이관 claim 과 구분) |
| `~/.claude/custom-plugin/taskflow/commands/auto.md` | claim 후 작업 일괄 수행 진입점 |

## 호출 예

```
/taskflow:claim                      ← available 분배 작업 목록
/taskflow:claim #auth-jwt            ← 배타적 claim + 분배 문서 로드
/taskflow:claim auth-jwt            ← 동일 (# 생략 가능)
/taskflow:claim #auth-jwt done      ← 완료 마킹
```

## 차별점 (다른 슬래시와)

| 슬래시 | 시점 | 동작 | 점유 |
|--------|------|------|------|
| `/taskflow:load` | 다음 세션 시작 | **동일 세션** Partial 작업 재개 (로드) | - |
| **`/taskflow:claim`** | 타 세션·에이전트 | **분배 #tag 배타적 claim + 로드 (실행 아님)** | **한 태그=한 세션 (lock)** |
| `/taskflow:consume` | worker 세션 (`/loop`) | **available 자동 폴링·claim·작업·done 연속** (본 슬래시의 무인 루프 버전) | 건별 lock |
| `/taskflow:execute` | claim 후 (위임) | 내 §계획 step 순차 실행 | - |
| `/taskflow:auto` | claim 후 (위임) | 묶음 승인 실행+자동화 | - |

## Changelog

- 2026-06-15: 신설
