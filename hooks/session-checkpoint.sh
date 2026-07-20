#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "session-checkpoint" "enter" "pid=$$"
# Stop Hook: 세션 종료 시 체크포인트 메모리 자동 저장
#
# 동작:
#   1. transcript_path에서 마지막 6턴(user 3 + assistant 3) 추출 (Raw, 모델 호출 없음)
#   2. git status/log 기반 객관적 상태 스냅샷 생성
#   3. ~/.claude/projects/{PROJECT}/memory/session_checkpoint.md 저장
#   4. MEMORY.md 인덱스에 pointer 자동 등록 (1회)
#
# 실패 시 graceful degrade — 세션 종료 차단하지 않음.
# 참고: claude -p --model haiku 요약 호출은 활성 세션과 충돌·timeout 빈발로 제거됨(하단 C 부분 주석 참조).

STDIN_DATA=$(cat)

# 기본 필드 추출
eval "$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    sid = data.get('session_id', '')
    cwd = data.get('cwd', '')
    tp = data.get('transcript_path', '')
    safe_cwd = cwd.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"')
    safe_tp = tp.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"')
    print(f'SESSION_ID=\"{sid}\"')
    print(f'CWD=\"{safe_cwd}\"')
    print(f'TRANSCRIPT=\"{safe_tp}\"')
except:
    print('SESSION_ID=\"\"')
    print('CWD=\"\"')
    print('TRANSCRIPT=\"\"')
" 2>/dev/null)"

# 필수 필드 누락 시 종료
if [ -z "$SESSION_ID" ] || [ -z "$CWD" ] || [ -z "$TRANSCRIPT" ]; then
  exit 0
fi

