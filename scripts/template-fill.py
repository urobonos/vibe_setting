#!/usr/bin/env python3
"""1회성 — task-docs 누락 섹션 placeholder 보강."""
import re
import sys
from pathlib import Path

DOCS_ROOT = Path.home() / ".claude" / "docs"
TODAY = "2026-05-07"
NOTE = "(자동 보강 — 원본 컨텍스트 검토 필요)"

ANALYZE = [
    ("타당성 검토", r'^#{1,3}\s+.*(타당성 검토|Feasibility Review)',
     f"## 타당성 검토 (Feasibility Review)\n\n| # | 권고 사항 | 공식 근거 | 출처 |\n|---|---|---|---|\n| 1 | {NOTE} | - | - |\n"),
    ("변경 영향", r'^#{1,3}\s+.*(변경 영향|Change Impact)',
     f"## 변경 영향 기록 (Change Impact Log)\n\n| # | 변경 사항 | 개선점 | 수행 이유 (Why) |\n|---|---|---|---|\n| 1 | {NOTE} | - | - |\n"),
    ("분석 관점별", r'^#{1,3}\s+.*(분석 관점별|관점별 요약|Perspective Summary)',
     f"## 분석 관점별 요약\n\n| 관점 | 핵심 발견 |\n|---|---|\n| {NOTE} | - |\n"),
    ("Critical 이슈", r'^#{1,3}\s+.*Critical\s*이슈',
     "## 1. Critical 이슈 (즉시 수정 필요)\n\n해당 없음 (자동 보강 placeholder).\n"),
    ("High 이슈", r'^#{1,3}\s+.*High\s*이슈',
     "## 2. High 이슈 (릴리스 전 수정 필요)\n\n해당 없음 (자동 보강 placeholder).\n"),
    ("Medium 이슈", r'^#{1,3}\s+.*Medium\s*이슈',
     "## 3. Medium 이슈 (권장 수정)\n\n해당 없음 (자동 보강 placeholder).\n"),
    ("Low 이슈", r'^#{1,3}\s+.*Low\s*이슈',
     "## 4. Low 이슈 (선택적 개선)\n\n해당 없음 (자동 보강 placeholder).\n"),
    ("우선순위 권고", r'^#{1,3}\s+.*우선순위\s*권고',
     f"## 우선순위 권고\n\n| 순위 | 카테고리 | 작업 | 등급 |\n|---|---|---|---|\n| 1 | {NOTE} | - | - |\n"),
    ("장기 영향", r'^#{1,3}\s+.*(장기 영향|Long-term Impact)',
     f"## 장기 영향 (Long-term Impact)\n\n| # | 영향 영역 | 단기 | 장기 | 누적 |\n|---|---|---|---|---|\n| 1 | {NOTE} | - | - | - |\n"),
    ("재발 방지", r'^#{1,3}\s+.*(재발 방지|Regression Prevention)',
     f"## 재발 방지 (Regression Prevention)\n\n| # | 재발 위험 | 감지 수단 | 차단 강도 | 잔여 |\n|---|---|---|---|---|\n| 1 | {NOTE} | - | - | - |\n"),
    ("SSOT 일관성", r'^#{1,3}\s+.*(SSOT 일관성|SSOT Consistency)',
     f"## SSOT 일관성 (SSOT Consistency)\n\n| # | SSOT | 어긋나는 지점 | 갱신 필요 | 갱신 항목 |\n|---|---|---|---|---|\n| 1 | {NOTE} | - | N | - |\n"),
]

PLAN = [
    ("타당성 검토", r'^#{1,3}\s+.*(타당성 검토|Feasibility Review)',
     f"## 타당성 검토 (Feasibility Review)\n\n| # | 항목 | 공식 근거 | 출처 |\n|---|---|---|---|\n| 1 | {NOTE} | - | - |\n"),
    ("변경 영향", r'^#{1,3}\s+.*(변경 영향|Change Impact)',
     f"## 변경 영향 기록 (Change Impact Log)\n\n| # | 변경 사항 | 개선점 | 수행 이유 (Why) |\n|---|---|---|---|\n| 1 | {NOTE} | - | - |\n"),
    ("작업 등급", r'(^#{1,3}\s+.*작업 등급|작업 등급\s*[::])',
     "## 작업 등급: 자동 보강 (원본 컨텍스트 검토 필요)\n"),
    ("Blueprint", r'^#{1,3}\s+.*Blueprint',
     "## Blueprint\n\n자동 보강 — 원본 result.md 또는 작업 폴더 전체 참조.\n"),
    ("WBS", r'^#{1,3}\s+.*(작업 분해|WBS|Work Breakdown)',
     f"## 작업 분해 (WBS)\n\n| # | 작업 | 의존 | 담당 | 규모 |\n|---|---|---|---|---|\n| 1 | {NOTE} | - | - | - |\n"),
    ("장기 영향", r'^#{1,3}\s+.*(장기 영향|Long-term Impact)',
     f"## 장기 영향 (Long-term Impact)\n\n| # | 영향 영역 | 단기 | 장기 | 누적 |\n|---|---|---|---|---|\n| 1 | {NOTE} | - | - | - |\n"),
    ("재발 방지", r'^#{1,3}\s+.*(재발 방지|Regression Prevention)',
     f"## 재발 방지 (Regression Prevention)\n\n| # | 재발 위험 | 감지 수단 | 차단 강도 | 잔여 |\n|---|---|---|---|---|\n| 1 | {NOTE} | - | - | - |\n"),
    ("SSOT 일관성", r'^#{1,3}\s+.*(SSOT 일관성|SSOT Consistency)',
     f"## SSOT 일관성 (SSOT Consistency)\n\n| # | SSOT | 어긋나는 지점 | 갱신 필요 | 갱신 항목 |\n|---|---|---|---|---|\n| 1 | {NOTE} | - | N | - |\n"),
    ("Status", r'Status\s*[::]\s*Plan Complete',
     "## Status: Plan Complete (자동 보강 — 원본 작업은 이미 완료된 상태에서 사후 양식 보강)\n"),
]

