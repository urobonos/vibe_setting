#!/usr/bin/env bash
# code-loop.sh — 분리 개발↔리뷰 루프를 "스텝 1개 = 프로세스 1개" 로 돌린다 (2026-09-16)
#
# 왜 스텝마다 프로세스인가:
#   메인에서 루프를 돌리면 루프가 태우는 도구 호출이 전부 메인 컨텍스트에 영구
#   누적되고 매 턴 cache_read 로 다시 읽힌다. 2026-09-16 실측(tick/code 세션 40개)
#   — 본체 Bash 7,449회 209만 토큰(73%) · 본체 Read 458회 49.8만(17%) · subagent
#   반환 588회 23.7만(7.6%). subagent 반환은 이미 1,121자 안팎으로 절단돼 들어오므로
#   줄일 여지가 없고, 남는 경로는 프로세스를 끊는 것뿐이었다.
#
#   루프 전체를 headless 1개로 빼는 것으로는 부족하다 — 그 러너가 라운드를 warm 하게
#   들고 있으면 누적이 메인에서 러너로 옮겨갈 뿐이다. 그래서 라운드가 아니라 스텝을
#   프로세스 경계로 삼는다. 어느 프로세스도 2스텝을 보지 않으므로 누적이 구조적으로 0이다.
#   대가는 스텝마다 cache_write 다 (read 의 20배 단가) — 그래서 스텝 수를 늘리지 않는다.
#
# 상태는 어디 있나:
#   전부 결과문서다. 프로세스 간에 넘어가는 것은 파일뿐이고, 셸은 VERDICT 줄만 읽어
#   분기한다. 판단(C·H·M 집계·반박 근거 3종 확인)은 여전히 모델이 하되 그 모델도 단발이다.
#
# 사용:
#   code-loop.sh "{구현 요청}"      루프 1회, RESULT.md 를 stdout 으로
#   code-loop.sh --resume {run}     중단된 run 을 마지막 스텝 다음부터
#   code-loop.sh status             run 목록
#
# 환경변수: CODE_LOOP_PERM(기본 auto) / CODE_LOOP_MODEL_{SPEC,DEV,REV,ADV}
# SSOT: custom-plugin/taskflow/commands/code-loop.md
set -uo pipefail

CLAUDE_HOME="$HOME/.claude"
STATE_DIR="$CLAUDE_HOME/state/code-loop"
CMD_DIR="$CLAUDE_HOME/custom-plugin/taskflow/commands"
# 크기 게이트 판정 줄 읽기 — hook(gate-enforce.sh)과 같은 함수를 쓴다. 러너 위치 기준으로
# 찾으므로 worktree 의 러너는 같은 worktree 의 lib 를 읽는다 (SSOT = custom-plugin/taskflow/hooks/lib/code-loop-gate.sh)
GATE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks/lib/code-loop-gate.sh"   # taskflow/bin → taskflow/hooks/lib
. "$GATE_LIB" 2>/dev/null
AGENT_DIR="$CLAUDE_HOME/custom-plugin/taskflow/agents"
PERM="${CODE_LOOP_PERM:-auto}"

# 스텝별 모델 — 개발자·리뷰어는 에이전트 정의 frontmatter 의 model: 을 그대로 읽는다.
# 사본을 두면 tick(Agent spawn)과 code-loop 가 다른 모델로 갈라진다. 전환 = /taskflow:models
agent_model() {
  sed -n '1,/^---$/{/^model:[[:space:]]*/{s///;s/[[:space:]]*$//;p;q;}}' "$AGENT_DIR/$1" 2>/dev/null
}
M_SPEC="${CODE_LOOP_MODEL_SPEC:-sonnet}"
M_DEV="${CODE_LOOP_MODEL_DEV:-$(agent_model step-developer.md)}"
M_DEV="${M_DEV:-sonnet}"
M_REV="${CODE_LOOP_MODEL_REV:-$(agent_model reviewer-correctness.md)}"
M_REV="${M_REV:-sonnet}"
# adversary 는 opus 고정이다. 이 역할만 "리뷰어가 통과시킨 것을 깨는" 일이고,
# 클린을 못 깨면 루프가 거기서 끝나므로 마지막 방어선의 판단력은 내리지 않는다
M_ADV="${CODE_LOOP_MODEL_ADV:-opus}"

# 2026-09-21 사용자 지시 "임시 캡제한 해제" — 기본 무제한(0). 되살리려면 환경변수로:
#   CODE_LOOP_DEV_CAP=5 CODE_LOOP_ADV_CAP=2 code-loop.sh "요청"
# 루프의 정상 종료는 캡이 아니라 판정이다 — dev 는 리뷰 CLEAN, adv 는 UPHELD.
DEV_CAP="${CODE_LOOP_DEV_CAP:-0}"   # 정규 라운드 캡 · 0 = 무제한
ADV_CAP="${CODE_LOOP_ADV_CAP:-0}"   # 적대적 게이트 캡 · 0 = 무제한
cap_label() { if [ "${1:-0}" -gt 0 ]; then printf '%s' "$1"; else printf '무제한'; fi; }

mkdir -p "$STATE_DIR"

# 개행을 먼저 지운다 — `sed` 는 줄 단위라 개행이 `[^a-z0-9]` 에 걸리지 않고,
# `cut -c1-40` 도 줄마다 따로 40자를 남긴다. 여러 줄 요청을 그대로 넘기면
# 각 줄이 디렉토리명 조각이 되어 `File name too long` 으로 죽는다 (2026-09-17 실측).
make_slug() {
  local s
  s=$(printf '%s' "$1" | tr '[:space:]' ' ' | tr '[:upper:]' '[:lower:]' \
      | sed 's/[^a-z0-9]\+/-/g; s/^-\+//; s/-\+$//' | cut -c1-40)
  [ -n "$s" ] || s="run"
  printf '%s' "$s"
}

usage() { sed -n '2,30p' "$0" | sed 's/^# \?//'; }

cmd_status() {
  # 토큰·비용은 스텝이 남긴 세션 jsonl 에서 읽는다 — 러너는 `claude -p` 를 띄우고
  # 끝나므로 자기가 쓴 양을 모른다. 집계는 헬퍼에 맡기고, 헬퍼가 없거나 python 이
  # 없으면 목록만 내고 계속한다 (조회가 집계에 종속되면 안 된다).
  local helper py
  helper="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/code-loop-usage.py"
  py=$(command -v python 2>/dev/null || command -v python3 2>/dev/null || true)
  if [ -n "$py" ] && [ -f "$helper" ]; then
    if CLAUDE_HOME="$CLAUDE_HOME" "$py" "$helper"; then return 0; fi
    echo "--- 사용량 집계 실패 — 목록만 낸다" >&2
  fi

  local found=0 d run rounds state
  for d in "$STATE_DIR"/*/; do
    [ -d "$d" ] || continue
    found=1; run=$(basename "$d")
    rounds=$(find "$d" -maxdepth 1 -name 'rev-*.md' 2>/dev/null | wc -l | tr -d ' ')
    if [ -f "$d/RESULT.md" ]; then state="완료"; else state="미완"; fi
    printf '%-46s %s  리뷰라운드 %s\n' "$run" "$state" "$rounds"
  done
  if [ "$found" = 1 ]; then
    # 진행 중인 run 을 눈으로 따라갈 방법을 여기서 알려준다 — 백그라운드로 띄우면
    # stdout 이 호출한 쪽으로 가버려서 터미널에는 아무것도 안 뜬다
    printf '\n진행 상황: tail -f %s/{run}/run.log\n' "$STATE_DIR"
  else
    echo "run 없음"
  fi
}

# 스텝 1회 시간 상한(분). 성공 run 222개의 스텝 소요(claude 기동 ~ 세션 마지막 기록) 최대치의
# 약 2~2.5배다 (2026-09-29 실측): dev 88.4분 → 180 · dev(adv) 46.8 → 100 · spec 38.3 / adv 40.0 /
# rev 37.9 → 100 · merge 16.4 / result 19.4 → 40. 전 스텝 일괄 재정의 = CODE_LOOP_STEP_TIMEOUT_MIN
step_timeout_min() {
  if [ -n "${CODE_LOOP_STEP_TIMEOUT_MIN:-}" ]; then echo "$CODE_LOOP_STEP_TIMEOUT_MIN"; return; fi
  case "$1" in
    *"(adv)")        echo 100 ;;
    dev-*)           echo 180 ;;
    merge-*|result)  echo 40 ;;
    *)               echo 100 ;;
  esac
}

# claude 를 시간 상한 안에서 돌린다. $1 분 / $2 출력 파일 / 나머지 = claude 인자, stdin 은 그대로 claude 로 간다.
# 상한을 넘기면 124. timeout 만으로는 claude 가 띄운 자식(Bash 도구의 bash·python 등)이 남는다
# (2026-09-29 재현: rc=124 뒤 python.exe 잔존). 그래서 --foreground 로 TERM 을 안쪽 bash 만 받게
# 하고, 그 trap 이 claude 래퍼의 *그 시점* winpid 로 taskkill //T 를 건다 — 기동 직후에 읽은 winpid 는
# 래퍼가 exec 하기 전 값이라 트리 뿌리가 아니었다(같은 날 재현, 수정 후 실 claude 3/3 잔존 0).
# 출력은 파이프가 아니라 파일로 받는다 — 트리 종료를 빠져나간 자손이 파이프를 쥐고 있으면 뒤의
# sed 가 그 자손이 끝날 때까지 막혀 상한이 무의미해진다(같은 날 stub 재현). taskkill 이 없으면 kill
claude_with_timeout() {
  local min="$1" outf="$2"; shift 2
  /usr/bin/timeout --foreground --kill-after=60 "${min}m" bash -c '
    o="$1"; shift
    claude "$@" <&0 > "$o" 2>&1 &
    c=$!
    trap '\''w=$(cat /proc/$c/winpid 2>/dev/null)
          { [ -n "$w" ] && taskkill //T //F //PID "$w" >/dev/null 2>&1; } || kill "$c" 2>/dev/null
          exit 124'\'' TERM
    wait "$c"' _ "$outf" "$@"
}

# 스텝 1개 = claude -p 1회. 출력 파일이 생겼는지로 성공을 판정한다 — exit 0 은
# 모델이 "못 하겠다"고 말하고 끝난 경우에도 나오므로 성공 신호가 못 된다
# $1 라벨 / $2 모델 / $3 허용 도구(비면 제한 없음) / $4 산출 파일 / $5 프롬프트
run_step() {
  local label="$1" model="$2" tools="$3" out="$4" prompt="$5" rc try=0 limit log
  limit=$(step_timeout_min "$label")
  while [ "$try" -lt 2 ]; do
    try=$((try + 1))
    echo "--- $(date '+%T') [$label] model=$model tools=${tools:-*} try=$try"
    log=$(mktemp)
    cd "$CLAUDE_HOME" || return 1
    # 프롬프트는 stdin 으로 준다. 인자로 주면 두 군데서 깨진다 (2026-09-16 실측):
    #   (a) 에이전트 정의가 --- 로 시작해서 CLI 가 옵션으로 파싱한다
    #       → error: unknown option '---
    #   (b) --allowed-tools 가 variadic 이라 뒤따르는 프롬프트까지 도구로 먹는다
    #       → Error: Input must be provided ...
    # MCP 서버는 띄우지 않는다 (--strict-mcp-config, --mcp-config 없이 = 서버 0개).
    # 설정된 Playwright MCP 가 매 스텝 `npx @playwright/mcp@latest` 로 떴는데, 스텝은
    # --allowed-tools 로 MCP 도구를 못 쓰고 실제 호출도 0건이었다. 그런데 기동이
    # 세션 시작을 막았다 — 225 스텝 실측에서 프로세스 기동부터 세션 첫 기록까지
    # 중앙 11초 · 평균 30초 · 최대 312초(5건, 타임아웃으로 보임) (2026-09-17).
    # 스킬 목록·자동 메모리도 싣지 않는다 — 첫 호출 67.5K → 50.8K(sonnet), 54.8K →
    # 41.3K(opus). 스텝 3,131 세션 전수에서 Skill 호출 1회·메모리 파일 읽기 3회뿐이었고,
    # 메모리 파일은 꺼도 경로로 직접 읽힌다 (2026-09-28).
    if [ -n "$tools" ]; then
      printf '%s' "$prompt" | CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 claude_with_timeout "$limit" "$log" -p --model "$model" \
        --strict-mcp-config --disable-slash-commands \
        --allowed-tools "$tools" --permission-mode "$PERM"
    else
      printf '%s' "$prompt" | CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 claude_with_timeout "$limit" "$log" -p --model "$model" \
        --strict-mcp-config --disable-slash-commands \
        --permission-mode "$PERM"
    fi
    rc=${PIPESTATUS[1]}
    sed 's/^/    /' "$log"; rm -f "$log"
    # 124 = 상한 도달(137 = TERM 뒤 60초 안에도 안 끝나 KILL). 결과문서에 TIMEOUT 으로 남긴다.
    # 멈춘 스텝은 다시 돌려도 같은 자리에서 멈출 공산이 커서 재시도하지 않는다
    if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then
      echo "TIMEOUT: [$label] try=$try ${limit}분 초과 (exit=$rc, $(date '+%F %T'))" >> "$(dirname "$out")/TIMEOUT.md"
      if [ -s "$out" ]; then
        echo "--- [$label] TIMEOUT(${limit}분) — 산출 파일은 있어 그대로 쓴다 ($(wc -c < "$out") bytes)"
        return 0
      fi
      echo "!!! [$label] TIMEOUT(${limit}분) — 산출 파일 없음, 재시도하지 않는다"
      return 1
    fi
    if [ -s "$out" ]; then
      echo "--- [$label] ok ($(wc -c < "$out") bytes)"
      return 0
    fi
    echo "--- [$label] 산출 파일 없음: $out (exit=$rc)"
  done
  return 1
}

# 결과문서 끝의 기계 판독용 한 줄. 없으면 계약 위반이므로 빈 값을 돌려 fail-closed.
# 표기 인정 범위는 GATE 줄(custom-plugin/taskflow/hooks/lib/code-loop-gate.sh)과 같다 — 앞의 공백·`#`·`>`·`*`, 값 뒤의
# 공백·`*` 허용(`## VERDICT: CLEAN` · `**VERDICT: UPHELD**`). 본문 언급(`- … VERDICT: …`)은 불인정.
# 2026-09-24 ISS-966 run 에서 합본이 헤더 표기로 써 "VERDICT 줄 없음" 중단이 두 번 났다
verdict_of() {
  grep -hE '^[[:space:]#>*]*VERDICT:' "$1" 2>/dev/null | tail -1 \
    | sed -E 's/^[[:space:]#>*]*VERDICT:[[:space:]*]*//; s/[[:space:]*]+$//'
}

