#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "git-quality-gate" "enter" "pid=$$"
# PreToolUse Hook: git commit 품질 게이트
# 통합: git-commit-lint.sh + single-purpose-commit.sh + no-test-no-merge.sh
# Fail-fast 순서: 1) 메시지 형식 → 2) 커밋 범위 → 3) 테스트 이력

# JSON 파싱 — lib/hook-input.sh SSOT (C3 2026-08-03)
#   구 코드는 python 을 `command -v` 로만 찾고 값 3개를 mapfile 로 받았다. python 이 검출되고
#   **실행만 실패**하면(Store 별칭 exit 9 · 크래시) _GQ 가 빈 배열 → COMMAND="" → 아래 `exit 0` 로
#   Conventional Commits + 커밋 범위 + No-Test-No-Merge 3단 게이트가 통째로 꺼졌다 (백스톱 0건).
#   lib 는 bash 정규식 → python → bash JSON 디코더 3단이라 python 없이도 명령 원문을 회수한다.
source "$(dirname "$0")/lib/hook-input.sh"
hook_read_stdin

TOOL_NAME=$(hook_parse_field tool_name)

# Bash 도구만 검사
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

hook_parse_session_id
hook_parse_cwd
hook_parse_command
# JSON 이스케이프된 \\ 를 실제 \ 로 복원 (Windows 경로 — bash 정규식 경로에서만 발생)
CWD="${CWD//\\\\/\\}"
# 의도된 의미 변경 (F9 2026-08-03): 구 python 파서는 `cmd.replace('\n',' ')` 로 명령을 한 줄로
#   눌러서 heredoc 커밋 본문 첫 줄과 제목 줄이 붙어버렸고, 그 때문에 heredoc 커밋이 형식 위반으로
#   **오차단**됐다 (실측 OLD rc=2 / NEW rc=0). lib 은 개행을 보존하므로 heredoc 정규식이
#   제목 줄만 정확히 집는다. 회귀 케이스 = hooks/tests/run-guard-tests.sh 의 heredoc 항목.

if [ -z "$COMMAND" ]; then
  exit 0
fi

# git commit 명령만 검사
if ! echo "$COMMAND" | grep -qE 'git\s+commit'; then
  exit 0
fi

# --amend, merge, --allow-empty 등 제외
if echo "$COMMAND" | grep -qE '(--amend|--allow-empty|--no-edit)'; then
  exit 0
fi

# ===== Phase 1: Conventional Commits 형식 검증 =====

