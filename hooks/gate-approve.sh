#!/bin/bash
# UserPromptSubmit Hook: 사용자 승인 감지 → Gate 레벨 증가
# Phase 3 Harness — 승인 키워드가 포함된 짧은 메시지 감지
#
# 승인 키워드: 진행, 승인, 확인, ok, yes, go, ㄱ, ㄱㄱ, 해, 해봐, 네, 넵, 좋아, lgtm, y, ㅇ, ㅇㅇ
# 조건: 메시지 길이 50자 이하 + 승인 키워드 포함

STDIN_DATA=$(cat)

# --- 디버그 로그 설정 ---
LOG_FILE="$HOME/.claude/gate-approve.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG_FILE" 2>/dev/null; }

# session_id와 prompt 추출 (python3 우선, 실패 시 grep/sed fallback)
PARSE_OK=0
PARSED=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    sid = data.get('session_id', '')
    prompt = data.get('prompt', '')
    if not sid:
        sys.exit(2)
    safe = prompt.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"').replace('\n', ' ')
    print(f'SESSION_ID=\"{sid}\"')
    print(f'PROMPT=\"{safe}\"')
except Exception as e:
    print(f'# parse_error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>>"$LOG_FILE")
if [ -n "$PARSED" ]; then
  eval "$PARSED"
  PARSE_OK=1
fi

# Fallback: python3 실패 시 grep/sed로 session_id/prompt 추출
if [ "$PARSE_OK" -eq 0 ]; then
  SESSION_ID=$(echo "$STDIN_DATA" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  # prompt 단순 추출 (escape된 따옴표는 일단 잘릴 수 있으나 승인 키워드 매칭용으로 충분)
  PROMPT=$(echo "$STDIN_DATA" | grep -o '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  SESSION_ID=${SESSION_ID:-default}
  log "WARN fallback-grep used session_id=[$SESSION_ID] prompt_len=${#PROMPT}"
fi

GATE_FILE="/tmp/claude_gate_${SESSION_ID}"

# gate 파일 없으면 무시 (세션 초기화 전)
if [ ! -f "$GATE_FILE" ]; then
  exit 0
fi

# 빈 프롬프트 무시
if [ -z "$PROMPT" ]; then
  exit 0
fi

# 메시지 길이 체크 (50자 초과면 새 작업 가능성 — 단, 승인 키워드 포함 시 리셋하지 않음)
PROMPT_LEN=${#PROMPT}
if [ "$PROMPT_LEN" -gt 50 ]; then
  LOWER_CHECK=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')
  HAS_APPROVAL=false
  if echo "$LOWER_CHECK" | grep -qE '(진행|승인|확인|해봐|해줘|좋아|좋습니다|넵|네|ㄱㄱ|ㄱ|ㅇㅇ|ㅇ|고고)'; then
    HAS_APPROVAL=true
  fi
  if echo "$LOWER_CHECK" | grep -qE '(^|\s)(ok|okay|yes|y|go|proceed|approve|lgtm|sure)(\s|$)'; then
    HAS_APPROVAL=true
  fi
  # 승인 키워드 없는 긴 메시지 = 새 작업 요청 → gate 리셋
  if [ "$HAS_APPROVAL" = false ]; then
    echo "0" > "$GATE_FILE"
    exit 0
  fi
  # 승인 키워드 있는 긴 메시지 = 조건부 승인 → 아래로 계속 진행
fi

# 소문자 변환
LOWER_PROMPT=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# 승인 키워드 패턴 (짧은 메시지에서만 매칭)
APPROVED=false

# 한국어 승인
if echo "$LOWER_PROMPT" | grep -qE '(진행|승인|확인|해봐|해줘|좋아|좋습니다|넵|네|응|ㄱㄱ|ㄱ|ㅇㅇ|ㅇ|고고)'; then
  APPROVED=true
fi

# 영어 승인
if echo "$LOWER_PROMPT" | grep -qE '^(ok|okay|yes|y|go|proceed|approve|lgtm|sure|do it|ship it)'; then
  APPROVED=true
fi

# 숫자만 (선택지 응답: "1", "2", "3" 등)
if echo "$PROMPT" | grep -qE '^[0-9]+$'; then
  APPROVED=true
fi

if [ "$APPROVED" = true ]; then
  CURRENT=$(cat "$GATE_FILE" 2>/dev/null || echo "0")
  NEW_LEVEL=$((CURRENT + 1))
  log "APPROVE sid=$SESSION_ID prompt_len=${#PROMPT} current=$CURRENT new=$NEW_LEVEL"

  # --- task-docs 체이닝 검증 ---
  # gate 1→2 진입 시: analyze.md 존재 필수
  if [ "$CURRENT" -eq 1 ] && [ "$NEW_LEVEL" -eq 2 ]; then
    TODAY=$(date +%Y%m%d)
    CWD=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('cwd', '.'))
except:
    print('.')
" 2>>"$LOG_FILE")
    # Fallback: python3 실패 시 grep/sed
    if [ -z "$CWD" ] || [ "$CWD" = "." ]; then
      CWD_FB=$(echo "$STDIN_DATA" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
      [ -n "$CWD_FB" ] && CWD="$CWD_FB"
    fi
    TASK_DIR="$CWD/docs/tasks/$TODAY"

    if [ -d "$TASK_DIR" ]; then
      # A. 최근 30분 이내 수정된 서브디렉토리만 검사 대상
      # → 이전 작업 잔재(analyze만 있고 plan 없는 폴더)로 인한 오탐 차단
      RECENT_SUBDIR=$(find "$TASK_DIR" -mindepth 1 -maxdepth 1 -type d -mmin -30 2>/dev/null | head -1)
      if [ -n "$RECENT_SUBDIR" ]; then
        # CLAUDE.md §4 산출물 유연성: analyze / plan / result 중 1종 이상 있으면 통과.
        # 분석 단독 세션은 analyze.md 하나로, 작은 구현 세션은 result.md 하나로 완결 가능.
        STAGE_DOC=$(find "$RECENT_SUBDIR" \( -name "*analyze.md" -o -name "*plan.md" -o -name "*result.md" \) -type f 2>/dev/null | head -1)
        if [ -z "$STAGE_DOC" ]; then
          log "BLOCK stage doc missing subdir=$RECENT_SUBDIR"
          echo "[TASK-DOCS GATE] 단계 문서 미생성 — gate 1→2 차단. $RECENT_SUBDIR/ 에 analyze.md / plan.md / result.md 중 최소 1종을 생성하세요." >&2
          exit 2
        fi
      fi
      # 최근 30분 내 수정 서브디렉토리 없음 = 현재 세션은 task-docs 구조 미사용(또는 이전 완료 작업만 존재) → 통과
    fi
    # task_dir 자체가 없으면 S등급 경량 경로로 판단 → 통과
  fi

  # 최대 레벨 2로 제한
  if [ "$NEW_LEVEL" -gt 2 ]; then
    NEW_LEVEL=2
  fi
  echo "$NEW_LEVEL" > "$GATE_FILE"
  log "SAVED sid=$SESSION_ID gate=$NEW_LEVEL"
fi

exit 0
