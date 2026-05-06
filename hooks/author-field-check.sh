#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# PreToolUse:Edit|Write|MultiEdit Hook — 산출물 frontmatter author/작성자 필드 위반 차단
#
# CLAUDE.md §4.1 "장기 관점 분석·계획·실행" 룰의 재발 방지 강제 수단.
# task-docs SKILL.md L128: 작성자 기본값 = jypark.
#
# 차단 대상: tool_input.content / new_string / edits[*].new_string 안에서
#            라인 시작 `^(작성자|author):` + `Claude` 포함 매칭.
# 정상값:    `작성자: jypark` / `author: jypark`.
# 예외:      .md 외 파일은 검증 제외.

source "$(dirname "$0")/lib/hook-input.sh"
hook_read_stdin
hook_parse_file_path

case "$FILE_PATH" in
  *.md|*.MD) ;;
  *) exit 0 ;;
esac

hook_python
if [ -z "$HOOK_PY" ]; then
  exit 0
fi

VIOLATING=$(echo "$STDIN_DATA" | "$HOOK_PY" -c '
import json, re, sys
try:
    data = json.load(sys.stdin)
    ti = data.get("tool_input", {})
    candidates = []
    if "content" in ti:
        candidates.append(ti["content"])
    if "new_string" in ti:
        candidates.append(ti["new_string"])
    if "edits" in ti:
        for e in ti["edits"]:
            if isinstance(e, dict) and "new_string" in e:
                candidates.append(e["new_string"])
    pattern = re.compile(r"^(작성자|author)\s*:\s*.*[Cc]laude.*$", re.MULTILINE)
    for text in candidates:
        if not isinstance(text, str):
            continue
        m = pattern.search(text)
        if m:
            print(m.group(0).strip())
            sys.exit(0)
except Exception:
    pass
' 2>/dev/null)

if [ -n "$VIOLATING" ]; then
  echo "[AUTHOR-FIELD] frontmatter 'author' / '작성자' 필드에 'Claude' 표기 차단:" >&2
  echo "  위반 라인: $VIOLATING" >&2
  echo "  정상값:    jypark (jypark 단독 author 정책)" >&2
  echo "  근거:      CLAUDE.md §4.1 '장기 관점 분석·계획·실행' 룰 — 재발 방지" >&2
  echo "             task-docs SKILL.md L128 — 작성자 기본값 = jypark" >&2
  exit 2
fi

exit 0
