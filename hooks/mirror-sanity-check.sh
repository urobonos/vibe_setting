#!/usr/bin/env bash
# mirror-sanity-check.sh — be 미러링 경량 drift 감지 (2026-05-18 신설)
#
# 동작: SessionStart 시 mtime 기반 경량 검사
#   (1) CLAUDE.md 양방향 (be ↔ global mirror)
#   (2) api-docs 3-way (global ↔ be ↔ hongcafe_global_docs)
#
# 비교 = mtime 만 (sha256 ✗) → 비용 ≈ stat × ~60 호출 = 수십 ms.
# 차이 발견 시 stderr 경고만 출력 + exit 0 (강제 차단 X).
#   → 사용자에게 `/mirror-be-claude verify` 명시 호출 유도.
#
# Why:
#   - 종전 mirror-docs.sh PostToolUse 단방향 (글로벌 → 외부) hook 폐기 후
#     api-docs 의 외부 IDE / be cwd 편집을 감지할 자동 경로 없음.
#   - SessionStart 경량 검사로 drift 알람 = 자동 sync 안 함, 사용자 결정 영역.
#   - 자동 sync = race / 잘못된 source 선택 위험 → 명시 진입점 (mirror-be-claude
#     skill `verify` + `sync-from-be` / `sync-from-global`) 으로 위임.
#
# SSOT: 본 hook + ~/.claude/skills/mirror-be-claude/SKILL.md + CLAUDE.md §File Paths
#       "api-docs 3-way 자동 미러링" 단락 (2026-05-18 갱신)

[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0

source "$(dirname "$0")/lib/log-helper.sh" 2>/dev/null

# 경로 정의
BE_MD="C:/Works/hongcafe_global_backend/CLAUDE.md"
MIRROR_MD="${HOME}/.claude/mirrors/hongcafe_global_backend/CLAUDE.md"
GLOBAL_DIR="${HOME}/.claude/docs/hongcafe_global_backend/api-docs"
BE_DIR="C:/Works/hongcafe_global_backend/api-docs"
DOCS_DIR="C:/Works/hongcafe_global_docs/be/api-docs"

WARNINGS=0

# ─────────────────────────────────────────────────────────
# (1) CLAUDE.md 양방향 — mtime 비교
# ─────────────────────────────────────────────────────────
if [ -f "$BE_MD" ] && [ -f "$MIRROR_MD" ]; then
  be_t=$(stat -c %Y "$BE_MD" 2>/dev/null || echo 0)
  mi_t=$(stat -c %Y "$MIRROR_MD" 2>/dev/null || echo 0)
  diff_sec=$((be_t > mi_t ? be_t - mi_t : mi_t - be_t))
  if [ "$diff_sec" -gt 60 ]; then
    newer="be"
    [ "$mi_t" -gt "$be_t" ] && newer="mirror"
    echo "[mirror-sanity] CLAUDE.md mtime drift: $diff_sec 초 (newer=$newer) — \`/mirror-be-claude verify\` 권장" >&2
    WARNINGS=$((WARNINGS + 1))
  fi
fi

# ─────────────────────────────────────────────────────────
# (2) api-docs 3-way — file count 차이 또는 maxdepth mtime sample
# ─────────────────────────────────────────────────────────
if [ -d "$GLOBAL_DIR" ] && [ -d "$BE_DIR" ] && [ -d "$DOCS_DIR" ]; then
  g_count=$(find "$GLOBAL_DIR" -maxdepth 3 -type f 2>/dev/null | wc -l)
  b_count=$(find "$BE_DIR"     -maxdepth 3 -type f 2>/dev/null | wc -l)
  d_count=$(find "$DOCS_DIR"   -maxdepth 3 -type f 2>/dev/null | wc -l)

  if [ "$g_count" != "$b_count" ] || [ "$g_count" != "$d_count" ]; then
    echo "[mirror-sanity] api-docs file count drift: global=$g_count / be=$b_count / docs=$d_count — \`/mirror-be-claude verify\` 권장" >&2
    WARNINGS=$((WARNINGS + 1))
  else
    # 같은 count 라도 be 의 1 sample mtime 이 글로벌보다 5분+ 새로우면 alarm
    sample_file=$(find "$BE_DIR" -maxdepth 3 -type f -name '*.yaml' 2>/dev/null | head -1)
    if [ -n "$sample_file" ]; then
      rel="${sample_file#$BE_DIR/}"
      b_t=$(stat -c %Y "$BE_DIR/$rel"     2>/dev/null || echo 0)
      g_t=$(stat -c %Y "$GLOBAL_DIR/$rel" 2>/dev/null || echo 0)
      if [ "$b_t" -gt 0 ] && [ "$g_t" -gt 0 ] && [ "$((b_t - g_t))" -gt 300 ]; then
        echo "[mirror-sanity] api-docs sample mtime drift: $rel (be > global by $((b_t - g_t))초) — \`/mirror-be-claude verify\` 권장" >&2
        WARNINGS=$((WARNINGS + 1))
      fi
    fi
  fi
fi

# 텔레메트리
if command -v log_event >/dev/null 2>&1; then
  log_event "mirror-sanity-check" "info" "warnings=$WARNINGS"
fi

exit 0