# adversary UPHELD 의 "재현된 이탈:" 값이 "없음" 이 아닌가. 재현까지 한 결함을
# 성공 기준 밖이라며 잔여 의심으로 내리는 강등을 셸이 되돌리는 fail-safe (2026-09-28,
# UPHELD 8건 중 5건에서 남은 결함을 본체가 정착 직전에 고쳤다). 줄이 없으면(구 양식) 손대지 않는다
has_reproduced_deviation() {
  local value
  value=$(grep -hE '^[[:space:]#>*-]*재현된 이탈:' "$1" 2>/dev/null | tail -1     | sed -E 's/^[[:space:]#>*-]*재현된 이탈:[[:space:]*]*//; s/[[:space:]*.]+$//')
  [ -n "$value" ] && [ "${value#없음}" = "$value" ]
}

# 00-spec.md 의 WORKTREE: 한 줄 — 기계검사가 FILES 상대경로를 풀 기준점
worktree_of() {
  grep -h '^WORKTREE:' "$1" 2>/dev/null | tail -1 | sed 's/^WORKTREE:[[:space:]]*//'
}

# 경로 비교용 정규화 — 요청은 C:/…, spec 은 /c/… 로 적을 수 있다
norm_path() {
  local p="${1%/}"
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$p" 2>/dev/null || printf '%s' "$p"; else printf '%s' "$p"; fi
}

# spec 동안 백그라운드로 돈 vendor ensure 를 기다리고 그 출력을 run.log 에 붙인다.
# ensure 실패 문구는 직렬 경로와 같다
vendor_bg_join() {
  [ -n "${VENDOR_BG_PID:-}" ] || return 0
  local rc=0
  wait "$VENDOR_BG_PID" || rc=$?
  sed 's/^/    /' "$VENDOR_BG_LOG" 2>/dev/null; rm -f "$VENDOR_BG_LOG"
  echo "--- $(date '+%T') [vendor] ensure (bg) 종료 (exit=$rc): $VENDOR_BG_WT"
  [ "$rc" = 0 ] || echo "!!! [vendor] ensure 실패 — vendor 없이 진행한다 (기계검사는 도구가 없으면 skip)"
  VENDOR_BG_PID=""
  return 0
}

# dev-NN.md 의 FILES: 섹션에서 "- {path} — ..." 줄의 경로만 뽑는다
files_of() {
  awk '
    /^FILES:/ { f=1; next }
    f && /^[A-Z][A-Z-]*:/ { exit }
    f && /^- / { line=$0; sub(/^- /,"",line)
                 # 삭제한 파일은 검사할 게 없다 — "(삭제) 경로" 를 경로로 읽어 "파일 없음" 이 났다(run 20260929-073124)
                 if (line ~ /^\((삭제|deleted)\)/) next
                 sub(/ — .*/,"",line); sub(/[[:space:]]*$/,"",line); print line }
  ' "$1"
}

# 에이전트 정의 본문을 프롬프트 앞에 붙인다. 이 프로세스가 곧 그 에이전트다
# (Agent 도구로 spawn 하는 게 아니라 프로세스 자체가 역할을 수행한다)
#
# frontmatter 는 뺀다 — 메타데이터라 역할 수행에 필요 없고, 프롬프트가 --- 로
# 시작하면 CLI 가 옵션으로 파싱한다. 대신 그 안의 tools 는 agent_tools 가 뽑아
# --allowed-tools 로 넘긴다.
step_prompt() {
  printf '%s\n\n===\n\n%s\n' "$(agent_body "$1")" "$2"
}

# 정의 frontmatter 의 tools 줄 → --allowed-tools 인자 (콤마 구분, 공백 제거)
#
# **이게 없으면 "리뷰어는 코드를 고치지 않는다" 가 강제되지 않는다.** 정의의
# 도구 목록은 Agent 도구로 spawn 할 때만 자동 적용되고, claude -p 로 띄우면
# 아무 제한이 없다 — 리뷰어와 adversary 가 Edit/Write 를 쓸 수 있게 된다.
# 짠 쪽과 본 쪽을 가르는 것이 이 루프의 값 전부이므로 여기가 비면 루프가 무의미해진다.
# (2026-09-16 실측 — --allowed-tools 로 Write 를 빼면 실제로 파일을 못 쓴다)
agent_tools() {
  awk '/^---$/{n++; next} n==1 && /^tools:/{
         sub(/^tools:[[:space:]]*/, ""); gsub(/[[:space:]]/, ""); print; exit }' "$1"
}

# frontmatter 를 뺀 본문
agent_body() {
  awk '/^---$/{n++; next} n>=2' "$1"
}

# 개발자 반환의 한 절(REBUTTED·DEFERRED)에 주어진 등급의 항목(- [등급] …)이 있는가.
# 필드 자체는 매 라운드 "REBUTTED: 없음" 으로 들어오므로 단어만 보면 전 라운드가 걸린다
# (과거 537라운드 중 93%)
dev_section_has() {
  awk -v section="$2" -v grades="$3" '
    $0 ~ "^[#*[:space:]]*" section "([[:space:]:*]|$)" { in_section = 1; next }
    /^[#*[:space:]]*(FIXED|REBUTTED|DEFERRED|NOTES|FILES|TESTS|BASELINE|WHY|CRITERIA)([[:space:]:*]|$)/ { in_section = 0 }
    in_section && $0 ~ "^[[:space:]]*[-*][[:space:]]*[*]*[[](" grades ")[]]" { found = 1 }
    END { exit !found }' "$1" 2>/dev/null
}

# 두 리뷰어 판정을 셸이 결정적으로 합쳐 rev-NN.md 를 쓴다. 판단이 필요한 라운드면 1 을
# 돌려 LLM 합본으로 넘긴다 — ① 개발자가 REBUTTED 로 반박했다(수용·기각 판정 필요)
# ①' 개발자가 Critical~Medium 을 DEFERRED 로 넘겼다(리뷰어가 CLEAN 이어도 미해결 — ISS-969 rev-03)
# ② 리뷰어 문서가 반환 양식을 벗어났다(VERDICT 가 CLEAN/FINDINGS 가 아니거나, CLEAN 인데
# Critical~Medium 지적이 있거나, FINDINGS 인데 지적 줄이 하나도 안 읽힌다).
# 중복 지적은 합치지 않는다 — 원문 그대로 두 목록을 싣고 개발자가 한 번에 고친다.
merge_reviews_shell() {
  local dir="$1" nn="$2" role f v lines blockers body="" c=0 h=0 m=0
  dev_section_has "$dir/dev-$nn.md" REBUTTED 'Critical|High|Medium|Low' && return 1
  dev_section_has "$dir/dev-$nn.md" DEFERRED 'Critical|High|Medium' && return 1
  for role in correctness design; do
    f="$dir/rev-$nn-$role.md"
    v=$(verdict_of "$f"); v="${v%% *}"
    lines=$(grep -E '^[[:space:]]*[-*][[:space:]]*\**\[(Critical|High|Medium|Low)\]' "$f")
    blockers=$(printf '%s\n' "$lines" | grep -cE '\[(Critical|High|Medium)\]')
    case "$v" in
      CLEAN) [ "$blockers" -eq 0 ] || return 1 ;;
      FINDINGS) [ -n "$lines" ] || return 1 ;;
      *) return 1 ;;
    esac
    c=$((c + $(printf '%s\n' "$lines" | grep -c '\[Critical\]')))
    h=$((h + $(printf '%s\n' "$lines" | grep -c '\[High\]')))
    m=$((m + $(printf '%s\n' "$lines" | grep -c '\[Medium\]')))
    body+="
