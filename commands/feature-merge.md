---
description: worktree 작업 결과 → 기존 feature 분기 ff-only 머지 (사용자 직접 머지)
---

# /feature-merge

기존 feature 분기 수정 worktree 작업 완료 후 해당 feature 로 ff-only 머지 + worktree/wip 삭제.

## 절차

1. worktree (`wip/{sid}-{slug}`) commit 완료 확인 — base = `feature/{이름}`
2. 대상 feature 분기 확인
3. **사용자 직접 실행** (`! ` prefix, Claude 자동 실행 금지):

```bash
FEATURE="feature/{...}"
SLUG="{작업 슬러그}"
SID="{session_id prefix 8자}"
git checkout ${FEATURE}
git merge --ff-only wip/${SID}-${SLUG}
git worktree remove ~/.claude/worktrees/${SID}-${SLUG}
git branch -D wip/${SID}-${SLUG}
```

## Why

- **기존 feature 수정 = worktree → feature 환원 패턴.** 별 feature 신설 안 함.
- **ff-only 강제** → 머지 커밋 없음.
- **Claude 자동 머지 금지** — 사용자 직접 `! ` prefix.

## SSOT
- CLAUDE.md §4.3 "worktree 항상 강제 + feature 요청 시 생성"
- 짝 진입점: `/feature-create` (신규 feature 생성 시)
