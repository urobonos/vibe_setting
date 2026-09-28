---
description: 메모리 통합 단계 진입 — 세션 트랜스크립트에서 신호를 뽑아 memory/ 를 정제한다. 직접 쓰지 않고 제안 diff 를 남긴 뒤 승인받아 반영.
allowed-tools: Bash, Edit, Write, Read, Glob, Grep
argument-hint: "[product-slug]  # 생략 시 현재 cwd 의 product"
---

메모리 통합(dream) 단계 진입 — `projects/{slug}/*.jsonl` 세션 이력을 훑어 `projects/{slug}/memory/` 를 정제한다.

**핵심 제약: dream 은 memory 파일을 직접 고치지 않는다.** 제안 diff 를 `output/analysis/` 에 남기고 사용자 승인 후 같은 세션에서 반영한다 (§3 비가역 보호).

## 인자

- `$ARGUMENTS` = (선택) `projects/` 하위 슬러그. 생략 시 cwd 로 결정 (`C:\Works\hongcafe-local-athena` → `C--Works-hongcafe-local-athena`).
- **product 단위 실행이 원칙.** memory 가 12개 프로젝트로 갈라져 있어 전역 1회 실행은 12곳 동시 mutation = §3 폭발.

## 동작 4단계

| 단계 | 동작 | 결과 |
|------|------|------|
| ① ORIENT | `memory/` 스캔 — 파일 수 / `MEMORY.md` 줄 수 / 타입 prefix 준수율 / backlog 인덱스 등재율 | 현황 표 (줄 수 200 근접 시 경고) |
| ② GATHER | `dream-scan.py` 로 트랜스크립트에서 correction·preference·decision 신호 추출 | 발췌 표 (전체 읽기 금지) |
| ③ CONSOLIDATE | 신호 → 기존 메모리 대조. 중복 병합 / 모순 해소 / 상대날짜 → 절대날짜 / 4분류 prefix 정규화 | 제안 diff |
| ④ PRUNE & INDEX | `MEMORY.md` 재작성안(200줄 상한, 포인터 1줄씩) + stale → `output/archive/` 이동안 + `INJECT.md` top-N 산출 | 제안 diff |

### ① ORIENT

```bash
SLUG={slug}; M=~/.claude/projects/$SLUG/memory
echo "파일 $(ls $M/*.md 2>/dev/null | wc -l) / MEMORY.md $(wc -l < $M/MEMORY.md)줄"
ls $M | sed 's/_.*//' | sort | uniq -c | sort -rn | head
```

`MEMORY.md` 가 **190줄을 넘으면 그 자체가 Critical** — 네이티브 자동 주입이 200줄에서 끊기고, 잘린 줄에 걸린 파일은 recall 단서를 잃는다 (2026-09-07 실측: 210줄·10줄 조용한 절단).

### ② GATHER

```bash
python3 ~/.claude/custom-plugin/taskflow/scripts/dream-scan.py --project {slug} --days 30
```

스크립트는 추출만 한다. **무엇을 메모리로 승격할지 판단은 이 단계가 아니라 ③ 에서 Claude 가 한다.**

### ③ CONSOLIDATE — 승격 기준

승격한다: 반복된 교정 · 명시된 선호 · 되돌아올 결정 · 재확인 비용이 큰 사실.
승격하지 않는다: 레포가 이미 기록하는 것(코드 구조·git 이력·CLAUDE.md) · 그 대화에서만 의미 있는 것 · 1회성 지시.

기존 파일과 겹치면 **새 파일을 만들지 말고 그 파일을 갱신**한다. 틀린 것으로 판명된 메모리는 삭제 대상으로 제안한다.

### ④ PRUNE & INDEX

- `MEMORY.md` 는 인덱스다 — 한 줄에 `- [제목](파일.md) — hook` 하나. 본문을 넣지 않는다.
- hook 문장은 **검색 가능한 명사**를 담는다. 네이티브 recall 이 이 한 줄만 보고 파일을 열지 결정하기 때문이다.
- 90일 이상 참조되지 않고 현행성이 끝난 항목은 삭제가 아니라 `~/.claude/docs/{product}/output/archive/` 로 이동 제안.
- `memory/INJECT.md` = 매 세션 강제 주입할 top 5~10건. `custom-plugin/taskflow/hooks/memory-inject.sh` 가 읽는다. 상한 초과분은 넣지 않는다.

## 출력과 승인

제안은 `~/.claude/docs/{product}/output/analysis/{YYYY-MM-DD}-dream-{NN}/` 에 남긴다.

| 파일 | 내용 |
|------|------|
| `{YYYY-MM-DD}-dream-report.md` | ①② 현황·신호 + ③④ 제안 요약 |
| `proposed-MEMORY.md` | 재작성안 전문 — **190줄 근접 시에만**. 여유 있으면 report 안 추가 diff 로 갈음 |
| `proposed-INJECT.md` | top-N 주입안 |

승인 후 반영한다. 반영 전 `memory/` 를 `~/.claude/backup/{YYYY-MM-DD}-dream-{slug}/` 로 복사한다 (원복 경로 확보).

## 트리거

수동 슬래시만. cron 자동화는 수동 실행 실측(제안 정확도·소요 시간)이 쌓인 뒤 별건으로 판단한다 — 무인 실행이 §3 비가역과 맞물리므로 선제 자동화하지 않는다.

## 직병렬 실행 지침

| 태스크 | 직렬·병렬 | 방법 |
|--------|----------|-----|
| ① ORIENT + ② GATHER | **병렬 가능** | 독립 조회 — 단일 응답 내 Bash 동시 호출 |
| ③ CONSOLIDATE | **직렬** | ①② 결과에 의존 |
| ④ PRUNE + INJECT 산출 | **직렬** | ③ 결과에 의존 |
| 다중 product | **직렬** | product 단위 승인이 끊기므로 병렬 금지 |

## Why

메모리는 줄어드는 경로가 없어 단조 증가한다 — backlog 328건이 2026-05-20 부터 3.5개월간 완료 0건으로 쌓인 것이 실증이다. `/taskflow:retro` 는 세션 단위 기록이고, dream 은 그 누적분을 되돌아보는 반대 방향 작업이다. 둘은 대체 관계가 아니다.

자동 쓰기를 주지 않은 이유: 잘못된 통합은 조용히 누적되고, 메모리는 다음 세션의 판단 근거가 되므로 오염 비용이 비대칭적으로 크다.

**SSOT:** 본 파일 + `custom-plugin/taskflow/scripts/dream-scan.py` + `custom-plugin/taskflow/hooks/memory-inject.sh`
