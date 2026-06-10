---
name: report
description: >
  업무 리포트 생성 스킬. 일일·주간·월간 리포트 산출.
  ~/.claude/docs/{product}/tasks/ 하위 작업 이력을 product 별로 스캔하여
  주제별 그룹화 + 진행률 판정 후 정리한다.
  절차·출력 형식 SSOT 는 commands/report.md.
triggers:
  - "/report"
  - "/report weekly"
  - "/report monthly"
  - "업무 리포트"
  - "업무 정리"
  - "리포트 만들어줘"
  - "리포트 작성"
  - "주간 리포트"
  - "월간 리포트"
  - "일일 리포트"
  - "오늘 작업 정리"
  - "이번 주 작업 정리"
version: 1.0.1
user-invocable: true
depends_on: [task-docs]
conflicts_with: []
min_claude_md_version: "4.0"
---

# Report Skill

업무 리포트 생성. 본 skill 은 **자연어 트리거 매칭** 과 **slash 진입점 명세** 만 담당하고, 실제 절차·출력 형식·진행률 판정 룰은 `commands/report.md` 가 SSOT.

> **[SSOT 분담]** `commands/report.md` = 절차 SSOT (수행 단계·출력 형식·정제 룰). 본 skill = 자연어 트리거 + frontmatter description 의 세션 카탈로그 자동 등재 (절차 본문은 commands/report.md 호출 시 로드). 두 파일 충돌 시 commands/report.md 우선.

---

## 1. 호출 방식

### 1.1. 자동 트리거 (자연어)

frontmatter `triggers` 의 자연어 패턴이 사용자 발화에 매칭되면 즉시 호출.

**트리거 예시 (호출됨):**
- "오늘 작업 정리해줘"
- "이번 주 업무 리포트 만들어줘"
- "월간 리포트 작성해줘"

**트리거 안 됨 (의도된 차단):**
- "이 함수 뭐 함?" → 단일 BE 질문, 작업 이력 스캔 불필요
- "최근 commit 보여줘" → git log 조회로 충분, 리포트 형식 불필요

### 1.2. 슬래시 커맨드

```
/report          # 일일 리포트 (오늘 날짜)
/report weekly   # 주간 리포트
/report monthly  # 월간 리포트
```

---

## 2. 수행 절차

`commands/report.md` §"수행 절차" §1~§8 을 그대로 따른다.

핵심 흐름 요약 (상세는 commands/report.md SSOT):

1. `~/.claude/docs/*/tasks/` 글로브로 모든 product 디렉토리 일괄 스캔
2. 각 product `history.md` 에서 대상 기간 항목 확인
3. `YYYYMMDD/{작업명}/` 단계 문서 매핑 (`*-analyze.md` / `*-plan.md` / `*-result.md`) 로 진행률 판정
4. `summary.md` 보조 참고
5. 주제별 그룹화 (날짜 다중·task 다중 → 1 그룹)
6. 언어 평문화 + 보고 정제 (사내 약어·코드네임 → 한국어, 메타 디테일 제거)
7. 출력 형식 (일일: `📋 업무 리포트 — YYYY.MM.DD` + `[글로벌]-[부서]-{작업} (진행률)` 라인 / 주간·월간: 주제별 그룹 트리)

---

## 3. product → [태그] 매핑

`commands/report.md` §"product → [태그] 매핑" SSOT 참조. 신규 product 등장 시 원본 이름 그대로 표기 + 사용자에게 매핑 등록 여부 확인.

---

## 4. Concise Reporting 적용

본 스킬 결과는 **사용자가 한눈에 보는 업무 현황**이 목적이므로 CLAUDE.md §4 "응답 간결" 룰 우선 적용. 정제 룰 (commands/report.md §"보고 정제 룰") 을 엄격히 따라 메타 디테일·진행 서술 제거.

---

## 5. Why

- `/report` 가 `commands/` 단독 정의일 때 **자연어 트리거 매칭 불가** → 사용자가 매번 슬래시 명시 호출 강제, "주간 리포트 만들어줘" 같은 자연어로 자동 활성 안 됨.
- skill 로 승격하여 자연어 트리거 + slash 둘 다 지원. 본문은 절차 중복 회피를 위해 `commands/report.md` SSOT 참조 형태로 thin 유지.
