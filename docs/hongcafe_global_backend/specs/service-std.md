---
문서명: Service — Software Test Documentation
문서 ID: service-std
버전: v1.1
상태: 승인됨
생성일: 2026-04-16
최종 수정일: 2026-04-21
작성자: jypark
대상 시스템: Service Module
관련 문서: service-srs.md, service-sdd.md, service-idd.md, project-stp.md
적용 표준: IEEE 829-2008
---

# Service — Software Test Documentation (STD)

> IEEE 829-2008 | version: 1.1 | lastUpdated: 2026-04-21 | module: Service

---

## 1. Introduction

### 1.1 Purpose

본 문서는 HongCafe Global Backend Service 모듈의 테스트 케이스, 실행 결과, 요구사항 추적성을 IEEE 829-2008 표준에 따라 기록한다.

### 1.2 Scope

Service 모듈의 서비스 목록/상세 조회, 차단(Reject) CRUD, Hermes 온콜 연동, a8.net 제휴 추적 기능을 대상으로 한다. 10개 테스트 파일에 포함된 총 62개 테스트 메서드를 검증 범위로 한다.

### 1.3 References

| 문서 | 경로 |
|------|------|
| SRS | `docs/specs/service-srs.md` v2.1 |
| SDD | `docs/specs/service-sdd.md` |
| IDD | `docs/specs/service-idd.md` |
| STP | `project-stp.md` |

---

## 2. Test Items

### 2.1 테스트 대상 클래스/메서드 목록

| 테스트 파일 | 테스트 유형 | 대상 클래스 | 테스트 수 |
|-----------|-----------|-----------|---------|
| `HermesApiTest` | Feature (통합) | `HermesController` (API 엔드포인트) | 3 |
| `RejectApiTest` | Feature (통합) | `RejectController` (API 엔드포인트) | 3 |
| `ServiceApiTest` | Feature (통합) | `ServiceController` (API 엔드포인트) | 3 |
| `A8TrackingServiceTest` | Unit | `A8TrackingService` | 9 |
| `HermesControllerTest` | Unit | `HermesController` | 3 |
| `HermesServiceTest` | Unit | `HermesService` | 8 |
| `RejectControllerTest` | Unit | `RejectController` | 4 |
| `RejectModelTest` | Unit | `RejectModel`, `RejectRepository` | 20 |
| `ServiceControllerTest` | Unit | `ServiceController` | 3 |
| `ServiceModelTest` | Unit | `ServiceModel`, `ServiceRepository` | 18 |

---

## 3. Test Cases

### 3.1 HermesApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SVC-001 | `testGetOnCallCalleeHecodeWithoutTypeReturns200` | type 없이 getOnCallCalleeHecode 호출 시 200 응답 | POST api/hermes/get-on-call-callee-hecode | HTTP 200 | P1 |
| TC-SVC-002 | `testGetOnCallCalleeHecodeWithTypeParameterReturns200` | type 쿼리 파라미터와 함께 호출 시 200 응답 | POST api/hermes/get-on-call-callee-hecode?type=coin | HTTP 200 | P1 |
| TC-SVC-003 | `testGetOnCallCalleeHecodeResponseIsArrayOrEmpty` | 응답이 JSON 배열 또는 빈 값 | POST api/hermes/get-on-call-callee-hecode | HTTP 200 + JSON 배열 또는 빈 배열 | P1 |

### 3.2 RejectApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SVC-004 | `testSaveRejectWithoutCeCodeReturnsError` | 필수 파라미터 없이 save-reject 요청 시 에러 | POST api/rejects/save-reject `{}` | HTTP 400 또는 에러 응답 | P2 |
| TC-SVC-005 | `testDeleteRejectWithoutCeCodeReturnsError` | 필수 파라미터 없이 delete-reject 요청 시 에러 | DELETE api/rejects/delete-reject `{}` | HTTP 400 또는 에러 응답 | P2 |
| TC-SVC-006 | `testGetCalleeRejectListWithoutLoginReturnsNeedLogin` | 비로그인 상태 get-callee-reject-list 요청 시 인증 필요 응답 | POST api/rejects/get-callee-reject-list `{}` | HTTP 401 또는 로그인 필요 응답 | P2 |