# transcript 파일 없으면 종료
if [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# 프로젝트 디렉토리명 변환: C:\Works\hongcafe_global_backend → C--Works-hongcafe-global-backend
PROJECT_NAME=$(echo "$CWD" | sed -e 's/[\\\/:_ ]/-/g')
MEMORY_DIR="$HOME/.claude/projects/$PROJECT_NAME/memory"

# memory 디렉토리 없으면 종료 (해당 프로젝트는 auto memory 미사용)
if [ ! -d "$MEMORY_DIR" ]; then
  exit 0
fi

CHECKPOINT_FILE="$MEMORY_DIR/session_checkpoint.md"
MEMORY_INDEX="$MEMORY_DIR/MEMORY.md"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# === B 부분: transcript에서 최근 6턴 추출 ===
RECENT_TURNS=$(python - "$TRANSCRIPT" <<'PYEOF'
import json, sys
path = sys.argv[1]
turns = []
try:
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except:
                continue
            msg = obj.get('message', obj)
            role = msg.get('role') if isinstance(msg, dict) else None
            if role not in ('user', 'assistant'):
                continue
            content = msg.get('content', '')
            # content가 리스트인 경우 text만 추출
            if isinstance(content, list):
                parts = []
                for item in content:
                    if isinstance(item, dict):
                        if item.get('type') == 'text':
                            parts.append(item.get('text', ''))
                        elif item.get('type') == 'tool_use':
                            parts.append(f"[tool: {item.get('name','')}]")
                        elif item.get('type') == 'tool_result':
                            t = item.get('content', '')
                            if isinstance(t, list):
                                t = ' '.join(str(x.get('text','')) if isinstance(x, dict) else str(x) for x in t)
                            parts.append(f"[tool_result: {str(t)[:200]}]")
                content = '\n'.join(p for p in parts if p)
            if not content or not isinstance(content, str):
                continue
            # 너무 긴 메시지는 절단
            if len(content) > 2000:
                content = content[:2000] + '...[truncated]'
            turns.append({'role': role, 'content': content})
    # 마지막 6턴
    recent = turns[-6:]
    for t in recent:
        print(f"### {t['role']}")
        print(t['content'])
        print()
except Exception as e:
    print(f"[transcript parsing error: {e}]")
PYEOF
)

# === C 부분: 객관적 상태 스냅샷 (git + 최근 수정 파일) ===
# 기존 claude -p --model haiku 호출은 활성 세션과 충돌하여 timeout 빈발 → 제거.
# 대신 Raw 턴(B) + 정확한 구조화 메타데이터로 대체.

GIT_STATUS=""
GIT_BRANCH=""
RECENT_COMMITS=""
if command -v git >/dev/null 2>&1 && [ -d "$CWD/.git" ]; then
  GIT_BRANCH=$(cd "$CWD" && git branch --show-current 2>/dev/null)
  GIT_STATUS=$(cd "$CWD" && git status --short 2>/dev/null | head -30)
  RECENT_COMMITS=$(cd "$CWD" && git log --oneline -5 2>/dev/null)
fi

# 최근 변경(untracked + modified) = git 기반으로 빠르게 확보
# find -mmin 스캔은 대형 프로젝트에서 수초 이상 소요 → 제거

# === 체크포인트 파일 작성 (매번 덮어쓰기) ===
cat > "$CHECKPOINT_FILE" <<EOF
---
name: session_checkpoint
description: 자동 생성 세션 체크포인트 — 중단 시점 인계용 ($TIMESTAMP)
type: project
---

# 세션 체크포인트 ($TIMESTAMP UTC)

> 이 파일은 Stop hook(\`session-checkpoint.sh\`)이 세션 종료 시 자동 생성한다.
> 재개 시 "session_checkpoint 보고 이어서" 라고 요청하면 이어서 작업할 수 있다.

## 작업 상태 스냅샷

### Git 브랜치
\`$GIT_BRANCH\`

### 수정 중 파일 (\`git status --short\`)
\`\`\`
$GIT_STATUS
\`\`\`

### 최근 커밋 5개
\`\`\`
$RECENT_COMMITS
\`\`\`

---

## Raw 최근 6턴 (대화 맥락)

$RECENT_TURNS

---

## 메타

| 항목 | 값 |
|------|-----|
| session_id | \`$SESSION_ID\` |
| cwd | \`$CWD\` |
| generated_at | $TIMESTAMP |
| transcript | \`$TRANSCRIPT\` |
EOF

# === MEMORY.md 인덱스 자동 등록 ===
if [ -f "$MEMORY_INDEX" ]; then
  if ! grep -q "session_checkpoint" "$MEMORY_INDEX" 2>/dev/null; then
    # Project 섹션 뒤에 추가. 없으면 맨 아래.
    if grep -q "^## Project" "$MEMORY_INDEX" 2>/dev/null; then
      # Project 섹션 맨 마지막 라인 다음에 삽입
      python - "$MEMORY_INDEX" <<'PYEOF'
import sys, re
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()
new_line = '- [session_checkpoint.md](session_checkpoint.md) — 세션 종료 시 자동 생성. 재개 시 "session_checkpoint 보고 이어서" 요청\n'
# Project 섹션 마지막 항목 뒤에 삽입
out = []
inserted = False
in_project = False
for i, line in enumerate(lines):
    out.append(line)
    if line.startswith('## Project'):
        in_project = True
        continue
    if in_project and not inserted:
        # 다음 섹션 시작 직전에 삽입
        if i + 1 < len(lines) and lines[i+1].startswith('## '):
            out.append(new_line)
            inserted = True
            in_project = False
# 끝까지 안 들어갔으면 파일 끝에 추가
if not inserted:
    out.append(new_line)
with open(path, 'w', encoding='utf-8') as f:
    f.writelines(out)
PYEOF
    else
      echo "" >> "$MEMORY_INDEX"
      echo "- [session_checkpoint.md](session_checkpoint.md) — 세션 종료 시 자동 생성. 재개 시 \"session_checkpoint 보고 이어서\" 요청" >> "$MEMORY_INDEX"
    fi
  fi
fi

exit 0