## $role — $v
${lines:-지적 없음}
"
  done
  {
    echo "# rev-$nn 합본 (셸)"
    echo
    echo "> 반박·양식 이탈이 없어 셸이 합쳤다. 근거·재현은 원문: rev-$nn-correctness.md · rev-$nn-design.md"
    echo "$body"
    if [ $((c + h + m)) -eq 0 ]; then echo "VERDICT: CLEAN"; else echo "VERDICT: FINDINGS C=$c H=$h M=$m"; fi
  } > "$dir/rev-$nn.md"
}

# 리뷰 1라운드 = 콜드 리뷰어 2인 병렬 + 합본. rev-NN.md 와 그 안의 VERDICT 줄을 남긴다.
#
# **dev-loop 와 adv-loop(BROKEN 재진입) 양쪽이 이 함수를 쓴다.** adversary 는 깨는
# 역할이지 판정 역할이 아니라서, 그것이 BROKEN 을 내고 개발자가 고친 변경도 반드시
# 이 라운드를 거쳐야 한다. 2026-09-16 ISS-570 실전 run 에서 그 수정분이 아무도 안 본 채
# 다음 게이트로 넘어갔다 — 결과적으로 UPHELD 라 무사했지만 무검증 변경이 클린을
# 달 수 있는 통로였다 (code-loop.md 는 "뺄 수 없다" 고 쓰고 구현이 안 지키고 있었다).
#
# $1 결과문서 디렉토리 / $2 라운드 번호(2자리) / $3 라운드 번호(정수) / $4 공통 프롬프트
review_round() {
  local dir="$1" nn="$2" n="$3" common="$4"
  [ -s "$dir/rev-$nn.md" ] && return 0

  local hist=""
  [ "$n" -gt 1 ] && hist="라운드 이력: $dir/rev-*.md — 이미 닫힌 판정을 다시 열지 않는다."
  local scope_note="" outside
  outside=$(scope_violations "$dir")
  if [ -n "$outside" ]; then
    { echo "# spec SCOPE_FILES 밖 변경 (라운드 $nn)"; echo; printf '%s\n' "$outside" | sed 's/^/- /'; } > "$dir/scope-$nn.md"
    echo "--- [scope-$nn] SCOPE_FILES 밖 변경 $(printf '%s\n' "$outside" | grep -c .)건"
    scope_note="spec SCOPE_FILES 밖에서 바뀐 파일이 있다: $dir/scope-$nn.md — 비목표를 넘었는지 판정한다."
  fi
  local rev_body="$common

너는 이 라운드의 콜드 리뷰어다. $dir/00-spec.md (대조 기준) 와 $dir/dev-$nn.md
(이번 변경 + BASELINE) 를 읽고, worktree 의 diff 를 실제로 돌려 판정한다.
셸 변이 검증 결과가 있으면 $dir/mut-$nn.md 도 읽는다 — GREEN 으로 남은 변이는 판별력 없는 테스트다.
$scope_note
$hist"

  run_step "rev-$nn-correctness" "$M_REV" "$(agent_tools "$AGENT_DIR/reviewer-correctness.md")" \
    "$dir/rev-$nn-correctness.md" \
    "$(step_prompt "$AGENT_DIR/reviewer-correctness.md" \
       "$rev_body
판정 결과를 $dir/rev-$nn-correctness.md 에 쓴다.")" &
  local p1=$!
  run_step "rev-$nn-design" "$M_REV" "$(agent_tools "$AGENT_DIR/reviewer-design.md")" \
    "$dir/rev-$nn-design.md" \
    "$(step_prompt "$AGENT_DIR/reviewer-design.md" \
       "$rev_body
판정 결과를 $dir/rev-$nn-design.md 에 쓴다.")" &
  local p2=$!
  wait $p1; local r1=$?
  wait $p2; local r2=$?
  if [ $r1 -ne 0 ] || [ $r2 -ne 0 ]; then
    echo "!!! 리뷰어 실패 (correctness=$r1 design=$r2) — 중단"
    return 1
  fi

  # 리뷰어가 인용한 테스트 수치를 셸이 직접 재실행해 대조 — dev측 verify_gate 와 대칭
  verify_rev_gate "$dir" "$nn" "$common" || return 1

  # 판단이 필요 없는 라운드는 셸이 합친다 — 합본 스텝(LLM)은 run 시간의 7% 였다
  if merge_reviews_shell "$dir" "$nn"; then
    echo "--- [merge-$nn] 셸 합본 ($(verdict_of "$dir/rev-$nn.md"))"
    return 0
  fi

  # 합본 + 반박 판정 — code.md 가 "본체" 에 맡긴 일이고, 그 본체도 여기선 단발이다
  local merge_body="$common

두 리뷰어 판정을 합쳐 $dir/rev-$nn.md 를 쓴다.
  입력: $dir/rev-$nn-correctness.md · $dir/rev-$nn-design.md · $dir/dev-$nn.md · $dir/00-spec.md
  합본 규칙 SSOT = $CLAUDE_HOME/custom-plugin/taskflow/references/review-contract.md 의 코드 축 절
  REBUTTED 가 있으면 $CLAUDE_HOME/custom-plugin/taskflow/references/review-contract.md 의 반박 판정 절에 있는 근거 3종을 직접 확인해
  수용·기각을 판정하고, 수용분은 REBUTTED-ACCEPTED 로 표시한다 (다음 라운드 재개봉 차단).
  BASELINE 전·후 명령이 다르거나 없으면 그 사실을 적는다 (관측 실패 — 라운드로 세지 않는다).
마지막 줄에 기계 판독용으로 정확히 한 줄:
  VERDICT: CLEAN                      (Critical·High·Medium 모두 0)
  VERDICT: FINDINGS C=n H=n M=n       (하나라도 잔존)"
  if ! run_step "merge-$nn" "$M_SPEC" "" "$dir/rev-$nn.md" "$merge_body"; then
    echo "!!! 합본 실패 — 중단"
    return 1
  fi
  return 0
}

# phpstan 에러 중 이번 diff 가 건드린 줄에 있는 것만 낸다 (raw 형식 `경로:줄:메시지`).
# 파일 전체를 판정하면 HEAD 에 이미 있던 에러까지 dev 탓이 된다 — run 20260928-230103(ISS-970)
# 에서 무관한 `Custom_helper.php:453` 1건이 매 라운드 불일치를 내 재보고 한도를 다 썼고, dev 는
# 그걸 없애려 범위 밖 코드를 고쳐 리뷰어 Medium 을 받았다. 추적 안 된 새 파일은 전 줄이 변경이다.
# 변경 줄이 아닌 곳에 생긴 파급 에러는 놓친다 — 그건 리뷰어가 diff 를 돌려 잡는 몫이다.
phpstan_new_errors() {
  local root="$1" rel="$2" out="$3" changed
  if ! git -C "$root" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
    printf '%s\n' "$out" | grep -E '\.php:[0-9]+:'
    return 0
  fi
  changed=$(git -C "$root" diff -U0 HEAD -- "$rel" | sed -nE 's/^@@ -[0-9,]+ \+([0-9]+)(,([0-9]+))? @@.*/\1 \3/p')
  printf '%s\n' "$out" | grep -E '\.php:[0-9]+:' | while IFS= read -r line; do
    local n start len
    n=$(printf '%s' "$line" | sed -nE 's/^.*\.php:([0-9]+):.*$/\1/p')
    [ -n "$n" ] || continue
    while read -r start len; do
      [ -n "$start" ] || continue
      len="${len:-1}"; [ "$len" -eq 0 ] && len=1
      if [ "$n" -ge "$start" ] && [ "$n" -lt $((start + len)) ]; then printf '%s\n' "$line"; break; fi
    done <<< "$changed"
  done
}

