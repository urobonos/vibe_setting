---
description: tick 병렬 오케스트레이터 — leader 가 워커 Agent 를 동적 spawn/kill 하고, 각 워커는 `registry_claim`(원자)으로 진행 가능 step 을 **자율 점유**해 병렬 진행. slug 발생 시 spawn / 완료 시 종료(유동 풀). tick(1워커)의 병렬 상위. 짝 = `/taskflow:tick`
allowed-tools: Bash, Read, Glob, Grep, Agent, Skill, PowerShell
argument-hint: "[N — 최대 동시 워커 수. 생략 시 min(진행가능 slug, min(16, cores-2))]"
---

`/taskflow:tick`(1 워커)의 **병렬 오케스트레이터**. leader 가 진행 가능 step 을 워커 팀에 맡기되, **분배를 leader 가 하지 않는다** — 중앙 분배는 순차 병목이므로, 각 워커가 lock 으로 **자율 claim** 한다 (진짜 동시).

## 핵심 원칙

- **워커 자율 claim (원자).** leader 는 워커 spawn/kill 만 담당. 각 워커가 `registry_claim`(lock 안 확인+add 원자)으로 자율 점유 → TOCTOU race 0. **`registry_find`+`registry_add` 분리 방식 금지** (밀리초 동시 race).
- **동적 유동 풀.** slug 발생 → 워커 spawn / 워커 완료 → 종료(kill). 놀고 있는 워커 0.
- **worktree 격리.** 각 워커 Agent = `isolation: worktree` → 병렬 코드 mutation 충돌 0.
- **로직 재구현 0.** 워커 = `/taskflow:tick` 1회분(claim + auto). leader = spawn + 수합.

## 동작

1. **leader**: `working_scan all` → 진행 가능 step slug 목록 산출 (tick 2-bis 의존 판정 재사용 — Pending + 직접 의존 선행 완료).
2. **동시 상한 N** = `min(진행가능 slug, min(16, cores-2))` (기본) 또는 인자 N.
3. **워커 spawn** (slug 후보마다, 상한 N까지) — Agent `isolation: worktree`, 프롬프트:
   > registry_claim 으로 다음 미점유 step 을 자율 claim (`CLAIMED`=진행 / `TAKEN`=다음 후보) → `/taskflow:auto` 로 그 step 진행(개발+verify+review) → 완료 시 step `상태: ReadyToMerge` + `registry_update {slug} {sid} paused`(반납) → 종료.
4. **수합·유동**: 워커 완료 → leader 가 결과 수합(claim 반납 확인). 진행 가능 slug 가 남아 있으면 빈 슬롯에 추가 spawn. 진행 가능 slug **0** → 종료.

## claim 원자성 (필수)

워커 동시 claim = **`registry_claim`** (lock 안 원자). 검증: 5 프로세스 동시 같은 slug → 1 `CLAIMED`, 4 `TAKEN`, REGISTRY entry 1개 (2026-07-23 실측). `registry_find`→`registry_add` 분리 방식은 밀리초 동시에 중복 claim 발생 → **금지**.

```bash
source ~/.claude/hooks/lib/registry-utils.sh
RESULT=$(registry_claim "{slug}" "{product}" "{sid8}" "{cwd}" "{working_file}")
# CLAIMED:<slug> → 진행 / ALREADY:<sid> → 본인 재claim / TAKEN:<sid> → 다음 후보
```

## Workflow 도구 활용 (선택, 대규모)

fan-out 규모가 크면 Workflow 도구(`parallel`/`pipeline`)로 구조화 가능 (opt-in — 사용자 명시). leader = `pipeline(slugs, claim→auto→release)`. 소규모는 Agent 직접 spawn 으로 충분.

## §3 Checkpoint

- 워커 코드 변경 = 각자 worktree 격리. **정착·머지·push = 사용자 직접** (tick 정합, §4.3).
- 워커 `registry_claim`/반납 = lock mutation (회복 가능). 실제 코드 작업이 §3 매칭이면 각 워커의 hook(dangerous-ops/branch-enforce)이 차단 — tick-team 이 §3 우회 통로가 아니다.
- leader 는 워커 수만 조절, 코드 판단은 각 워커 책임.

## SSOT

| 조각 | SSOT |
|------|------|
| **원자 claim** | `hooks/lib/registry-utils.sh::registry_claim` |
| 워커 로직 (claim+auto+반납) | `custom-plugin/taskflow/commands/tick.md` |
| step 스캔 + 진행가능 판정 | `hooks/lib/working-scan.sh` + tick.md §2-bis |
| fan-out 수단 | Agent `isolation: worktree` / Workflow 도구 |
| 대기 큐 리뷰 | `custom-plugin/taskflow/commands/control.md` |

## 호출 예

```
/taskflow:tick-team          ← 진행 가능 slug 만큼 워커 (상한 자동)
/taskflow:tick-team 3        ← 최대 3 워커 동시
```

> **loop 결합:** `/loop 30m /taskflow:tick-team` 도 가능하나, 단일 `/taskflow:tick` loop 가 안정화된 뒤 사용 권장 (병렬 + loop 동시 도입은 진단 난이도↑).

## Changelog

- 2026-07-23: 신설 (동적 워커 풀 — 워커 자율 원자 claim, worktree 격리)
