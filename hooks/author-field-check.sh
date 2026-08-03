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

# early-exit 최적화 (2026-07-03): .md 판정을 lib source 전 bash 내장으로 수행.
#   대부분 편집은 .md 가 아니라 즉시 exit → lib source (log-helper + hook-input) fork 세금 회피.
#   Windows Git Bash 는 fork 당 40~100ms → early-exit hook 도 수백 ms 소요하던 것을 제거.
STDIN_DATA=$(cat 2>/dev/null)
_fp=""
[[ "$STDIN_DATA" =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && _fp="${BASH_REMATCH[1]}"
[ -z "$_fp" ] && [[ "$STDIN_DATA" =~ \"filePath\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && _fp="${BASH_REMATCH[1]}"
case "$_fp" in
  *.md|*.MD) ;;
  "") ;;          # file_path 추출 실패(드묾) → early-exit 하지 않고 lib 재파싱에 위임 (원본 3단 fallback 견고성 보존)
  *) exit 0 ;;
esac

# .md 확정/미상 (드문 경로) → lib source + telemetry
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "author-field-check" "enter" "pid=$$"
source "$(dirname "$0")/lib/hook-input.sh"
# 추출 성공분은 재사용, 실패분만 python fallback 포함 lib 로 재파싱 후 .md 최종 판정
if [ -n "$_fp" ]; then FILE_PATH="$_fp"; else hook_parse_file_path; case "$FILE_PATH" in *.md|*.MD) ;; *) exit 0 ;; esac; fi

# 본문(content / new_string / edits[*].new_string) 회수 = lib/hook-input.sh::hook_parse_content SSOT.
#   L3 2026-08-03: 구 코드는 `[ -z "$HOOK_PY" ] && exit 0` — python 이 없거나 Store 별칭으로
#   실행이 죽으면 검사 자체가 사라졌다. lib 은 python 실패 시 bash JSON 디코더로 내려간다.
hook_parse_content
[ -z "$CONTENT" ] && exit 0

# 디코드 불가분이 남으면 판정하지 않고 차단 (fail-closed, F10 계약 소비 — share-guard 와 동일 분기).
#   초안은 이 신호를 share-guard 만 받고 여기서는 무시해, 같은 payload 가 한쪽은 차단·한쪽은
#   통과했다 (degraded + surrogate 실측: share-guard rc=2 / author-field-check rc=0).
if [ "${CONTENT_UNDECODED:-0}" = "1" ]; then
  echo "[AUTHOR-FIELD] 본문을 완전히 해석하지 못해 작성자 필드를 검증할 수 없습니다." >&2
  echo "  파일: $FILE_PATH" >&2
  echo "  원인: python 미가용 + 디코드 불가 이스케이프(서로게이트 페어) 잔존" >&2
  echo "  조치: python 실행 가능 상태를 복구한 뒤 다시 시도하거나, 작성자 필드를 직접 확인하세요." >&2
  command -v log_event >/dev/null 2>&1 && log_event "author-field-check" "block" "reason=undecoded-content"
  exit 2
fi

# 라인 매칭은 bash 내장 정규식 (grep fork 0) — 구 python re.MULTILINE 판정과 동일 결과 확인.
_re_author=$'(^|\n)(작성자|author)[ \t]*:[ \t]*[^\n]*[Cc]laude[^\n]*'
VIOLATING=""
if [[ "$CONTENT" =~ $_re_author ]]; then
  VIOLATING="${BASH_REMATCH[0]#$'\n'}"
fi

if [ -n "$VIOLATING" ]; then
  echo "[AUTHOR-FIELD] frontmatter 'author' / '작성자' 필드에 'Claude' 표기 차단:" >&2
  echo "  위반 라인: $VIOLATING" >&2
  echo "  정상값:    jypark (jypark 단독 author 정책)" >&2
  echo "  근거:      CLAUDE.md §4.1 '장기 관점 분석·계획·실행' 룰 — 재발 방지" >&2
  echo "             task-docs SKILL.md L128 — 작성자 기본값 = jypark" >&2
  command -v log_event >/dev/null 2>&1 && log_event "author-field-check" "block" "reason=author-claude"
  exit 2
fi

exit 0