# dev-$nn.md 의 FILES: 목록에 php -l/php-cs-fixer/phpstan 을 셸이 직접 재실행한다.
# step-developer.md §"반환 전 기계 검사"와 같은 3종 — 자기신고가 아니라 셸이 판정한다.
# WORKTREE: 줄이 없거나(구버전 spec) 도구가 레포에 없으면 조용히 건너뛴다.
verify_mechanical() {
  local dir="$1" nn="$2" root fail=0 f abspath out
  root=$(worktree_of "$dir/00-spec.md")
  if [ -z "$root" ]; then
    echo "--- [dev-$nn] WORKTREE: 줄 없음 — 기계검사 skip"
    return 0
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in *.php) ;; *) continue ;; esac
    abspath="$root/$f"
    [ -f "$abspath" ] || abspath="$f"
    if [ ! -f "$abspath" ]; then
      echo "!!! [dev-$nn] 기계검사: 파일 없음 — $f"
      fail=1
      continue
    fi
    if command -v php >/dev/null 2>&1; then
      if ! out=$(php -l "$abspath" 2>&1); then
        echo "!!! [dev-$nn] 기계검사 불일치 — php -l 실패: $f"
        printf '%s\n' "$out" | sed 's/^/    /'
        fail=1
      fi
    fi
    local csfixer_bin=""
    if [ -x "$root/vendor/bin/php-cs-fixer" ]; then
      csfixer_bin="$root/vendor/bin/php-cs-fixer"
    elif command -v php-cs-fixer >/dev/null 2>&1; then
      csfixer_bin="php-cs-fixer"
    fi
    if [ -n "$csfixer_bin" ]; then
      if ! out=$(cd "$root" && "$csfixer_bin" fix --dry-run --diff "$abspath" 2>&1); then
        echo "!!! [dev-$nn] 기계검사 불일치 — php-cs-fixer: $f"
        printf '%s\n' "$out" | sed 's/^/    /'
        fail=1
      fi
    fi
    local phpstan_bin=""
    if [ -x "$root/vendor/bin/phpstan" ]; then
      phpstan_bin="$root/vendor/bin/phpstan"
    elif command -v phpstan >/dev/null 2>&1; then
      phpstan_bin="phpstan"
    fi
    # 테스트 파일은 phpstan 에서 뺀다 — 같은 파일에 정의한 스텁 클래스를 못 찾아
    # class.notFound 가 쏟아진다(run 20260928-120313 ISS-694: 156 errors, 재보고 캡 소진).
    # 도구 적용 범위 문제지 코드 결함이 아니다. php -l·php-cs-fixer 는 그대로 돈다
    case "$f" in tests/*|*/tests/*) phpstan_bin="" ;; esac
    if [ -n "$phpstan_bin" ]; then
      # worktree 밖(러너 cwd)에서 돌리면 그 자리의 config(또는 config 없음)를 주워 무관한
      # 클래스까지 "unknown class" 로 뜬다(실측 2026-09-22, run 20260922-160417) — 반드시
      # worktree 루트에서, 그 worktree 자신의 phpstan 로 돈다.
      if ! out=$(cd "$root" && "$phpstan_bin" analyse --no-progress --error-format=raw "$abspath" 2>&1); then
        local fresh
        if printf '%s\n' "$out" | grep -q 'No files found to analyse' \
           && ! printf '%s\n' "$out" | grep -qE '\.php:[0-9]+:'; then
          # 넘긴 파일이 phpstan.neon 의 excludePaths 안이다(app/Views 등). 제외 판정은 phpstan 자신에게
          # 맡긴다 — 러너가 neon 을 따로 읽으면 설정 해석이 두 벌이 되어 어긋날 때 반대로 오판한다.
          # 불일치로 치던 동안 view 만 바꾼 run 이 재보고 횟수를 헛되이 소진했다(run 723, 2026-09-29)
          echo "--- [dev-$nn] phpstan skip(excludePaths): $f"
        elif ! printf '%s\n' "$out" | grep -qE '\.php:[0-9]+:'; then
          # 에러 줄이 없는 실패 = 도구 자체 오류(설정·메모리). 걸러낼 기준이 없으니 그대로 불일치다
          echo "!!! [dev-$nn] 기계검사 불일치 — phpstan 실행 실패: $f"
          printf '%s\n' "$out" | sed 's/^/    /'
          fail=1
        elif fresh=$(phpstan_new_errors "$root" "$f" "$out") && [ -n "$fresh" ]; then
          echo "!!! [dev-$nn] 기계검사 불일치 — phpstan (변경 줄): $f"
          printf '%s\n' "$fresh" | sed 's/^/    /'
          fail=1
        else
          echo "--- [dev-$nn] phpstan: $f — 에러는 전부 변경 밖 줄(기존 코드), 불일치 아님"
        fi
      fi
    fi
  done < <(files_of "$dir/dev-$nn.md")
  return "$fail"
}

# 재실행 대상은 phpunit 실행 명령뿐이다. 리뷰어가 백틱에 경로만 적거나
# (`tests/unit/Filters/` → OK (387 tests…) — ISS-694 run.log) 옵션 조각을 적으면 그 토큰을
# eval 해 "매치 없음" 불일치가 났다. 임의 토큰 eval 의 부작용면도 여기서 닫는다
is_phpunit_cmd() {
  case "$1" in *[\;\&\|\>\<\`]*|*'$('*) return 1 ;; esac
  printf '%s' "$1" | grep -qE '^([^ ]*php(\.exe)? +)?[^ ]*vendor/bin/phpunit( |$)'
}

# BASELINE 의 "$ {명령}" 을 재실행해 "N tests, M assertions" 주장과 대조한다.
# phpunit 표준 형식일 때만 자동판정한다 — 실측(2026-09-22, dev-NN.md 전수 확인)으로
# BASELINE 이 diff/git status 같은 산문형도 흔해, 그 형태까지 일반화하면 오탐이 는다.
# 그 외 형태는 이 함수가 손대지 않고 재실행도 하지 않는다 (일반 명령 eval 은 phpunit
# 형식이 잡힐 때만 — 범위를 넓히면 임의 명령 재실행의 부작용면이 같이 넓어진다).
verify_baseline_counts() {
  local dir="$1" nn="$2" root fail=0 cmd claim actual claim_n actual_n
  root=$(worktree_of "$dir/00-spec.md")
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    claim=$(awk -v c="$cmd" '
      index($0, "$ " c) { found=1; next }
      found && /후[[:space:]]*[(:]/ { print; exit }
    ' "$dir/dev-$nn.md")
    case "$claim" in
      *tests*assertions*) ;;
      *) continue ;;
    esac
    claim_n=$(printf '%s' "$claim" | grep -oE '[0-9]+ tests?, *[0-9]+ assertions?' | head -1)
    [ -n "$claim_n" ] || continue
    is_phpunit_cmd "$cmd" || continue
    if [ -n "$root" ]; then
      actual=$(cd "$root" 2>/dev/null && eval "$cmd" 2>&1)
    else
      actual=$(eval "$cmd" 2>&1)
    fi
    actual_n=$(printf '%s' "$actual" | grep -oE '[0-9]+ tests?, *[0-9]+ assertions?' | head -1)
    if [ "$claim_n" != "$actual_n" ]; then
      echo "!!! [dev-$nn] 기계검사 불일치 — BASELINE 주장 vs 재실행 다름"
      echo "    명령: $cmd"
      echo "    주장(후): $claim_n"
      echo "    실측: ${actual_n:-매치 없음}"
      fail=1
    fi
  done < <(awk '/^BASELINE:/{b=1; next} b && /^[A-Z][A-Z-]*:/{exit} b && /^[[:space:]]*\$ /{sub(/^[[:space:]]*\$ /,""); print}' "$dir/dev-$nn.md")
  return "$fail"
}

# 00-spec.md 성공 기준마다 dev-$nn.md CRITERIA 에 증거 줄이 있는지 본다 (2026-09-28).
# 패치 후 70 run 의 라운드1 고유 지적 중 8~9건이 "성공 기준을 실행하지 않은 채 반환"
# (Skipped 를 통과로 읽음 · 변이 판별력 미시도 · spec 이 지정한 대조 생략)이었고, 개발자가
# NOTES 에 스스로 "실행하지 못했다" 고 적은 경우도 그대로 리뷰 라운드를 태웠다.
# 증거가 참인지는 리뷰어가 재실행해 판정한다 — 여기선 기준마다 줄이 있고 안 했다고
# 자백하지 않았는지만 본다. CRITERIA: 줄이 없는 spec(구버전)은 건너뛴다.
CRITERIA_UNDONE_RE='미실행|실행하지 (못|않)|실행 못|못 돌|돌리지 (못|않)|진행하지 (못|않)|미시도|시도하지 않|미확인|확인 못|못했|포기|넘어갔|빼먹|생략|TODO'
verify_criteria() {
  local dir="$1" nn="$2" want i line fail=0 section
  want=$(sed -nE 's/^[[:space:]#>*]*CRITERIA:[[:space:]*]*([0-9]+)[[:space:]*]*$/\1/p' "$dir/00-spec.md" 2>/dev/null | tail -1)
  [ -n "$want" ] || return 0
  # 섹션 제목은 `CRITERIA:` 와 `## CRITERIA` 가 섞여 온다 (2026-09-24~28 dev-01 37건 중
  # `## FIELD` 22 · `FIELD:` 15) — 둘 다 받고, 다음 필드 제목(어느 형식이든)에서 끊는다
  section=$(awk '/^[[:space:]#>*]*CRITERIA[[:space:]*]*:?[[:space:]*]*$/{b=1; next}
                 b && (/^[A-Z][A-Z-]*:/ || /^#+[[:space:]]/){exit} b' "$dir/dev-$nn.md")
  for i in $(seq 1 "$want"); do
    line=$(printf '%s\n' "$section" | grep -E "^[[:space:]*-]*\(?$i[).:][[:space:]]*[^[:space:]]" | head -1)
    if [ -z "$line" ]; then
      echo "!!! [dev-$nn] 성공 기준 $i/$want — CRITERIA 에 증거 줄 없음"
      fail=1
    elif printf '%s' "$line" | grep -qE "$CRITERIA_UNDONE_RE"; then
      echo "!!! [dev-$nn] 성공 기준 $i/$want — 실행하지 않았다고 적혀 있음"
      echo "    $line"
      fail=1
    fi
  done
  return "$fail"
}

# 성공 기준의 "변이 시 red" 를 셸이 실 소스 변이로 직접 확인한다 (2026-09-28).
# ISS-694: 기준 5 "offline 을 MENU_AUTH_PATHS 에서 빼면 red" 를 dev 가 변이를 흉내 내는
# 테스트(항상 참)로 "충족"했고 네 번 지적되고도 남았다 — red 요구는 자기신고로만 통과했다.
#
# 변이는 dev worktree 가 아니라 일회용 스크래치 worktree 에 가한다. 원복 실패가 구조적으로
# 없다(통째로 지운다). 스크래치 = HEAD + dev 의 diff(add -N 포함) + untracked 파일 + vendor-pool
# 하드링크 — junction 이 아니라서 --force 제거가 원본 vendor 를 지우지 않는다(vendor-pool.sh 머리말).
#
# 판정은 대조군이 있을 때만 한다: 변이 없이 같은 명령이 green 이어야 한다. green 이 아니면
# (환경 누락 등) red 가 변이 때문인지 가를 수 없어 판정 무효로 적고 dev 를 탓하지 않는다.
#
#   MUTATIONS: {n}                                          (00-spec.md — 변이 기준 개수)
#   MUTATION: {파일} | {원문 조각} ==> {변이 조각} | {phpunit 명령}   (spec 또는 dev-NN.md)
MUTATION_RED_RE='FAILURES!|ERRORS!|Tests: [0-9]+.*(Failures|Errors): [1-9]'
# 대조군이 exit 0 이어도 assertion 이 0 이면(전건 skip·테스트 0개) 변이도 당연히 통과한다 —
# 그걸 GREEN(약한 테스트)으로 적으면 dev 가 고칠 수 없는 걸로 재보고만 소진한다(run 20260929-073124)
MUTATION_VACUOUS_RE='Assertions: 0([^0-9]|$)|No tests executed|OK \(0 tests'

mutation_lines() {
  grep -hE '^[[:space:]#>*-]*MUTATION:' "$@" 2>/dev/null \
    | sed -E 's/^[[:space:]#>*-]*MUTATION:[[:space:]]*//; s/[[:space:]]+$//'
}

