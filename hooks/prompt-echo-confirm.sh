#!/usr/bin/env bash
# prompt-echo-confirm.sh
# UserPromptSubmit Hook: 코드/분석 지시 프롬프트 감지 → Claude 에 echo-back 강제 신호 주입.
#
# 동작:
#   1. SKIP_HOOKS=1 → 즉시 통과
#   2. 빈 프롬프트 / 길이 < 10자 → 통과 (단답)
#   3. 부정 컨텍스트 (취소/보류/no/cancel 등) → 통과 (작업 거부 의사)
#   4. 승인 키워드 단독 (^진행$/^ok$ 등) → 펜딩 마커 제거 후 통과
#   5. 펜딩 마커 이미 존재 → 통과 (정정/추가 지시는 새 echo 안 띄움)
#   6. 코드/분석 트리거 키워드 매칭 → 펜딩 마커 생성 + stdout 으로 system reminder 주입
#
# 짝 hook: gate-approve.sh (UserPromptSubmit, 승인 키워드 → gate level 증가)
#         양쪽 hook 은 독립 동작. 본 hook 는 gate-approve.sh 미수정.
#
# SSOT: 본 hook + 글로벌 CLAUDE.md §4.4 "Echo-Back Confirm (필수)" 룰

# shellcheck disable=SC1091
source "$(dirname "$0")/lib/hook-input.sh"

hook_init
hook_read_stdin
hook_parse_session_id

PROMPT=$(hook_parse_field "prompt")

# --- 디버그 로그 설정 (2026-05-13 telemetry lib 마이그레이션) ---
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null || {
  LOG_FILE="$HOME/.claude/prompt-echo-confirm.log"
  log_event() {
    local hook="$1" event="$2"; shift 2
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$event] $*" >> "$LOG_FILE" 2>/dev/null
  }
}
log() { log_event "prompt-echo-confirm" "info" "$*"; }

PENDING_MARKER="/tmp/claude_echo_pending_${SESSION_ID}"

# --- 스킵 1: 빈 프롬프트 ---
if [ -z "$PROMPT" ]; then
  exit 0
fi

