#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "branch-enforce" "enter" "pid=$$"
# PreToolUse:Edit|Write|Bash Hook — push 차단 + master/main 머지 금지 (잔존 영역, 2026-05-20 retire 후)
#
# 정책 (2026-04-30 / 2026-05-07 / 2026-05-13 / 2026-05-20 부분 retire):
#   - §(1) git push 차단 (모든 분기) — 유지
#   - §(1.5) master/main 머지·checkout·switch 절대 금지 — 유지
#   - §(2) Protected 브랜치 자동 강제 + Edit/Write 차단 = **retire (2026-05-20)**
#     → `worktree-enforce.sh` 로 의미 이관 (worktree 항상 강제 + feature 분기 요청 시 생성)
#
# 산출물 SSOT: ~/.claude/docs/claude-harness/tasks/20260520/worktree-always-policy/2026-05-20-worktree-always-policy-unified.md
#             + ~/.claude/docs/claude-harness/output/guide/2026-04-30-branch-workflow/ (구 정책 참조)

source "$(dirname "$0")/lib/hook-input.sh"
source "$(dirname "$0")/lib/path-utils.sh"
hook_init
hook_read_stdin

# 현재 브랜치 — git repo 가 아니면 통과
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -z "$BRANCH" ] && exit 0

# tool_name 추출 (Edit / Write / Bash 분기)
TOOL_NAME=""
if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
  hook_python
  TOOL_NAME=$(echo "$STDIN_DATA" | "$HOOK_PY" -c "
import json, sys
try:
    print(json.load(sys.stdin).get('tool_name', ''))
except Exception:
    print('')
" 2>/dev/null)
fi

# ─────────────────────────────────────────────────────────
# 기한부 push 예외 (2026-05-29 사용자 결정 / 전 프로젝트 / ~2026-07-31 자동 만료)
#   출시 전 파이프라인 자동배포 기간 — Claude 가 push + worktree→production 머지 + 배포를 자율 수행 허용.
#   2026-08-01 0시부터 TODAY(YYYYMMDD) > 20260731 → 예외 자동 비활성 → §(1) push 전면 금지 복귀.
#   유지(예외 무관 그대로 차단): force push(dangerous-ops-guard L82) / master·main 머지·checkout(§1.5) /
#     rm -rf / reset --hard / DB 마이그 등 §3 절대 차단. phpunit 그린-before-push 게이트도 정책상 유지.
#   SSOT: 글로벌 CLAUDE.md §4.3 (d) "기한부 push 예외" + C:\Works\hongcafe_global_backend\CLAUDE.md "배포 자동화".
# ─────────────────────────────────────────────────────────
PUSH_EXCEPTION_UNTIL="20260731"
PUSH_EXCEPTION_ACTIVE="0"
_TODAY="$(date +%Y%m%d 2>/dev/null)"
if [ -n "$_TODAY" ] && [ "$_TODAY" -le "$PUSH_EXCEPTION_UNTIL" ]; then
  PUSH_EXCEPTION_ACTIVE="1"
fi

# ─────────────────────────────────────────────────────────
# (1) git push — 모든 분기에서 차단 (자동 원격 push 전면 금지, 2026-05-07 / 2026-05-08 정밀화)
# 매칭: 명령을 ;/&&/|| 로 분리한 각 절을 shlex 토큰화 → 첫 두 토큰이 ['git','push'] 인 절만 차단.
# Why: substring 매칭은 commit 메시지·heredoc 본문·grep 인자 안의 'git push' 문자열까지 false-positive 차단함.
# 2026-05-29~ : PUSH_EXCEPTION_ACTIVE=1 (≤2026-07-31) 이면 차단 스킵 (force push 는 dangerous-ops-guard 가 별도 차단).
# ─────────────────────────────────────────────────────────
if [ "$TOOL_NAME" = "Bash" ]; then
  hook_parse_command
  # H-2 wire-in point: push 검출 단일점 — 향후 PUSH_EXCEPTION_ACTIVE 정책 분기를 여기서 (현 behavior 불변)
  PUSH_DETECTED="0"
  hook_python
  # 배칭: git detector 를 all 모드로 1회 호출 후 캐시 (push/master-merge/cherry-pick python 3회→1회).
  GG_ALL=""
  [ -n "$HOOK_PY" ] && GG_ALL=$(printf '%s' "$COMMAND" | "$HOOK_PY" "$(dirname "$0")/lib/git-guard.py" all 2>/dev/null)
  GG_ALL="${GG_ALL//$'\r'/}"   # Windows python CRLF 제거 (라인 매칭 정확성)
  gg() {
    local w=$'\n'"$GG_ALL"$'\n' r
    case "$w" in
      *$'\n'"$1="*) r="${w##*$'\n'"$1="}"; printf '%s' "${r%%$'\n'*}" ;;
      *) printf '0' ;;
    esac
  }
  if [ -n "$HOOK_PY" ]; then
    PUSH_DETECTED=$(gg push)
  fi
  # python 부재 시 grep 백스톱 (fail-open → fail-closed, H1 2026-06-16): 절(;/&&/||/|/&) 분리 후
  #   첫 git 토큰이 push 인 절 차단. python 가용 시엔 git-guard.py(정확) 단독 — FP(commit 메시지 등) 회귀 0.
  if [ -z "$HOOK_PY" ] && [ "$PUSH_DETECTED" != "1" ]; then
    if printf '%s' "$COMMAND" | grep -qE '(^|[;&|])[[:space:]]*((sudo|env|nohup|timeout|command|exec)[[:space:]]+[^;&|]*)?git[[:space:]]+push([[:space:]]|$)'; then
      PUSH_DETECTED="1"
    fi
  fi
  if [ "$PUSH_DETECTED" = "1" ]; then
    command -v log_event >/dev/null 2>&1 && log_event "branch-enforce" "block" "reason=auto-push branch=$BRANCH"
    echo "[BRANCH-GUARD] 차단: 자동 원격 push 전면 금지 (현재 분기 '$BRANCH')" >&2
    echo "              명령: $COMMAND" >&2
    echo "              정책: Claude 는 Bash 도구로 git push 를 직접 호출하지 않습니다 (모든 분기 / 모든 옵션 예외 0)." >&2
    echo "              조치: 사용자가 직접 \`! git push ...\` (Bash prefix) 또는 PowerShell 셸에서 실행" >&2
    echo "              SSOT: 글로벌 CLAUDE.md §4.3(d) \"git push 전면 금지\" + skills/git-push/SKILL.md" >&2
    exit 2
  fi