# 스크래치 worktree 에 dev worktree 의 현재 상태를 옮긴다. 옮긴 뒤 두 쪽의 변경 파일 집합이
# 다르면 1 — add -N 을 안 한 새 파일이 diff 에서 빠지는 함정을 여기서 잡는다.
# $3 = 진단 로그. 실패하면 어느 단계인지 stdout 에 한 줄로 내고, 그 단계의 stderr(대조 실패면 양쪽
# 경로 목록 차이)를 $3 에 남긴다 — 네 단계를 return 1 하나로 돌려주고 stderr 도 버려서, 간헐 실패
# (run 20260929-091648 mut-01 이식 불일치, 같은 worktree 재실행에선 미재현)의 원인을 가릴 수 없었다
mutation_scratch_prepare() {
  local root="$1" scratch="$2" err="$3" patch stale owner a b
  # 이전 검증이 도중에 죽어(kill·low-memory reap — SIGKILL 은 trap 이 못 잡는다) 남긴 스크래치를
  # 먼저 쓸어낸다. prune 은 디렉토리가 사라진 등록만 지우므로 살아 있는 고아는 직접 제거한다.
  # 단 소유 러너가 살아 있는 것은 건너뛴다 — 같은 레포에서 run 이 겹치면 남의 진행 중 스크래치를
  # 지워 그쪽 이식이 깨진다(동시 run 청소 경합 가설, 2026-09-29). owner.pid 가 없는 것은 이 규칙
  # 이전의 잔재라 고아로 본다
  git -C "$root" worktree list --porcelain | sed -n 's/^worktree //p' | grep -E '/code-loop-mut$' \
    | while IFS= read -r stale; do
        owner=$(cat "$(dirname "$stale")/owner.pid" 2>/dev/null)
        if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then continue; fi
        mutation_scratch_remove "$root" "$stale"
      done
  if ! git -C "$root" worktree add --detach -q "$scratch" HEAD 2>>"$err"; then
    echo "worktree add 실패"; return 1
  fi
  patch=$(mktemp)
  git -C "$root" diff HEAD --binary > "$patch" 2>>"$err"
  if [ -s "$patch" ] && ! git -C "$scratch" apply --whitespace=nowarn "$patch" 2>>"$err"; then
    rm -f "$patch"; echo "diff apply 실패"; return 1
  fi
  rm -f "$patch"
  git -C "$root" ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do
    mkdir -p "$scratch/$(dirname "$f")"
    cp -p "$root/$f" "$scratch/$f" 2>>"$err"
  done
  if [ -f "$scratch/composer.lock" ]; then
    if ! bash "$HOME/.claude/bin/vendor-pool.sh" ensure "$scratch" >>"$err" 2>&1; then
      echo "vendor-pool ensure 실패"; return 1
    fi
  fi
  # --untracked-files=all — 기본값은 새 디렉토리 속 untracked 를 디렉토리 한 줄로 접는다. dev 쪽은 add -N
  # 이라 파일 단위, 스크래치 쪽은 untracked 라 디렉토리 한 줄이 되어 새 디렉토리를 만드는 step 은
  # 늘 불일치였다 (run 20260929-110429 mut-01, 위 진단 로그로 확정)
  a=$(git -C "$root" status --porcelain --untracked-files=all | cut -c4- | sort)
  b=$(git -C "$scratch" status --porcelain --untracked-files=all | cut -c4- | sort)
  if [ "$a" != "$b" ]; then
    { echo "root 에만:";    comm -23 <(printf '%s\n' "$a") <(printf '%s\n' "$b") | sed 's/^/  /'
      echo "scratch 에만:"; comm -13 <(printf '%s\n' "$a") <(printf '%s\n' "$b") | sed 's/^/  /'; } >> "$err"
    echo "변경 파일 집합 불일치"; return 1
  fi
}

mutation_scratch_remove() {
  local root="$1" scratch="$2"
  git -C "$root" worktree remove --force "$scratch" 2>/dev/null
  git -C "$root" worktree prune 2>/dev/null
  rm -f "$(dirname "$scratch")/owner.pid"
  rmdir "$(dirname "$scratch")" 2>/dev/null
}

verify_mutations() {
  local dir="$1" nn="$2" want root lines count scratch report fail=0 line file from to cmd out rc before_sha
  report="$dir/mut-$nn.md"
  want=$(sed -nE 's/^[[:space:]#>*]*MUTATIONS:[[:space:]*]*([0-9]+)[[:space:]*]*$/\1/p' "$dir/00-spec.md" 2>/dev/null | tail -1)
  lines=$(mutation_lines "$dir/00-spec.md" "$dir/dev-$nn.md")
  count=$(printf '%s' "$lines" | grep -c .)
  [ "${want:-0}" -gt 0 ] || [ "$count" -gt 0 ] || return 0
  if [ "$count" -lt "${want:-0}" ]; then
    echo "!!! [dev-$nn] 변이 기준 ${want}건인데 MUTATION 줄은 ${count}건 — 변이 red 는 자기증명하지 말고 MUTATION 줄로 넘긴다"
    fail=1
  fi
  [ "$count" -gt 0 ] || return "$fail"
  root=$(worktree_of "$dir/00-spec.md")
  if [ -z "$root" ] || [ ! -d "$root" ]; then
    echo "!!! [dev-$nn] 변이 검증 불가 — WORKTREE 없음"
    return "$fail"
  fi
  scratch="$(mktemp -d)/code-loop-mut"
  # 소유 표시 — 다른 run 의 고아 청소가 이 러너가 살아 있는 동안은 이 스크래치를 건너뛴다
  echo "$$" > "$(dirname "$scratch")/owner.pid"
  { echo "# 셸 변이 검증 (dev-$nn)"; echo; } > "$report"
  local why errlog
  errlog=$(mktemp)
  if ! why=$(mutation_scratch_prepare "$root" "$scratch" "$errlog"); then
    echo "--- [mut-$nn] 스크래치 준비 실패(${why:-원인 미상}) — 판정 무효" | tee -a "$report"
    { echo; echo '진단 (stderr · 경로 목록 차이):'; echo '```'; cat "$errlog"; echo '```'; } >> "$report"
    rm -f "$errlog"
    mutation_scratch_remove "$root" "$scratch"
    return "$fail"
  fi
  rm -f "$errlog"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    file=$(printf '%s' "$line" | sed -E 's/[[:space:]]*\|.*$//')
    cmd=$(printf '%s' "$line" | sed -E 's/^.*\|[[:space:]]*//')
    from=$(printf '%s' "$line" | sed -E 's/^[^|]*\|[[:space:]]*//; s/[[:space:]]*\|[^|]*$//; s/[[:space:]]*==>.*$//')
    to=$(printf '%s' "$line" | sed -E 's/^[^|]*\|[[:space:]]*//; s/[[:space:]]*\|[^|]*$//; s/^.*==>[[:space:]]*//')
    if ! is_phpunit_cmd "$cmd" || [ -z "$from" ] || [ ! -f "$scratch/$file" ]; then
      echo "!!! [dev-$nn] MUTATION 줄 해석 불가 — $line" | tee -a "$report"
      fail=1; continue
    fi
    before_sha=$(sha256sum "$root/$file" 2>/dev/null | cut -d' ' -f1)
    out=$(cd "$scratch" && eval "$cmd" 2>&1); rc=$?
    if [ "$rc" -ne 0 ] || printf '%s' "$out" | grep -qE "$MUTATION_RED_RE"; then
      echo "--- [mut-$nn] 대조군이 green 이 아니다 — 판정 무효: $cmd" | tee -a "$report"
      continue
    fi
    if printf '%s' "$out" | grep -qE "$MUTATION_VACUOUS_RE"; then
      echo "--- [mut-$nn] 대조군 assertion 0(전건 skip·테스트 없음) — 실행 환경이 없어 판정 무효: $cmd" | tee -a "$report"
      continue
    fi
    cp -p "$scratch/$file" "$scratch/$file.mutation-orig"
    if ! python - "$scratch/$file" "$from" "$to" <<'PY'
import sys
path, before, after = sys.argv[1:]
text = open(path, encoding="utf-8").read()
if before not in text:
    sys.exit(1)
open(path, "w", encoding="utf-8", newline="").write(text.replace(before, after, 1))
PY
    then
      echo "!!! [dev-$nn] 변이 원문 조각이 $file 에 없다 — $from" | tee -a "$report"
      fail=1; continue
    fi
    out=$(cd "$scratch" && eval "$cmd" 2>&1); rc=$?
    mv -f "$scratch/$file.mutation-orig" "$scratch/$file"
    if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qE "$MUTATION_RED_RE"; then
      echo "- red ✓ $file: \`$from\` ==> \`$to\`" >> "$report"
    else
      echo "!!! [dev-$nn] 변이가 GREEN — 테스트가 이 변이를 판별하지 못한다: $file \`$from\` ==> \`$to\`" | tee -a "$report"
      fail=1
    fi
    if [ "$(sha256sum "$root/$file" 2>/dev/null | cut -d' ' -f1)" != "$before_sha" ]; then
      echo "!!! [dev-$nn] dev worktree 의 $file 이 변이 검증 중 바뀌었다 — 중단"
      mutation_scratch_remove "$root" "$scratch"
      return 2
    fi
  done <<< "$lines"
  mutation_scratch_remove "$root" "$scratch"
  return "$fail"
}

# spec 의 SCOPE_FILES 밖에서 바뀐 파일을 한 줄씩 낸다 (2026-09-28). 막지 않고 드러내기만 한다 —
# 필요한 범위 확장까지 막으면 run 이 교착된다. ISS-292 step-10: dev-02 가 비목표
# (getCallListCount() 내부 수정 금지)를 넘어 CallModel.php 를 고쳤는데 리뷰어 2축은 수정이
# 옳은지만 보고 범위 이탈을 결함으로 세지 않았다. SCOPE_FILES 줄이 없으면(구 spec) 아무것도 안 낸다.
#   SCOPE_FILES: {glob}, {glob} ...   (worktree 루트 기준, * 는 / 도 넘는다)
scope_violations() {
  local dir="$1" root scope changed glob inside
  scope=$(sed -nE 's/^[[:space:]#>*-]*SCOPE_FILES:[[:space:]]*//p' "$dir/00-spec.md" 2>/dev/null | tail -1 | tr ',' ' ')
  [ -n "$scope" ] || return 0
  root=$(worktree_of "$dir/00-spec.md")
  [ -n "$root" ] && [ -d "$root" ] || return 0
  git -C "$root" -c core.quotepath=off status --porcelain --untracked-files=all | cut -c4- | sed 's/^.* -> //; s/^"//; s/"$//' \
    | while IFS= read -r changed; do
        inside=0
        set -f
        for glob in $scope; do
          # shellcheck disable=SC2053 — glob 매칭이 의도다
          [[ "$changed" == $glob ]] && { inside=1; break; }
        done
        set +f
        [ "$inside" -eq 1 ] || printf '%s\n' "$changed"
      done
}

