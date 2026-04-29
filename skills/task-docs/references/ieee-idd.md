---
type: reference
for: task-docs/SKILL.md Part 5-4
title: IDD — Interface Design Document (MIL-STD-498 DI-IPSC-81436)
---

## 5-4. IDD — Interface Design Document (MIL-STD-498 DI-IPSC-81436)

### 파일 경로
```
~/.claude/docs/{product}/specs/{모듈}-idd.md
```

### 템플릿

```markdown
# {모듈명} — Interface Design Document
> version: 1.0 | lastUpdated: YYYY-MM-DD | module: {BC명} | standard: MIL-STD-498 DI-IPSC-81436

## 1. Scope
### 1.1 Identification
| 항목 | 내용 |
|------|------|
| 모듈(BC) | {BC명} |
| 기반 SDD | `{모듈}-sdd.md` v{버전} |
| 인터페이스 수 | 내부 {N}개 / 외부 {N}개 |

### 1.2 Purpose

## 2. Referenced Documents
- `{모듈}-srs.md`, `{모듈}-sdd.md`

## 3. Interface Design — 내부 인터페이스

### IF-INT-001: {인터페이스명}

#### 3.1.1 Interface Identifier & Diagram
| 항목 | 내용 |
|------|------|
| 제공 모듈 | {BC명} |
| 소비 모듈 | {BC명} |
| 방식 | {직접 호출 / 이벤트 / 공유 서비스} |

#### 3.1.2 Data Elements (메서드 시그니처)
```php
public function method(Type $param): ReturnType;
```

#### 3.1.3 Communication Methods
| 항목 | 내용 |
|------|------|
| 동기/비동기 | {동기} |
| 프로토콜 | {service() DI / HTTP / Queue} |

#### 3.1.4 Error Handling
| 예외 | HTTP | 에러 코드 | 소비자 대응 |
|------|------|----------|------------|

#### 3.1.5 Flow Control / Sequencing
- {호출 순서, 선행 조건}

## 4. Interface Design — 외부 인터페이스

### IF-EXT-001: {인터페이스명}

#### 4.1.1 Interface Identifier & Diagram
| 항목 | 내용 |
|------|------|
| 대상 시스템 | {외부 서비스명} |
| 프로토콜 | {REST/gRPC/WebSocket/DB직접접속} |
| 인증 방식 | {API Key/OAuth/JWT/DB Credentials} |
| Base URL | `{URL}` |
| 타임아웃 | {초} |
| 재시도 정책 | {횟수, 간격, Backoff} |

#### 4.1.2 Data Elements (요청/응답)
| HTTP | URL | 요청 | 응답 | 설명 |
|------|-----|------|------|------|

#### 4.1.3 요청/응답 JSON 예시
```json
// 요청
{ ... }
// 응답
{ ... }
```

#### 4.1.4 Error Handling
| HTTP Status | 에러 코드 | 설명 | 소비자 대응 |
|------------|----------|------|------------|

#### 4.1.5 Communication Methods
| 항목 | 내용 |
|------|------|
| 동기/비동기 | {동기} |
| 연결 관리 | {Connection Pool / 요청별 생성} |
| 장애 대응 | {Circuit Breaker / Graceful Degradation / Retry} |

## 5. Event Contracts

| 이벤트명 | 발행 모듈 | 구독 모듈 | 트리거 | 페이로드 | 설명 |
|---------|----------|----------|--------|---------|------|

## 6. Data Formats

### DTO / Value Object
| DTO | 필드 | 타입 | 필수 | 설명 |
|-----|------|------|------|------|

### 공통 응답 포맷
```json
// 성공
{ "data": {...} }
// 에러
{ "error": { "code": "...", "message": "..." } }
// 페이지네이션
{ "data": [], "meta": { "currentPage", "perPage", "total", "lastPage" } }
```

## 7. Requirements Traceability

| SRS FR | IDD 인터페이스 | SDD 설계 요소 | 비고 |
|--------|-------------|-------------|------|
| FR-001 | IF-INT-001 | Controller::method | |

## 8. 타당성 검토 (Feasibility Review)
| # | 설계 결정 | 공식 근거 | 출처 | 결론 |
|---|----------|----------|------|------|

## 9. 변경 영향 기록 (Change Impact Log)
| # | 변경 사항 | 개선점 | 수행 이유 |
|---|----------|--------|----------|

## 10. 검토 체크리스트 (MIL-STD-498 기반)

### 완전성
- [ ] 내부 IF 전체 정의 (각 IF에 5개 하위 섹션: Identifier/Data/Communication/Error/Flow)
- [ ] 외부 IF 전체 정의 (각 IF에 5개 하위 섹션 + JSON 예시)
- [ ] 이벤트 계약 전체 정의
- [ ] DTO/VO 전체 정의
- [ ] Requirements Traceability 작성

### 일관성
- [ ] SDD 클래스 ↔ 인터페이스 매핑 일치
- [ ] 요청/응답 포맷 일관성 (camelCase)
- [ ] 에러 코드 체계 통일
- [ ] 인증 방식 일관성

### 계약 명확성
- [ ] 각 IF에 PHP 메서드 시그니처 (타입 포함)
- [ ] 외부 IF에 타임아웃/재시도/장애대응 정의
- [ ] 요청/응답 JSON 예시 포함
- [ ] 하위 호환성 보장 방안

### 추적성
- [ ] SRS FR ↔ IDD IF 매핑
- [ ] SDD Class ↔ IDD IF 매핑
- [ ] 외부 IF ↔ 에러 처리 매핑

## 11. 변경 로그
| 일자 | 버전 | 변경 내용 |
|------|------|----------|
```

---

## 트리거 조건

| 트리거 | 생성 문서 |
|--------|----------|
| 프로젝트 착수 / 마일스톤 시작 | SDP |
| 모듈(BC) 신규 개발 착수 | SRS → SDD → IDD (순차) |
| 요구사항 변경 | SRS 갱신 → Verification Matrix 동기화 |
| 설계 변경 | SDD 갱신 → Traceability Matrix + IDD 동기화 확인 |
| 외부 연동 추가 | IDD 갱신 (IF-EXT 추가) |
| 사용자 명시 요청 (`/task-docs specs`) | 지정 문서 생성 |
