---
description: 회고 단계 진입 — history.md + summary.md 자동 기록 + working-lifecycle.sh 호출. 세션 마감 정리 (Persistence 룰 정합).
allowed-tools: Bash, Edit, Write, Read, Glob, Grep, Skill
argument-hint: "[작업명]  # 생략 시 본 세션 전체 회고"
---

회고 단계 진입 — 본 세션 변경 내역 요약 + `~/.claude/docs/{product}/tasks/history.md` 및 `tasks/YYYYMMDD/summary.md` 자동 기록.

## 인자

- `$ARGUMENTS` = (선택) 작업명 kebab-case. 생략 시 본 세션 전체 회고.

## 동작 4단계

| 단계 | 동작 | 결과 |
|------|------|------|
| ① 변경 내역 요약 | 본 세션 git status / log 스캔 + working/ 단일 통합 문서 스캔 | 작업명 / 영향 영역 / 변경 파일 수 |
| ② history.md 기록 | `~/.claude/docs/{product}/tasks/history.md` 에 1행 추가 (날짜 / 작업명 / 요약) | 영구 이력 |
| ③ summary.md 기록 | `~/.claude/docs/{product}/tasks/YYYYMMDD/summary.md` 에 일일 요약 추가 | 일일 누적 |
| ④ CLAUDE.md size delta | `wc -c ~/.claude/CLAUDE.md` + 직전 커밋 대비 증감 1줄 보고 — 증가 시 §4.4 신규 룰 작성 관습 준수 여부 1줄 자가 점검 | 재팽창 가시화 (CLAUDE.md §4.4 작성 관습 보조, 2026-06-10 경량화 축⑥) |

## 당일 커밋 전수 대조 (역커버리지·추적성 차단, 2026-06-02~)

① 변경 내역 요약 시 **당일 production-reachable 커밋 전수**를 summary 항목과 대조한다 (audit 2026-06-02 — 06-02 summary 가 ~21 커밋 중 2건만 문서화한 inverse-coverage 재발 방지).

1. **전수 추출:** `git -C {repo} log --since="{오늘} 00:00" --first-parent {배포브랜치} --pretty=oneline`
2. **대조:** 각 커밋이 summary/working 에 문서화됐는지 확인 → 누락분은 1줄 링크 추가 (별 세션 위임분도 명시).
3. **인용 해시 reachable 확인:** summary 인용 해시가 `git merge-base --is-ancestor {hash} HEAD` 로 reachable 인지 확인. rebase/cherry-pick 로 orphan 된 해시(HEAD 미도달)는 **최종 reachable 해시로 교체**(또는 patch-id 병기). 죽은 해시 인용 금지.

**Why:** 산문 단언 + orphan 해시 = 독자가 git log 로 추적 불가 (audit "문서화·추적성" / "정직성" 감점 핵심). hook 강제 불가(자유텍스트)라 /taskflow:retro 단계 체크로 둔다 (§4.4 — substance 검증 못 하는 건 checklist, 신규 blocker hook 비추천). 정착 시점 예방 = `/git:merge` §4.

## 직병렬 실행 지침

**원칙:** 할당된 하위 태스크는 의존성을 먼저 판단 → 독립 태스크는 단일 응답 내 병렬(multi tool_use / Agent spawn), 의존 태스크는 직렬. 동일 파일 mutation·순서 의존 시 직렬 fallback (race 방지). 강제 병렬 modifier = `/taskflow:parallel`.

| 태스크 | 직렬·병렬 | 방법 |
|--------|----------|-----|
| ① 변경 내역 요약 (git status/log + working/ 스캔) | **병렬 가능** | 단일 응답 내 `git status`·`git log` Bash 조회 + working/ Glob·Read 동시 호출 |
| ② history.md + ③ summary.md 기록 | **병렬 가능** | 두 파일 독립 (다른 경로) → Edit/Write 동시 호출 |
| ① → ②③ 순서 | **직렬** | 요약 완료 후 기록 (요약 출력에 의존) |

## 자연어 trigger

