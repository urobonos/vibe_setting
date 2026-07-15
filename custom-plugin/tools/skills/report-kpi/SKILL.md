---
name: report-kpi
description: "분기 업적평가(70%) 실행 — KPI 7영역 산정 + 세부의견 + 인사 제출본 + 역량 합산 전체 종합. 3개월 주기. 트리거: 업적평가, KPI 평가, 분기 평가"
---

# tools:report-kpi — 분기 업적 KPI (70%) + 전체 합산

인자: `[기간]` (예: `2026-Q3` 또는 `7~9월`, 생략 시 직전 3개월). 공통 원칙·수집 실패 대비 = `${CLAUDE_PLUGIN_ROOT}/templates/common-rules.md` **필독 후 진행**.

## 절차

1. **수집** — 본 플러그인 agents 병렬 4종 (기간 = 3개월): `gantt-collector` · `docs-index-collector` · `history-collector` · `git-collector`.
2. **산정** — `${CLAUDE_PLUGIN_ROOT}/templates/kpi-table.md` 양식: 7영역, 전 영역 정량평가 표기, 달성률 분모는 영역별 실측으로 조절.
3. **세부의견** — 성과 나열 + 차별점 서술 ("~한 점이 우수/차별적"), A 미만은 근거를 성과 서술에 내재.
4. **제출본** — `${CLAUDE_PLUGIN_ROOT}/templates/submission-rules.md` 적용 별도 섹션 (내부 용어 제거판).
5. **합산** — 최신 `tools:report-competency` 결과와 합산 (업적 환산 + 역량 환산 = 합계 100%) → 전체 종합의견 = 산문 2~3문장, 수치 최소, 세부의견 중복(리바이벌) 금지, 평가성 사족·전망 금지.