# dev-$nn.md 를 리뷰어에게 넘기기 전에 셸 독립 재실행으로 자기신고를 대체한다.
# 불일치는 코드 결함이 아니라 보고 오류이므로 정규 DEV_CAP 을 소비하지 않고,
# 별도의 작은 재시도만 소진한다 (2026-09-22 사용자 지시: "불일치시 캡소진안함").
#
# 재시도를 다 써도 불일치가 안 풀리면 런을 중단하지 않는다 — 이 게이트는 리뷰어를
# 대신하는 판정자가 아니라 리뷰어 토큰을 아끼는 값싼 전처리다. 못 푼 불일치는 그대로
# 리뷰어에게 넘긴다 — 리뷰어는 어차피 diff·BASELINE 을 자체 재실행해 판정하므로
# (review_round 프롬프트 "worktree 의 diff 를 실제로 돌려 판정한다") 자기신고를 안
# 믿는 건 똑같고, 못 고친 결함이면 FINDINGS 로 정규 캡을 쓰는 게 맞는 경로다.
# 셸이 죽어야 하는 건 재보고 스텝 자체가 실패(에이전트 프로세스 오류)할 때뿐이다.
VERIFY_RETRY_CAP=2
verify_gate() {
  local dir="$1" nn="$2" common="$3" try=0
  while :; do
    # 변이는 앞 단계와 독립으로 돈다 — 앞이 막히면 변이를 한 번도 안 보고 재보고 한도를 다 쓴다
    # (run 20260928-230103: phpstan 오판 3회로 변이 검증 0회). 변이는 자체 대조군(무변이 green)이
    # 있어 코드가 깨져 있으면 판정 무효로 끝나므로 앞 결과에 기대지 않아도 된다
    local mutation_rc=0 pre_ok=0
    verify_criteria "$dir" "$nn" && verify_mechanical "$dir" "$nn" && verify_baseline_counts "$dir" "$nn" || pre_ok=1
    verify_mutations "$dir" "$nn"; mutation_rc=$?
    [ "$mutation_rc" -eq 2 ] && return 1
    [ "$pre_ok" -eq 0 ] && [ "$mutation_rc" -eq 0 ] && return 0
    if [ "$try" -ge "$VERIFY_RETRY_CAP" ]; then
      break
    fi
    try=$((try + 1))
    echo "=== [dev-$nn] 셸 재검증 불일치 — 재보고 요청 $try/$VERIFY_RETRY_CAP"
    local fix_body="$common

방금 반환한 $dir/dev-$nn.md 가 셸 재검증(CRITERIA → 기계검사 → BASELINE 순, 앞이 실패하면 뒤는
안 돌았다. 변이는 이와 따로 매번 돈다)을 통과하지 못했다. 무엇이 걸렸는지는 run.log 의 위 !!! 줄에 있다. 실제 상태를 다시 확인해 같은 파일을 갱신 반환한다 —
새 라운드가 아니라 같은 dev-$nn.md 의 재보고다. 주장을 실측에 맞게 고치거나,
실측이 틀렸다면 그 근거를 NOTES 에 남긴다.
CRITERIA 에 빠졌거나 안 했다고 적힌 성공 기준은 실제로 실행해 증거를 붙인다. 환경 탓에
정말 못 돌리면 시도한 명령과 그 출력을 그 줄에 적는다 — 안 한 것을 한 것으로 적지 않는다.
변이가 GREEN 으로 걸렸으면 보고가 아니라 테스트를 고친다 — 그 테스트는 약속한 동작을 판별하지
못한다. 결과는 $dir/mut-$nn.md 에 있다.
갱신한 반환은 같은 경로 $dir/dev-$nn.md 에 다시 쓴다."
    rm -f "$dir/dev-$nn.md"
    if ! run_step "dev-$nn" "$M_DEV" "$(agent_tools "$AGENT_DIR/step-developer.md")" "$dir/dev-$nn.md" \
         "$(step_prompt "$AGENT_DIR/step-developer.md" "$fix_body")"; then
      echo "!!! [dev-$nn] 재보고 실패 — 중단"
      return 1
    fi
  done
  echo "=== [dev-$nn] 셸 재검증 재시도 소진($VERIFY_RETRY_CAP) — 중단하지 않고 리뷰어에게 넘긴다"
  return 0
}

# rev-$nn-{correctness,design}.md 안의 "`cmd` → OK (N tests, M assertions)" idiom 을
# 셸이 직접 재실행해 대조한다. dev측(BASELINE:/FILES:)과 달리 리뷰어 반환 양식엔
# 구조화 필드가 없어 이 1종 idiom만 취급한다 (2026-09-22 실측: state/code-loop 상
# rev 문서 63건이 이 정확한 형태 — 그 외 "무변경"·"바이트 일치" 서술은 자유서술에
# 흩어져 있고 명령의 실제 측정 범위와 주장의 범위가 어긋나는 사례가 확인돼 자동
# 대조 대상에서 제외했다. 새 필드를 리뷰어 계약에 추가하지 않는다 — 자유서술과
# 중복 기재되거나 뉘앙스가 손실된다).
verify_rev_baseline_counts_file() {
  local f="$1" root="$2" fail=0 line cmd claim_n actual actual_n
  [ -f "$f" ] || return 0
  while IFS= read -r line; do
    cmd=$(printf '%s' "$line" | sed -n 's/^[^`]*`\([^`]*\)`.*/\1/p')
    [ -n "$cmd" ] || continue
    claim_n=$(printf '%s' "$line" | grep -oE '[0-9]+ tests?, *[0-9]+ assertions?' | head -1)
    [ -n "$claim_n" ] || continue
    is_phpunit_cmd "$cmd" || continue
    if [ -n "$root" ]; then
      actual=$(cd "$root" 2>/dev/null && eval "$cmd" 2>&1)
    else
      actual=$(eval "$cmd" 2>&1)
    fi
    actual_n=$(printf '%s' "$actual" | grep -oE '[0-9]+ tests?, *[0-9]+ assertions?' | head -1)
    if [ "$claim_n" != "$actual_n" ]; then
      echo "!!! [$(basename "$f")] 리뷰 주장 재검증 불일치"
      echo "    명령: $cmd"
      echo "    주장: $claim_n"
      echo "    실측: ${actual_n:-매치 없음}"
      fail=1
    fi
  done < <(grep -E '`[^`]+`.*(→|->).*OK.*\([0-9]+ tests?,? *[0-9]+ assertions?\)' "$f")
  return "$fail"
}

VERIFY_REV_RETRY_CAP=2
verify_rev_gate() {
  local dir="$1" nn="$2" common="$3" root try=0 bad_c bad_d
  root=$(worktree_of "$dir/00-spec.md")
  while :; do
    verify_rev_baseline_counts_file "$dir/rev-$nn-correctness.md" "$root"; bad_c=$?
    verify_rev_baseline_counts_file "$dir/rev-$nn-design.md" "$root"; bad_d=$?
    if [ "$bad_c" -eq 0 ] && [ "$bad_d" -eq 0 ]; then
      return 0
    fi
    if [ "$try" -ge "$VERIFY_REV_RETRY_CAP" ]; then
      break
    fi
    try=$((try + 1))
    echo "=== [rev-$nn] 셸 재검증 불일치 — 리뷰어 재검토 요청 $try/$VERIFY_REV_RETRY_CAP"
    local fix_body="$common

방금 반환한 판정 파일의 테스트 수치 주장이 셸의 독립 재실행과 다르다(run.log 의
위 로그 참조). 실제 수치를 다시 확인해 같은 판정 파일을 갱신 반환한다 — 새
라운드가 아니라 같은 rev-$nn 의 재검토다."
    if [ "$bad_c" -ne 0 ]; then
      rm -f "$dir/rev-$nn-correctness.md"
      if ! run_step "rev-$nn-correctness" "$M_REV" "$(agent_tools "$AGENT_DIR/reviewer-correctness.md")" \
           "$dir/rev-$nn-correctness.md" \
           "$(step_prompt "$AGENT_DIR/reviewer-correctness.md" \
              "$fix_body
판정 결과를 $dir/rev-$nn-correctness.md 에 쓴다.")"; then
        echo "!!! [rev-$nn] correctness 재검토 실패 — 중단"
        return 1
      fi
    fi
    if [ "$bad_d" -ne 0 ]; then
      rm -f "$dir/rev-$nn-design.md"
      if ! run_step "rev-$nn-design" "$M_REV" "$(agent_tools "$AGENT_DIR/reviewer-design.md")" \
           "$dir/rev-$nn-design.md" \
           "$(step_prompt "$AGENT_DIR/reviewer-design.md" \
              "$fix_body
판정 결과를 $dir/rev-$nn-design.md 에 쓴다.")"; then
        echo "!!! [rev-$nn] design 재검토 실패 — 중단"
        return 1
      fi
    fi
  done
  echo "=== [rev-$nn] 셸 재검증 재시도 소진($VERIFY_REV_RETRY_CAP) — 중단하지 않고 합본 단계로 넘긴다"
  return 0
}

