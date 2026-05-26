#!/bin/bash
# SessionStart / 매뉴얼 호출 — settings.json 의 hook 명령 경로 검증
#
# 동작 모드:
#   (인자 없음)         SessionStart 검증 모드. 누락 hook 발견 시 stderr 보고 + 처리 옵션 안내. 항상 exit 0.
#   --list              누락 list 만 탭-구분 형식으로 stdout 출력 (소스파일\t이벤트\t누락경로)
#   --disable-missing   settings.json 백업 후 누락 hook entry 제거 (사용자 명시 호출 전용)
#
# Why:
#   누락 hook 이 매 도구 호출마다 "No such file or directory" 를 발생시키는 상황을
#   세션 시작 시 1회 보고하고 사용자가 제거/복구/무시 중 선택하도록 안내한다.
#   자동 비활성화는 settings.json 변경이라는 광범위한 영향이 있어 사용자 명시 호출(--disable-missing)로 분리.

[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "hook-health-check" "enter" "pid=$$"

source "$(dirname "$0")/lib/hook-input.sh"

MODE="${1:-check}"

CWD=""
hook_read_stdin
hook_parse_session_id
hook_parse_cwd
[ -z "$CWD" ] && CWD=$(pwd)

SETTINGS_FILES=("$HOME/.claude/settings.json")
if [ -n "$CWD" ]; then
  [ -f "$CWD/.claude/settings.json" ] && SETTINGS_FILES+=("$CWD/.claude/settings.json")
  [ -f "$CWD/.claude/settings.local.json" ] && SETTINGS_FILES+=("$CWD/.claude/settings.local.json")
fi

hook_python
if [ -z "$HOOK_PY" ]; then
  echo "[hook-health-check] python 미검출 — 검사 SKIP" >&2
  exit 0
fi

MISSING=$("$HOOK_PY" - "${SETTINGS_FILES[@]}" <<'PY'
import json, os, re, sys

PATTERN = re.compile(r'bash\s+("([^"]+\.sh)"|([A-Za-z]:[/\\][^\s]+\.sh)|(/[^\s]+\.sh)|(\S+\.sh))')

missing = []
seen = set()
for path in sys.argv[1:]:
    if not os.path.isfile(path):
        continue
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception:
        continue
    hooks = data.get('hooks', {})
    if not isinstance(hooks, dict):
        continue
    for event, groups in hooks.items():
        if not isinstance(groups, list):
            continue
        for group in groups:
            if not isinstance(group, dict):
                continue
            for h in group.get('hooks', []) or []:
                cmd = h.get('command', '') if isinstance(h, dict) else ''
                if not cmd:
                    continue
                m = PATTERN.search(cmd)
                if not m:
                    continue
                hp = next((g for g in m.groups()[1:] if g), '')
                if not hp:
                    continue
                hp = os.path.expanduser(hp.replace('\\', '/'))
                if hp in seen:
                    continue
                seen.add(hp)
                if not os.path.isfile(hp):
                    missing.append((path, event, hp))

for src, event, hp in missing:
    print(f"{src}\t{event}\t{hp}")
PY
)

if [ -z "$MISSING" ]; then
  [ "$MODE" = "check" ] && exit 0
  echo "[hook-health-check] 누락 hook 없음" >&2
  exit 0
fi

if [ "$MODE" = "--list" ]; then
  echo "$MISSING"
  exit 0
fi

if [ "$MODE" = "check" ]; then
  COUNT=$(echo "$MISSING" | wc -l | tr -d ' ')
  {
    echo ""
    echo "⚠️  Hook Health Check — 누락 hook 파일 ${COUNT}개 감지"
    echo ""
    echo "$MISSING" | awk -F'\t' '{printf "  - [%s] %s\n      ↳ source: %s\n", $2, $3, $1}'
    echo ""
    echo "처리 방법 (사용자 선택):"
    echo "  1) 자동 비활성화 — bash ~/.claude/hooks/hook-health-check.sh --disable-missing"
    echo "       (settings.json 백업 후 누락 hook entry 제거)"
    echo "  2) 복구 — git 등에서 누락 파일 복원 후 세션 재시작"
    echo "  3) 무시 — 매 세션마다 동일 경고가 다시 발생합니다"
    echo ""
    echo "현재 세션은 그대로 진행되며, 누락 hook 호출 시 \"No such file or directory\" 가 발생할 수 있습니다."
    echo ""
  } >&2
  exit 0
fi

if [ "$MODE" = "--disable-missing" ]; then
  TS=$(date +%Y%m%d%H%M%S)
  HOOK_HEALTH_TS="$TS" HOOK_HEALTH_MISSING="$MISSING" "$HOOK_PY" <<'PY'
import json, os, re, shutil, sys

ts = os.environ['HOOK_HEALTH_TS']
missing_text = os.environ.get('HOOK_HEALTH_MISSING', '')
PATTERN = re.compile(r'bash\s+("([^"]+\.sh)"|([A-Za-z]:[/\\][^\s]+\.sh)|(/[^\s]+\.sh)|(\S+\.sh))')

missing_paths = set()
sources = set()
for line in missing_text.splitlines():
    if not line.strip():
        continue
    parts = line.split('\t')
    if len(parts) < 3:
        continue
    sources.add(parts[0])
    missing_paths.add(parts[2])

for src in sorted(sources):
    bak = f"{src}.bak.{ts}"
    shutil.copy2(src, bak)
    with open(src, 'r', encoding='utf-8') as f:
        data = json.load(f)
    hooks = data.get('hooks', {})
    removed = []
    for event in list(hooks.keys()):
        groups = hooks.get(event) or []
        new_groups = []
        for group in groups:
            if not isinstance(group, dict):
                new_groups.append(group)
                continue
            new_h = []
            for h in group.get('hooks', []) or []:
                cmd = h.get('command', '') if isinstance(h, dict) else ''
                m = PATTERN.search(cmd) if cmd else None
                if m:
                    hp = next((g for g in m.groups()[1:] if g), '')
                    hp = os.path.expanduser(hp.replace('\\', '/')) if hp else ''
                    if hp and hp in missing_paths:
                        removed.append((event, hp))
                        continue
                new_h.append(h)
            if new_h:
                group['hooks'] = new_h
                new_groups.append(group)
        if new_groups:
            hooks[event] = new_groups
        else:
            del hooks[event]
    data['hooks'] = hooks
    with open(src, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print(f"[OK] {src}")
    print(f"     백업: {bak}")
    for ev, hp in removed:
        print(f"     - 제거: [{ev}] {hp}")
PY
  exit 0
fi

echo "[HOOK-HEALTH] WARN: 알 수 없는 모드: $MODE (사용 가능: --list, --disable-missing) — skip" >&2
exit 0