fi

# ─────────────────────────────────────────────────────────
# (1.5) master/main 머지 절대 금지 (모든 분기에서, 2026-05-13 신규)
# 매칭: 명령을 ;/&&/|| 로 분리한 각 절을 shlex 토큰화 →
#   (a) tokens=[git, merge, ...] AND any(t in MASTER_TARGETS for t in tokens[2:])  → target=main/master 머지 차단
#   (b) tokens=[git, checkout, ...] AND any(t in MASTER_TARGETS for t in tokens[2:]) → chained `checkout main && merge` 우회 차단
#   (c) 현재 분기 = master/main 이면 변경계 git 명령 (commit/merge/rebase) 차단 — 기존 (2) 룰로 처리
# Why: 사용자 명시 (2026-05-13) "master 머지 진행 절대금지" — 기존 hook 는 "현재 분기 protected" 만 검사로
#      chained 명령 `git checkout main && git merge feature/x` 우회 가능했음. shlex 토큰화로 false-positive 방지.
# MASTER_TARGETS = main / master / origin/main / origin/master / refs/heads/main / refs/heads/master / upstream/main / upstream/master
# ─────────────────────────────────────────────────────────
if [ "$TOOL_NAME" = "Bash" ]; then
  MASTER_MERGE_DETECTED="0"
  # 배칭 GG_ALL 재사용 (push 섹션에서 1회 계산) — master-merge 값은 패턴명 또는 '0'
  if [ -n "$HOOK_PY" ]; then
    MASTER_MERGE_DETECTED=$(gg master-merge)
  fi
  if [ "$MASTER_MERGE_DETECTED" != "0" ]; then
    command -v log_event >/dev/null 2>&1 && log_event "branch-enforce" "block" "reason=master-merge pattern=$MASTER_MERGE_DETECTED branch=$BRANCH"
    echo "[BRANCH-GUARD] 차단: master/main 머지 절대 금지 (감지 패턴 '$MASTER_MERGE_DETECTED', 현재 분기 '$BRANCH')" >&2
    echo "              명령: $COMMAND" >&2
    echo "              정책: Claude 는 Bash 도구로 master/main 으로의 머지·checkout·switch 를 직접 호출하지 않습니다 (모든 분기 / 모든 옵션 예외 0)." >&2
    echo "              조치: 사용자가 직접 \`! git merge ...\` / \`! git checkout main\` (Bash prefix) 또는 PowerShell 셸에서 실행" >&2
    echo "              SSOT: 글로벌 CLAUDE.md §4.3 \"master/main 머지 절대 금지\" + 본 hook (1.5)" >&2
    exit 2
  fi
