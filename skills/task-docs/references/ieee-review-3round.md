# 3-Round IEEE 적합성 재검토

소프트웨어 개발 산출물(SDP/SRS/SDD/IDD/STP/STD) 생성 또는 갱신 후, **반드시 3회 재검토를 수행한다**. 재검토를 거치지 않은 산출물은 "초안" 상태로 간주하며, "승인됨" 상태로 전환할 수 없다.

> **Why:** SRS↔SDD↔IDD 3종 문서는 상호 참조가 정합해야 추적성 매트릭스가 성립하며, 단일 패스 작성에 의존하면 누락 섹션·placeholder·교차 불일치가 그대로 "승인됨" 상태로 굳어진다.

## Round 1: 구조 검증 (Structure Compliance)

IEEE 필수 섹션 존재 여부를 체크리스트로 검증한다.

### SRS (IEEE 29148) 구조 체크
- [ ] §1 Introduction (Purpose, Scope, Definitions, References, Overview)
- [ ] §2 Overall Description (Perspective, Functions, Users, Constraints, Assumptions)
- [ ] §3 Functional Requirements (각 FR에 선행/후행/검증방법 포함)
- [ ] §4 Non-Functional Requirements (정량 기준 + 검증 방법)
- [ ] §5 External Interface Requirements
- [ ] §6 Use Cases (정상/대안/에러 흐름)
- [ ] §7 Verification Matrix (FR ↔ UC ↔ Test ↔ SDD 4방향)
- [ ] §8 Data Dictionary
- [ ] §9 타당성 검토
- [ ] §10 변경 영향 기록

### SDD (IEEE 1016) 구조 체크
- [ ] §1 Introduction (Purpose, Scope, Definitions, References)
- [ ] §2 Design Stakeholders & Concerns
- [ ] §3 VP-1~VP-8 (Context/Composition/Logical/Dependency/Information/Interface/Interaction/Patterns)
- [ ] §4 Design Overlay (보안/에러/로깅/트랜잭션)
- [ ] §5 Design Rationale (ADR)
- [ ] §6 Traceability Matrix (SRS FR → SDD)
- [ ] §7 타당성 검토
- [ ] §8 변경 영향 기록

### IDD (MIL-STD-498) 구조 체크
- [ ] §1 Scope (Identification, Purpose)
- [ ] §2 Referenced Documents
- [ ] §3 내부 IF (각 IF에 5-subsection: Identifier/Data/Communication/Error/Flow)
- [ ] §4 외부 IF (각 IF에 5-subsection + JSON 예시)
- [ ] §5 Event Contracts
- [ ] §6 Data Formats (DTO + 공통 응답 포맷)
- [ ] §7 Requirements Traceability
- [ ] §8 타당성 검토
- [ ] §9 변경 영향 기록

**Round 1 통과 기준:** 모든 필수 섹션이 존재하고, 빈 섹션(placeholder만)이 없을 것.

## Round 2: 내용 검증 (Content Quality)

각 섹션의 내용 깊이와 정확성을 검증한다.

### Verification / Traceability 검증
- [ ] SRS Verification Matrix에 빈 셀 없음 (모든 FR에 UC/Test/SDD 매핑)
- [ ] SDD Traceability Matrix에 빈 셀 없음 (모든 FR에 Controller/Service/Repository/Table 매핑)
- [ ] IDD Requirements Traceability에 빈 셀 없음

### 내용 깊이 검증
- [ ] FR에 입력 검증 규칙(CI4 Validation) 명시
- [ ] NFR에 정량 기준 (ms, TPS, 횟수 등) 명시
- [ ] SDD에 실제 PHP 클래스/메서드명 사용 (추상적 placeholder 아님)
- [ ] SDD에 SQL DDL (CREATE TABLE) 포함
- [ ] SDD에 정상 + 에러 시퀀스 모두 포함
- [ ] IDD에 PHP 메서드 시그니처 (파라미터 타입, 반환 타입) 포함
- [ ] IDD에 요청/응답 JSON 예시 포함
- [ ] 타당성 검토에 공식 문서(OWASP/RFC/IEEE/CI4 docs) 근거 명시
- [ ] 변경 영향 기록에 변경 사항 + 개선점 + 수행 이유 3열 완비

### Design Overlay 검증 (SDD)
- [ ] 보안 설계 (인증/인가/입력검증/XSS/SQLi) 기술
- [ ] 에러 처리 전략 (에러 코드 체계, 예외 계층) 기술
- [ ] 트랜잭션 전략 (경계, 롤백 정책) 기술

**Round 2 통과 기준:** 모든 체크 항목 통과. 1건이라도 미통과 시 해당 섹션 보강 후 Round 2 재수행.

## Round 3: 상호 참조 일관성 (Cross-Reference Consistency)

SRS ↔ SDD ↔ IDD 3개 문서 간 상호 참조가 정합한지 검증한다.

### SRS → SDD 정합성
- [ ] SRS의 모든 FR이 SDD Traceability Matrix에 매핑됨
- [ ] SRS의 API 엔드포인트와 SDD Controller 메서드 1:1 매핑
- [ ] SRS 제약사항이 SDD Design Overlay에 반영됨
- [ ] SRS NFR이 SDD 인덱스 전략/캐시 설계에 반영됨

### SDD → IDD 정합성
- [ ] SDD VP-3의 Service Interface가 IDD 내부 IF에 전체 매핑
- [ ] SDD VP-6의 외부 연동이 IDD 외부 IF에 전체 매핑
- [ ] SDD Entity/VO가 IDD DTO와 필드 일치
- [ ] SDD Design Overlay의 에러 코드가 IDD 에러 처리 계약과 일치

### SRS → IDD 정합성
- [ ] SRS External Interface Requirements가 IDD 외부 IF에 전체 매핑
- [ ] IDD Requirements Traceability의 SRS FR 참조가 정확

### 버전/참조 정합성
- [ ] SDD의 "기반 SRS" 버전이 실제 SRS 버전과 일치
- [ ] IDD의 "기반 SDD" 버전이 실제 SDD 버전과 일치
- [ ] 상호 참조 문서의 "관련 문서" 필드가 양방향으로 기재

**Round 3 통과 기준:** 모든 체크 항목 통과. 불일치 발견 시 원인 문서 수정 후 Round 3 재수행.

## 재검토 결과 기록

3회 재검토 완료 후, 문서의 프론트매터 `상태`를 `초안` → `승인됨`으로 변경하고, 변경 로그에 다음을 기록한다:

```markdown
| 일자 | 버전 | 변경 내용 |
|------|------|----------|
| YYYY-MM-DD | x.x.x | 3-Round IEEE Review 통과. Round 1(구조)/Round 2(내용)/Round 3(상호참조) 전체 PASS |
```

**재검토 미수행 또는 미통과 상태에서 "승인됨"으로 상태 전환하는 것은 지침 위반이다.**

> **Why:** "승인됨" 상태는 다운스트림(개발·테스트·배포 절차)이 해당 산출물을 신뢰 가능한 계약으로 사용한다는 신호이므로, 검증되지 않은 문서가 승인 상태로 노출되면 잘못된 계약을 기준 삼아 코드·테스트가 작성되는 연쇄 오류가 발생한다.
