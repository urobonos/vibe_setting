---
type: reference
for: task-docs/SKILL.md Part 5-3
title: SDD — Software Design Document (IEEE 1016-2009 Multi-Viewpoint)
---

## 5-3. SDD — Software Design Document (IEEE 1016-2009 Multi-Viewpoint)

### 파일 경로
```
~/.claude/docs/{product}/specs/{모듈}-sdd.md
```

### 템플릿

```markdown
# {모듈명} — Software Design Document
> version: 1.0 | lastUpdated: YYYY-MM-DD | module: {BC명} | standard: IEEE 1016-2009

## 1. Introduction
### 1.1 Purpose
| 항목 | 내용 |
|------|------|
| 모듈(BC) | {BC명} |
| 아키텍처 패턴 | {Modular Monolith — Layered} |
| 기반 SRS | `{모듈}-srs.md` v{버전} |

### 1.2 Scope
### 1.3 Definitions
### 1.4 References

## 2. Design Stakeholders & Concerns
| 이해관계자 | 관심사 | 관련 Viewpoint |
|-----------|--------|---------------|
| 개발자 | 클래스 구조, 코드 패턴 | Logical, Composition |
| DBA | 스키마, 인덱스, 성능 | Information |
| 프론트엔드 | API 계약, 응답 포맷 | Interface |
| 운영팀 | 에러 처리, 로깅, 모니터링 | Design Overlay |

## 3. Design Viewpoints

### VP-1. Context Viewpoint (시스템 경계)
- 시스템 경계 다이어그램 (외부 엔티티, 외부 시스템)
- 모듈이 의존하는 외부 시스템 목록

### VP-2. Composition Viewpoint (모듈 분해)
```text
app/Modules/{BC}/
├── Controllers/
├── Services/
├── Repositories/
├── Models/
├── Entities/
└── Config/
```

### VP-3. Logical Viewpoint (클래스/인터페이스)

#### Controller Layer
| 클래스 | 메서드 | HTTP | URL | 설명 |
|--------|--------|------|-----|------|

#### Service Layer
| 클래스 | 메서드 | 입력 | 출력 | 설명 |
|--------|--------|------|------|------|

#### Repository Layer
| 클래스 | 메서드 | 쿼리 유형 | 설명 |
|--------|--------|----------|------|

#### Entity / Value Object
| 클래스 | 타입 | 속성 | 설명 |
|--------|------|------|------|

### VP-4. Dependency Viewpoint (의존 관계)
- 모듈 간 의존 방향도 (Interface Only 원칙)
- DI 등록 (Config/Services.php)
- 순환 의존 없음 확인

### VP-5. Information Viewpoint (데이터 모델)

#### 테이블 정의
| 테이블 | 설명 | 주요 컬럼 |
|--------|------|----------|

#### ERD (텍스트)
```text
[테이블A] 1──N [테이블B]
```

#### SQL DDL
```sql
CREATE TABLE {table} (...) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### 인덱스 전략
| 테이블 | 인덱스명 | 컬럼 | 유형 | 사유 |
|--------|---------|------|------|------|

### VP-6. Interface Viewpoint (외부 인터페이스 요약)
- IDD 참조: `{모듈}-idd.md`
- 주요 외부 연동 목록

### VP-7. Interaction Viewpoint (시퀀스/상태 머신)

#### 정상 흐름 시퀀스
```text
Client → Controller → Service → Repository → DB
```

#### 에러 흐름 시퀀스
```text
Client → Controller → 검증 실패 → 400/403/409
```

#### 상태 머신 (해당 시)
```text
[상태A] → [상태B] → [상태C]
```

### VP-8. Patterns Viewpoint (설계 패턴 / ADR)
| # | 결정 | 적용 패턴 | 근거 | 대안 |
|---|------|----------|------|------|

## 4. Design Overlay (Cross-Cutting Concerns)

### 4.1 보안 설계
- 인증/인가 (JWT, role:callee, AuthFilter)
- 입력 검증 (CI4 Validation)
- XSS/SQL Injection 방지

### 4.2 에러 처리 전략
- 에러 코드 체계 (`INVALID_INPUT`, `NOT_FOUND`, `UNAUTHORIZED`, ...)
- 예외 계층 (Controller catch → BaseApiController::respond*)

### 4.3 로깅/모니터링
- 로그 레벨 기준, 로그 포맷
- 감사 로그(audit) 해당 여부

### 4.4 트랜잭션 전략
- 트랜잭션 경계 (Repository 레벨)
- 분산 트랜잭션 해당 여부 (Outbox Pattern)

## 5. Design Rationale (ADR 상세)
| # | 결정 | 근거 | 대안 | 트레이드오프 |
|---|------|------|------|------------|

## 6. Traceability Matrix (SRS → SDD)

| SRS FR | SDD 설계 요소 | Controller::method | Service::method | Repository::method | DB 테이블 |
|--------|-------------|-------------------|-----------------|-------------------|----------|
| FR-001 | {설계요소} | {Controller::m} | {Service::m} | {Repository::m} | {table} |

## 7. 타당성 검토 (Feasibility Review)
| # | 설계 결정 | 공식 근거 | 출처 | 결론 |
|---|----------|----------|------|------|

## 8. 변경 영향 기록 (Change Impact Log)
| # | 변경 사항 | 개선점 | 수행 이유 |
|---|----------|--------|----------|

## 9. 검토 체크리스트 (IEEE 1016 기반)

### 완전성
- [ ] 8개 Viewpoint 전체 작성
- [ ] Design Overlay (보안/에러/로깅/트랜잭션) 작성
- [ ] Entity/VO 전체 정의
- [ ] SQL DDL 포함
- [ ] 시퀀스 (정상+에러) 작성
- [ ] 상태 머신 (해당 시) 작성
- [ ] Traceability Matrix (SRS FR → SDD) 작성

### 일관성
- [ ] SRS 요구사항과 설계 매핑 완전 (Traceability Matrix 빈 셀 없음)
- [ ] 클래스 시그니처와 실제 구현 일치
- [ ] DB 스키마와 Entity 속성 일치

### 구현 가능성
- [ ] 클래스 간 의존 방향 명확 (VP-4)
- [ ] DB 인덱스 전략 성능 고려
- [ ] 트랜잭션 경계 정의

### 추적성
- [ ] SRS FR ↔ Controller 매핑
- [ ] Entity ↔ DB 테이블 매핑
- [ ] ADR 근거와 대안 기록

## 10. 변경 로그
| 일자 | 버전 | 변경 내용 |
|------|------|----------|
```
