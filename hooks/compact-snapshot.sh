#!/bin/bash
# compact-snapshot.sh
# PreCompact — 압축 **직전에** 트랜스크립트에서 기계 추출 가능한 사실을 문서로 박제한다.
#
# Why:
#   CLAUDE.md §1 요약 양식 7항목 중 **2번(수정 파일·명령어)** 과 **7번(마지막 질문 원문)** 은
#   Claude 의 기억이 아니라 트랜스크립트에서 **기계적으로** 뽑을 수 있다. 뽑아두면 요약이 빠뜨려도 살아남는다.
#   나머지(결정·막다른 길·제약)는 서술이 필요해 요약이 담당한다 — 역할을 가른다.
#
#   PostCompact 는 요약을 받지만 그때는 원 정보가 이미 사라진 뒤라 복구가 불가능하다.
#   압축 전에 닿을 수 있는 유일한 지점이 PreCompact 다.
#
# 스키마 근거 (2026-09-16 `bin/claude.exe` 실측):
#   PreCompact stdin = 공통필드(session_id · transcript_path · cwd) + trigger("manual"|"auto") + custom_instructions
#   PreCompact 는 additionalContext 주입 스키마가 없다 → 출력은 **파일로만**, 경로 통지는 SessionStart(compact) 가 한다.
#
# 짝 hook: compact-context-restore.sh (SessionStart matcher=compact — 이 파일을 가리킨다)
# SSOT: CLAUDE.md §1 "Context Compaction 요약 양식"

