#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "skill-preload" "enter" "pid=$$"
# skill-preload.sh
# SessionStart hook: 모든 글로벌 스킬의 SKILL.md를 컨텍스트에 주입

SKILLS_DIR="$HOME/.claude/skills"
output=""

for skill_dir in "$SKILLS_DIR"/*/; do
    skill_file="$skill_dir/SKILL.md"
    [[ -f "$skill_file" ]] || continue
    name=$(basename "$skill_dir")
    [[ "$name" == "audit-config" ]] && continue
    # UTF-8 BOM 제거 — sub-agent 가 SKILL.md 재작성 시 BOM 추가하면
    # frontmatter 파싱 깨져 description 이 `---` 으로 표시되는 회귀 방지
    content=$(sed $'1s/^\xef\xbb\xbf//' "$skill_file")
    output="${output}
--- SKILL: ${name} ---
${content}
"
done

if [[ -n "$output" ]]; then
    # JSON 안전하게 이스케이프
    escaped=$(python3 -c "
import sys, json
content = sys.stdin.read()
print(json.dumps(content))
" <<< "$output")

    cat <<HOOK_JSON
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":${escaped}}}
HOOK_JSON
fi
