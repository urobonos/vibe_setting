---
description: 대기 큐 리뷰 — cwd product 의 `ReadyToMerge` step(머지 준비) + `NeedsDecision` task(판단 대기) + task별 완료 게이트 상태를 리스트업 + 처리 진입 안내. read-only(목록 후 정지, mutation 0). `/taskflow:tick`(무인 생산)의 소비 대시보드. 짝 = `/taskflow:tick`
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[all — 선택. 생략=cwd product / all=전체 product]"
---

`/taskflow:tick` 의 대칭짝 — tick 이 무인으로 올린 **사용자 대기 큐**를 한눈에 리뷰한다. **read-only**: 리스트업 + 진입 안내까지만, 실제 머지·결정은 개별 `/taskflow:save`·`/taskflow:load` 로.

> `/taskflow:watch` loop 가 돌고 있으면 리뷰 클린인 `ReadyToMerge` step 은 watch 가 ff머지로 먼저 해소한다. 그래서 여기 남는 건 **리뷰에서 반려된 것**(`Pending` 복귀 + 반려 체크박스)**과 판단 대기**다.

## 리스트업 대상

| 대상 | 단위 | 의미 | 요약 소스 | 처리 진입 |
|------|------|------|----------|----------|
| `NeedsDecision` | unified(task) | 판단 대기 | `## 결정 Escalation 로그` | `/taskflow:load {작업명}` → 결정 입력 |
| `ReadyToMerge` | **step** | 그 step 머지 준비 완료 | step 파일 `## 머지 전 리뷰 포인트` | `/taskflow:save {작업명}` → step 개별 머지 |
| 완료 게이트 | task | Done 가능 여부 | `working_gate_blockers` | blocker 0 시 `/taskflow:save` → Done |

> 우선순위 = **판단(NeedsDecision) > 머지 준비(ReadyToMerge step) > 완료 게이트**. NeedsDecision 은 후속 step 을 막고, ReadyToMerge step 은 머지 대기, 완료 게이트는 task 종결 조건이다. SessionStart 배너의 1줄 요약과 동일 — control 은 on-demand 상세판.

## 동작

1. **product 식별** — 인자 없음 = `resolve_product "$PWD"` / `all` = 전체.
2. **working-scan** — `hooks/lib/working-scan.sh::working_scan {product}` 로 unified + step 문서 상태를 일괄 수집 (인라인 grep 재작성 금지, SSOT 재사용).
3. **분류** — `ReadyToMerge` step(is_step=1) / `NeedsDecision` task(is_step=0) / task별 완료 게이트(`working_gate_blockers`).
4. **각 항목 요약** — NeedsDecision = `## 결정 Escalation 로그` 판단사항 + 선택지 / ReadyToMerge step = `## 머지 전 리뷰 포인트`(worktree·핵심 변경·verify/review).
5. **출력 후 정지** — mutation 0.

### 스캔 (Bash — working-scan 재사용)

```bash
source ~/.claude/hooks/lib/product-resolver.sh
source ~/.claude/hooks/lib/working-scan.sh
PRODUCT=$(resolve_product "$PWD")          # 'all' 인자면 working_scan all

# 판단 대기 / 머지 준비 step
working_scan "$PRODUCT" | while IFS=$'\t' read -r path date prod task st is_step; do
  case "$st" in
    NeedsDecision) [ "$is_step" = 0 ] && echo "판단  | $task | $(basename "$path")" ;;
    ReadyToMerge)  [ "$is_step" = 1 ] && echo "머지  | $task | $(basename "$path")" ;;
  esac
done

# task별 완료 게이트 (blocker 0 = Done 가능)
for t in $(working_scan "$PRODUCT" | cut -f4 | sort -u); do
  bl=$(working_gate_blockers "$PRODUCT" "$t")
  [ -z "$bl" ] && echo "완료가능 | $t" || echo "미완 | $t | $(echo "$bl" | paste -sd';')"
done
```

각 문서 본문 요약은 Claude 본체가 Read 로 해당 § 섹션을 정독해 압축한다.

## 해소 후 문서 전파 (자동 — control 재구현 X)

control 은 read-only 라 전파를 트리거하지 않는다. 처리 경로가 태운다:

- **ReadyToMerge step 해소:** `/taskflow:save {작업명}` → step 개별 머지 → step `Status: Done`.
- **모든 step 머지 + 완료 게이트 통과:** save 가 `working_gate_blockers` 0 확인 → unified `Status: Done` → `working-lifecycle.sh` PostToolUse 발동.
- **NeedsDecision 해소:** `/taskflow:load {작업명}` → 결정 입력 → Claude 본체가 결정 기록 + step `상태: Pending` 복귀 + unified `Status: In Progress` + `registry_update … active` (절차 SSOT = `tick.md` §"결정 수용") → 다음 tick 이 재잡이 → ReadyToMerge → 위 경로.

`Status: Done` 시 `working-lifecycle.sh` 자동: tasks/ 이동 · history/summary · 작업분석 인덱스 역갱신 · REGISTRY·lock 정리 · step 평면 파일 `steps/` 분배. (SSOT = `working-lifecycle.sh` + `survey.md §전파`)

## 출력 예

```
[대기 큐 — cwd product=claude-harness]

⚠️ 판단 필요 (NeedsDecision) — 1건
  1. commerce-audit  판단: 가격 반올림 A(내림)/B(반올림) — 매출 상충 (§3) → /taskflow:load commerce-audit

✅ 머지 준비 step (ReadyToMerge) — 2건
  1. commerce-audit / step-01-price-calc   verify 5/5·review 통과 → /taskflow:save commerce-audit
  2. commerce-audit / step-02-rounding     verify 5/5

🚦 완료 게이트
  - commerce-audit: 미완 — step-03 In Progress · NeedsDecision · 미체크박스 2건 (해소 후 Done 가능)
```

잔존 0건이면 `[대기 큐 — cwd product={PRODUCT}] 비어 있음` 1줄.

## §3 / read-only

- control 은 mutation 도구를 쓰지 않는다 (스캔·Read·요약만). 머지·결정·Status 변경은 개별 `/taskflow:save`·`/taskflow:load` = §3 게이트가 그쪽에서 작동.
- 목록·요약 출력 후 정지 (`/taskflow:load` "목록 후 정지" 정합) — 스스로 처리 슬래시를 호출하지 않는다.

## SSOT

| 조각 | 역할 | SSOT |
|------|------|------|
| product 식별 | cwd → product | `hooks/lib/product-resolver.sh` |
| **working/ 스캔 + 완료 게이트** | `working_scan` · `working_gate_blockers` | **`hooks/lib/working-scan.sh`** |
| status 정의 | ReadyToMerge(step) / NeedsDecision(task) | `custom-plugin/taskflow/commands/tick.md` |
| 처리 진입 | 머지·완료 = save / 결정 = load | `custom-plugin/taskflow/commands/{save,load}.md` |
| 해소 후 전파 | Done 시 이동·인덱스·REGISTRY·step | `hooks/working-lifecycle.sh` + `survey.md §전파` |
| SessionStart 요약판 | 1줄 자동 배너 | `hooks/agent-first-banner.sh` (cwd 추천 블록) |

## 호출 예

```
/taskflow:control            ← cwd product 대기 큐 리뷰
/taskflow:control all        ← 전체 product 대기 큐 리뷰
```

## Changelog

- 2026-07-23: 신설 → step ReadyToMerge + 완료 게이트 + working-scan 재사용