### 3.3 ServiceApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SVC-007 | `testGetServiceListMobileWithEmptyBodyReturns200` | 빈 body로 get-service-list-mobile 요청 시 200 | POST api/services/get-service-list-mobile `{}` | HTTP 200 | P1 |
| TC-SVC-008 | `testGetServiceListMobileWithOrderReturns200` | order/limit 포함 요청 시 200 | POST api/services/get-service-list-mobile `{ "order": "itemNew", "limit": 10 }` | HTTP 200 | P1 |
| TC-SVC-009 | `testGetServiceListMobileNewWithEmptyBodyReturns200` | 빈 body로 get-service-list-mobile-new 요청 시 200 | POST api/services/get-service-list-mobile-new `{}` | HTTP 200 | P1 |

### 3.4 A8TrackingServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SVC-010 | `testA8TrackingServiceCanBeInstantiated` | A8TrackingService 인스턴스화 확인 | (없음) | `assertInstanceOf` | P3 |
| TC-SVC-011 | `testTrackFirstPaymentConversionMethodExists` | trackFirstPaymentConversion 메서드 존재 | Reflection | `method_exists` = true | P3 |
| TC-SVC-012 | `testTrackFirstPaymentConversionAcceptsCorrectParams` | trackFirstPaymentConversion 시그니처 (acId, crCode, order) | Reflection | 파라미터 3개, 이름 일치 | P3 |
| TC-SVC-013 | `testTrackFirstPaymentConversionReturnsBool` | 반환 타입 bool 검증 | Reflection | `getReturnType()->getName()` = 'bool' | P3 |
| TC-SVC-014 | `testTrackFirstPaymentConversionThirdParamIsArray` | 세 번째 파라미터 타입 array | Reflection | `getType()->getName()` = 'array' | P3 |
| TC-SVC-015 | `testTrackFirstPaymentConversionIsPublic` | 메서드 가시성 public | Reflection | `isPublic` = true | P3 |
| TC-SVC-016 | `testServiceClassExistsInExpectedNamespace` | 네임스페이스 확인 | Reflection | `class_exists` = true | P3 |
| TC-SVC-017 | `testServiceClassIsNotAbstract` | 비추상 클래스 확인 | Reflection | `isAbstract` = false | P3 |
| TC-SVC-018 | `testServiceClassHasNoRequiredConstructorParams` | 생성자 필수 파라미터 0개 | Reflection | requiredCount = 0 | P3 |

### 3.5 HermesControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SVC-019 | `testControllerExtendsBaseApiController` | HermesController 상속 검증 | Reflection | `isSubclassOf` = true | P2 |
| TC-SVC-020 | `testGetOnCallCalleeMethodExists` | getOnCallCallee 메서드 존재 | Reflection | `method_exists` = true | P1 |
| TC-SVC-021 | `testGetOnCallCalleeHecodeMethodExists` | getOnCallCalleeHecode 메서드 존재 | Reflection | `method_exists` = true | P1 |

