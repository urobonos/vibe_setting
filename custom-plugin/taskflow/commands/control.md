---
description: 대기 큐 리뷰 — cwd product 의 `Status: NeedsDecision`(판단 대기) + `ReadyToMerge`(머지 대기) 문서를 리스트업 + 각 항목의 판단사항·머지 포인트 요약 + 처리 진입 안내. read-only(목록 후 정지, mutation 0). `/taskflow:tick`(무인 생산)의 소비 대시보드. 짝 = `/taskflow:tick`
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[all — 선택. 생략=cwd product / all=전체 product]"
---

`/taskflow:tick` 의 대칭짝 — tick 이 무인으로 쌓은 **사용자 대기 큐**(NeedsDecision·ReadyToMerge)를 한눈에 리뷰한다. **read-only**: 리스트업 + 처리 진입 안내까지만, 실제 머지·결정은 개별 `/taskflow:save`·`/taskflow:load` 로 수행한다 (`/taskflow:load` 목록 후 정지 정합).

## 리스트업 대상

| Status | 의미 | 요약 소스 (문서 §) | 처리 진입 |
|--------|------|------------------|----------|
| `NeedsDecision` | 사용자 **판단** 대기 | `## 결정 Escalation 로그` | `/taskflow:load {작업명}` → 판단사항 확인 후 결정 입력 |
| `ReadyToMerge` | 사용자 **머지** 대기 | `## 머지 전 리뷰 포인트` | `/taskflow:save {작업명}` → worktree 정착 승인 |

> 우선순위 = **NeedsDecision > ReadyToMerge** (판단은 후속 작업을 막지만, 머지 대기는 완료된 것이므로). SessionStart 배너(`agent-first-banner.sh`)의 1줄 요약과 동일 우선순위 — control 은 그 on-demand 상세판이다.

## 동작

1. **product 식별** — 인자 없음 = `resolve_product "$PWD"` (본 cwd product) / `all` = 전체 product.
2. **working/ 스캔** — `~/.claude/docs/working/YYYYMMDD/*.md` 에서 `Status: NeedsDecision|ReadyToMerge` 문서 수집 (step 평면 파일 `-step-NN-` 제외). product 매칭 = 파일명 `{date}-{product}-{작업명}`.
3. **REGISTRY 교차** — `REGISTRY.md` 의 `needs-decision`/`ready-to-merge` status entry 와 대조 (working 문서 Status ↔ REGISTRY status 정합 확인, 불일치 시 경고 1줄).
4. **각 항목 요약** — NeedsDecision = `## 결정 Escalation 로그` 표에서 "무엇을 결정해야 하는지" + 선택지 / ReadyToMerge = `## 머지 전 리뷰 포인트` 에서 worktree 경로 + 핵심 변경 + 미결.
5. **리스트업 출력 후 정지** — mutation 0. 처리는 사용자가 개별 슬래시로.

### 스캔 (Bash 예시)

```bash
source ~/.claude/hooks/lib/product-resolver.sh
PRODUCT=$(resolve_product "$PWD")          # 'all' 인자면 product 필터 생략
for f in ~/.claude/docs/working/*/*.md; do
  [ -f "$f" ] || continue
  basename "$f" | grep -qE -- '-step-[0-9]+-' && continue     # step 평면 파일 제외
  st=$(grep -m1 -oE '^Status:[[:space:]]*(NeedsDecision|ReadyToMerge)' "$f" | grep -oE '(NeedsDecision|ReadyToMerge)') || continue
  [ -z "$st" ] && continue
  # product 매칭 (all 이면 무조건 포함)
  fname=$(basename "$f")
  if [ "$1" != "all" ] && ! echo "$fname" | grep -qE -- "-${PRODUCT}-"; then continue; fi
  echo "$st | $fname"
done
```

각 문서 본문 요약은 Claude 본체가 Read 로 해당 § 섹션을 정독해 압축한다.

