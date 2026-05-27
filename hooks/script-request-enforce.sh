#!/bin/bash
# script-request-enforce.sh
# Stop Hook: 마지막 assistant 응답에 "비-§3 미스크립트 `! cmd` 실행요청"이 있으면 차단 → 재진입.
#
# 사용자 명시 승인: 2026-05-27 "실행요청을 할때는 스크립트생성해서 요청하는부분 강제시켜 자꾸 드리프트일으키네"
#   강제 강도 = 하드 차단(exit 2)+재진입 / 탐지 = 백틱 `! cmd` 토큰 정밀 / 예외 = 정상형 + §3.
#
# 동작:
#   1. SKIP_HOOKS=1 → 통과
#   2. transcript 마지막 assistant 텍스트에서 인라인 백틱 `! cmd` 토큰 추출 (python)
#   3. 분류: placeholder skip / 정상형(bash …docs/scripts…sh) skip / §3 skip / 그 외 = 위반
#   4. 위반 0 → exit 0. 위반 ≥1 → 5회 회로차단기 확인 후 exit 2 + 재진입 stderr
#   5. fail-open: transcript 부재 / python 실패 / 빈 텍스트 = exit 0
#
# 본 hook 은 §3 enforcer 가 아니다 — §3 차단 SSOT = dangerous-ops-guard.sh / branch-enforce.sh.
#   여기 §3 예외 목록은 "텍스트 §3 명령을 false-block 하지 않기" 용도의 generous(과다 면제) 목록.
#   over-exempt = 안전(드리프트 일부 누락) / under-exempt = 위험(§3 텍스트 안내 차단). 후자를 피한다.
#
# SSOT: 본 hook + CLAUDE.md §4.2 "사용자 직접 실행 명령 스크립트화" + feedback_script-request-enforce.md
# 짝 패턴: auto-iterate-stop-guard.sh (transcript 파서 + 5회 회로차단기 재사용)