### 3.6 HermesServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SVC-022 | `testGetOnCallCalleeReturnsMappedByHeCode` | he_code 기반 매핑 반환 검증 | rawOnCall 2건 | result['HE001'].call_type='coin', result['HE002'].call_type='class' | P1 |
| TC-SVC-023 | `testGetOnCallCalleeReturnsEmptyArrayWhenModelReturnsFalse` | Model false 반환 시 빈 배열 | getOnCallCallee=false | `assertSame([])` | P1 |
| TC-SVC-024 | `testGetOnCallCalleeReturnsEmptyArrayWhenModelReturnsEmptyArray` | Model 빈 배열 반환 시 빈 배열 | getOnCallCallee=[] | `assertSame([])` | P1 |
| TC-SVC-025 | `testGetOnCallCalleeUsesHeCodeAsMapKey` | he_code를 맵 키로 사용 | rawOnCall [HE100] | `array_key_first` = 'HE100' | P1 |
| TC-SVC-026 | `testGetOnCallCalleeHecodeReturnsHeCodeArray` | he_code 배열 반환 검증 | rawOnCall 2건, type='coin' (query string 기준) | ['HE001', 'HE002'] | P1 |
| TC-SVC-027 | `testGetOnCallCalleeHecodeReturnsEmptyArrayWhenModelReturnsFalse` | Model false 시 빈 배열 | getOnCallCallee=false | `assertSame([])` | P1 |
| TC-SVC-028 | `testGetOnCallCalleeHecodePassesTypeArgToModel` | type 인자 전달 검증 — query string 기준 | type=['coin', 'class'] (query string으로 수신) | `expects(once)->with(['coin', 'class'])` | P1 |

### 3.7 RejectControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SVC-029 | `testControllerExtendsBaseApiController` | RejectController 상속 검증 | Reflection | `isSubclassOf` = true | P2 |
| TC-SVC-030 | `testSaveRejectMethodExists` | saveReject 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-SVC-031 | `testDeleteRejectMethodExists` | deleteReject 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-SVC-032 | `testGetCalleeRejectListMethodExists` | getCalleeRejectList 메서드 존재 | Reflection | `method_exists` = true | P2 |

### 3.8 RejectModelTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SVC-033 | `testModelCanBeInstantiated` | RejectModel 인스턴스화 | (없음) | `assertInstanceOf` | P2 |
| TC-SVC-034 | `testModelHasCorrectTableConfig` | 테이블명 tb_reject 확인 | Reflection | table = 'tb_reject' | P2 |
| TC-SVC-035 | `testModelHasPrimaryKey` | PK rj_no 확인 | Reflection | primaryKey = 'rj_no' | P2 |
| TC-SVC-036 | `testModelHasAllowedFields` | allowedFields 비어있지 않음 | Reflection | `assertNotEmpty` | P2 |
| TC-SVC-037 | `testInsertRejectMethodExists` | RejectRepository.insertReject 존재 | Reflection | `method_exists` = true | P2 |
| TC-SVC-038 | `testDeleteRejectMethodExists` | RejectRepository.deleteReject 존재 | Reflection | `method_exists` = true | P2 |
| TC-SVC-039 | `testCheckRejectMethodExists` | RejectRepository.checkReject 존재 | Reflection | `method_exists` = true | P2 |
| TC-SVC-040 | `testGetRejectItemMethodExists` | RejectRepository.getRejectItem 존재 | Reflection | `method_exists` = true | P2 |
| TC-SVC-041 | `testGetCalleeRejectListMethodExists` | RejectRepository.getCalleeRejectList 존재 | Reflection | `method_exists` = true | P2 |
| TC-SVC-042 | `testGetCalleeRejectMethodExists` | RejectRepository.getCalleeReject 존재 | Reflection | `method_exists` = true | P2 |
| TC-SVC-043 | `testAllowedFieldsContainsAllExpectedColumns` | ce_code, cr_code, regist_date 포함 확인 | Reflection | 3개 컬럼 존재 | P2 |
| TC-SVC-044 | `testAllowedFieldsCountMatchesExpected` | allowedFields 수 3개 | Reflection | `assertCount(3)` | P2 |
| TC-SVC-045 | `testUseTimestampsIsFalse` | useTimestamps=false 확인 | Reflection | `assertFalse` | P2 |
| TC-SVC-046 | `testModelExtendsBaseModel` | BaseModel 상속 검증 | Reflection | `assertInstanceOf(BaseModel)` | P2 |
| TC-SVC-047 | `testRepositoryImplementsInterface` | RejectRepositoryInterface 구현 검증 | Reflection | `is_a` = true | P2 |
| TC-SVC-048 | `testInsertRejectReflectionSignature` | insertReject 시그니처 (data: array): bool | Reflection | 파라미터 1개, 반환 bool | P2 |
| TC-SVC-049 | `testDeleteRejectReflectionSignature` | deleteReject 시그니처 (rjNo): void | Reflection | 파라미터 1개, 반환 void | P2 |
| TC-SVC-050 | `testCheckRejectReflectionSignature` | checkReject 시그니처 (ceCode, crCode): bool | Reflection | 파라미터 2개, 반환 bool | P2 |
| TC-SVC-051 | `testGetCalleeRejectListReflectionSignature` | getCalleeRejectList 시그니처 (params=[]): array | Reflection | 파라미터 1개(선택적), 반환 array | P2 |
| TC-SVC-052 | `testGetErrorMessageReflectionSignature` | getErrorMessage 시그니처 (): ?string | Reflection | 파라미터 0개, nullable string | P2 |
| TC-SVC-053 | `testGetTableReflectionSignature` | getTable 시그니처 (5 파라미터) | Reflection | 파라미터 5개, select 기본값='*' | P2 |

