---
paths:
  - "skills/**"
  - "custom-plugin/**"
  - "hooks/**"
  - "commands/**"
  - "agents/**"
  - ".claude/skills/**"
  - "**/CLAUDE.md"
---

# 하니스 생성물 룰 (CLAUDE.md §4.3·§4.4·§5 에서 이관, 2026-09-28)

- **신규 룰 작성 관습 (필수, 재팽창 방지):** BLOCK-path(exit 2) hook 이 조치·SSOT·예시를 stderr 전량 출력하면 본문엔 1줄 포인터만 둔다. hook 부재·warning-only 룰만 산문 유지하되 판별식·§3 단서 중심 6줄 이내. **단 Claude 학습 prior 가 안전 기본값을 거스르는 룰(Co-Authored-By·master/main 머지·force-push·rm -rf 류)은 BLOCK-path 여도 본문 proactive 산문 유지** — hook 발화 전 prior 가 먼저 작동하고 모든 경로에 hook 이 있지도 않다. 특정 파일·작업에서만 필요한 룰은 본문 대신 `rules/`(paths — 프로젝트 루트 상대경로만 매칭) 또는 해당 스킬로 둔다. 외부에서 인용 중인 룰 이름은 1줄 앵커로 남긴다. Why·적용 전개 = `output/analysis/2026-06-01-funnel-improvement` SSOT.
- **신설 hook·슬래시·SSOT 권고:** "6개월 후에도 필요한가" + "실제로 변하는가" 2질문 통과 후 (`orchestration` §3.5).
- **Skill & Slash Inventory:** user-invocable/internal skill 전체 표·자동화 분류(A/B/C)·카운트·`commands/*.md` 매핑 = SSOT `~/.claude/docs/references/skill-inventory.md`. 신규/삭제/rename/자동화 강도 변경 시 그 파일 §5.1 표 갱신, 절차 = `skills/skill-creator/SKILL.md` §"인벤토리 동기화 규칙".

- **신규 생성물 플러그인 우선 (필수):** 신규 커맨드·hook·스킬·에이전트 생성 시 먼저 플러그인(`custom-plugin/{name}/`) 편입 가능 여부를 판단 → 가능하면 플러그인으로 우선 생성한다. 글로벌 `commands/`·`hooks/`·`skills/` 직접 추가는 플러그인화 불가 시(전역 always-on 가드·`settings.json` 강제 등록 hook 등)에만. **판정:** "특정 도메인 묶음에 속하는가" = 예 → 플러그인 / 하니스 전역 강제 → 글로벌. 생성 절차·승인은 기존 흐름 유지(스킬 파일 = `skill-creator` 경유, §3 우선).
- **스킬 생성·수정·최적화 — skill-creator 강제 진입점 (필수):** `.claude/skills/{skill}/` 하위 모든 파일 수정·생성 = `skill-creator` 경유 강제. 진입·락 우회·종료 정리 절차 SSOT = `skill-edit-guard.sh` (exit 2 차단 시 락 절차 전량 출력).