- `회고` / `세션 마감 정리` / `retro` / `retrospective`

## 강제 hook

| Hook | 검증 | 차단 강도 |
|------|------|----------|
| `session-completeness-check.sh` | history.md + summary.md 동시 갱신 여부 | exit 0 (경고) |
| `working-lifecycle.sh` | Status: Done + ## Self-Critique 시 tasks/ 자동 이동 | PostToolUse 자동 |

## 회고 양식 (working/ § 회고 섹션)

```markdown
## 회고 (Retrospective)

### 본 세션 변경 내역 요약
| # | 변경 사항 | 영향 영역 |
|---|----------|---------|
| 1 | {변경 1} | {영역} |
| 2 | {변경 2} | {영역} |

### history.md / summary.md 기록 확인
- [ ] `~/.claude/docs/{product}/tasks/history.md` 항목 추가
- [ ] `~/.claude/docs/{product}/tasks/YYYYMMDD/summary.md` 항목 추가
- [ ] 당일 production-reachable 커밋 전수 대조 — summary 누락 0 (별 세션 위임분 포함)
- [ ] summary 인용 해시 전부 HEAD reachable — orphan(rebase/cherry-pick) 인용 0

### 잘된 점 / 개선점
- 잘된 점: {1~2줄}
- 개선점: {1~2줄}

### 다음 세션 진입점
- 잔여 작업이 있으면 `/taskflow:save` 으로 Status: Partial 저장 + `/taskflow:load` 재진입
```

## 호출 예

```
/taskflow:retro                                  ← 본 세션 전체 회고
/taskflow:retro auth-refactor                    ← 특정 작업 회고
```

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/CLAUDE.md` §4.1 "Persistence (필수)" | 정책 SSOT (history.md / summary.md 기록 의무) |
| `~/.claude/skills/task-docs/SKILL.md` | history.md / summary.md 양식 SSOT |
| `~/.claude/skills/task-docs/references/unified-template.md` § 회고 | 양식 SSOT |
| `~/.claude/hooks/session-completeness-check.sh` | history/summary 동시 갱신 강제 |
| `~/.claude/hooks/working-lifecycle.sh` | Status: Done 자동 이동 본체 |

**책임 분담선 (audit M14 명문 2026-05-20):** 본 슬래시 책임 = history.md + summary.md 기록 (Persistence §4.1). push·머지·정착 영역 = `/taskflow:deploy` 책임 (별 SSOT). 본 슬래시 = read-only or `~/.claude/docs/` mutation 만, 외부 git 명령 0.

## §3 Checkpoint 우선 적용

본 슬래시는 기록 위주 (Edit history.md / summary.md). 비가역 작업 없음 — 사용자 승인 없이 진행 가능.

**worktree 적용 (CLAUDE.md §4.3 (a)):** 본 슬래시 = `~/.claude/docs/{product}/tasks/history.md` + `YYYYMMDD/summary.md` mutation. exemption #5 (`*/.claude/docs/*`) 자동 통과. worktree 필수 아님.

## Skip 조건

| 등급 | 진행 여부 |
|------|----------|
| S (단발 작업, 1~3 파일) | 면제 — `/taskflow:save` 또는 working-lifecycle 자동 이동 시 history.md 자동 1줄 추가만으로 충분 |
| M / L | **권장** — 회고 요약 + 다음 세션 진입점 명시 |

## 차별점 (다른 슬래시와)

| 슬래시 | 시점 | 범위 |
|--------|------|------|
| `/taskflow:review` | §실행 직후 | Self-Critique + simplify |
| `/taskflow:deploy` | §리뷰 통과 후 | git-push + branch-enforce 안내 |
| **`/taskflow:retro`** | §배포 후 / 세션 마감 직전 | history.md + summary.md 기록 + 회고 요약 |
| `/taskflow:save` | 세션 마감 직전 | worktree 정착 + 잔여 작업 통합 저장 (회고 와 보완 관계) |
| `/taskflow:done` | 작업 완료 직후 | working/ → tasks/ 단순 이동 |

## Changelog

- 2026-05-15: 신설
