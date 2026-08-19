---
description: worktree(wip) 작업 → 기존 feature 분기 ff-only 머지·정착
---

# /git:merge

기존 feature 분기 수정 worktree 작업 완료 후 해당 feature 로 ff-only 머지 + worktree/wip 삭제.

## 절차

1. worktree (`wip/{sid}-{slug}`) commit 완료 확인 — base = `feature/{이름}`
2. 대상 feature 분기 확인

> **`/taskflow:code` 가 만든 worktree(`wip/{sid8}-{slug}`)는 아래 3 대신 §"squash 정착" 으로 간다.** 판정 기준은 브랜치 이름이 아니라 **출처**다 — 리뷰 루프가 라운드마다 커밋을 쌓아 중간 상태가 남기 때문이다. `/taskflow:tick`·`/taskflow:watch`·`/taskflow:save` 경로는 3 그대로(ff-only).
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

## squash 정착 — `/taskflow:code` 산 worktree

**`wip/{sid8}-{slug}` 패턴(= `/taskflow:code` 분리 루프 산출물)은 squash 머지가 기본이다.** 라운드별 중간 상태를 이력에 남기지 않는다 (근거 = `custom-plugin/taskflow/commands/code.md` §"정착은 1커밋으로").

각 명령을 **개별 Bash 호출**로 실행한다 (`&&`/`;` 결합 금지 — 위 3의 결합 금지 이유 그대로).

```bash
# FEATURE = feature/{이름} — master/main 이면 정착 절대 금지 (branch-enforce §1.5 차단, PR 절차로 대체)
git checkout feature/{이름}
git merge --squash wip/{sid8}-{slug}
git commit -m "type(scope): 제목"
git worktree remove ~/.claude/worktrees/{sid8}-{slug}
git branch -D wip/{sid8}-{slug}
```

- **`--squash` 는 스테이징만 한다** — 커밋이 자동 생성되지 않으므로 `git commit` 이 별도 명령으로 붙는다. 3(ff-only)이 4명령인데 여기가 5명령인 이유다.
- **cherry-pick fallback 이 없다.** `--squash` 는 feature 가 분기 후 전진(divergence)해도 성공하므로 3의 ff-only 실패 경로가 발생하지 않는다. 충돌이 나면 자동 해결하지 않고 `git merge --abort` 후 충돌 파일 목록을 보고하고 정지한다 (wip 분기는 보존된다).
- **`git branch -D` 는 그대로다.** squash 후 wip 은 "not fully merged" 상태지만 `-D` 가 강제 삭제하고, `dangerous-ops-guard.sh` 의 단일 라인 면제도 그대로 매칭된다.
- **커밋 메시지 = `/taskflow:code` 1단계에서 확정한 type·scope + 제목 한 줄.** 포맷 SSOT 는 `custom-plugin/git/skills/push/SKILL.md` §"커밋 메시지 컨벤션" 이다 — type 목록·scope 규칙·72자·명령형을 **여기서 재정의하지 않는다.** 본문을 쓰는 경우는 BREAKING CHANGE(`type(scope)!:` + footer) 뿐이다.
- **push 하지 않는다.** push 스킬 §"규칙"(자동 원격 push 전면 금지)과 `branch-enforce.sh` 가 그대로 적용된다. 머지 후 사용자에게 `! git push origin {branch}` 형태를 안내하는 것까지가 범위다.
- 정착 후 해시 기록은 위 4 그대로 (squash 커밋 = 새 해시이므로 wip 해시를 인용하면 orphan 이 된다).

## Why

- **기존 feature 수정 = worktree → feature 환원 패턴.** 별 feature 신설 안 함.
- **ff-only 강제** → 머지 커밋 없음.
- **Claude 자동 머지 허용** (2026-06-04~ 사용자 명시 승인) — worktree → feature ff-only 머지 + worktree remove + wip branch -D 를 Claude 가 직접 수행. **단 대상이 master/main 이면 절대 금지** (branch-enforce §1.5 차단, PR 절차).

## SSOT
- CLAUDE.md §4.3 "worktree 항상 강제 + feature 요청 시 생성"
- 짝 진입점: `/git:create` (신규 feature 생성 시)
- 커밋 포맷: `custom-plugin/git/skills/push/SKILL.md` §"커밋 메시지 컨벤션" (본 파일에 재정의 0)

## Changelog

- 2026-08-19: **`/taskflow:code` 산 worktree 전용 squash 정착 분기 추가** — 리뷰 루프가 라운드마다 쌓은 중간 커밋은 리뷰를 통과한 적이 없고, 린터 `--fix` 커밋이 `git blame` 을 오염시킨다. **기존 ff-only 경로(`/taskflow:tick`·`/taskflow:watch`·`/taskflow:save`)는 건드리지 않았다** — CLAUDE.md §4.3(f)·`watch.md` 머지 사다리 L1~L3 가 ff-only 를 전제한다. 커밋 포맷은 push 스킬 포인터(재정의 0), push 는 여전히 사용자 직접
