#!/bin/bash
# skill-preload.sh
# SessionStart hook: 모든 글로벌 스킬의 SKILL.md를 컨텍스트에 주입

SKILLS_DIR="$HOME/.claude/skills"
output=""

for skill_dir in "$SKILLS_DIR"/*/; do
    skill_file="$skill_dir/SKILL.md"
    [[ -f "$skill_file" ]] || continue
    name=$(basename "$skill_dir")
    [[ "$name" == "audit-config" ]] && continue
    content=$(cat "$skill_file")
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
