#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "agent-first-banner" "enter" "pid=$$"
# SessionStart Hook: Agent-First Default 배너 출력
# CLAUDE.md §4 "에이전트 우선 위임" + orchestration §0 "Agent-First Default" SSOT.
# 본 세션의 default 동작이 "Agent 도구 우선 위임" 임을 매 세션 시작 시 상기시킨다.

cat <<'BANNER'
[Agent-First Default] 본 세션 default = Agent 도구·팀 스킬 우선 위임.
  • 탐색 3쿼리+ → Explore / 다파일 분석 → Team 1 / API 작업 → hongcafe:api-team / 의견 갈림 → /taskflow:debate
  • 병렬 spawn = 효율 상한까지 제안 (독립 태스크 min(16,cores−2), SSOT orchestration §2.3)
  • 직접 작업 허용 = 단일 파일 trivial 수정·단발성 조회 1회만 (사유 1줄 보고)
  • 보고 = 결론 + 판단 근거만 3~6줄, 표는 대조 필수 시만 — 상세는 질문 시 (CLAUDE.md §4 "응답 간결")
  • 상세: CLAUDE.md §4 "에이전트 우선 위임", skills/orchestration §0 "Agent-First Default"
BANNER

# 작업 재개 추천 블록은 taskflow 플러그인 소관 → custom-plugin/taskflow/hooks/resume-banner.sh (2026-09-28 이동)

exit 0
