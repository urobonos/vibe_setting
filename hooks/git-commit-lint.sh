#!/bin/bash
# PreToolUse Hook: git commit 메시지 Conventional Commits 검증
# 차단(exit 2) — git commit 실행 전 메시지 형식 강제
#
# 형식: type(scope): 제목
# 허용 type: feat, fix, refactor, docs, test, chore, style, perf, ci, build, revert
# scope: 선택 (PascalCase 모듈명 또는 소문자 공통명)

STDIN_DATA=$(cat)

TOOL_NAME=$(echo "$STDIN_DATA" | grep -o '"tool_name" *: *"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

# Bash 도구만 검사
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

COMMAND=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# git commit 명령이 아니면 통과
if ! echo "$COMMAND" | grep -qE 'git\s+commit'; then
  exit 0
fi

# --amend, merge commit, --allow-empty 등은 형식 검증 제외
if echo "$COMMAND" | grep -qE '(--amend|--allow-empty|--no-edit)'; then
  exit 0
fi

# -m 플래그에서 메시지 추출
# HEREDOC 방식: "$(cat <<'EOF' ... EOF )" 또는 단순 -m "..."
COMMIT_MSG=$(echo "$COMMAND" | python -c "
import re, sys
cmd = sys.stdin.read().strip()

# HEREDOC 패턴
heredoc = re.search(r'<<[\x27]?EOF[\x27]?\s*\n(.*?)\nEOF', cmd, re.DOTALL)
if heredoc:
    msg = heredoc.group(1).strip().split('\n')[0].strip()
    print(msg)
    sys.exit(0)

# 단순 -m 패턴: -m \"...\" 또는 -m '...'
m_match = re.search(r'-m\s+[\x22\x27](.*?)[\x22\x27]', cmd)
if m_match:
    print(m_match.group(1).strip().split('\n')[0].strip())
    sys.exit(0)

print('')
" 2>/dev/null)

if [ -z "$COMMIT_MSG" ]; then
  # 메시지 추출 실패 → 통과 (interactive commit 등)
  exit 0
fi

# Conventional Commits 형식 검증: type(scope): 제목 또는 type: 제목
VALID_TYPES="feat|fix|refactor|docs|test|chore|style|perf|ci|build|revert"

if ! echo "$COMMIT_MSG" | grep -qE "^(${VALID_TYPES})(\([A-Za-z0-9_-]+\))?: .+"; then
  echo "[BLOCKED] 커밋 메시지 형식 위반 — Conventional Commits 규격 필수" >&2
  echo "" >&2
  echo "  현재: $COMMIT_MSG" >&2
  echo "  형식: type(scope): 제목" >&2
  echo "  허용 type: feat, fix, refactor, docs, test, chore, style, perf, ci, build, revert" >&2
  echo "  예시: feat(Commerce): 결제 API 추가" >&2
  echo "        fix: 인증 토큰 만료 처리 버그 수정" >&2
  exit 2
fi

# 커밋 제목 72자 초과 검증
MSG_LEN=${#COMMIT_MSG}
if [ "$MSG_LEN" -gt 72 ]; then
  echo "[BLOCKED] 커밋 제목 72자 초과 (${MSG_LEN}자) — 72자 이내로 줄이세요." >&2
  echo "  현재: $COMMIT_MSG" >&2
  exit 2
fi

# Co-Authored-By 포함 여부 (dangerous-command-guard와 중복 방어)
if echo "$COMMAND" | grep -qiE 'co-authored-by'; then
  echo "[BLOCKED] Co-Authored-By 차단 — 커밋 메시지에 포함하지 마세요." >&2
  exit 2
fi

exit 0