### 3.9 ServiceControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SVC-054 | `testControllerExtendsBaseApiController` | ServiceController 상속 검증 | Reflection | `isSubclassOf` = true | P2 |
| TC-SVC-055 | `testGetServiceListMobileMethodExists` | getServiceListMobile 메서드 존재 | Reflection | `method_exists` = true | P1 |
| TC-SVC-056 | `testGetServiceListMobileNewMethodExists` | getServiceListMobileNew 메서드 존재 | Reflection | `method_exists` = true | P1 |

### 3.10 ServiceModelTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SVC-057 | `testModelCanBeInstantiated` | ServiceModel 인스턴스화 | (없음) | `assertInstanceOf` | P2 |
| TC-SVC-058 | `testModelHasCorrectTableConfig` | 테이블명 tb_goods_category 확인 | Reflection | table = 'tb_goods_category' | P2 |
| TC-SVC-059 | `testModelHasPrimaryKey` | PK goods_category_code 확인 | Reflection | primaryKey = 'goods_category_code' | P2 |
| TC-SVC-060 | `testModelHasAllowedFields` | allowedFields에 핵심 필드 포함 | Reflection | goods_category_code, goods_category_name, goods_genre 포함 | P2 |
| TC-SVC-061 | `testGetServiceCategoryMethodExists` | ServiceRepository.getServiceCategory 존재 | Reflection | `method_exists` = true | P2 |
| TC-SVC-062 | `testGetServiceCategoryFirstMethodExists` | getServiceCategoryFirst 존재 | Reflection | `method_exists` = true | P2 |
| TC-SVC-063 | `testGetServiceCategoryAllMethodExists` | getServiceCategoryAll 존재 | Reflection | `method_exists` = true | P2 |
| TC-SVC-064 | `testGetMobileServiceMethodExists` | getMobileService 존재 | Reflection | `method_exists` = true | P1 |
| TC-SVC-065 | `testGetMobileServiceNewMethodExists` | getMobileServiceNew 존재 | Reflection | `method_exists` = true | P1 |
| TC-SVC-066 | `testGetMobileServiceCategoryMethodExists` | getMobileServiceCategory 존재 | Reflection | `method_exists` = true | P2 |
| TC-SVC-067 | `testGetMobileServiceGenreMethodExists` | getMobileServiceGenre 존재 | Reflection | `method_exists` = true | P2 |
| TC-SVC-068 | `testGetBannerPositionsMethodExists` | getBannerPositions 존재 | Reflection | `method_exists` = true | P2 |
| TC-SVC-069 | `testAllowedFieldsContainsAllExpectedColumns` | 5개 필수 컬럼 포함 | Reflection | 5개 컬럼 존재 | P2 |
| TC-SVC-070 | `testAllowedFieldsCountMatchesExpected` | allowedFields 수 5개 | Reflection | `assertCount(5)` | P2 |
| TC-SVC-071 | `testUseTimestampsIsFalse` | useTimestamps=false 확인 | Reflection | `assertFalse` | P2 |
| TC-SVC-072 | `testModelExtendsBaseModel` | BaseModel 상속 검증 | Reflection | `assertInstanceOf(BaseModel)` | P2 |
| TC-SVC-073 | `testGetServiceCategoryReflectionSignature` | getServiceCategory 시그니처 (): array | Reflection | 파라미터 0개, 반환 array | P2 |
| TC-SVC-074 | `testGetMobileServiceReflectionSignature` | getMobileService 시그니처 (post: array): array | Reflection | 파라미터 1개, 반환 array | P2 |
| TC-SVC-075 | `testGetMobileServiceGenreReflectionSignature` | getMobileServiceGenre 시그니처 (cate): string | Reflection | 파라미터 1개, 반환 string | P2 |
| TC-SVC-076 | `testGetBannerPositionsReflectionSignature` | getBannerPositions 시그니처 (bngType): array | Reflection | 파라미터 1개, 반환 array | P2 |
| TC-SVC-077 | `testRepositoryImplementsInterface` | ServiceRepositoryInterface 구현 검증 | Reflection | `is_a` = true | P2 |
| TC-SVC-078 | `testGetMobileServiceCategoryReflectionSignature` | getMobileServiceCategory 시그니처 (categoryFirst: string): array | Reflection | 파라미터 1개, 반환 array | P2 |

