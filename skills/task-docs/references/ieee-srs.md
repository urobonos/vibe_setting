---
type: reference
for: task-docs/SKILL.md Part 5-2
title: SRS — Software Requirements Specification (IEEE 29148:2018)
---

## 5-2. SRS — Software Requirements Specification (IEEE 29148:2018)

### 파일 경로
```
~/.claude/docs/{product}/specs/{모듈}-srs.md
```

### 템플릿

```markdown
# {모듈명} — Software Requirements Specification
> version: 1.0 | lastUpdated: YYYY-MM-DD | module: {BC명} | standard: IEEE/ISO/IEC 29148:2018

## 1. Introduction
### 1.1 Purpose
| 항목 | 내용 |
|------|------|
| 모듈(BC) | {BC명} |
| 목적 | {비즈니스 문제} |
| 이해관계자 | {역할/시스템} |

### 1.2 Scope
### 1.3 Definitions, Acronyms, Abbreviations
| 용어 | 정의 |
|------|------|

### 1.4 References
- `{모듈}-sdd.md`, `{모듈}-idd.md`
- OWASP Top 10, RFC 등

### 1.5 Overview

## 2. Overall Description
### 2.1 Product Perspective (시스템 내 위치, 다른 모듈과의 관계)
### 2.2 Product Functions (주요 기능 요약)
### 2.3 User Characteristics (사용자 유형: Caller, Callee, Admin)
### 2.4 Constraints (기술적/비즈니스 제약)
### 2.5 Assumptions and Dependencies

## 3. Specific Requirements — Functional

### FR-001: {요구사항 제목}
| 항목 | 내용 |
|------|------|
| 설명 | {상세 설명} |
| 선행 조건 | {precondition} |
| 후행 조건 | {postcondition} |
| 입력 검증 | {CI4 Validation Rules: required, max_length 등} |
| 우선순위 | {필수/권장/선택} |
| 관련 API | `{HTTP Method} {URL}` |
| 검증 방법 | {Test/Inspection/Analysis/Demonstration} |

## 4. Specific Requirements — Non-Functional

| ID | 구분 | 요구사항 | 기준 (정량) | 검증 방법 |
|----|------|---------|------------|----------|
| NFR-001 | 성능 | {요구사항} | {예: 200ms 이내} | {Load Test} |
| NFR-002 | 보안 | {요구사항} | {기준} | {Security Audit} |

## 5. External Interface Requirements
### 5.1 User Interfaces (해당 시)
### 5.2 Hardware Interfaces (해당 시)
### 5.3 Software Interfaces (의존 모듈, 외부 시스템)
### 5.4 Communication Interfaces (프로토콜, 포트)

## 6. Use Cases

### UC-001: {유스케이스명}
- **액터:** {사용자/시스템}
- **정상 흐름:**
  1. {단계}
- **대안 흐름:** {예외/분기}
- **에러 흐름:** {실패 시나리오}

## 7. Verification Matrix

| FR/NFR ID | 요구사항 요약 | UC 매핑 | 검증 방법 | 테스트 케이스 | 설계 요소 (SDD) |
|-----------|-------------|---------|----------|-------------|---------------|
| FR-001 | {요약} | UC-001 | Test | {테스트명} | {Controller::method} |
| NFR-001 | {요약} | — | Load Test | {테스트명} | {인프라 설정} |

> **Traceability Matrix**: FR ↔ UC ↔ Test Case ↔ SDD Design Element 4방향 추적 필수.

## 8. Data Dictionary (부록)

| 데이터 항목 | 타입 | 범위/제약 | 설명 |
|-----------|------|----------|------|
| {필드명} | {string/int/...} | {max 500, enum 등} | {설명} |

## 9. 타당성 검토 (Feasibility Review)
| # | 요구사항/결정 | 공식 근거 | 출처 | 결론 |
|---|-------------|----------|------|------|

## 10. 변경 영향 기록 (Change Impact Log)
| # | 변경 사항 | 개선점 | 수행 이유 |
|---|----------|--------|----------|

## 11. 검토 체크리스트 (IEEE 29148 기반)

### 완전성
- [ ] FR 전체 정의 (각 FR에 선행/후행 조건, 입력 검증, 검증 방법 포함)
- [ ] NFR 전체 정의 (정량 기준 + 검증 방법)
- [ ] External Interface Requirements 작성
- [ ] UC 정상/대안/에러 흐름 작성
- [ ] Verification Matrix 작성 (FR ↔ UC ↔ Test ↔ SDD 4방향)
- [ ] Data Dictionary 작성
- [ ] 제약사항/가정사항 명시
- [ ] 용어 정의 완료

### 일관성
- [ ] FR 간 상충 없음
- [ ] NFR 측정 기준 정량화
- [ ] UC와 FR 매핑 완전
- [ ] Verification Matrix 빈 셀 없음

### 검증 가능성
- [ ] 각 FR에 검증 방법(Test/Inspection/Analysis/Demonstration) 지정
- [ ] 각 NFR에 측정 방법 정의
- [ ] 수락 조건 명확

### 추적성
- [ ] FR ↔ UC 매핑
- [ ] FR ↔ API 엔드포인트 매핑
- [ ] FR ↔ SDD 설계 요소 매핑 (Verification Matrix)
- [ ] NFR ↔ 아키텍처 결정 연결

## 12. 변경 로그
| 일자 | 버전 | 변경 내용 |
|------|------|----------|
```
