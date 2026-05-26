#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "ieee-specs-round-check" "enter" "pid=$$"
# PostToolUse:Edit|Write Hook — IEEE specs 3-Round 메타데이터 검증 (G3)
#
# 대상:
#   ~/.claude/docs/{product}/specs/*-{srs|sdd|idd|sdp|stp|std}.md
#
# 검증:
#   1. frontmatter status: 초안 | 검토중 | 승인됨  (3택 1)
#   2. frontmatter round-1 / round-2 / round-3 필드 존재 (값: pass | fail | pending)
#   3. 본문에 '## Round 1', '## Round 2', '## Round 3' 헤더 3개 존재
#   4. status: 승인됨 → round-1/2/3 모두 pass 필수
#
# 정책: exit 0 + stderr 경고 (PostToolUse 차단 비활성)
# 출처: task-docs §H IEEE 적합성 재검토

source "$(dirname "$0")/lib/hook-input.sh"
source "$(dirname "$0")/lib/path-utils.sh"
hook_read_stdin
hook_parse_file_path
# Windows backslash → forward slash 정규화 (path-utils.sh::normalize_path SSOT)
FILE_PATH=$(normalize_path "$FILE_PATH")

# specs/{모듈}-{srs|sdd|idd|sdp|stp|std}.md 패턴만 검증
echo "$FILE_PATH" | grep -qiE '/docs/[^/]+/specs/.+-(srs|sdd|idd|sdp|stp|std)\.md$' || exit 0

[ -f "$FILE_PATH" ] || exit 0

# frontmatter 추출 (첫 --- 부터 두 번째 --- 까지)
FRONTMATTER=$(awk '/^---$/{c++; if(c==1){next} else {exit}} c==1' "$FILE_PATH")

if [ -z "$FRONTMATTER" ]; then
  echo "[IEEE-SPECS] $FILE_PATH: YAML frontmatter 누락" >&2
  exit 0
fi

ERRORS=()

# 검증 1: status 필드
STATUS=$(echo "$FRONTMATTER" | grep -E '^status:' | head -1 | sed -E 's/^status:[[:space:]]*//' | tr -d '"' | tr -d "'")
if [ -z "$STATUS" ]; then
  ERRORS+=("status 필드 누락 (값: 초안 | 검토중 | 승인됨)")
elif ! echo "$STATUS" | grep -qE '^(초안|검토중|승인됨)$'; then
  ERRORS+=("status: '$STATUS' 비표준 (허용: 초안 | 검토중 | 승인됨)")
fi

# 검증 2: round-1/2/3 필드
declare -A ROUNDS
for n in 1 2 3; do
  VAL=$(echo "$FRONTMATTER" | grep -E "^round-$n:" | head -1 | sed -E "s/^round-$n:[[:space:]]*//" | tr -d '"' | tr -d "'")
  if [ -z "$VAL" ]; then
    ERRORS+=("round-$n 필드 누락 (값: pass | fail | pending)")
  elif ! echo "$VAL" | grep -qE '^(pass|fail|pending)$'; then
    ERRORS+=("round-$n: '$VAL' 비표준 (허용: pass | fail | pending)")
  fi
  ROUNDS[$n]=$VAL
done

# 검증 3: 본문 Round 헤더
for n in 1 2 3; do
  if ! grep -qE "^##\s+Round\s+$n" "$FILE_PATH"; then
    ERRORS+=("본문 '## Round $n ...' 헤더 누락")
  fi
done

# 검증 4: status=승인됨 → 3 round 모두 pass
if [ "$STATUS" = "승인됨" ]; then
  for n in 1 2 3; do
    if [ "${ROUNDS[$n]}" != "pass" ]; then
      ERRORS+=("status: 승인됨 인 경우 round-$n: pass 필수 (현재: '${ROUNDS[$n]}')")
    fi
  done
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "[IEEE-SPECS] $FILE_PATH: 3-Round 메타데이터 검증 실패" >&2
  for err in "${ERRORS[@]}"; do
    echo "             - $err" >&2
  done
  echo "             task-docs §H — SRS/SDD/IDD/SDP/STP/STD 적합성 재검토 필수." >&2
fi

exit 0