fi

# ─────────────────────────────────────────────────────────
# (1.6) master/main HEAD 에서 git cherry-pick 차단 (2026-06-04 신규)
# Why: §4.3(f) 정착 fallback 으로 cherry-pick 을 Claude 자동 실행 어휘에 편입 → merge 는 §1.5 가 차단하나
#   cherry-pick 은 통과하는 비대칭 발생. cherry-pick 은 target arg 가 아닌 "현재 HEAD 분기"에 적용되므로
#   §1.5 (target 토큰 검사) 패턴이 아닌 현재 BRANCH 검사. §(2) retire(2026-05-20)로 "현재 분기 master/main
#   변경계 차단" 구멍이 열려 있었음 — 본 가드가 cherry-pick 한정으로 그 구멍을 닫는다 (자동 루프 §3 hard-block 계약 정합).
# 매칭: 현재 BRANCH ∈ {main,master} AND 명령 절 토큰이 [git, cherry-pick, ...]. --abort/--quit/--skip 복구계는 면제
#   (진행 중 cherry-pick 상태 정리는 master/main 에서도 허용). 정착 happy-path 는 feature/* 체크아웃 후라 무영향.
# ─────────────────────────────────────────────────────────
if [ "$TOOL_NAME" = "Bash" ] && { [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; }; then
  CHERRY_DETECTED="0"
  # 배칭 GG_ALL 재사용 (push 섹션에서 1회 계산)
  if [ -n "$HOOK_PY" ]; then
    CHERRY_DETECTED=$(gg cherry-pick)
  fi
  if [ "$CHERRY_DETECTED" = "1" ]; then
    command -v log_event >/dev/null 2>&1 && log_event "branch-enforce" "block" "reason=master-cherry-pick branch=$BRANCH"
    echo "[BRANCH-GUARD] 차단: master/main HEAD 에서 git cherry-pick 금지 (현재 분기 '$BRANCH')" >&2
    echo "              명령: $COMMAND" >&2
    echo "              정책: cherry-pick 자동 실행은 정착(feature/* 체크아웃) 한정. master/main 위 적용은 merge 와 동일 차단 (§1.5 미러)." >&2
    echo "              조치: feature 분기 체크아웃 후 정착하거나, 사용자가 직접 \`! git cherry-pick ...\` 실행" >&2
    echo "              SSOT: 글로벌 CLAUDE.md §4.3(f) + 본 hook (1.6)" >&2
    exit 2
  fi
fi

# ─────────────────────────────────────────────────────────
# (2) [retired 2026-05-20] Protected 브랜치 자동 강제 + Edit/Write 차단 영역.
#     worktree-enforce.sh 로 의미 이관. 본 hook 는 §(1) push 차단 + §(1.5) master/main 금지만 잔존.
# ─────────────────────────────────────────────────────────
exit 0
