#!/bin/bash
# UserPromptSubmit Hook: 사용자 승인 감지 → Gate 레벨 증가
# Phase 3 Harness — 승인 키워드가 포함된 짧은 메시지 감지
#
# 승인 키워드: 진행, 승인, 확인, ok, yes, go, ㄱ, ㄱㄱ, 해, 해봐, 네, 넵, 좋아, lgtm, y, ㅇ, ㅇㅇ
# 조건: 메시지 길이 50자 이하 + 승인 키워드 포함

STDIN_DATA=$(cat)

# session_id와 prompt 추출
eval "$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    sid = data.get('session_id', 'default')
    prompt = data.get('prompt', '')
    # shell-safe 출력
    print(f'SESSION_ID=\"{sid}\"')
    # 줄바꿈 제거, 따옴표 이스케이프
    safe = prompt.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"').replace('\n', ' ')
    print(f'PROMPT=\"{safe}\"')
except:
    print('SESSION_ID=\"default\"')
    print('PROMPT=\"\"')
" 2>/dev/null)"

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

  # --- task-docs 체이닝 검증 ---
  # gate 1→2 진입 시: analyze.md 존재 필수
  if [ "$CURRENT" -eq 1 ] && [ "$NEW_LEVEL" -eq 2 ]; then
    TODAY=$(date +%Y%m%d)
    CWD=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('cwd', '.'))
except:
    print('.')
" 2>/dev/null)
    TASK_DIR="$CWD/docs/tasks/$TODAY"

    if [ -d "$TASK_DIR" ]; then
      # task 디렉토리 안에 서브디렉토리가 있는지 확인
      SUBDIRS=$(find "$TASK_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
      if [ -n "$SUBDIRS" ]; then
        # 서브디렉토리 ��재 = 정식 경로 → analyze.md + plan.md 체���닝 검증
        ANALYZE_FOUND=$(find "$TASK_DIR" -name "*analyze.md" -type f 2>/dev/null | head -1)
        if [ -z "$ANALYZE_FOUND" ]; then
          echo "[TASK-DOCS GATE] analyze.md 미생성 — gate 1→2 차단. docs/tasks/$TODAY/{작업��}/analyze.md를 먼저 생성하세��." >&2
          exit 2
        fi

        PLAN_FOUND=$(find "$TASK_DIR" -name "*plan.md" -type f 2>/dev/null | head -1)
        if [ -z "$PLAN_FOUND" ]; then
          echo "[TASK-DOCS GATE] plan.md 미생성 — gate 1→2 차단. analyze.md→plan.md 순서를 준수하세��." >&2
          exit 2
        fi
      fi
      # 서브��렉토리 없음 (빈 폴더) = S등급 경��� 경로 → 통과
    fi
    # task_dir 자체가 없으면 S등급 경량 경로로 판단 → 통과
  fi

  # 최대 레벨 2로 제한
  if [ "$NEW_LEVEL" -gt 2 ]; then
    NEW_LEVEL=2
  fi
  echo "$NEW_LEVEL" > "$GATE_FILE"
fi

exit 0
