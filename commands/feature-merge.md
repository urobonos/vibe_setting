---
description: worktree 작업 결과 → 기존 feature 분기 ff-only 머지 (사용자 직접 머지)
---

# /feature-merge

기존 feature 분기 수정 worktree 작업 완료 후 해당 feature 로 ff-only 머지 + worktree/wip 삭제.

## 절차

1. worktree (`wip/{sid}-{slug}`) commit 완료 확인 — base = `feature/{이름}`
2. 대상 feature 분기 확인
3. **Claude 자동 실행** (2026-06-04~, 사용자 명시 승인 — 각 명령을 **개별 Bash 호출**로 실행, `&&`/`;` 결합 금지):

```bash
# FEATURE = feature/{이름} — master/main 이면 정착 절대 금지 (branch-enforce §1.5 차단, PR 절차로 대체)
git checkout feature/{이름}
git merge --ff-only wip/{sid}-{slug}
git worktree remove ~/.claude/worktrees/{sid}-{slug}
git branch -D wip/{sid}-{slug}
```

   - 결합 금지 이유: `dangerous-ops-guard.sh` 의 `git branch -D` 면제는 **단일 라인 `git branch -D wip/…`** 만 매칭한다 (`&&`/`;`/`|` 결합 시 면제 실패 → 차단). 따라서 4개 명령을 한 줄씩 개별 Bash 호출.

   **ff-only 실패 시 cherry-pick fallback** (2026-06-04~, Claude 자동 실행 허용 — 정착 한정): `git merge --ff-only` 가 `fatal: Not possible to fast-forward` 로 실패하면 (feature 분기가 분기 후 전진 = divergence) cherry-pick 으로 wip 커밋 범위를 정착한다. 각 명령 **개별 Bash 호출**.

```bash
# feature/{이름} 체크아웃 상태 유지 (master/main 이면 branch-enforce §1.6 차단). ff-only 실패 시에만 실행.
BASE=$(git merge-base feature/{이름} wip/{sid}-{slug})   # wip 분기점 (공통 조상)
git cherry-pick ${BASE}..wip/{sid}-{slug}                 # tip 만 집지 말 것 — base..wip 미반영 커밋 범위 전체
git worktree remove ~/.claude/worktrees/{sid}-{slug}
git branch -D wip/{sid}-{slug}
```

   - **충돌 시:** `git cherry-pick --abort` 로 클린 복구 후 사용자 보고 (Claude auto-resolve 금지) — worktree/wip 보존, 사용자 판단 대기.
   - **master/main 금지:** master/main HEAD 에서의 cherry-pick 은 `branch-enforce.sh §1.6` 차단 (merge §1.5 미러). PR 절차로 대체.

4. **정착 후 reachable 해시 기록 (추적성, 2026-06-02~):** ff-only 머지·cherry-pick 후 working/summary 에 기록하는 커밋 해시는 **정착 후 reachable 최종 해시**여야 한다 (`git rev-parse ${FEATURE}` / `git log -1 --format=%h`). 머지 전 wip 해시·rebase 이전 해시를 인용하면 HEAD 에서 도달 불가한 orphan 이 된다 (audit 2026-06-02 — BE summary 6개 해시 전부 orphan 인용, patch-id 로만 작업 확인됨). `/회고` 단계에서 `git merge-base --is-ancestor` 로 재확인.

## Why

- **기존 feature 수정 = worktree → feature 환원 패턴.** 별 feature 신설 안 함.
- **ff-only 강제** → 머지 커밋 없음.
- **Claude 자동 머지 허용** (2026-06-04~ 사용자 명시 승인) — worktree → feature ff-only 머지 + worktree remove + wip branch -D 를 Claude 가 직접 수행. **단 대상이 master/main 이면 절대 금지** (branch-enforce §1.5 차단, PR 절차).

## SSOT
- CLAUDE.md §4.3 "worktree 항상 강제 + feature 요청 시 생성"
- 짝 진입점: `/feature-create` (신규 feature 생성 시)
