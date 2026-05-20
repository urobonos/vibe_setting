---
description: worktree 작업 결과 → 신규 feature 분기 정착 (사용자 직접 머지)
---

# /feature-create

worktree (wip/*) 에서 작업 완료 후 신규 feature 분기 생성 + worktree ff-only 머지 + worktree/wip 삭제.

## 절차

1. worktree (`wip/{sid}-{slug}`) commit 완료 확인
2. source 분기 확인 (예: `vibe_setting` / `production` / `staging` / `develop`)
3. **사용자 직접 실행** (`! ` prefix, Claude 자동 실행 금지):

```bash
SOURCE="{source-branch}"
SLUG="{작업 슬러그}"
SID="{session_id prefix 8자}"
git checkout ${SOURCE}
git checkout -b feature/${SOURCE}_${SLUG}
git merge --ff-only wip/${SID}-${SLUG}
git worktree remove ~/.claude/worktrees/${SID}-${SLUG}
git branch -D wip/${SID}-${SLUG}
```

## Why

- **worktree = 작업 격리 공간 / feature = 통합 분기.** 분리 명시화.
- **Claude 자동 머지 금지** (§3 Checkpoint "비가역적 작업" 매칭) — 사용자 직접 `! ` prefix.
- **ff-only 강제** → linear history, merge commit 없음.

## SSOT
- CLAUDE.md §4.3 "worktree 항상 강제 + feature 요청 시 생성"
- 짝 진입점: `/feature-merge` (기존 feature 수정 시)
- 정착 명령 = `git-push` 스킬 + `branch-enforce.sh` retire 후 worktree-enforce.sh
