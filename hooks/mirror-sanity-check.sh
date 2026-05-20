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
# (2) api-docs 3-way — top-dir mtime 경량 비교 (Tier 1) → drift 의심 시 sample yaml mtime (Tier 2)
#     2026-05-20 F2: find -maxdepth 3 ×3 (≈600 stat) → stat ×3 (≈3 stat) 로 경량화
#     정확성 보강 = sample yaml mtime 비교는 그대로 유지
#     file count 완전 일치 검증 = `/mirror-be-claude verify` (sha256 + count) 위임
# ─────────────────────────────────────────────────────────
if [ -d "$GLOBAL_DIR" ] && [ -d "$BE_DIR" ] && [ -d "$DOCS_DIR" ]; then
  # Tier 1: top-dir mtime 3-way 비교 (파일 추가/삭제 시 부모 dir mtime 갱신)
  g_dt=$(stat -c %Y "$GLOBAL_DIR" 2>/dev/null || echo 0)
  b_dt=$(stat -c %Y "$BE_DIR"     2>/dev/null || echo 0)
  d_dt=$(stat -c %Y "$DOCS_DIR"   2>/dev/null || echo 0)

  max_t=$g_dt; [ "$b_dt" -gt "$max_t" ] && max_t=$b_dt; [ "$d_dt" -gt "$max_t" ] && max_t=$d_dt
  min_t=$g_dt; [ "$b_dt" -lt "$min_t" ] && min_t=$b_dt; [ "$d_dt" -lt "$min_t" ] && min_t=$d_dt

  if [ "$((max_t - min_t))" -gt 300 ]; then
    newer="global"
    [ "$b_dt" = "$max_t" ] && newer="be"
    [ "$d_dt" = "$max_t" ] && newer="docs"
    echo "[mirror-sanity] api-docs top-dir mtime drift: $((max_t - min_t))초 (newer=$newer) — \`/mirror-be-claude verify\` 권장" >&2
    WARNINGS=$((WARNINGS + 1))
  else
    # Tier 2: top-dir 동일 mtime 이라도 sample yaml mtime drift 검사 (내용 수정만 발생한 경우)
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
