---
paths:
  - "skills/**"
  - "custom-plugin/**"
  - "hooks/**"
  - "commands/**"
  - "agents/**"
  - ".claude/skills/**"
---

# 하니스 생성물 룰 (CLAUDE.md §4.3 에서 이관, 2026-09-28)

- **신규 생성물 플러그인 우선 (필수):** 신규 커맨드·hook·스킬·에이전트 생성 시 먼저 플러그인(`custom-plugin/{name}/`) 편입 가능 여부를 판단 → 가능하면 플러그인으로 우선 생성한다. 글로벌 `commands/`·`hooks/`·`skills/` 직접 추가는 플러그인화 불가 시(전역 always-on 가드·`settings.json` 강제 등록 hook 등)에만. **판정:** "특정 도메인 묶음에 속하는가" = 예 → 플러그인 / 하니스 전역 강제 → 글로벌. 생성 절차·승인은 기존 흐름 유지(스킬 파일 = `skill-creator` 경유, §3 우선).
- **스킬 생성·수정·최적화 — skill-creator 강제 진입점 (필수):** `.claude/skills/{skill}/` 하위 모든 파일 수정·생성 = `skill-creator` 경유 강제. 진입·락 우회·종료 정리 절차 SSOT = `skill-edit-guard.sh` (exit 2 차단 시 락 절차 전량 출력).