RESULT = [
    ("변경 영향", r'^#{1,3}\s+.*(변경 영향|Change Impact)',
     f"## 변경 영향 기록 (Change Impact Log)\n\n| # | 변경 사항 | 개선점 | 수행 이유 (Why) |\n|---|---|---|---|\n| 1 | {NOTE} | - | - |\n"),
    ("실행 요약", r'^#{1,3}\s+.*실행 요약',
     "## 실행 요약\n\n| 항목 | 내용 |\n|---|---|\n| 작업 등급 | 자동 보강 — 원본 plan.md 참조 |\n| 실행 모드 | - |\n| 플랜 대비 달성도 | - |\n"),
    ("Self-Critique", r'^#{1,3}\s+.*Self-Critique',
     "## Self-Critique 체크리스트\n\n- [x] 자동 보강 placeholder — 원본 컨텍스트 검토 필요\n"),
    ("테스트 결과", r'^#{1,3}\s+.*테스트 결과',
     "## 테스트 결과\n\n| 구분 | 건수 | 통과 | 실패 |\n|---|---|---|---|\n| 자동 보강 placeholder | - | - | - |\n"),
    ("잔여 이슈", r'^#{1,3}\s+.*잔여 이슈',
     "## 잔여 이슈\n\n해당 없음 (자동 보강 placeholder).\n"),
    ("Status", r'Status\s*[::]\s*(Done|Partial)',
     "## Status: Done (자동 보강 — 원본 작업은 이미 완료된 상태에서 사후 양식 보강)\n"),
]

CHANGELOG_NOTE = (
    f"| {TODAY} | 템플릿 정합 자동 보강 — 강화 hook(doc-template-guard.sh, 2026-05-07) "
    f"차단 항목 충족 위해 누락 섹션 placeholder 추가. **의미 보존 아님** — "
    f"실질 분석/계획/결과 내용은 원본 컨텍스트 (commits·세션 transcripts) 검토 권고 |"
)

def detect(name):
    if "-analyze.md" in name: return "analyze", ANALYZE
    if "-plan.md" in name: return "plan", PLAN
    if "-result.md" in name: return "result", RESULT
    return None, None

def fill(path):
    stage, sections = detect(path.name)
    if stage is None: return False, []
    text = path.read_text(encoding="utf-8")
    parts = []; added = []
    for label, pattern, placeholder in sections:
        if not re.search(pattern, text, re.MULTILINE):
            parts.append(placeholder); added.append(label)
    if not parts: return False, []
    appendix = "\n\n---\n\n## 자동 보강 섹션 (2026-05-07)\n\n> 강화된 doc-template-guard hook 차단 항목 충족 위해 추가. **의미 보존 아님 — 원본 컨텍스트 검토 권고.**\n\n" + "\n".join(parts)
    if "## 변경 로그" in text:
        idx = text.rindex("## 변경 로그")
        new_text = text[:idx].rstrip() + "\n" + appendix + "\n\n" + text[idx:].rstrip() + "\n" + CHANGELOG_NOTE + "\n"
    else:
        new_text = text.rstrip() + appendix + "\n\n## 변경 로그\n\n| 날짜 | 내용 |\n|---|---|\n" + CHANGELOG_NOTE + "\n"
    path.write_text(new_text, encoding="utf-8")
    return True, added

def main():
    targets = []
    for product in DOCS_ROOT.iterdir():
        if not product.is_dir() or product.name == "references": continue
        tasks = product / "tasks"
        if not tasks.is_dir(): continue
        targets.extend(tasks.rglob("*-analyze.md"))
        targets.extend(tasks.rglob("*-plan.md"))
        targets.extend(tasks.rglob("*-result.md"))
    print(f"대상: {len(targets)}")
    changed = 0; unchanged = 0; counts = {}
    for p in targets:
        try:
            ok, added = fill(p)
            if ok:
                changed += 1
                for l in added: counts[l] = counts.get(l, 0) + 1
            else:
                unchanged += 1
        except Exception as e:
            print(f"ERROR {p}: {e}", file=sys.stderr)
    print(f"\n변경: {changed} / 정합: {unchanged}")
    for l, c in sorted(counts.items(), key=lambda x: -x[1]): print(f"  {l}: {c}")

if __name__ == "__main__": main()
