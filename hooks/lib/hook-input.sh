#!/usr/bin/env bash
# hook-input.sh
# Claude Code hook 들의 stdin/JSON 파싱 공통 헬퍼.
# python3/python fallback + grep+sed graceful degrade 로 환경 차이 흡수한다.
#
# 사용 패턴:
#   #!/bin/bash
#   source "$(dirname "$0")/lib/hook-input.sh"
#   hook_init                    # SKIP_HOOKS=1 즉시 처리
#   hook_read_stdin              # STDIN_DATA 채움
#   hook_parse_session_id        # SESSION_ID 채움
#   hook_parse_command           # COMMAND 채움 (Bash 도구 hook)
#   # 이후 본 hook 의 로직 실행
#
# 규칙:
#   - 모든 함수는 부수효과로 전역 변수에 결과 채움 (return 값 사용 X)
#   - python 검출 결과는 HOOK_PY 변수에 캐시 (반복 호출 비용 0)
#   - python 실패 시 grep+sed fallback 으로 graceful degrade
#   - `set -e` 사용 금지 (호출하는 hook 마다 정책 다를 수 있음)

# ---------------------------------------------------------------------------
# hook_init
# ---------------------------------------------------------------------------
# SKIP_HOOKS=1 환경변수 검사 후 즉시 우회. stderr 에 1줄 기록.
hook_init() {
  if [ "${SKIP_HOOKS:-0}" = "1" ]; then
    echo "[SKIP] $0 SKIP_HOOKS=1" >&2
    exit 0
  fi
}

# ---------------------------------------------------------------------------
# resolve_python  (2026-08-03 — hook_python 의 실행검증 판)
# ---------------------------------------------------------------------------
# **실제로 한 번 실행해서 성공하는** 인터프리터만 채택. HOOK_PY 변수 캐시 (프로세스당 1회).
#
# Why `command -v` 로는 부족한가:
#   Windows Store 별칭(`.../WindowsApps/python3.exe`)이 PATH 앞에 놓이면 `command -v python3` 는
#   통과하고 실행은 exit 9 로 죽는다 — 2026-07-16 실발생(메모리 reference_gitbash-python3-store-alias.md).
#   그 결과 `[ -n "$HOOK_PY" ]` 로만 게이트한 가드들(branch-enforce §1.5/§1.6 · git-quality-gate ·
#   author-field-check)이 **조용히 fail-open** 했다: 검출은 성공, 판정은 공백.
#   → 후보를 `-c pass` 로 1회 실행해 exit 0 인 것만 HOOK_PY 로 승격한다.
#   실측 비용 = 37~39ms/프로세스 (PreToolUse 체인 2,877ms 대비 약 1.4%), 프로세스 내 1회 캐시.
#   `py` 는 Windows 런처 — python3/python 이 둘 다 Store 별칭에 가려졌을 때의 실 탈출구.
#
# 외부 주입(HOOK_PY=... 환경변수)은 존중한다 — 장애 재현 테스트의 진입점이다.
#   **주의: 주입된 인터프리터가 깨져 있으면 각 hook 은 grep/awk 백스톱으로 내려가는데, 백스톱은
#   git-guard.py 판정의 근사치다** (토큰화가 아닌 정규식). 정상 경로와 동일한 정확도를 보장하지
#   않으므로 주입은 테스트 용도로만 쓴다 — 상시 운용에서 python 을 일부러 죽이지 말 것.
resolve_python() {
  if [ -n "${HOOK_PY_RESOLVED:-}" ]; then
    return 0
  fi
  HOOK_PY_RESOLVED=1
  if command -v timeout >/dev/null 2>&1; then
    HOOK_PY_TIMEOUT="timeout ${HOOK_PY_TIMEOUT_SEC:-2}"
  else
    HOOK_PY_TIMEOUT=""
  fi
  if [ -n "${HOOK_PY:-}" ]; then
    return 0
  fi
  local _cand
  for _cand in python3 python py; do
    command -v "$_cand" >/dev/null 2>&1 || continue
    # 프로브는 HOOK_PY_TIMEOUT 으로 감싸지 않는다: 파이프도 stdin reader 도 없어 2026-07-30 에
    #   실측된 "고아 손자" 조건이 성립하지 않는다. 래핑하면 spawn 이 2개가 돼 56ms(vs 39ms).
    if "$_cand" -c "pass" >/dev/null 2>&1; then
      HOOK_PY="$_cand"
      return 0
    fi
  done
  HOOK_PY=""
}

