---
name: report-competency
description: "월간 역량평가(30%) 실행 — 9항목(업무능력·업무태도·협업능력) 산정 + 직전 확정 대비 Before/After. 매월 1회. 트리거: 역량평가, 월간 역량"
---

# tools:report-competency — 월간 역량평가 (30%)

인자: `[YYYY-MM]` (생략 시 직전 월). 공통 원칙·수집 실패 대비 = `${CLAUDE_PLUGIN_ROOT}/templates/common-rules.md` **필독 후 진행**.

## 절차

1. **수집** — 본 플러그인 agents 병렬 3종 (기간 = 대상 월): `gantt-collector` · `history-collector` · `git-collector`.
2. **산정** — `${CLAUDE_PLUGIN_ROOT}/templates/competency-table.md` 양식: 9항목, 직전 확정본 대비 **Before/After 표 필수**, 변동 항목마다 증빙 1줄.
3. **출력** — 평가표 + Before/After + 참조 출처 → 산출물 저장 + 채팅 보고 (결론 먼저, 소계·등급·변동 요약 우선).
4. **합산 연계** — 전체(100%) 필요 시 최신 `tools:report-kpi` 결과와 결합 (업적 환산 + 역량 환산).