run_loop() {
  local request="$1" run="$2" resume="${3:-}" dir="$STATE_DIR/$2"
  mkdir -p "$dir"
  echo "=== $(date '+%F %T') code-loop 시작 (run=$run perm=$PERM)"
  echo "=== 결과문서: $dir"
  # 판정 lib 가 없으면 크기 게이트를 읽을 수 없다 — spec 스텝을 태우기 전에 멈춘다
  if ! declare -F code_loop_gate >/dev/null; then
    echo "!!! GATE 판정 lib 를 못 읽었다: $GATE_LIB — 중단"
    return 1
  fi

  local common="결과문서 디렉토리: $dir
루프 계약 SSOT = $CLAUDE_HOME/custom-plugin/taskflow/references/review-contract.md (루프 계약 절) · 흐름 = $CMD_DIR/code.md · 결과문서 규약 SSOT = $CMD_DIR/code-loop.md
필요한 문서는 직접 Read 한다. 머지·push 하지 않는다."

  # ── 1단계: 범위 확정 + worktree ───────────────────────────────────────
  VENDOR_BG_PID="" VENDOR_BG_WT="" VENDOR_BG_LOG=""
  if [ ! -s "$dir/00-spec.md" ]; then
    local spec_body="$common

루프 계약의 1단계(범위 확인)와 크기 게이트를 그대로 수행해 $dir/00-spec.md 를 쓴다.
담을 것: 요청 · 성공 기준(검증 가능하게) · 테스트 범위(케이스 단위) · 비목표 ·
커밋 type·scope · worktree 경로 · 형식 변경이면 파급면·결함면.
worktree 는 여기서 실제로 만들고 그 절대 경로를 문서에 박는다. 그와 별개로
기계 판독용으로 정확히 한 줄 추가한다 (dev 반환분을 셸이 재검증할 때 쓴다):
  WORKTREE: {절대경로}
성공 기준에는 1부터 번호를 매기고, 그 개수를 기계 판독용 한 줄로 따로 쓴다 (dev 반환의
기준별 증거를 셸이 대조할 때 쓴다):
  CRITERIA: {성공 기준 개수}
성공 기준 중 '이 변이에서 red' 를 요구하는 것의 개수를 한 줄로 쓴다 (없으면 0). 변이는 셸이
실 소스에 직접 가해 확인한다 — 테스트 안에서 변이를 흉내 내는 방식은 판별력이 0 이 된다(ISS-694):
  MUTATIONS: {변이 기준 개수}
대상 코드가 이미 있어 원문을 지금 확정할 수 있으면 변이마다 한 줄씩 쓴다 (새로 짤 코드면 dev 가 쓴다):
  MUTATION: {파일 상대경로} | {원문 조각} ==> {변이 조각} | {phpunit 명령}
수정을 허용하는 경로를 기계 판독용 한 줄로 쓴다 (worktree 루트 기준 glob, 쉼표 구분, * 는 / 도 넘는다 —
테스트 파일 경로도 넣는다). 셸이 이 밖의 변경을 리뷰어와 결과문서에 드러낸다:
  SCOPE_FILES: {glob}, {glob}
vendor 는 러너가 채운다(vendor-pool.sh ensure) — vendor 를 junction·symlink 로 링크하지 않는다.
마지막 줄에 기계 판독용으로 정확히 한 줄을 쓴다:
  GATE: OK          (성공 기준 3개 이하 — 진행)
  GATE: TOO-LARGE   (4개 이상 — /taskflow:plan 으로 넘길 것)

구현 요청:
$request"
    # 요청이 기존 worktree 를 WORKTREE: 줄로 이미 정해 왔으면 vendor 하드링크(4.6만 파일 · ~72초)를
    # spec 과 겹쳐 돌린다 — 예전엔 spec 이 끝난 뒤 직렬이라 매 run spec 구간에 그대로 더해졌다
    # (2026-09-29 run 11건). 그동안 spec 이 반쯤 링크된 vendor 를 보지 않게 vendor 명령을 막는다
    VENDOR_BG_PID="" VENDOR_BG_WT="" VENDOR_BG_LOG=""
    local req_wt
    req_wt=$(printf '%s\n' "$request" | grep -E '^[[:space:]]*WORKTREE:' | tail -1 | sed -E 's/^[[:space:]]*WORKTREE:[[:space:]]*//; s/[[:space:]]+$//')
    if [ -n "$req_wt" ] && [ -f "$req_wt/composer.lock" ] && [ -f "$CLAUDE_HOME/bin/vendor-pool.sh" ]; then
      VENDOR_BG_WT="$req_wt"; VENDOR_BG_LOG=$(mktemp)
      bash "$CLAUDE_HOME/bin/vendor-pool.sh" ensure "$req_wt" > "$VENDOR_BG_LOG" 2>&1 &
      VENDOR_BG_PID=$!
      echo "--- $(date '+%T') [vendor] ensure (bg): $req_wt"
      spec_body="$spec_body

(러너 공지) 이 worktree 의 vendor 는 지금 러너가 채우는 중이다. 이 단계에서는 vendor 를 쓰는
명령(phpunit · spark · phpstan · composer)을 실행하지 않는다 — 범위 확정에는 필요 없다."
    fi
    if ! run_step spec "$M_SPEC" "" "$dir/00-spec.md" "$spec_body"; then
      vendor_bg_join
      echo "!!! 1단계 실패 — 중단"
      return 1
    fi
    vendor_bg_join
  fi

  # 세 갈래다. 판정 줄이 없으면 진행하지 않는다 (fail-closed, code-loop.md §VERDICT 계약) —
  # 예전엔 TOO-LARGE 줄만 찾아서 헤더형 TOO-LARGE 와 판정 줄 없음을 전부 "진행" 으로 읽었다
  case "$(code_loop_gate "$dir/00-spec.md")" in
    OK) ;;
    TOO-LARGE)
      echo "=== 크기 게이트: 성공 기준 4개 이상 — 이 커맨드로 받지 않는다."
      echo "=== /taskflow:plan 경로를 쓴다. spec: $dir/00-spec.md"
      return 2 ;;
    *)
      echo "!!! 00-spec.md 에 GATE 판정 줄이 없다 — 크기 게이트를 못 받았다. 중단 (spec: $dir/00-spec.md)"
      return 1 ;;
  esac

  # 이 아래 스텝들이 코드를 쓸 수 있게 한다. gate-enforce.sh 의 plan-before 게이트는
  # 세션 SID8 로 REGISTRY 를 찾는데, 스텝마다 새 프로세스라 매번 새 SID8 이 나와
  # 원천적으로 닿지 못한다. 그 대신 이 경로의 00-spec.md 를 §계획으로 인정한다.
  # 변수는 포인터일 뿐이고 통과 판정은 hook 이 파일 실재와 GATE: OK 로 한다
  # (SSOT = custom-plugin/taskflow/hooks/gate-enforce.sh plan-before 절)
  export CODE_LOOP_SPEC="$dir/00-spec.md"

  # vendor 는 에이전트 재량에 두지 않고 러너가 채운다 (ISS-285 후속). 에이전트가 원본
  # vendor 로 junction 을 걸면 `git worktree remove --force` 가 그걸 따라가 원본을 지운다
  local spec_worktree
  spec_worktree=$(worktree_of "$dir/00-spec.md")
  if [ -n "$VENDOR_BG_WT" ] && [ -n "$spec_worktree" ] \
     && [ "$(norm_path "$VENDOR_BG_WT")" = "$(norm_path "$spec_worktree")" ]; then
    echo "--- [vendor] spec 과 겹쳐 이미 채웠다: $spec_worktree"
  elif [ -n "$spec_worktree" ] && [ -f "$spec_worktree/composer.lock" ]; then
    [ -n "$VENDOR_BG_WT" ] && echo "--- [vendor] spec 이 요청과 다른 worktree 를 골랐다 — 직렬 ensure 로 폴백"
    if [ -f "$CLAUDE_HOME/bin/vendor-pool.sh" ]; then
      echo "--- [vendor] ensure: $spec_worktree"
      bash "$CLAUDE_HOME/bin/vendor-pool.sh" ensure "$spec_worktree" \
        || echo "!!! [vendor] ensure 실패 — vendor 없이 진행한다 (기계검사는 도구가 없으면 skip)"
    else
      echo "!!! [vendor] vendor-pool.sh 없음 — ensure skip"
    fi
  fi

  # ── dev-loop ──────────────────────────────────────────────────────────
  local n nn verdict=""
  n=0
  while :; do
    n=$((n + 1))
    if [ "$DEV_CAP" -gt 0 ] && [ "$n" -gt "$DEV_CAP" ]; then break; fi
    nn=$(printf '%02d' "$n")
    echo "=== dev-loop 라운드 $n/$(cap_label "$DEV_CAP")"

    if [ ! -s "$dir/dev-$nn.md" ]; then
      local prev_rev="" whys=""
      if [ "$n" -gt 1 ]; then
        prev_rev="직전 지적: $dir/rev-$(printf '%02d' $((n - 1))).md 를 읽고 전건 처리한다."
        whys=$(ls "$dir"/dev-*.md 2>/dev/null | tr '\n' ' ')
      fi
      local dev_body="$common

너는 이 라운드의 개발자다. 앞 라운드를 기억하지 못하므로 문서로만 이어받는다.
먼저 $dir/00-spec.md 를 읽어 범위·성공 기준·비목표·worktree 경로를 확인한다.
${whys:+앞 라운드 기록: $whys — 각 파일의 WHY 섹션만 읽는다. 전문은 읽지 않는다.}
$prev_rev

구현 후 $dir/dev-$nn.md 를 쓴다. 섹션:
  FILES / TESTS / NOTES / BASELINE(착수 전·반환 전 같은 명령) / CRITERIA / WHY
