---
description: worktree(wip) 작업 → 기존 feature 분기 ff-only 머지·정착
---

# /git:merge

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

# [사전 검사] wip 범위에 머지 커밋이 있으면 범위 cherry-pick 불가 → 아래 출력이 1건 이상이면 정지
git rev-list --merges ${BASE}..wip/{sid}-{slug}          # 머지 커밋 목록 (비어 있어야 cherry-pick 진행)

# 위 출력이 비어 있을 때만 아래 진행
git cherry-pick ${BASE}..wip/{sid}-{slug}                 # tip 만 집지 말 것 — base..wip 미반영 커밋 범위 전체
git worktree remove ~/.claude/worktrees/{sid}-{slug}
git branch -D wip/{sid}-{slug}
```

   - **사전 검사 (머지 커밋 존재):** cherry-pick **시작 전** `git rev-list --merges ${BASE}..wip/{sid}-{slug}` 로 wip 범위 내 머지 커밋을 확인한다 (개별 Bash 호출). 출력이 **1건 이상이면** 범위 cherry-pick 이 불가하므로 cherry-pick 을 **시작하지 않고** "wip 에 머지 커밋 N건 존재 — 범위 cherry-pick 불가, 수동 정착 필요" 를 사용자에게 보고하고 **정지**한다.
   - **충돌 시:** cherry-pick 중 충돌이 발생하면 자동 해결을 시도하지 않는다. 즉시 `git cherry-pick --abort` (개별 Bash 호출) 로 feature 분기를 원상 복구하고, **충돌 파일 목록** + "wip 분기는 그대로 보존됨, 수동 정착 또는 충돌 해결 후 재시도" 를 사용자에게 보고한다.
   - **master/main 금지:** master/main HEAD 에서의 cherry-pick 은 `branch-enforce.sh §1.6` 차단 (merge §1.5 미러). PR 절차로 대체.

4. **정착 후 reachable 해시 기록 (추적성, 2026-06-02~):** ff-only 머지·cherry-pick 후 working/summary 에 기록하는 커밋 해시는 **정착 후 reachable 최종 해시**여야 한다 (`git rev-parse ${FEATURE}` / `git log -1 --format=%h`). 머지 전 wip 해시·rebase 이전 해시를 인용하면 HEAD 에서 도달 불가한 orphan 이 된다 (audit 2026-06-02 — BE summary 6개 해시 전부 orphan 인용, patch-id 로만 작업 확인됨). `/taskflow:retro` 단계에서 `git merge-base --is-ancestor` 로 재확인.

## Why

- **기존 feature 수정 = worktree → feature 환원 패턴.** 별 feature 신설 안 함.
- **ff-only 강제** → 머지 커밋 없음.
- **Claude 자동 머지 허용** (2026-06-04~ 사용자 명시 승인) — worktree → feature ff-only 머지 + worktree remove + wip branch -D 를 Claude 가 직접 수행. **단 대상이 master/main 이면 절대 금지** (branch-enforce §1.5 차단, PR 절차).

## SSOT
- CLAUDE.md §4.3 "worktree 항상 강제 + feature 요청 시 생성"
- 짝 진입점: `/git:create` (신규 feature 생성 시)