# ---------------------------------------------------------------------------
# hook_python  [DEPRECATED — resolve_python 을 직접 부르세요]
# ---------------------------------------------------------------------------
# 2026-08-03 이전 이름. hooks/ 안 호출부는 전건 resolve_python 으로 이관했고, 본 별칭은
# 하니스 밖(플러그인·개인 스크립트) 미확인 호출부를 위해서만 남긴다. 신규 코드에 쓰지 말 것.
#
# HOOK_PY_TIMEOUT (2026-07-30): python 호출을 감싸는 `timeout N` prefix.
#   Why: hook 이 자체 timeout(3~5초)으로 kill 되면 Windows 에는 프로세스 그룹 kill 도
#   SIGPIPE 도 없어 파이프 안의 python 손자가 남고, stdout reader 가 사라진 write 에서
#   영구 블록한다 (2026-07-29 실측 — 14시간에 9건 잔존, `python3 git-guard.py all` 6건 +
#   인라인 `json.load(sys.stdin)` 3건). `timeout` 을 끼우면 부모가 죽어도 손자가 N초 뒤
#   스스로 회수된다 (부모 강제 kill 재현 후 검증 — 래핑 없음 = 잔존 / 래핑 = 3초 후 소멸).
#   값 2초 = git-guard.py 실측 308~1215ms 위 마진 + branch-enforce hook timeout(5초) 안.
#   사용 시 **unquoted** 로 전개해야 두 토큰으로 분리된다: `$HOOK_PY_TIMEOUT "$HOOK_PY" …`
#   timeout 부재 환경은 빈 문자열 → 기존 동작 그대로 (fallback 패턴 = HOOK_PY 와 동일).
hook_python() {
  resolve_python
}

# ---------------------------------------------------------------------------
# hook_read_stdin
# ---------------------------------------------------------------------------
# stdin 데이터를 STDIN_DATA 전역 변수에 저장. 빈 문자열이면 ""로 둠.
hook_read_stdin() {
  STDIN_DATA=$(cat 2>/dev/null || true)
  if [ -z "$STDIN_DATA" ]; then
    STDIN_DATA=""
  fi
}