---

## 4. Test Execution Results

| 범주 | PASS | SKIP | FAIL | 합계 |
|------|------|------|------|------|
| Feature (HermesApiTest) | 0 | 3 | 0 | 3 |
| Feature (RejectApiTest) | 0 | 3 | 0 | 3 |
| Feature (ServiceApiTest) | 0 | 3 | 0 | 3 |
| Unit (A8TrackingServiceTest) | 9 | 0 | 0 | 9 |
| Unit (HermesControllerTest) | 3 | 0 | 0 | 3 |
| Unit (HermesServiceTest) | 8 | 0 | 0 | 8 |
| Unit (RejectControllerTest) | 4 | 0 | 0 | 4 |
| Unit (RejectModelTest) | 20 | 0 | 0 | 20 |
| Unit (ServiceControllerTest) | 3 | 0 | 0 | 3 |
| Unit (ServiceModelTest) | 18 | 0 | 0 | 18 |
| **합계** | **65** | **9** | **0** | **74** |

최종 실행일: 2026-04-15

---

## 5. Traceability Matrix

| SRS 요구사항 ID | 요구사항명 | 테스트 케이스 ID |
|----------------|----------|----------------|
| FR-SVC-001 | 서비스 목록 조회 | TC-SVC-007, TC-SVC-008, TC-SVC-009, TC-SVC-054~056, TC-SVC-057~078 |
| FR-SVC-002 | 서비스 상세 조회 (**미구현 — OQ-3**) | 테스트 케이스 없음 (미구현 EP — 제품 결정 대기) |
| FR-SVC-003 | 차단 등록 | TC-SVC-004, TC-SVC-030, TC-SVC-037, TC-SVC-048, TC-SVC-050 |
| FR-SVC-004 | 차단 해제 | TC-SVC-005, TC-SVC-031, TC-SVC-038, TC-SVC-049 |
| FR-SVC-005 | 차단 목록 조회 | TC-SVC-006, TC-SVC-032, TC-SVC-041, TC-SVC-051 |
| FR-SVC-006 | Hermes 온콜 상담사 조회 (연결 EP 미구현 — OQ-1) | TC-SVC-001, TC-SVC-002, TC-SVC-003, TC-SVC-019~028 |
| FR-SVC-007 | a8.net 제휴 추적 | TC-SVC-010~018 |
| NFR-SVC-001 | Hermes DB 연결 격리 | TC-SVC-001~003 (통합 테스트, DB 연결 의존) |
| NFR-SVC-002 | a8.net 추적 격리 | TC-SVC-018 (생성자 required 파라미터 0개 확인) |
| NFR-SVC-004 | 보안 | TC-SVC-006 (비로그인 접근 검증) |

