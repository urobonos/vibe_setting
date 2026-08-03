---
description: 배포 **절차 안내** 진입 — feature 분기 검증 + git-push + branch-enforce 통합 정책 (사용자 직접 실행만 허용, Claude 자동 push·merge 금지).
allowed-tools: Bash, Read, Glob, Grep, Skill
argument-hint: "[작업명]  # 생략 시 현재 브랜치 기준 안내"
---

배포 **절차 안내** 진입 — feature 분기 검증 + 머지·push 절차 안내 출력. **Claude 본체 직접 실행 금지** (사용자 `! ` prefix 실행만 허용). 본 슬래시 = read-only + 안내 텍스트 출력.

## 인자

- `$ARGUMENTS` = (선택) 작업명 kebab-case. 생략 시 현재 브랜치 기준 안내.

## 동작 3단계

| 단계 | 동작 | 결과 |
|------|------|------|
| ① 현재 브랜치 확인 | `git rev-parse --abbrev-ref HEAD` + `git status` (read-only) | 현재 분기 + 변경 상태 |
| ② feature/* 분기 검증 | 현재 분기가 `feature/{source}_{slug}` 패턴인지 확인. master/main 직접 머지 금지 | 통과 또는 차단 |
| ③ git-push 스킬 안내 | Conventional Commits 양식 안내 + 사용자 직접 push 명령 출력 | 사용자 직접 실행 |

## 직병렬 실행 지침

**원칙:** 본 단계는 순서가 강제되어 **직렬 필수** — Claude 자동 mutation 0 (사용자 직접 실행만), 병렬화 대상이 아니다.

| 태스크 | 직렬·병렬 | 방법 |
|--------|----------|-----|
| ① → ② → ③ 전 단계 | **직렬 필수** | 브랜치 확인 → feature 검증 → push 안내 (read-only 순차) |
| 병렬 기회 | **없음** | 사용자 직접 실행 영역 — Claude 병렬화 대상 아님 |

## 자연어 trigger

- `배포해줘` / `git push` / `merge` / `정착`

## 보조 스킬 호출

| 스킬 | 역할 |
|------|------|
| `git-push` | Conventional Commits v1.0.0 표준 (`type(scope): 제목`) + push 실행 SSOT |

## 사용자 직접 실행 명령 (안내만)

```bash
# 1) 커밋 (Conventional Commits 양식)
! git add <files>
! git commit -m "feat(scope): 제목"

# 2) push (사용자 직접만 — Claude 자동 push 금지)
! git push -u origin feature/{source}_{slug}

# 3) 머지 (사용자 직접만 — source 가 production/staging/develop 인 경우만)
! git checkout {source-branch}
! git merge --ff-only feature/{source}_{slug}
! git branch -D feature/{source}_{slug}
```

## 강제 hook

| Hook | 검증 | 차단 강도 |
|------|------|----------|
| `branch-enforce.sh` §(1) | `git push` 자동 호출 차단 (shlex 토큰화 exit 2) | exit 2 |
| `branch-enforce.sh` §(1.5) | master/main 머지·체크아웃 자동 호출 차단 | exit 2 |
| `dangerous-ops-guard.sh` | force push / reset --hard / Co-Authored-By 검출 시 차단 | exit 2 |

## 제약 (CLAUDE.md §4.3 정합)

| 항목 | 제약 |
|------|------|
| `git push` 전면 금지 | 어떤 분기·시나리오에서도 Claude 자동 `git push` 금지 (feature/source/personal/relay 모두) |
| master/main 머지·체크아웃 | 자동 호출 절대 금지. PR 절차로 대체 권고 |
| Co-Authored-By 라인 | 커밋 메시지 포함 금지 (dangerous-ops-guard.sh 차단) |
| 세션 내 commit 수정 | `git revert` 금지 / `git reset --soft HEAD~N` + 새 commit |

## source 브랜치 분기

| source | 정착 가능 | 절차 |
|--------|----------|------|
| production / staging / develop | ✓ | feature/* → ff-only merge → branch -D |
| main / master | ✗ | PR 생성 안내로 대체 — `gh pr create` 사용자 직접 |
| vibe_setting (~/.claude/) | ✓ | worktree 강제 영역 (2026-05-20 claude-harness 면제 폐기). functional exemption #5 (`*/.claude/docs/*`) + #6/#7 (settings.json/local) 만 통과 |

## 호출 예

```
/taskflow:deploy                                  ← 현재 분기 기준 배포 절차 안내
/taskflow:deploy auth-refactor                    ← 특정 작업 배포 절차 안내
```

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/CLAUDE.md` §4.3 "브랜치·worktree·push·머지 통합 정책" | 정책 SSOT |
| `~/.claude/custom-plugin/git/skills/push/SKILL.md` | 커밋 메시지 양식 SSOT (Conventional Commits) |
| `~/.claude/hooks/branch-enforce.sh` | push / 머지 / 체크아웃 강제 차단 |
| `~/.claude/hooks/dangerous-ops-guard.sh` | force push / reset / Co-Authored-By 차단 |

**책임 분담선 (audit M14 명문 2026-05-20):** 본 슬래시 책임 = push·머지·정착 절차 안내 (§4.3 (d)(e)(f)). history.md/summary.md 기록 영역 = `/taskflow:retro` 책임 (별 SSOT). 본 슬래시 = Claude 자동 mutation 0, 사용자 직접 실행만.

## §3 Checkpoint 우선 적용

본 슬래시는 §3 5조건 (비가역 / 외부 시스템) 매칭 100% — Claude 자동 실행 불가. 사용자 명시 직접 실행 (`! ` prefix) 만 허용.

**worktree 적용 (CLAUDE.md §4.3 (a)):** 본 슬래시는 안내만 수행 (Claude 자동 mutation 0). 사용자 직접 (`! ` prefix) 머지·push 명령은 worktree 정착 절차 (`/git:create` / `/git:merge`) 로 분리.

## Skip 조건

| 영역 | 진행 여부 |
|------|----------|
| `git push` / 머지 / 정착 동반 작업 | **필수** — 사용자 직접 실행 명령 안내 출력 |
| 단순 working/ 문서·hook·skill 수정 (push 무관) | 면제 — `/taskflow:save` 또는 working-lifecycle 자동 이동만으로 종결 |

## 짝 슬래시

앞 = `/taskflow:review` / 뒤 = `/taskflow:retro` → `/taskflow:save`. 본 슬래시는 **절차 안내만** 한다 — 실제 push·머지는 사용자 직접(§4.3(d)(e)). 전체 맵 = `execute.md` §"워크플로우 맵" SSOT.

## Changelog

- 2026-08-03: 구 `## 차별점` 표 → `## 짝 슬래시` 포인터로 축약 (전체 맵 SSOT = `execute.md` §"워크플로우 맵")
- 2026-05-15: 신설