COMMIT_MSG=""
resolve_python
if [ -n "$HOOK_PY" ]; then
  COMMIT_MSG=$(echo "$COMMAND" | "$HOOK_PY" -c "
import re, sys
cmd = sys.stdin.read().strip()
heredoc = re.search(r'<<[\x27]?EOF[\x27]?\s*\n(.*?)\nEOF', cmd, re.DOTALL)
if heredoc:
    msg = heredoc.group(1).strip().split('\n')[0].strip()
    print(msg)
    sys.exit(0)
m_match = re.search(r'-m\s+[\x22\x27](.*?)[\x22\x27]', cmd)
if m_match:
    print(m_match.group(1).strip().split('\n')[0].strip())
    sys.exit(0)
print('')
" 2>/dev/null)
fi

# python 부재·실행실패 시 bash 정규식 백스톱 (C3 2026-08-03) — 여기가 비면 Phase 1 이 통째로
#   건너뛰어져 규격 위반 커밋이 통과한다. 순서·의미는 위 python 판과 동일 (heredoc 우선 → -m).
if [ -z "$COMMIT_MSG" ]; then
  _re_heredoc=$'<<[\'"]?EOF[\'"]?[ \t]*\r?\n([^\n]*)'
  _re_m_dq=$'-m[ \t]+"([^"]*)"'
  _re_m_sq=$'-m[ \t]+\'([^\']*)\''
  if [[ "$COMMAND" =~ $_re_heredoc ]]; then
    COMMIT_MSG="${BASH_REMATCH[1]}"
  elif [[ "$COMMAND" =~ $_re_m_dq ]]; then
    COMMIT_MSG="${BASH_REMATCH[1]}"
  elif [[ "$COMMAND" =~ $_re_m_sq ]]; then
    COMMIT_MSG="${BASH_REMATCH[1]}"
  fi
  COMMIT_MSG="${COMMIT_MSG%%$'\n'*}"
  COMMIT_MSG="${COMMIT_MSG#"${COMMIT_MSG%%[![:space:]]*}"}"   # 좌 trim
  COMMIT_MSG="${COMMIT_MSG%"${COMMIT_MSG##*[![:space:]]}"}"   # 우 trim
fi

if [ -n "$COMMIT_MSG" ]; then
  VALID_TYPES="feat|fix|refactor|docs|test|chore|style|perf|ci|build|revert"

  if ! echo "$COMMIT_MSG" | grep -qE "^(${VALID_TYPES})(\([A-Za-z0-9_-]+\))?: .+"; then
    echo "[BLOCKED] 커밋 메시지 형식 위반 — Conventional Commits 규격 필수" >&2
    echo "" >&2
    echo "  현재: $COMMIT_MSG" >&2
    echo "  형식: type(scope): 제목" >&2
    echo "  허용 type: feat, fix, refactor, docs, test, chore, style, perf, ci, build, revert" >&2
    echo "  예시: feat(Commerce): 결제 API 추가" >&2
    echo "        fix: 인증 토큰 만료 처리 버그 수정" >&2
    command -v log_event >/dev/null 2>&1 && log_event "git-quality-gate" "block" "reason=commit-format"
    exit 2
  fi

  # 문자 단위 길이 (multibyte safe — 한국어 / em dash 정합, 2026-05-12 정정)
  # bash ${#var} 는 byte 단위 — 한국어 utf-8 (3 byte/char) + em dash (3 byte) 시 byte 계산 오류
  MSG_LEN=""
  [ -n "$HOOK_PY" ] && MSG_LEN=$(printf '%s' "$COMMIT_MSG" | "$HOOK_PY" -c "import sys; print(len(sys.stdin.read()))" 2>/dev/null)
  if [ -z "$MSG_LEN" ]; then
    # python 없는 경로의 문자 수 계산 (F3 2026-08-03) — fork 0.
    #   구 폴백 `${#COMMIT_MSG}` 는 **바이트**를 세서 한글 커밋을 거짓 차단했다. 실측:
    #   `feat(taskflow): watch G2 사전조사 …` = 67자 / 87바이트 → 72 초과로 rc=2.
    #   구 코드에서는 python 실패 시 COMMAND 가 비어 이 줄까지 오지 못했는데(=exit 0),
    #   C3 백스톱이 COMMAND 를 복구하면서 이 잠복 버그가 활성화됐다.
    #   로케일 판정: '한'(UTF-8 3바이트)의 길이가 1이면 bash 가 문자를, 3이면 바이트를 센다.
    _lc_probe=$'\xed\x95\x9c'
    if [ ${#_lc_probe} -eq 1 ]; then
      MSG_LEN=${#COMMIT_MSG}
    else
      _msg_lead="${COMMIT_MSG//[$'\x80'-$'\xbf']/}"   # UTF-8 연속바이트 제거 → 남은 = 문자당 1
      MSG_LEN=${#_msg_lead}
    fi
  fi
  if [ "$MSG_LEN" -gt 72 ]; then
    echo "[BLOCKED] 커밋 제목 72자 초과 (${MSG_LEN}자, 문자 단위) — 72자 이내로 줄이세요." >&2
    echo "  현재: $COMMIT_MSG" >&2
    command -v log_event >/dev/null 2>&1 && log_event "git-quality-gate" "block" "reason=title-length"
    exit 2
  fi
fi

# Co-Authored-By 차단은 dangerous-ops-guard.sh 에서 단일 처리 (SSOT) — 본 hook 에서는 검사하지 않음

# ===== Phase 2: 커밋 범위 검증 (1 커밋 = 1 변경) =====

STAGED_FILES=$(git diff --cached --name-only 2>/dev/null)

if [ -n "$STAGED_FILES" ]; then
  MODULE_COUNT=$(echo "$STAGED_FILES" | grep -oE 'app/Modules/[A-Za-z]+' | sort -u | wc -l)

  # 3개 이상 모듈 동시 변경 → 차단
  if [ "$MODULE_COUNT" -ge 3 ]; then
    MODULES=$(echo "$STAGED_FILES" | grep -oE 'app/Modules/[A-Za-z]+' | sort -u | sed 's|app/Modules/||')
    echo "[BLOCKED] 1 커밋 1 변경 위반 — ${MODULE_COUNT}개 모듈 동시 변경 감지" >&2
    echo "  모듈: $MODULES" >&2
    echo "  각 모듈별로 커밋을 분리하세요." >&2
    command -v log_event >/dev/null 2>&1 && log_event "git-quality-gate" "block" "reason=multi-module"
    exit 2
  fi

  # 모듈 코드 + docs + config 혼합 → 경고 (차단 아님)
  HAS_DOCS=$(echo "$STAGED_FILES" | grep -cE '^docs/' 2>/dev/null)
  HAS_CONFIG=$(echo "$STAGED_FILES" | grep -cE '^app/Config/' 2>/dev/null)
  HAS_MODULE=$(echo "$STAGED_FILES" | grep -cE '^app/Modules/' 2>/dev/null)

  if [ "$HAS_MODULE" -gt 0 ] && [ "$HAS_DOCS" -gt 0 ] && [ "$HAS_CONFIG" -gt 0 ]; then
    echo ""
    echo "━━━ 커밋 범위 경고 ━━━"
    echo "[WARNING] 모듈 코드 + docs + config가 혼합되어 있습니다."
    echo "  가능하면 코드/문서/설정을 별도 커밋으로 분리하세요."
    echo "━━━━━━━━━━━━━━━━━━━━━"
  fi
fi

# ===== Phase 3: 테스트 실행 이력 검증 =====

# --allow-empty는 이미 위에서 제외됨

TEST_FLAG="/tmp/claude_test_run_${SESSION_ID}"
if [ -f "$TEST_FLAG" ]; then
  exit 0
fi

# 테스트 프레임워크 없는 프로젝트 → 통과
HAS_TEST_FRAMEWORK=false
for marker in "phpunit.xml" "phpunit.xml.dist" "jest.config.js" "jest.config.ts" "pytest.ini" "pyproject.toml" "vitest.config.ts" "vitest.config.js"; do
  if [ -f "$CWD/$marker" ]; then
    HAS_TEST_FRAMEWORK=true
    break
  fi
done

if [ "$HAS_TEST_FRAMEWORK" = false ]; then
  exit 0
fi

# docs/config-only commit 면제 — markdown / 설정 파일 / 텍스트만 staged 시 통과
# (audit 권고: docs-only commit, hotfix, hook 수정 등 false positive 빈발 차단)
if [ -n "$STAGED_FILES" ]; then
  NON_DOCS=$(echo "$STAGED_FILES" | grep -vE '\.(md|markdown|txt|rst|json|ya?ml|toml|ini|conf)$|^docs/|^README|^CHANGELOG|^LICENSE' | head -1)
  if [ -z "$NON_DOCS" ]; then
    echo "[git-quality-gate] docs/config-only commit — 테스트 면제." >&2
    exit 0
  fi
fi

echo "[NO TEST, NO MERGE] git commit 차단 — 이번 세션에서 테스트를 실행한 이력이 없습니다." >&2
echo "  phpunit, composer test, npm test 등을 먼저 실행하세요." >&2
echo "  테스트 불필요한 변경이라면 사용자에게 확인 후 진행하세요." >&2
command -v log_event >/dev/null 2>&1 && log_event "git-quality-gate" "block" "reason=no-test"
exit 2