[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0

# enter telemetry
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null
command -v log_event >/dev/null 2>&1 && log_event "script-request-enforce" "enter" "pid=$$"

STDIN_DATA=$(cat)
SESSION_ID=$(echo "$STDIN_DATA" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
SESSION_ID=${SESSION_ID:-default}
COUNTER_FILE="/tmp/claude_script_enforce_count_${SESSION_ID}"

# transcript 마지막 assistant 텍스트 추출 (auto-iterate-stop-guard 동일 파서)
TRANSCRIPT_PATH=$(echo "$STDIN_DATA" | grep -o '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    rm -f "$COUNTER_FILE" 2>/dev/null
    exit 0   # fail-open
fi

LAST_ASSISTANT_TEXT=$(tail -200 "$TRANSCRIPT_PATH" 2>/dev/null | python -c "
import sys, json
last_text = ''
for line in sys.stdin:
    try:
        d = json.loads(line)
        if d.get('type') != 'assistant':
            continue
        msg = d.get('message', {})
        if not isinstance(msg, dict):
            continue
        content = msg.get('content', [])
        if isinstance(content, list):
            for c in content:
                if isinstance(c, dict) and c.get('type') == 'text':
                    last_text = c.get('text', '')
        elif isinstance(content, str):
            last_text = content
    except Exception:
        pass
print(last_text)
" 2>/dev/null)

if [ -z "$LAST_ASSISTANT_TEXT" ]; then
    rm -f "$COUNTER_FILE" 2>/dev/null
    exit 0   # fail-open
fi

# 백틱 `! cmd` 토큰 추출 + 분류 (위반만 한 줄씩 출력)
VIOLATIONS=$(printf '%s' "$LAST_ASSISTANT_TEXT" | python -c "
import sys, re
text = sys.stdin.read()
tokens = re.findall(r'\`!\s+([^\`]+)\`', text)
viol = []
for raw in tokens:
    cmd = raw.strip()
    # placeholder/template (실제 실행요청 아님) → skip
    if re.search(r'[<>{}…]|\.\.\.', cmd):
        continue
    # 스크립트화 정상형 → OK
    if re.search(r'\bbash\s+\S*docs/scripts/\S+\.sh', cmd):
        continue
    # §3 절대차단(텍스트 안내 필수) → 예외 (generous: over-exempt 안전)
    if re.search(r'\bgit\s+push\b', cmd): continue
    if re.search(r'\bgit\s+(merge|checkout|switch)\b.*\b(main|master|origin/|upstream/)', cmd): continue
    if re.search(r'\bgit\s+worktree\s+remove\b', cmd): continue
    if re.search(r'\bgit\s+branch\s+-D\b', cmd): continue
    if re.search(r'\brm\s+-[rfRF]', cmd): continue
    if re.search(r'\b(migrate|rollback)\b', cmd): continue
    if re.search(r'\baws\s+', cmd): continue
    viol.append(cmd)
for v in viol:
    print(v)
" 2>/dev/null)

if [ -z "$VIOLATIONS" ]; then
    rm -f "$COUNTER_FILE" 2>/dev/null
    exit 0
fi

# 5회 회로차단기 — false-positive 가 재진입 응답에도 반복되면 무한 Stop block → 영구 wedge.
# auto-iterate-stop-guard.sh L149-163 패턴 재사용 (마커만 분리).
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
COUNT=$((COUNT + 0))
if [ "$COUNT" -ge 5 ]; then
    command -v log_event >/dev/null 2>&1 && log_event "script-request-enforce" "block" "circuit-breaker reset (count>=5)"
    rm -f "$COUNTER_FILE" 2>/dev/null
    cat >&2 <<'EOF'
[script-request-enforce — 재진입 한계 도달 (5회)]
- 비-§3 미스크립트 `! cmd` 탐지가 5회 반복됨 → 무한 Stop block 방지 위해 통과.
- false-positive 의심 (예: 본 hook 논의 중 예시 토큰). 비-§3 구체 명령은 백틱 인라인 대신
  플레이스홀더(`! <command>`) / §3 예시 / 백틱 없는 일반 텍스트로 기술.
- 실제 드리프트라면: ~/.claude/docs/scripts/*.sh 작성 후 `! bash …sh` 로 안내.
EOF
    exit 0
fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

command -v log_event >/dev/null 2>&1 && log_event "script-request-enforce" "block" "count=${COUNT} tokens=$(echo "$VIOLATIONS" | tr '\n' ';')"

{
  printf '[BLOCKED] 비-§3 실행요청 스크립트화 누락 (§4.2 / %s/5)\n' "$COUNT"
  printf '%s\n' '- 다음 `! cmd` 실행요청이 스크립트화 안 된 채 응답에 포함됨:'
  printf '%s\n' "$VIOLATIONS" | sed 's/^/    • /'
  cat <<'EOF'
- 조치: ~/.claude/docs/scripts/{yyyy-mm-dd-HHMM}-{sid8}-{slug}.sh 작성
        (shebang + set -euo pipefail + 본문 + 완료 echo + chmod +x) 후
        `! bash ~/.claude/docs/scripts/{file}.sh` 단일 라인으로만 안내.
- 비-§3 스크립트는 Claude 본체가 먼저 `bash {script}` 직접 호출 시도 (실패 시에만 ! 안내).
- §3 절대차단(git push / master·main 머지·체크아웃 / git worktree remove / git branch -D /
  rm -rf / DB 마이그·롤백 / aws 변경계)은 예외 — 텍스트 직접 안내 유지 (스크립트화 불가).
- false-positive(예시 토큰 등)면 비-§3 구체 명령을 플레이스홀더(`! <command>`) /
  §3 예시 / 일반 텍스트로 바꿔 재응답.
- SSOT: CLAUDE.md §4.2 / feedback_script-request-enforce.md.
EOF
} >&2

exit 2
