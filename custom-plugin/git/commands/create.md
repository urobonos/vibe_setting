---
description: worktree(wip) 작업 → 신규 feature 분기 생성·ff-only 정착 (사용자 직접 머지)
---

# /git:create

worktree (wip/*) 에서 작업 완료 후 신규 feature 분기 생성 + worktree ff-only 머지 + worktree/wip 삭제.

## 절차

1. worktree (`wip/{sid}-{slug}`) commit 완료 확인
2. source 분기 확인 (예: `vibe_setting` / `production` / `staging` / `develop`)
3. **Claude 자동 실행** (2026-06-04~, 사용자 명시 승인 — 각 명령을 **개별 Bash 호출**로 실행, `&&`/`;` 결합 금지):

```bash
# SOURCE = vibe_setting / production / staging / develop 등 — main/master 면 정착 절대 금지 (branch-enforce §1.5 차단, PR 절차로 대체)
git checkout {source-branch}
git checkout -b feature/{source}_{slug}
git merge --ff-only wip/{sid}-{slug}
git worktree remove ~/.claude/worktrees/{sid}-{slug}
git branch -D wip/{sid}-{slug}
```

   - 결합 금지 이유: `dangerous-ops-guard.sh` 의 `git branch -D` 면제는 **단일 라인 `git branch -D wip/…`** 만 매칭한다 (`&&`/`;`/`|` 결합 시 면제 실패 → 차단). 따라서 명령을 한 줄씩 개별 Bash 호출.

   **ff-only 실패 시 cherry-pick fallback** (2026-06-04~, Claude 자동 실행 허용 — 정착 한정): wip 생성 후 source 가 전진하면 새 feature 분기로의 `git merge --ff-only` 가 `fatal: Not possible to fast-forward` 로 실패할 수 있다 (divergence). 이때 cherry-pick 으로 wip 커밋 범위를 정착한다. 각 명령 **개별 Bash 호출**.

```bash
# feature/{source}_{slug} 체크아웃·생성 직후 상태 유지 (source 가 master/main 이면 애초에 정착 금지).
BASE=$(git merge-base feature/{source}_{slug} wip/{sid}-{slug})   # wip 분기점 (공통 조상)
git cherry-pick ${BASE}..wip/{sid}-{slug}                          # tip 만 집지 말 것 — base..wip 미반영 커밋 범위 전체
git worktree remove ~/.claude/worktrees/{sid}-{slug}
git branch -D wip/{sid}-{slug}
```

   - **충돌 시:** `git cherry-pick --abort` 로 클린 복구 후 사용자 보고 (Claude auto-resolve 금지) — worktree/wip 보존, 사용자 판단 대기.
   - **master/main 금지:** master/main HEAD 에서의 cherry-pick 은 `branch-enforce.sh §1.6` 차단 (merge §1.5 미러). PR 절차로 대체.

## Why

- **worktree = 작업 격리 공간 / feature = 통합 분기.** 분리 명시화.
- **Claude 자동 머지 허용** (2026-06-04~ 사용자 명시 승인) — worktree → feature/source ff-only 머지 + worktree remove + wip branch -D 를 Claude 가 직접 수행. **단 source 가 master/main 이면 정착 절대 금지** (branch-enforce §1.5 차단, PR 절차).
- **ff-only 강제** → linear history, merge commit 없음.

## SSOT
- CLAUDE.md §4.3 "worktree 항상 강제 + feature 요청 시 생성"
- 짝 진입점: `/git:merge` (기존 feature 수정 시)
- 정착 명령 = `git:push` 스킬 + `branch-enforce.sh` retire 후 worktree-enforce.sh