---

## 6. Defects & Issues

| ID | 설명 | 심각도 | 상태 | 비고 |
|----|------|--------|------|------|
| DEF-SVC-001 | Feature 테스트 9건이 MySQL DB 연결 없이 실행 불가 | 낮음 | 허용 | MySQL 통합 테스트 환경 미구성으로 SKIP. 스테이징 환경에서 실행 필요. (이전 "SQLite" 설명은 이 프로젝트 Aurora MySQL 환경에 맞지 않아 수정 — SERVICE-DEF-010) |
| DEF-SVC-002 | A8TrackingService.trackFirstPaymentConversion 실제 동작 테스트 미구현 (a8.net cURL 외부 의존) | 중간 | 미해결 | Mock HTTP Client 기반 테스트 추가 권장 |
| DEF-SVC-003 | Hermes DB 연결 격리(NFR-SVC-001) 및 타임아웃(5초) 전용 테스트 미구현 | 중간 | 미해결 | 외부 DB 의존으로 통합 테스트 환경 필요 |
| DEF-SVC-004 | FR-SVC-003 UNIQUE KEY 위반 CONFLICT(409) 테스트가 Feature 레벨에서만 확인 가능하나 DB 의존 SKIP | 중간 | 미해결 | MySQL 연결 환경(스테이징)에서 검증 필요 |
| DEF-SVC-005 | 차단 등록/해제 후 예약 가용성 즉시 반영(NFR-SVC-003) 테스트 미구현 | 낮음 | 미해결 | 모듈 간 통합 테스트 필요 |
| DEF-SVC-006 | TC-SVC-026~028 type 파라미터 수신 방식 불일치 — query string 기준으로 정비 필요 | 낮음 | 부분 해결 | STD TC 설명 수정 완료(SERVICE-DEF-011). 실제 테스트 코드 수정은 페이즈 2 |

---

## 7. Change Log (변경 이력)

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|---------|
| v1.0 | 2026-04-16 | jypark | 최초 작성. IEEE 829-2008 전면 작성. 62 TC → 74 TC(실제 테스트 수 갱신). |
| v1.1 | 2026-04-21 | jypark | **API ↔ IEEE 대조 리포트 [A] 이슈 반영**: TC-SVC-001~003 EP URL POST RPC 형식으로 수정, type 파라미터 query string 명기(SERVICE-DEF-010,011). TC-SVC-004~006 EP URL save-reject/delete-reject/get-callee-reject-list 수정. TC-SVC-007~009 EP URL get-service-list-mobile/new 수정. TC-SVC-026~028 type 파라미터 수신 방식 query string으로 명기(SERVICE-DEF-011). DEF-SVC-001 SKIP 사유 "MySQL 통합 테스트 환경 미구성" 으로 교체(SERVICE-DEF-010). DEF-SVC-006 신규 추가. SRS 참조 버전 v2.1로 갱신. |

### 변경 영향 기록 (v1.1)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| TC-SVC-001~003 입력 URL POST RPC 형식으로 수정 | TC와 실제 EP가 일치하여 Feature 테스트 실행 가능성 향상 | Routes.php 실제 EP는 POST/RPC 방식이나 TC에 GET URL이 기술되어 있었음 |
| TC-SVC-004~006 입력 URL 수정 | TC와 실제 EP 경로 일치 | save-reject, delete-reject, get-callee-reject-list가 TC에 미반영 |
| TC-SVC-026~028 type 파라미터 query string 명기 | 테스트 의도와 실제 파라미터 수신 방식 일치 확인 | API 문서는 query string, 컨트롤러 시그니처는 route parameter — STD에서 query string 기준 명세(SERVICE-DEF-011) |
| DEF-SVC-001 SKIP 사유 수정 | 정확한 SKIP 원인 기록으로 재실행 환경(스테이징 CI) 계획 수립 가능 | "SQLite" 설명은 이 프로젝트(Aurora MySQL)에 맞지 않는 표현 |
