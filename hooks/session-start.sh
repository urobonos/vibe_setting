#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
# PreToolUse Hook: 세션 시작 시 토큰 사용량 스냅샷 저장 (세션당 1회)
# python3 없이 grep/sed로 session_id를 추출하여 반복 호출 시 오버헤드 최소화

SNAPSHOT_DIR="$HOME/.claude/monitoring/snapshots"

source "$(dirname "$0")/lib/hook-input.sh"
hook_read_stdin
# session_id 누락 시 동작 보존 — default fallback 적용 전에 빈 값이면 exit 0
SESSION_ID=$(hook_parse_field "session_id")
if [ -z "$SESSION_ID" ]; then exit 0; fi

SNAPSHOT_FILE="$SNAPSHOT_DIR/${SESSION_ID}.json"
# 이미 스냅샷 존재 → 즉시 종료 (python3 호출 없이)
if [ -f "$SNAPSHOT_FILE" ]; then exit 0; fi

# 최초 실행: 스냅샷 생성
mkdir -p "$SNAPSHOT_DIR"
STATS_FILE="$HOME/.claude/stats-cache.json"
if [ ! -f "$STATS_FILE" ]; then exit 0; fi

python3 - <<PYEOF
import json, os
from datetime import datetime, timezone
session_id = r"$SESSION_ID"
stats_path = os.path.expanduser("~/.claude/stats-cache.json")
snapshot_path = os.path.expanduser(f"~/.claude/monitoring/snapshots/{session_id}.json")
try:
    with open(stats_path, 'r', encoding='utf-8') as f:
        stats = json.load(f)
    snapshot = {"session_id": session_id, "snapshot_at": datetime.now(timezone.utc).isoformat(), "model_usage": stats.get("modelUsage", {}), "total_messages": stats.get("totalMessages", 0), "total_sessions": stats.get("totalSessions", 0)}
    with open(snapshot_path, 'w', encoding='utf-8') as f:
        json.dump(snapshot, f, indent=2, ensure_ascii=False)
except:
    pass
PYEOF
