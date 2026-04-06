#!/bin/bash
# Stop Hook: 세션 종료 시 토큰 사용량 리포트 생성

STDIN_DATA=$(cat)

# session_id, cwd 경량 추출 (python3 의존 제거)
SESSION_ID=$(echo "$STDIN_DATA" | grep -o '"session_id" *: *"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
PROJECT_CWD=$(echo "$STDIN_DATA" | grep -o '"cwd" *: *"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "unknown" ]; then exit 0; fi

DATE=$(date +%Y-%m-%d)
REPORT_DIR="$HOME/.claude/monitoring/reports/$DATE"
mkdir -p "$REPORT_DIR"

python3 - <<PYEOF
import json, os
from datetime import datetime, timezone
session_id = r"$SESSION_ID"
project_cwd = r"$PROJECT_CWD"
date_str = r"$DATE"
stats_path = os.path.expanduser("~/.claude/stats-cache.json")
snapshot_path = os.path.expanduser(f"~/.claude/monitoring/snapshots/{session_id}.json")
report_path = os.path.expanduser(f"~/.claude/monitoring/reports/{date_str}/{session_id}.json")
try:
    with open(stats_path, 'r', encoding='utf-8') as f:
        current_stats = json.load(f)
    current_usage = current_stats.get("modelUsage", {})
except Exception as e:
    print(f"stats-cache.json 읽기 실패: {e}")
    exit(1)
snapshot_usage = {}
snapshot_at = None
has_snapshot = False
if os.path.exists(snapshot_path):
    try:
        with open(snapshot_path, 'r', encoding='utf-8') as f:
            snap = json.load(f)
        snapshot_usage = snap.get("model_usage", {})
        snapshot_at = snap.get("snapshot_at")
        has_snapshot = True
    except:
        pass
delta = {}
all_models = set(list(current_usage.keys()) + list(snapshot_usage.keys()))
for model in all_models:
    cur = current_usage.get(model, {})
    snap = snapshot_usage.get(model, {})
    d = {"input_tokens": cur.get("inputTokens", 0) - snap.get("inputTokens", 0), "output_tokens": cur.get("outputTokens", 0) - snap.get("outputTokens", 0), "cache_read_tokens": cur.get("cacheReadInputTokens", 0) - snap.get("cacheReadInputTokens", 0), "cache_creation_tokens": cur.get("cacheCreationInputTokens", 0) - snap.get("cacheCreationInputTokens", 0)}
    if any(v > 0 for v in d.values()):
        total = d["input_tokens"] + d["cache_read_tokens"]
        d["cache_hit_rate_pct"] = round(d["cache_read_tokens"] / total * 100, 1) if total > 0 else 0
        delta[model] = d
totals = {"input_tokens": sum(d.get("input_tokens", 0) for d in delta.values()), "output_tokens": sum(d.get("output_tokens", 0) for d in delta.values()), "cache_read_tokens": sum(d.get("cache_read_tokens", 0) for d in delta.values()), "cache_creation_tokens": sum(d.get("cache_creation_tokens", 0) for d in delta.values())}
total_input_side = totals["input_tokens"] + totals["cache_read_tokens"]
totals["cache_hit_rate_pct"] = round(totals["cache_read_tokens"] / total_input_side * 100, 1) if total_input_side > 0 else 0
def cache_grade(rate):
    if rate >= 85: return ("S", "매우 효율적")
    if rate >= 70: return ("A", "효율적")
    if rate >= 50: return ("B", "보통")
    if rate >= 30: return ("C", "비효율적")
    return ("D", "캐시 미활용")
grade_val, grade_label = cache_grade(totals["cache_hit_rate_pct"])
report = {"session_id": session_id, "project": project_cwd, "date": date_str, "ended_at": datetime.now(timezone.utc).isoformat(), "snapshot_at": snapshot_at, "has_snapshot": has_snapshot, "note": "stats-cache.json 스냅샷 기반 추정값" if has_snapshot else "스냅샷 없음 — 누적 전체값", "totals": totals, "by_model": delta if delta else {}, "cache_grade": grade_val, "cache_grade_label": grade_label}
with open(report_path, 'w', encoding='utf-8') as f:
    json.dump(report, f, indent=2, ensure_ascii=False)
sep = "-" * 50
print()
print("=" * 50)
print("   Claude Session Report")
print("=" * 50)
print(f"  Session : {session_id[:20]}...")
print(f"  Project : ...{project_cwd[-35:] if len(project_cwd) > 35 else project_cwd}")
print(sep)
if has_snapshot and any(v > 0 for v in totals.values()):
    print(f"  Input          : {totals['input_tokens']:>12,} tokens")
    print(f"  Output         : {totals['output_tokens']:>12,} tokens")
    print(f"  Cache Read     : {totals['cache_read_tokens']:>12,} tokens  (절감)")
    print(f"  Cache Creation : {totals['cache_creation_tokens']:>12,} tokens  (신규)")
    print(sep)
    bar_len = 28
    filled = int(totals['cache_hit_rate_pct'] / 100 * bar_len)
    bar_str = "#" * filled + "." * (bar_len - filled)
    print(f"  Cache [{bar_str}] {totals['cache_hit_rate_pct']}%")
    print(f"  Grade : {grade_val} - {grade_label}")
elif has_snapshot:
    print("  (이번 세션에서 토큰 변화 없음)")
else:
    print("  WARNING: 세션 시작 스냅샷 없음")
print(sep)
print(f"  저장: monitoring/reports/{date_str}/{session_id[:16]}.json")
print()
PYEOF
