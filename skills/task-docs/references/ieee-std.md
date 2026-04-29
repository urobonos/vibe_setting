---
type: reference
for: task-docs/SKILL.md Part 5-6
title: STD — Software Test Documentation (IEEE 829-2008)
---

## 5-6. STD — Software Test Documentation (IEEE 829-2008)

### 파일 경로
```
~/.claude/docs/{product}/specs/{모듈}-std.md
```

### 필수 섹션

```markdown
---
문서명: {Module} — Software Test Documentation
문서 ID: {module}-std
버전: v{버전}
상태: {초안|승인됨}
생성일: {YYYY-MM-DD}
최종 수정일: {YYYY-MM-DD}
작성자: jypark
대상 시스템: {Module} Module
관련 문서: {module}-srs.md, {module}-sdd.md, {module}-idd.md, project-stp.md
적용 표준: IEEE 829-2008
---

# {Module} — Software Test Documentation (STD)

> IEEE 829-2008 | version: {버전} | lastUpdated: {YYYY-MM-DD} | module: {Module}

## 1. Introduction
### 1.1 Purpose
### 1.2 Scope
### 1.3 References
- SRS/SDD/IDD 상호참조 필수

## 2. Test Items
- 테스트 대상 클래스/메서드 목록 (Unit/Feature 구분)

## 3. Test Cases
| TC ID | 테스트 메서드 | 설명 | 입력 | 기대결과 | 우선순위 |
|-------|-------------|------|------|---------|---------|
- 실제 테스트 파일의 메서드명을 가공 없이 기재

## 4. Test Execution Results
| 항목 | 값 |
|------|-----|
| 총 TC | {N} |
| PASS | {N} |
| FAIL | {N} |
| SKIP | {N} |
| 최종 실행일 | {YYYY-MM-DD} |

## 5. Traceability Matrix
| SRS 요구사항 ID | 요구사항 요약 | TC ID | 커버리지 |
|----------------|-------------|-------|---------|
- SRS FR/NFR ↔ TC 매핑 필수

## 6. Defects & Issues
| DEF ID | 설명 | 심각도 | 상태 |
|--------|------|--------|------|

## 7. 변경 로그
```

### STD 작성 규칙

1. **테스트 파일 기반:** 실제 `tests/Modules/{Module}/` 하위 파일의 메서드명을 TC로 등록한다. 가상 TC를 만들지 않는다.
2. **SRS 매핑 필수:** Traceability Matrix에서 SRS의 모든 FR/NFR이 최소 1개 TC에 매핑되거나, 미커버 사유를 명시한다.
3. **결과 실측:** PASS/FAIL/SKIP 수치는 PHPUnit 실행 결과 기반이다. 추정값을 쓰지 않는다.