## 해소 후 문서 전파 (자동 — control 재구현 X)

control 은 read-only 라 전파를 **트리거하지 않는다**. 항목을 처리하는 경로가 태운다:

- **ReadyToMerge 해소:** `/taskflow:save {작업명}` → worktree 정착 승인 → `Status: ReadyToMerge` → `Status: Done` 전환 → `working-lifecycle.sh` PostToolUse 발동.
- **NeedsDecision 해소:** `/taskflow:load {작업명}` → 결정 입력 → `Status: In Progress` 재개 → 완주 → `ReadyToMerge` → 위 save 경로 → Done.

`Status: Done` 시 `working-lifecycle.sh` 가 자동 수행 (control 이 아니라 lifecycle 이 SSOT):

| 전파 | 내용 |
|------|------|
| tasks/ 이동 | working/ → `tasks/YYYYMMDD/{작업명}/{...}-unified.md` |
| 이력 기록 | history.md + YYYYMMDD/summary.md 갱신 |
| 작업분석 인덱스 역갱신 | Phase 4 backlink 심긴 survey 문서의 `⏳ Plan → ✓ Done` + tasks 링크 (`survey.md §전파`) |
| REGISTRY 정리 | 동일 slug entry 제거 + `state/sessions/{slug}/` lock 제거 |
| step 분배 | `-step-NN-` 평면 파일 → `tasks/.../{작업명}/steps/NN-{slug}.md` |

## 출력 예

```
[대기 큐 — cwd product=claude-harness]

⚠️ 판단 필요 (NeedsDecision) — 2건
  1. commerce-price-audit
     판단: 가격 반올림 정책 A(내림)/B(반올림) 중 — 매출 영향 상충 (§3 요구사항 상충)
     → /taskflow:load commerce-price-audit
  2. mod07-incentive
     판단: 정산 스키마 컬럼 추가 = DB 마이그레이션 (§3 비가역)
     → /taskflow:load mod07-incentive

✅ 머지 대기 (ReadyToMerge) — 1건
  1. chat-500-fix
     worktree: ~/.claude/worktrees/abc123-chat-500-fix / verify 5/5 · review 통과
     → /taskflow:save chat-500-fix

(처리 후 Status: Done 시 tasks/ 이동·인덱스 전파 자동. control 은 read-only.)
```

잔존 0건이면 `[대기 큐 — cwd product={PRODUCT}] 비어 있음` 1줄.

## §3 / read-only

- control 은 mutation 도구를 쓰지 않는다 (스캔·Read·요약만). 머지·결정·Status 변경은 전부 개별 `/taskflow:save`·`/taskflow:load` 경로 = §3 게이트가 그쪽에서 작동.
- 목록·요약 출력 후 정지 (`/taskflow:load` "목록 후 정지" 정합) — 스스로 처리 슬래시를 호출하지 않는다.

## SSOT

| 조각 | 역할 | SSOT |
|------|------|------|
| product 식별 | cwd → product | `hooks/lib/product-resolver.sh` |
| status 정의 | NeedsDecision / ReadyToMerge | `custom-plugin/taskflow/commands/tick.md` |
| 요약 소스 | §결정 Escalation 로그 / §머지 전 리뷰 포인트 | `tick.md` (기록 주체) |
| 처리 진입 | 머지 = save / 결정 = load | `custom-plugin/taskflow/commands/{save,load}.md` |
| 해소 후 전파 | Done 시 이동·인덱스·REGISTRY·step | `hooks/working-lifecycle.sh` + `survey.md §전파` |
| SessionStart 요약판 | 1줄 자동 배너 | `hooks/agent-first-banner.sh` (cwd 추천 블록) |

## 호출 예

```
/taskflow:control            ← cwd product 대기 큐 리뷰
/taskflow:control all        ← 전체 product 대기 큐 리뷰
```

## Changelog

- 2026-07-23: 신설 (tick 대기 큐 소비 대시보드)