CRITERIA 에는 00-spec.md 성공 기준마다 한 줄씩 \`{번호}: {실행한 명령·확인 방법} → {실제 결과}\`
를 적는다. 셸이 기준마다 줄이 있는지 대조하고, 없거나 안 했다고 적힌 기준은 리뷰 전에 되돌린다.
WHY 에는 무엇을 왜 그렇게 했는지 + 남겨둔 선택지와 이유 + 반박(REBUTTED)이면 근거
3종(도달 불가 / 상위 처리 / 비목표 매칭) 중 무엇인지를 적는다. 다음 라운드의 나는
이 WHY 만 보므로 여기 없으면 없는 것이다.
코드만 쓴다 — 커밋하지 않는다."
      if ! run_step "dev-$nn" "$M_DEV" "$(agent_tools "$AGENT_DIR/step-developer.md")" "$dir/dev-$nn.md" \
           "$(step_prompt "$AGENT_DIR/step-developer.md" "$dev_body")"; then
        echo "!!! dev-$nn 실패 — 중단"
        return 1
      fi
      # 셸 독립 재검증 — 이번에 새로 반환된 dev-$nn.md 만 검증한다. resume 으로
      # 기존 파일을 다시 만난 경우는 이전 프로세스에서 이미 통과했다고 간주한다
      verify_gate "$dir" "$nn" "$common" || return 1
    fi

    # 리뷰어 2인 병렬 + 합본 — adv-loop 의 BROKEN 재진입도 같은 함수를 쓴다
    review_round "$dir" "$nn" "$n" "$common" || return 1

    verdict=$(verdict_of "$dir/rev-$nn.md")
    echo "=== 라운드 $n 판정: ${verdict:-(VERDICT 줄 없음)}"
    case "$verdict" in
      CLEAN*)
        break ;;
      FINDINGS*)
        if [ "$DEV_CAP" -gt 0 ] && [ "$n" -eq "$DEV_CAP" ]; then
          echo "=== 캡 $DEV_CAP 소진 — 적대적 게이트를 돌리지 않는다 (깰 것이 없다)"
        fi ;;
      *)
        echo "!!! VERDICT 줄이 없다 — 계약 위반. 중단"
        return 1 ;;
    esac
  done

  # ── adv-loop ──────────────────────────────────────────────────────────
  local adv_verdict="(skipped)"
  case "$verdict" in
    CLEAN*)
      local m mm nn2
      m=0
      while :; do
        m=$((m + 1))
        if [ "$ADV_CAP" -gt 0 ] && [ "$m" -gt "$ADV_CAP" ]; then break; fi
        mm=$(printf '%02d' "$m")
        echo "=== adv-loop $m/$(cap_label "$ADV_CAP")"
        if [ ! -s "$dir/adv-$mm.md" ]; then
          local adv_body="$common

리뷰어들이 통과시킨 클린을 깬다. 입력:
  대조 기준      $dir/00-spec.md
  클린 판정 근거  $dir/rev-*.md 전문 (REBUTTED-ACCEPTED 포함)
  변경·BASELINE  $dir/dev-*.md + worktree diff
재현 없이 지적하지 않는다. 재현한 것은 성공 기준 밖이어도 잔여 의심으로 내리지 않는다
(adversary.md §\"재현된 이탈은 기준 밖이어도 BROKEN\"). UPHELD 면 \`재현된 이탈: 없음\` 줄을 쓴다.
결과를 $dir/adv-$mm.md 에 쓰고 마지막 줄에 정확히 한 줄:
  VERDICT: UPHELD           (못 깼다 — 시도 나열 필수)
  VERDICT: BROKEN           (깼다 — 재현 명령·출력 필수)
  VERDICT: BROKEN-UNDECIDED (입력이 부족해 판정 못 함)"
          if ! run_step "adv-$mm" "$M_ADV" "$(agent_tools "$AGENT_DIR/adversary.md")" "$dir/adv-$mm.md" \
               "$(step_prompt "$AGENT_DIR/adversary.md" "$adv_body")"; then
            echo "!!! adv-$mm 실패 — 중단"
            return 1
          fi
        fi
        adv_verdict=$(verdict_of "$dir/adv-$mm.md")
        echo "=== adv 판정: ${adv_verdict:-(없음)}"
        if [ "${adv_verdict%% *}" = UPHELD ] && has_reproduced_deviation "$dir/adv-$mm.md"; then
          adv_verdict="BROKEN (재현된 이탈 — 셸 승격)"
          echo "=== UPHELD 인데 재현된 이탈이 적혀 있다 — BROKEN 으로 승격"
        fi
        case "$adv_verdict" in
          UPHELD*)
            break ;;
          BROKEN-UNDECIDED*)
            # 입력 조립이 틀린 것이지 코드 문제가 아니다 — 캡에 넣지 않고 재스폰
            rm -f "$dir/adv-$mm.md"
            echo "=== 입력 조립 오류 — 캡에 넣지 않고 재스폰"
            continue ;;
          BROKEN*)
            # code.md: BROKEN 수정분은 반드시 리뷰 1라운드를 거친다. 그 라운드는 정규 캡에
            # 계상한다 — 게이트 캡이 정규 캡을 늘리는 통로가 되면 클린 직전에 라운드가 무한히 열린다
            n=$((n + 1))
            if [ "$DEV_CAP" -gt 0 ] && [ "$n" -gt "$DEV_CAP" ]; then
              echo "=== 정규 캡 소진 — 재현물을 잔여로 넘긴다"
              break
            fi
            echo "=== BROKEN — dev-loop 재진입 (라운드 $n, 정규 캡 계상)"
            nn2=$(printf '%02d' "$n")
            local fix_body="$common
적대적 검증이 깼다: $dir/adv-$mm.md 의 재현 명령·출력을 읽고 고친다.
범위는 $dir/00-spec.md 그대로다. $dir/dev-$nn2.md 를 쓴다 (FILES/TESTS/NOTES/BASELINE/WHY)."
            # dev-loop 의 dev 스텝과 같은 재개 가드. 없으면 --resume 이 끝난 수정을
            # 다시 태우고, 그때 덮이는 것은 코드가 아니라 **판정**이다 — adv 수정분이
            # "FILES: 없음"(고칠 코드가 없다)으로 끝나는 경우가 실재하고(2026-09-16
            # ISS-570 dev-02), 그 판정이 사라지면 왜 안 고쳤는지가 함께 사라진다
            if [ ! -s "$dir/dev-$nn2.md" ]; then
              if ! run_step "dev-$nn2(adv)" "$M_DEV" "$(agent_tools "$AGENT_DIR/step-developer.md")" "$dir/dev-$nn2.md" \
                   "$(step_prompt "$AGENT_DIR/step-developer.md" "$fix_body")"; then
                echo "!!! adv 수정 실패 — 중단"
                return 1
              fi
            else
              echo "--- [dev-$nn2(adv)] 기존 산출물 재사용 ($(wc -c < "$dir/dev-$nn2.md") bytes)"
            fi
            # adversary 수정분도 반드시 리뷰를 거친다 — 안 그러면 아무도 안 본 변경이
            # 클린을 달고 남는다 (adversary 는 깨는 역할이지 판정 역할이 아니다)
            review_round "$dir" "$nn2" "$n" "$common" || return 1
            verdict=$(verdict_of "$dir/rev-$nn2.md")
            echo "=== adv 수정분 리뷰 판정: ${verdict:-(VERDICT 줄 없음)}"
            case "$verdict" in
              CLEAN*) ;;   # 통과 — 다음 adv 회차로
              *)
                # 정규 루프로 되돌리지 않는다. 게이트 캡이 정규 캡을 늘리는 통로가 되면
                # 클린 직전에 라운드가 무한히 열린다 (code.md 와 같은 이유)
                echo "=== adv 수정분에 지적 잔존 — 잔여로 넘기고 게이트를 닫는다"
                break ;;
            esac
            ;;
          *)
            echo "!!! adv VERDICT 줄이 없다 — 계약 위반. 중단"
            return 1 ;;
        esac
      done ;;
  esac

  # ── 반환 ──────────────────────────────────────────────────────────────
  local result_body="$common

$dir 의 결과문서 전부를 읽고 메인 세션에 돌려줄 $dir/RESULT.md 를 쓴다.
담을 것: 변경 요약(파일·무엇을) · 라운드 로그(dev 라운드 수 · adv 회차 · 각 VERDICT) ·
잔여 핸드오프(범위밖·Low·재현물) · worktree 경로와 커밋 여부.
이것만 메인이 읽는다 — 여기 없는 것은 메인에 존재하지 않는다. 간결하게 쓴다."
  if ! run_step result "$M_SPEC" "" "$dir/RESULT.md" "$result_body"; then
    echo "!!! RESULT.md 생성 실패"
  fi

  local final_outside
  final_outside=$(scope_violations "$dir")
  if [ -n "$final_outside" ] && [ -s "$dir/RESULT.md" ] && ! grep -q '^> \[§3 범위 변경\]' "$dir/RESULT.md"; then
    { echo "> [§3 범위 변경] spec SCOPE_FILES 밖 수정 — 정착 전에 범위 확장 여부를 결정해야 한다:"
      printf '%s\n' "$final_outside" | sed 's/^/>   - /'
      echo
      cat "$dir/RESULT.md"; } > "$dir/RESULT.md.tmp" && mv -f "$dir/RESULT.md.tmp" "$dir/RESULT.md"
    echo "=== [§3 범위 변경] SCOPE_FILES 밖 수정 $(printf '%s\n' "$final_outside" | grep -c .)건 — RESULT.md 맨 위에 올림"
  fi

  # 마지막 dev 의 BASELINE 이 assertion 0 이면 이 CLEAN 은 실행 증거가 없다. 판정은 막지 않고
  # 정착 전에 반드시 보이게 맨 위에 올린다 (run 20260929-073124: 23건 전건 skip 인 채 CLEAN·UPHELD)
  local last_dev
  last_dev=$(ls "$dir"/dev-*.md 2>/dev/null | sort | tail -1)
  if [ -n "$last_dev" ] && [ -s "$dir/RESULT.md" ] && ! grep -q '^> \[미검증\]' "$dir/RESULT.md" \
     && awk '/^BASELINE:/{f=1} f&&/^[A-Z][A-Z-]*:/&&!/^BASELINE:/{exit} f' "$last_dev" | grep -qE "$MUTATION_VACUOUS_RE"; then
    { echo "> [미검증] 마지막 dev 의 BASELINE 이 assertion 0건(전건 skip 등) — 이 판정은 실행 증거 없이 났다. 정착 전에 실행 환경을 갖춰 다시 돌린다."
      echo
      cat "$dir/RESULT.md"; } > "$dir/RESULT.md.tmp" && mv -f "$dir/RESULT.md.tmp" "$dir/RESULT.md"
    echo "=== [미검증] BASELINE assertion 0 — RESULT.md 맨 위에 올림"
  fi

  echo "=== $(date '+%F %T') code-loop 종료 (dev=$verdict adv=$adv_verdict)"
  if [ -s "$dir/RESULT.md" ]; then
    echo
    echo "───────── RESULT.md ─────────"
    cat "$dir/RESULT.md"
    return 0
  fi
  echo
  echo "!!! RESULT.md 없음 — 이어서: code-loop.sh --resume $run"
  ls -1 "$dir" 2>/dev/null | sed 's/^/    /'
  return 1
}

# 루프 출력을 run.log 에 남기고 stdout 으로 미러링한다.
#
# 왜 tee 가 아니라 파일 우선인가:
#   `code-loop.sh … | head` 처럼 호출자가 stdout 을 일찍 닫으면 tee 가 SIGPIPE 로
#   죽고 그 다음 루프까지 죽는다 (2026-09-16 실측 — run.log 205 bytes 에서 중단,
#   RESULT.md 미생성). 수십 분짜리 루프가 조용히 중단되는 것이 최악이므로
#   루프는 파일에만 쓰고, stdout 은 tail 이 미러링한다. tail 이 죽어도 루프는 산다.
#
# 백그라운드로 띄우면 stdout 은 호출한 쪽으로 가버려 터미널에 아무것도 안 뜬다 —
# 그때 진행을 볼 창구가 이 파일이다 (tail -f).
tee_run() {
  local run="$1"; shift
  local dir="$STATE_DIR/$run" log="$STATE_DIR/$run/run.log"
  mkdir -p "$dir"
  acquire_run_lock "$dir" || return 1
  echo "로그: $log"
  : >> "$log"
  run_loop "$@" >> "$log" 2>&1 &
  local pid=$! rc
  # 잠금은 이 셸이 아니라 루프 프로세스를 가리킨다 — 호출한 셸이 먼저 죽어도 루프는 살아
  # 있으므로, 그때 잠금이 죽은 것으로 읽히면 같은 run 에 두 번째 루프가 붙는다
  echo "$pid" > "$dir/.lock/pid"
  # --pid 는 GNU coreutils 기능이다. 없으면 미러링을 포기하고 루프만 돌린다 —
  # 진행은 tail -f 로 따로 볼 수 있으므로 미러링 실패가 루프를 막아선 안 된다
  tail -n +1 -f --pid="$pid" "$log" 2>/dev/null || true
  wait "$pid"; rc=$?
  rm -f "$dir/.lock/pid"
  rmdir "$dir/.lock" 2>/dev/null
  return "$rc"
}

# 한 run 에는 루프 프로세스 하나만 붙는다. 2026-09-25 run 112255 에서 진행 중인 run 에
# --resume 이 한 번 더 들어와 dev-01 두 개가 같은 worktree 를 동시에 고쳤고, 클래스
# 중복선언 Fatal 끝에 둘 다 리뷰 전에 죽었다. mkdir 은 원자적이라 동시 기동 경합에서도
# 하나만 이긴다. 잠금을 쥔 PID 가 이미 죽었으면(강제 종료 잔재) 넘겨받는다.
acquire_run_lock() {
  local lock="$1/.lock" holder
  if mkdir "$lock" 2>/dev/null; then
    echo "$$" > "$lock/pid"
    return 0
  fi
  holder=$(cat "$lock/pid" 2>/dev/null)
  if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
    echo "!!! 이미 실행 중인 run 이다 (PID $holder) — 중복 기동 거부: $1"
    echo "    진행 상황: tail -f $1/run.log"
    return 1
  fi
  echo "--- 죽은 잠금 인수 (PID ${holder:-기록 없음})"
  echo "$$" > "$lock/pid"
}

case "${1:-}" in
  ""|-h|--help)
    usage ;;
  status)
    cmd_status ;;
  --resume)
    if [ -z "${2:-}" ]; then
      echo "run 이름이 필요하다. 목록 = code-loop.sh status"; exit 1
    fi
    if [ ! -s "$STATE_DIR/$2/00-spec.md" ]; then
      echo "재개 불가 (00-spec.md 없음): $2"; exit 1
    fi
    tee_run "$2" "" "$2" resume ;;
  *)
    RUN="$(date '+%Y%m%d-%H%M%S')-$(make_slug "$1")"
    tee_run "$RUN" "$1" "$RUN" ;;
esac
