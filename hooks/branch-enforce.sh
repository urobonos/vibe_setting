#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# PreToolUse:Edit|Write|Bash Hook — Trunk-Based + Short-lived Feature Branch 강제
#
# 정책 (사용자 결정 2026-04-30 / 2026-05-07 갱신):
#   - 분기명 규칙: feature/{source-branch}_{작업명}
#   - Protected 브랜치 = production / staging / develop / main / master (정확 매칭)
#   - Protected 위에서 코드/설정/문서 변경 시 차단 + feature 분기 생성 유도
#   - 면제 영역: ~/.claude/docs/{product}/  (산출물) + projects/.../memory/  (메모리)
#   - Bash 도구: git commit / merge / rebase 는 protected 위에서만 차단
#   - **2026-05-07 추가**: git push 는 모든 분기에서 차단 (자동 원격 push 전면 금지 룰)
#     → 사용자가 직접 `! git push` 또는 PowerShell 셸로 실행해야 통과
#
# 산출물 SSOT: ~/.claude/docs/claude-harness/output/guide/2026-04-30-branch-workflow/2026-04-30-branch-workflow-design.md

source "$(dirname "$0")/lib/hook-input.sh"
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
# (1) git push — 모든 분기에서 차단 (자동 원격 push 전면 금지, 2026-05-07 / 2026-05-08 정밀화)
# 매칭: 명령을 ;/&&/|| 로 분리한 각 절을 shlex 토큰화 → 첫 두 토큰이 ['git','push'] 인 절만 차단.
# Why: substring 매칭은 commit 메시지·heredoc 본문·grep 인자 안의 'git push' 문자열까지 false-positive 차단함.
# ─────────────────────────────────────────────────────────
if [ "$TOOL_NAME" = "Bash" ]; then
  hook_parse_command
  PUSH_DETECTED="0"
  hook_python
  if [ -n "$HOOK_PY" ]; then
    PUSH_DETECTED=$(printf '%s' "$COMMAND" | "$HOOK_PY" -c "
import sys, shlex, re
cmd = sys.stdin.read()
for part in re.split(r'(?:&&|\|\||;)', cmd):
    try:
        tokens = shlex.split(part, posix=True)
    except ValueError:
        tokens = part.strip().split()
    if len(tokens) >= 2 and tokens[0] == 'git' and tokens[1] == 'push':
        print('1'); sys.exit(0)
print('0')
" 2>/dev/null)
  fi
  if [ "$PUSH_DETECTED" = "1" ]; then
    echo "[BRANCH-GUARD] 차단: 자동 원격 push 전면 금지 (현재 분기 '$BRANCH')" >&2
    echo "              명령: $COMMAND" >&2
    echo "              정책: Claude 는 Bash 도구로 git push 를 직접 호출하지 않습니다 (모든 분기 / 모든 옵션 예외 0)." >&2
    echo "              조치: 사용자가 직접 \`! git push ...\` (Bash prefix) 또는 PowerShell 셸에서 실행" >&2
    echo "              SSOT: 글로벌 CLAUDE.md §\"자동 원격 push 전면 금지\" + skills/git-push/SKILL.md" >&2
    exit 2
  fi
fi

# ─────────────────────────────────────────────────────────
# (2) Protected 브랜치 강제 — production/staging/develop/main/master
# ─────────────────────────────────────────────────────────
case "$BRANCH" in
  production|staging|develop|main|master) ;;
  *) exit 0 ;;
esac

# Bash 도구 — 변경계 git 명령 차단 (push 는 위에서 이미 처리)
if [ "$TOOL_NAME" = "Bash" ]; then
  case "$COMMAND" in
    *"git commit"*|*"git merge"*|*"git rebase"*)
      ;;
    *)
      exit 0
      ;;
  esac
  echo "[BRANCH-GUARD] 차단: protected 브랜치 '$BRANCH' 에서 변경계 git 명령" >&2
  echo "              명령: $COMMAND" >&2
  echo "              조치: feature/${BRANCH}_{작업명} 분기 생성 후 재실행" >&2
  echo "              예시: git checkout -b feature/${BRANCH}_my-work" >&2
  exit 2
fi

# Edit / Write 도구 — 면제 영역 검사 후 차단
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "MultiEdit" ]; then
  hook_parse_file_path
  FILE_PATH=$(echo "$FILE_PATH" | tr '\\' '/')

  # 면제 영역
  case "$FILE_PATH" in
    */.claude/docs/*)        exit 0 ;;
    */projects/*/memory/*)   exit 0 ;;
    */.claude/.skill-creator-active.lock) exit 0 ;;
  esac

  echo "[BRANCH-GUARD] 차단: protected 브랜치 '$BRANCH' 직접 수정" >&2
  echo "              파일: $FILE_PATH" >&2
  echo "              조치: feature/${BRANCH}_{작업명} 분기 생성 후 재시도" >&2
  echo "              예시: git checkout -b feature/${BRANCH}_my-work" >&2
  echo "              면제: ~/.claude/docs/ (산출물) / projects/.../memory/ (메모리)" >&2
  exit 2
fi

exit 0