# ---------------------------------------------------------------------------
# hook_parse_field "<field_name>"
# ---------------------------------------------------------------------------
# STDIN_DATA JSON 에서 특정 필드값 1개 추출. 결과는 stdout 으로 출력.
# python3/python → grep+sed fallback. 빈 값이면 빈 문자열 출력.
hook_parse_field() {
  local field="$1"
  local result=""
  if [ -z "$STDIN_DATA" ] || [ -z "$field" ]; then
    echo ""
    return 0
  fi
  # bash 내장 정규식 primary (fork/python 0) — 문자열 필드, 대부분 세션에서 python 起動(~367ms) 회피
  if [[ "$STDIN_DATA" =~ \"$field\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
    result="${BASH_REMATCH[1]}"
  fi
  # bash 로 안 잡히면(비문자열 bool·중첩·escape) python → grep fallback
  if [ -z "$result" ]; then
    resolve_python
    if [ -n "$HOOK_PY" ]; then
      result=$(echo "$STDIN_DATA" | "$HOOK_PY" -c "
import json, sys
try:
    data = json.load(sys.stdin)
    val = data.get('$field', '')
    if isinstance(val, bool):
        print('true' if val else 'false')
    elif val is None:
        print('')
    else:
        print(val)
except Exception:
    print('')
" 2>/dev/null | tr -d '\r')
    fi
  fi
  if [ -z "$result" ]; then
    result=$(echo "$STDIN_DATA" | grep -o "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')
  fi
  echo "$result"
}

# ---------------------------------------------------------------------------
# hook_json_string "<field_name>" ["all"]   (2026-08-03)
# ---------------------------------------------------------------------------
# STDIN_DATA 의 `"key": "값"` 을 **escape 해석해서** stdout 출력. python 없이 동작.
#   2번째 인자 "all" = 같은 키의 모든 문자열 값을 개행으로 이어 출력 (MultiEdit edits[*] 용).
#   종료코드: 0 = 성공 / 1 = 값 없음 / **3 = 디코드 불가 잔존** (surrogate pair 등 — 소비자는
#   3 을 "판정 불가" 로 받아 fail-closed 처리해야 한다. 값 자체는 부분 디코드분이 나온다).
#
# Why: `"key"…"([^"]*)"` 정규식(bash·grep 공통)은 escape 된 따옴표 `\"` 에서 값을 잘라먹는다.
#   커밋 메시지(`git commit -m \"...\"`)·문서 본문처럼 따옴표·개행을 품은 값은 truncate 되고,
#   소비자는 그걸 "값 없음/짧은 값" 으로 오인해 검사를 건너뛴다 (= fail-open). python 이 죽어 있을 때
#   이 함수가 정확도를 유지하는 마지막 단이다.
#
# `\uXXXX` (2026-08-03 정정): "하니스 JSON 에 \u 이스케이프 0건" 은 **오측이었다** — 실측 재조사
#   결과 transcript 40개에서 `\u` 이스케이프가 실재한다(제어문자·서로게이트). 그래서 원형 보존이
#   아니라 BMP 범위를 UTF-8 로 직접 디코드한다(python chr() 와 바이트 동일 확인: U+D55C·U+00E9·U+0001).
#   서로게이트 페어(U+D800~DFFF)만 미해결로 남기고 **exit 3** 으로 신고한다.
#   (구 주석의 "500개 초과분" 은 폐기된 구현의 잔재 — 현 코드에 그런 상한은 없다.)
#
# python 판 ↔ awk 판 바이트 동치: 12 대조 케이스 전건 동일. `\r`·`\b`·`\f` 도 그대로 살린다 —
#   초안은 이 3개를 조용히 버려 python 판과 1바이트씩 어긋났다(현 소비자엔 무영향이었지만
#   "두 경로가 같은 값을 준다" 는 계약이 깨져 있었다).
#
# 구현 주의 (실측 기반):
#   - 순수 bash 문자열 루프 판은 escape 1개당 payload 전체를 복사해 75KB 에서 **14.8초** → 폐기.
#   - awk 판도 초안은 `s = s $0 "\n"` 슬럽이 2차식이라 82KB=243ms / 342KB=2.8s / 684KB=10.5s /
#     1.37MB=43.7s 였다 (hook timeout 5초 → 450KB 이상 kill = 도로 fail-open). JSON 문자열 값은
#     raw 개행을 담을 수 없으므로 **레코드(줄) 단위로 처리**해 슬럽을 없앴다. 봉인 해제도
#     split+concat(O(n·k)) → gsub 1회(O(n))로 바꿨다 (gawk5 실측: 치환문자열 = backslash 1자 그대로).
hook_json_string() {
  local key="$1" mode="${2:-first}"
  if [ -z "$STDIN_DATA" ] || [ -z "$key" ]; then
    return 1
  fi
  printf '%s' "$STDIN_DATA" | awk -v key="$key" -v mode="$mode" '
    function hexval(c) { return index("0123456789abcdef", tolower(c)) - 1 }
    function utf8(n) {
      if (n < 128)  return sprintf("%c", n)
      if (n < 2048) return sprintf("%c%c", 192 + int(n/64), 128 + n%64)
      return sprintf("%c%c%c", 224 + int(n/4096), 128 + int(n/64)%64, 128 + n%64)
    }
    # escape 해석 결과를 **문자열로 쌓지 않고 즉시 출력**한다 (O(n)).
    #   gawk 의 gsub 은 1MB 값에서 4회 호출에 32.8초가 걸린다(실측) — 매 치환마다 문자열을
    #   재구성해 사실상 2차식이다. backslash 로 split 한 뒤 조각을 흘려보내면 같은 값이 ~0.1초다.
    #   부수 효과로 sentinel 봉인이 사라져 `` 이 봉인문자와 충돌하던 버그도 없어진다.
    function emit(val,   n, parts, i, p, c, rest, lit, hex, cp) {
      n = split(val, parts, BS)
      printf "%s", parts[1]
      lit = 0
      for (i = 2; i <= n; i++) {
        p = parts[i]
        if (lit) { printf "%s", p; lit = 0; continue }   # 앞 조각이 \\ 였다 → 이 조각은 리터럴
        if (p == "") { printf "%s", BS; lit = 1; continue }
        c = substr(p, 1, 1); rest = substr(p, 2)
        if (c == "n")      printf "\n%s", rest
        else if (c == "t") printf "\t%s", rest
        else if (c == "r") printf "\r%s", rest
        else if (c == "b") printf "%c%s", 8, rest
        else if (c == "f") printf "%c%s", 12, rest
        else if (c == "u" && length(p) >= 5) {
          hex = substr(p, 2, 4)
          cp = hexval(substr(hex,1,1))*4096 + hexval(substr(hex,2,1))*256 \
               + hexval(substr(hex,3,1))*16 + hexval(substr(hex,4,1))
          if (cp >= 55296 && cp <= 57343) { UNDEC = 1; printf "?%s", substr(p, 6) }  # surrogate pair
          else printf "%s%s", utf8(cp), substr(p, 6)
        }
        else if (c == "u") { UNDEC = 1; printf "%s", p }
        else printf "%s%s", c, rest                      # \" \\ \/ 등
      }
    }
    BEGIN { BS = sprintf("%c", 92); pat = "\"" key "\""; found = 0; UNDEC = 0 }
    {
      pos = 1
      while (1) {
        idx = index(substr($0, pos), pat)
        if (idx == 0) break
        after = pos + idx - 1 + length(pat)
        rest = substr($0, after)
        # `"key"` 뒤가 `: "` 가 아니면 문자열 값이 아니다 (null·숫자·객체) → 다음 출현 탐색
        if (match(rest, /^[ \t\r]*:[ \t\r]*"/) == 0) { pos = after; continue }
        vstart = after + RLENGTH
        v = substr($0, vstart)
        # 값 = escape 쌍(\\.) 또는 비따옴표·비백슬래시 문자의 최대 연속 → 그 끝이 닫는 따옴표
        if (match(v, /^(\\.|[^"\\])*/) == 0) { pos = after; continue }
        vlen = RLENGTH
        if (found) printf "\n"
        emit(substr(v, 1, vlen))
        found = 1
        if (mode != "all") exit 0
        pos = vstart + vlen + 1
      }
    }
    END { if (!found) exit 1; if (UNDEC) exit 3 }
  '
}

# ---------------------------------------------------------------------------
# hook_parse_content   (2026-08-03)
# ---------------------------------------------------------------------------
# Write 의 tool_input.content / Edit 의 new_string / MultiEdit 의 edits[*].new_string 을
# 개행으로 이어 CONTENT 전역 변수에 채운다 (본문을 검사하는 Edit|Write hook 공용 진입점).
# python → hook_json_string(awk) 2단. **degraded(python 부재) 에서도 MultiEdit 의 edits[*] 를
# 전건 수집한다** — 첫 new_string 만 보면 edits[1..] 안의 위반이 조용히 통과한다 (2026-08-03 F8).
#
# CONTENT_UNDECODED=1 (전역): 디코드 불가 이스케이프가 남아 판정을 신뢰할 수 없다는 신호.
#   소비자는 이 값이 1이면 "통과" 시키지 말고 fail-closed 로 처리해야 한다.
# 순서가 **awk 우선 · python 예비**인 이유 (2026-08-03 실측):
#   두 경로는 바이트 동치가 검증돼 있고(위 헤더), 본문 payload 는 MB 급이 될 수 있다.
#   python 을 먼저 두면 1MB payload 를 파이프로 밀어넣는 동안 `HOOK_PY_TIMEOUT`(2초)에 걸려
#   **kill → CONTENT 공백 → awk 로 같은 일을 다시** 하는 경로가 열린다 (부하 상황 실측:
#   share-guard 775KB = 4.3~5.0초로 hook timeout 5초에 근접). awk 를 먼저 돌리면 그 2초가 사라진다.
#   python 은 awk 가 디코드하지 못한 것(서로게이트 페어)이 남았을 때만 부른다 — 그 경우만
#   python 이 더 정확하다.
hook_parse_content() {
  CONTENT=""
  CONTENT_UNDECODED=0
  if [ -z "$STDIN_DATA" ]; then
    return 0
  fi
  local _c _n
  _c=$(hook_json_string content)
  [ $? -eq 3 ] && CONTENT_UNDECODED=1
  _n=$(hook_json_string new_string all)
  [ $? -eq 3 ] && CONTENT_UNDECODED=1
  if [ -n "$_c" ] && [ -n "$_n" ]; then
    CONTENT="$_c"$'\n'"$_n"
  else
    CONTENT="${_c}${_n}"
  fi
  # python 재시도 조건 = (a) awk 미해결 이스케이프 잔존 또는 (b) awk 부재 등으로 값을 못 얻음
  if [ "$CONTENT_UNDECODED" = "1" ] || { [ -z "$CONTENT" ] && [[ "$STDIN_DATA" == *'"content"'* || "$STDIN_DATA" == *'"new_string"'* ]]; }; then
    resolve_python
    if [ -n "$HOOK_PY" ]; then
      local _py
      # shellcheck disable=SC2086  # HOOK_PY_TIMEOUT 은 두 토큰으로 분리돼야 한다
      _py=$(printf '%s' "$STDIN_DATA" | $HOOK_PY_TIMEOUT "$HOOK_PY" -c "
import json, sys
try:
    ti = json.load(sys.stdin).get('tool_input') or {}
    out = []
    for k in ('content', 'new_string'):
        v = ti.get(k)
        if isinstance(v, str) and v:
            out.append(v)
    for e in (ti.get('edits') or []):
        if isinstance(e, dict) and isinstance(e.get('new_string'), str):
            out.append(e['new_string'])
    # buffer.write = **바이너리 출력**. text 모드로 쓰면 Windows 에서 \n 이 \r\n 으로 번역되고,
    # 그 CR 을 bash \${VAR//\$'\r'/} 로 지우는 데 760KB 기준 9.1초가 든다 (실측 — hook timeout 초과).
    sys.stdout.buffer.write('\n'.join(out).encode('utf-8', 'replace'))
except Exception:
    pass
" 2>/dev/null)
      if [ -n "$_py" ]; then
        CONTENT="$_py"
        CONTENT_UNDECODED=0     # python 이 서로게이트까지 정확히 디코드했다
      fi
    fi
  fi
}

# ---------------------------------------------------------------------------
# hook_parse_session_id
# ---------------------------------------------------------------------------
# session_id 추출 + 빈 값 시 "default" fallback. SESSION_ID 전역 변수.
hook_parse_session_id() {
  SESSION_ID=$(hook_parse_field "session_id")
  if [ -z "$SESSION_ID" ]; then
    SESSION_ID="default"
  fi
}

# ---------------------------------------------------------------------------
# hook_parse_cwd
# ---------------------------------------------------------------------------
# cwd 추출 + 빈 값 시 `pwd` fallback. CWD 전역 변수.
hook_parse_cwd() {
  CWD=$(hook_parse_field "cwd")
  if [ -z "$CWD" ]; then
    CWD=$(pwd)
  fi
}

# ---------------------------------------------------------------------------
# hook_parse_command
# ---------------------------------------------------------------------------
# tool_input.command 추출 (Bash 도구 hook 용). COMMAND 전역 변수.
hook_parse_command() {
  COMMAND=""
  if [ -z "$STDIN_DATA" ]; then
    return 0
  fi
  # 1단 bash 내장 정규식 = **escape 가 하나도 없는 명령 전용 fast-path**.
  #   이 정규식이 돌려주는 건 JSON 원문 조각이라 escape 가 해석돼 있지 않다. backslash 가 하나라도
  #   있으면 버리고 정확 디코드(2단 python → 3단 awk)로 내려간다.
  #
  #   구 조건은 `[[ "$STDIN_DATA" == *'\"'* ]]` — **따옴표 escape 가 있을 때만** 재파싱이라
  #   `\n`·`\\` 만 있는 명령은 원문 그대로 통과했다. 그 결과 여러 줄 명령이 git-guard.py 에
  #   **한 줄로** 전달돼 절 분리가 무너지고 push/merge 가 검출되지 않았다 (2026-08-03 실측:
  #   `cat <<EOF … EOF` + 개행 + `git push origin feature/x` → normal rc=0 = 주 경로 fail-open.
  #   따옴표가 우연히 섞인 같은 명령은 rc=2 라 재현이 들쭉날쭉했다).
  if [[ "$STDIN_DATA" =~ \"command\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
    COMMAND="${BASH_REMATCH[1]}"
    [[ "$COMMAND" == *\\* ]] && COMMAND=""
  fi
  if [ -z "$COMMAND" ]; then
    local _pycmd=""
    resolve_python
    if [ -n "$HOOK_PY" ]; then
      _pycmd=$(echo "$STDIN_DATA" | "$HOOK_PY" -c "
import json, sys
try:
    data = json.load(sys.stdin)
    cmd = data.get('tool_input', {}).get('command', '')
    print(cmd if cmd is not None else '')
except Exception:
    print('')
" 2>/dev/null | tr -d '\r')
      [ -n "$_pycmd" ] && COMMAND="$_pycmd"
    fi
    # 3단: python 부재·실패 시 bash JSON 디코더 (2026-08-03 — 구 grep+sed 대체)
    #   escape 된 따옴표를 품은 명령(`git commit -m \"…\"`)에서 1단 bash 정규식과 grep+sed 는
    #   똑같이 truncate 된다 → 소비자(git-quality-gate)가 메시지를 못 읽고 게이트를 건너뛴다.
    #   hook_json_string 은 escape 를 해석하므로 python 장애에서도 원문이 보존된다.
    if [ -z "$_pycmd" ]; then
      local _bashcmd
      _bashcmd=$(hook_json_string command)
      [ -n "$_bashcmd" ] && COMMAND="$_bashcmd"
    fi
  fi
}

# ---------------------------------------------------------------------------
# hook_parse_file_path
# ---------------------------------------------------------------------------
# tool_input.file_path 추출 (없으면 tool_response.filePath fallback). FILE_PATH 전역 변수.
hook_parse_file_path() {
  FILE_PATH=""
  if [ -z "$STDIN_DATA" ]; then
    return 0
  fi
  # bash 내장 정규식 primary (fork/python 0) — file_path 는 escape 드묾, 대부분 python 起動 회피
  if [[ "$STDIN_DATA" =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
    FILE_PATH="${BASH_REMATCH[1]}"
  elif [[ "$STDIN_DATA" =~ \"filePath\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
    FILE_PATH="${BASH_REMATCH[1]}"
  fi
  if [ -z "$FILE_PATH" ]; then
    resolve_python
    if [ -n "$HOOK_PY" ]; then
      FILE_PATH=$(echo "$STDIN_DATA" | "$HOOK_PY" -c "
import json, sys
try:
    data = json.load(sys.stdin)
    fp = data.get('tool_input', {}).get('file_path', '')
    if not fp:
        fp = data.get('tool_response', {}).get('filePath', '')
    print(fp if fp is not None else '')
except Exception:
    print('')
" 2>/dev/null | tr -d '\r')
    fi
  fi
  if [ -z "$FILE_PATH" ]; then
    FILE_PATH=$(echo "$STDIN_DATA" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')
    if [ -z "$FILE_PATH" ]; then
      FILE_PATH=$(echo "$STDIN_DATA" | grep -o '"filePath"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')
    fi
  fi
}

# ---------------------------------------------------------------------------
# hook_parse_stop_active
# ---------------------------------------------------------------------------
# stop_hook_active boolean 추출. STOP_HOOK_ACTIVE 전역 변수 ("true"/"false").
hook_parse_stop_active() {
  STOP_HOOK_ACTIVE="false"
  if [ -z "$STDIN_DATA" ]; then
    return 0
  fi
  # bash 내장 primary (bool 단순 패턴 — python 불필요, 원본 fallback 도 grep 이었음)
  if [[ "$STDIN_DATA" =~ \"stop_hook_active\"[[:space:]]*:[[:space:]]*true ]]; then
    STOP_HOOK_ACTIVE="true"
  fi
}
