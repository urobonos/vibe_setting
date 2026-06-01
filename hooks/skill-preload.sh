#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "skill-preload" "enter" "pid=$$"
# skill-preload.sh
# SessionStart hook: 모든 글로벌 스킬의 SKILL.md frontmatter(메타)를 컨텍스트에 주입
# (본문은 Skill 도구 호출 시 on-demand 로드 — preload 는 메타만, 토큰/ITPM 절감)

SKILLS_DIR="$HOME/.claude/skills"
output=""

for skill_dir in "$SKILLS_DIR"/*/; do
    skill_file="$skill_dir/SKILL.md"
    [[ -f "$skill_file" ]] || continue
    name=$(basename "$skill_dir")
    [[ "$name" == "audit-config" ]] && continue
    # UTF-8 BOM 제거 — sub-agent 가 SKILL.md 재작성 시 BOM 추가하면
    # frontmatter 파싱 깨져 description 이 `---` 으로 표시되는 회귀 방지
    # frontmatter 블록(첫 --- ~ 둘째 ---)만 추출 — 본문 미주입(토큰/ITPM 절감).
    # 첫 줄이 --- 가 아니면(비표준 frontmatter) 출력 공백 → 해당 스킬 주입 skip(안전 degrade).
    content=$(sed $'1s/^\xef\xbb\xbf//' "$skill_file" \
        | awk 'NR==1 && /^---/ {f=1; print; next} f && /^---/ {print; exit} f {print}')
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
