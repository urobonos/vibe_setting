---
description: working/ 단일 통합 문서 → tasks/ 자동 이동 트리거 (CLAUDE.md §File Paths "working/ 단일 통합 문서" SSOT, 2026-05-12 시행)
allowed-tools: Bash, Read, Glob
argument-hint: "[작업명]  # 생략 시 working/ 전체 일괄 이동"
---

본 슬래시 = `~/.claude/hooks/working-lifecycle.sh` SSOT 의 수동 진입점.

진행 중 작업 단일 통합 문서 (`~/.claude/docs/working/YYYYMMDD/{yyyy-mm-dd}-{product}-{작업명}.md`) 를 즉시 완료 상태로 표시하고 `~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-unified.md` 로 이동한다.

## 호출 방식

| 인자 | 동작 |
|------|------|
| 인자 없음 (`/working-done`) | `~/.claude/docs/working/` 전체 스캔 → 모든 진행 중 파일 일괄 이동 |
| `{작업명}` (`/working-done auth-refactor`) | 파일명 매칭 → 특정 작업만 이동 |

## 자동 이동 트리거 (본 슬래시 외)

| 트리거 | 조건 | 발동 시점 |
|--------|------|---------|
| **본문 마커 자동** | working/ 파일에 `^Status:\s*Done` (시작 라인) + `## Self-Critique` 섹션 동시 존재 | PostToolUse (Edit/Write 직후) |
| **자연어 키워드** | `작업 완료` / `tasks 이동` / `working 정리` / `done` / `완료 저장` | UserPromptSubmit |

## 이동 절차

1. **파일명 파싱** — `{yyyy-mm-dd}-{product}-{작업명}.md` → date / product / 작업명 추출
   - product 매칭 = `~/.claude/docs/{product}/` 디렉토리 prefix 탐색 (working / references 제외)
   - 동일 prefix 경합 시 가장 긴 매칭 우선 (예: `hongcafe_global_backend` > `hongcafe`)
2. **대상 경로 결정** — `~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-unified.md`
3. **mkdir -p** 대상 폴더 생성 (미존재 시)
4. **충돌 처리** — 동일 파일명 존재 시 `.bak-{timestamp}` 백업 후 덮어쓰기 (역소급 3종 산출물과는 suffix `-unified` 로 자연 구분)
5. **mv** — working/ 원본을 tasks/ 로 이동 (working/ 원본 자동 제거)
6. **history/summary 갱신** — `tasks/history.md` (오늘 항목 + 작업 링크) + `tasks/YYYYMMDD/summary.md` (작업 링크)
7. **사후 hook 검증** — 이동 후 1회 발동:
   - `doc-template-guard.sh` — `*-unified.md` 패턴, analyze + plan + result 합집합 필수 헤더 (exit 2)
   - `checklist-count-check.sh` — 체크리스트 ≥ 50 (exit 2)
   - `change-impact-section-check.sh` — 변경 영향 3열 표 (exit 0 경고)
   - `feasibility-section-check.sh` — 타당성 검토 + [Source:...] 인용 (exit 0 경고)

## 사용자 사전 확인 (이동 전)

- [ ] working/ 문서 `## 실행` 섹션 + 변경 내역 작성 완료
- [ ] `## Self-Critique` 체크리스트 ≥ 15개 작성 (통합 문서 전체 ≥ 50)
- [ ] `Status: Done` (시작 라인) 추가 — `Status: Partial` 도 허용
- [ ] unified-template.md 양식 충족 (이동 후 doc-template-guard.sh 검증)

## Why (수동 트리거가 필요한 이유)

- 본문 마커 자동 감지가 작동하지 않는 경우 (마커 형식 오타·들여쓰기 등)
- 본문 마커 추가 없이 즉시 이동 (긴급 정리)
- 다중 working/ 파일 일괄 처리
- 작업이 `Status: Partial` 상태 (부분 완료) 로 종료하지만 working/ → tasks/ 정리는 필요한 경우

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/CLAUDE.md` §File Paths "working/ 단일 통합 문서" | 정책 SSOT |
| `~/.claude/skills/task-docs/SKILL.md` §"working/ 단일 통합 워크플로우" | 작성 절차 SSOT |
| `~/.claude/hooks/working-lifecycle.sh` | 실행 본체 (PostToolUse + UserPromptSubmit 양쪽 등록) |
| `~/.claude/skills/task-docs/references/unified-template.md` | 양식 SSOT |
| `~/.claude/commands/working-done.md` (본 파일) | 수동 진입점 슬래시 thin wrapper |

## 실행

본 슬래시는 hook 본체를 한 번 호출하면 끝나므로 명시 명령 흐름은 다음과 같다:

```bash
# 인자 없음 — 전체 일괄
bash ~/.claude/hooks/working-lifecycle.sh <<< '{"hook_event_name":"UserPromptSubmit","prompt":"작업 완료"}'

# 특정 작업명 — 해당 파일만 (working-lifecycle.sh 가 prompt 안의 작업명 매칭 후 일치 파일만 처리)
bash ~/.claude/hooks/working-lifecycle.sh <<< '{"hook_event_name":"UserPromptSubmit","prompt":"working 정리 auth-refactor"}'
```

> Claude 본체는 본 슬래시 호출 시 위 흐름을 직접 Bash 도구로 실행하고 stderr 로그를 사용자에게 그대로 보고한다.