[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "compact-snapshot" "enter" "pid=$$"

source "$(dirname "$0")/lib/hook-input.sh"
hook_read_stdin
hook_parse_session_id

[ -z "$SESSION_ID" ] && exit 0
resolve_python 2>/dev/null
[ -z "$HOOK_PY" ] && exit 0   # python 없으면 조용히 포기 (압축을 막지 않는다)

OUT_DIR="$HOME/.claude/docs/compact/${SESSION_ID}"
mkdir -p "$OUT_DIR" 2>/dev/null || exit 0

# 같은 세션에서 압축은 여러 번 일어난다 — 순번으로 누적한다 (덮어쓰면 이전 구간이 사라진다)
SEQ=$(( $(ls -1 "$OUT_DIR"/*.md 2>/dev/null | wc -l) + 1 ))
SEQ_PAD=$(printf '%02d' "$SEQ")
OUT_FILE="${OUT_DIR}/${SEQ_PAD}-$(date +%Y-%m-%d-%H%M%S).md"

# git 관측 (cwd 기준) — 서술이 아니라 지금 읽은 값
GIT_BLOCK=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_BLOCK="- 작업 트리: $(git rev-parse --show-toplevel 2>/dev/null) (브랜치 $(git rev-parse --abbrev-ref HEAD 2>/dev/null))
- 최근 커밋: $(git log --oneline -1 2>/dev/null)
- 미커밋(tracked) $(git status --porcelain 2>/dev/null | grep -cv '^??')건:
$(git status --porcelain 2>/dev/null | grep -v '^??' | head -30 | sed 's/^/    /')"
fi

# 이벤트 JSON 은 **환경변수로** 넘긴다 — heredoc 이 stdin 을 점유해 파이프가 무시되기 때문 (2026-09-16 실측)
export SNAP_OUT="$OUT_FILE" SNAP_SEQ="$SEQ_PAD" SNAP_GIT="$GIT_BLOCK" SNAP_SID="$SESSION_ID" SNAP_EVENT="$STDIN_DATA"
"$HOOK_PY" - <<'PYEOF'
import json, os, sys, datetime

try:
    ev = json.loads(os.environ.get("SNAP_EVENT") or "")
except Exception:
    sys.exit(0)

tp = ev.get("transcript_path") or ""
trigger = ev.get("trigger") or "?"
custom = ev.get("custom_instructions") or ""

files, cmds, users, tests = [], [], [], []
if tp and os.path.exists(tp):
    for line in open(tp, encoding="utf-8", errors="replace"):
        try:
            d = json.loads(line)
        except Exception:
            continue
        # 진짜 사용자 입력 판별 (2026-09-16 실측):
        #   promptSource 보유 = 사람이 친 프롬프트 · isMeta=true = Stop hook feedback 등 하니스 합성
        #   "<" 로 시작 = task-notification·system-reminder 류 주입
        # 이걸 안 가르면 §1 7번 "마지막 질문 원문" 자리에 hook feedback 이 앉는다.
        is_real_user = (
            d.get("type") == "user"
            and not d.get("isMeta")
            and d.get("promptSource") is not None
        )
        msg = d.get("message") or {}
        content = msg.get("content")
        if isinstance(content, str):
            if is_real_user and not content.lstrip().startswith("<"):
                users.append(content)
            continue
        if not isinstance(content, list):
            continue
        for b in content:
            if not isinstance(b, dict):
                continue
            if b.get("type") == "tool_use":
                nm, inp = b.get("name"), (b.get("input") or {})
                fp = inp.get("file_path")
                if nm in ("Edit", "Write", "NotebookEdit") and fp:
                    files.append(fp)
                cmd = inp.get("command")
                if nm in ("Bash", "PowerShell") and cmd:
                    cmds.append(cmd)
                    low = cmd.lower()
                    if "phpunit" in low or "pytest" in low or "npm test" in low or "spark test" in low:
                        tests.append(cmd)
            elif b.get("type") == "text" and is_real_user:
                t = b.get("text", "")
                if t and not t.lstrip().startswith("<"):
                    users.append(t)

def uniq(seq):
    seen, out = set(), []
    for x in seq:
        if x not in seen:
            seen.add(x); out.append(x)
    return out

files_u, tests_u = uniq(files), uniq(tests)
now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
L = []
L.append(f"# compact 스냅샷 {os.environ.get('SNAP_SEQ','')} — {now}")
L.append("")
L.append(f"> 압축 **직전**에 PreCompact hook 이 트랜스크립트에서 기계 추출한 값이다 (서술 아님).")
L.append(f"> 요약과 어긋나면 이 쪽이 사실이다. 원문 전체 = `{tp}`")
L.append("")
L.append(f"- trigger: `{trigger}`" + (f" · custom_instructions: `{custom}`" if custom else ""))
L.append(f"- session: `{os.environ.get('SNAP_SID','')}`")
L.append("")
g = os.environ.get("SNAP_GIT", "")
if g.strip():
    L.append("## git 관측")
    L.append("")
    L.append(g)
    L.append("")
L.append(f"## 수정한 파일 ({len(files_u)}건 · Edit/Write 전수)")
L.append("")
L += [f"- `{f}`" for f in files_u] or ["- 없음"]
L.append("")
if tests_u:
    L.append("## 테스트 명령어")
    L.append("")
    L += [f"- `{c}`" for c in tests_u]
    L.append("")
L.append(f"## 실행 명령어 ({len(cmds)}건 · 최근 40)")
L.append("")
L.append("```")
L += cmds[-40:] or ["(없음)"]
L.append("```")
L.append("")
L.append(f"## 사용자 발화 전문 ({len(users)}건 · 원문 그대로)")
L.append("")
for i, u in enumerate(users, 1):
    L.append(f"### {i}")
    L.append("")
    L.append("```")
    L.append(u.strip())
    L.append("```")
    L.append("")

out = os.environ.get("SNAP_OUT")
with open(out, "w", encoding="utf-8") as f:
    f.write("\n".join(L) + "\n")
PYEOF

# GC — 14일 지난 스냅샷 정리 (무한 증식 차단)
find "$HOME/.claude/docs/compact" -mindepth 2 -name '*.md' -mtime +14 -delete 2>/dev/null
find "$HOME/.claude/docs/compact" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null

exit 0