# --- 스킵 2: 길이 < 10자 (단답) ---
PROMPT_LEN=${#PROMPT}
if [ "$PROMPT_LEN" -lt 10 ]; then
  # 단답 중 승인 키워드면 마커 제거
  LOWER_SHORT=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')
  if echo "$LOWER_SHORT" | grep -qE '^[[:space:]]*(진행|승인|확인|오케이|오키|해|해봐|해줘|좋아|넵|네|ㄱ|ㄱㄱ|ㅇ|ㅇㅇ|ㅇㅋ|ok|okay|yes|y|go|lgtm|sure|approve|proceed|맞아|맞|맞음)[[:space:]!.?,~]*$'; then
    rm -f "$PENDING_MARKER" 2>/dev/null
    log "APPROVE_SHORT sid=$SESSION_ID len=$PROMPT_LEN — marker removed"
  fi
  exit 0
fi

LOWER_PROMPT=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# --- 스킵 3: 부정 컨텍스트 (gate-approve.sh §NEGATED 패턴 재사용) ---
NEGATED=false
if echo "$LOWER_PROMPT" | grep -qE '(안\s*(진행|승인|확인|해|되|돼)|하지\s*마|보류|취소|중단|멈춰|제외|말아|말자|말것|말 것)'; then
  NEGATED=true
fi
if echo "$LOWER_PROMPT" | grep -qE '(^|\s)(no|nope|stop|cancel|abort|hold|wait|never|don.?t|do not|not yet)(\s|$|[.!?,])'; then
  NEGATED=true
fi
if [ "$NEGATED" = true ]; then
  log "NEGATED sid=$SESSION_ID len=$PROMPT_LEN — skip"
  exit 0
fi

# --- 스킵 4: 승인 키워드 단독 (긴 프롬프트에 묻혀도 시작/종결부 매칭) ---
APPROVED_ONLY=false
if echo "$LOWER_PROMPT" | grep -qE '^[[:space:]]*(진행|승인|확인|오케이|오키|해|해봐|해줘|좋아|좋습니다|넵|네|응응|응|ㄱㄱ|ㄱ|ㅇㅇ|ㅇ|ㅇㅋ|고고|그래|콜|맞아|맞|맞음)([[:space:]!.?,~]|$)'; then
  APPROVED_ONLY=true
fi
if echo "$LOWER_PROMPT" | grep -qE "^[[:space:]]*(ok|okay|yes|y|go|proceed|approve|lgtm|sure|do it|ship it|let.?s go|lets go)([[:space:]!.?,~]|$)"; then
  APPROVED_ONLY=true
fi
# 승인 키워드 + 짧은 보충 (50자 이하)
if [ "$APPROVED_ONLY" = true ] && [ "$PROMPT_LEN" -le 50 ]; then
  rm -f "$PENDING_MARKER" 2>/dev/null
  log "APPROVE_LONG sid=$SESSION_ID len=$PROMPT_LEN — marker removed"
  exit 0
fi

# --- 스킵 5: 펜딩 마커 이미 존재 (정정/추가 지시는 통과) ---
if [ -f "$PENDING_MARKER" ]; then
  log "PENDING_EXIST sid=$SESSION_ID len=$PROMPT_LEN — skip new echo"
  exit 0
fi

# --- 스킵 6 (T1-b, 2026-05-11): 묶음 승인 후 60분 후속 면제 ---
# gate-approve.sh 가 BUNDLED_APPROVED=true 매칭 시 GATE_FILE 을 2 로 설정.
# 묶음 승인 직후 60분 내 후속 mutation/분석 지시는 의도 정리 단계 면제.
# — 단일 묶음 승인이 권고 처리 흐름 끝까지 자동 진행 보장.
# — 60분 초과 시 다시 Echo-Back 정상 발동 (새 작업으로 간주).
GATE_FILE="/tmp/claude_gate_${SESSION_ID}"
if [ -f "$GATE_FILE" ] && [ "$(cat "$GATE_FILE" 2>/dev/null)" = "2" ]; then
  # mtime 60분 이내 검사 (find -mmin 호환 — Windows Git Bash 동작 확인)
  if find "$GATE_FILE" -mmin -60 2>/dev/null | grep -q .; then
    log "BUNDLED_RECENT sid=$SESSION_ID len=$PROMPT_LEN — skip (gate=2, <60min)"
    exit 0
  fi
fi

# --- 트리거 키워드 매칭 (코드 mutation + 분석 + 실행) ---
TRIGGER=false

# 코드 mutation 키워드
if echo "$LOWER_PROMPT" | grep -qE '(만들어|만들자|만들|구현|추가|넣어|넣자|수정|고쳐|고치|리팩토링|리팩터링|리팩|디버그|디버깅|픽스|fix|버그|생성|create|삭제|지워|delete|이동|move|변경|바꿔|change|제거|remove|통합|merge|분리|split|적용|apply|연결|connect|리네임|rename|개선|향상|최적화|optimize)'; then
  TRIGGER=true
fi

# 분석 키워드
if [ "$TRIGGER" = false ] && echo "$LOWER_PROMPT" | grep -qE '(분석|analyze|조사|investigate|비교|compare|검토|review|점검|검사|확인해|살펴|audit|감사|리뷰|찾아|find|파악|대조|매핑|mapping|추적|trace|영향)'; then
  TRIGGER=true
fi

# 실행/배포 키워드
if [ "$TRIGGER" = false ] && echo "$LOWER_PROMPT" | grep -qE '(실행해|돌려|돌려줘|run해|run\s|배포|deploy|마이그레이션|migrate|롤백|rollback)'; then
  TRIGGER=true
fi

if [ "$TRIGGER" = false ]; then
  log "NO_TRIGGER sid=$SESSION_ID len=$PROMPT_LEN — skip"
  exit 0
fi

# --- 트리거 매칭 → 마커 생성 + system reminder 주입 ---
touch "$PENDING_MARKER" 2>/dev/null
log "TRIGGERED sid=$SESSION_ID len=$PROMPT_LEN — echo-back required"

cat <<'EOF'
<system-reminder>
[Echo-Back Confirm 룰 발동 — 글로벌 CLAUDE.md §4.4]

본 프롬프트는 코드/분석 지시로 판정되었습니다. 응답 절차 (필수):

1. **첫 단락 = 의도 정리 (echo back)** — "내가 이해한 바:" 로 시작. 사용자 프롬프트의 핵심 의도·작업 범위·산출물·예상 영향을 3~6줄로 압축 재출력.
2. **마지막 줄 = 승인 요청** — "위 정리가 맞으면 '진행/ok/맞아' 중 하나로 응답해주세요. 다르면 정정 부탁드립니다." 형태.
3. **승인 키워드 수신 전 mutation 도구 호출 금지** — Edit/Write/MultiEdit/NotebookEdit/Bash mutation(rm/mv/cp 변경계/git commit/git push/aws *변경계*/DB 변경 등) 모두 차단. 단 read-only 도구 (Read/Glob/Grep/git status/git log/git diff/aws *describe*/SELECT 등) 는 의도 정리 정확성을 위해 1~2건 허용.
4. **사용자 정정 시** = 의도 재정리 + 다시 승인 요청. 펜딩 마커는 유지.
5. **펜딩 마커 자동 정리** — `/tmp/claude_echo_pending_${SESSION_ID}` 가 마커. 본 hook 가 승인 키워드 단독 수신 시 자동 제거.

§3 Checkpoint 발동 작업은 본 룰 위에 추가 승인 절차 적용 (Checkpoint 가 우선).

본 시그널을 무시하고 곧장 mutation 도구를 호출하는 것은 글로벌 CLAUDE.md §4.4 위반입니다.
</system-reminder>
EOF

exit 0
