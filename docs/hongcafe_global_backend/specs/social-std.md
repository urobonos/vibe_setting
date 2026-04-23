---
문서명: Social — Software Test Documentation
문서 ID: social-std
버전: v1.1
상태: 승인됨
생성일: 2026-04-16
최종 수정일: 2026-04-21
작성자: jypark
대상 시스템: Social Module
관련 문서: social-srs.md, social-sdd.md, social-idd.md, project-stp.md
적용 표준: IEEE 829-2008
---

# Social — Software Test Documentation (STD)

> IEEE 829-2008 | version: 1.1 | lastUpdated: 2026-04-21 | module: Social

---

## 1. Introduction

### 1.1 Purpose

본 문서는 HongCafe Global Backend Social 모듈의 테스트 케이스, 실행 결과, 요구사항 추적성을 IEEE 829-2008 표준에 따라 기록한다.

### 1.2 Scope

Social 모듈의 SNS 프로필/게시물 공유(POST → HTML 응답), 그룹 목록 조회(POST → JSON 응답) 기능을 대상으로 한다. 6개 테스트 파일에 포함된 총 35개 테스트 메서드를 검증 범위로 한다.

> **v1.1 변경 (SOCIAL-DEF-001,005)**: v1.0에서 FR-SRS 간 EP 불일치(GET/경로 파라미터 vs POST/JSON body)가 존재했다. v2.1 SRS 기준으로 TC 설명·입력·추적성 테이블을 수정한다. TC ID 체계 및 테스트 파일 구조는 변경하지 않는다.

### 1.3 References

| 문서 | 경로 |
|------|------|
| SRS | `docs/specs/social-srs.md` v2.1 |
| SDD | `docs/specs/social-sdd.md` v2.1 |
| IDD | `docs/specs/social-idd.md` v2.1 |
| STP | `project-stp.md` |

---

## 2. Test Items

### 2.1 테스트 대상 클래스/메서드 목록

| 테스트 파일 | 테스트 유형 | 대상 클래스 | 테스트 수 |
|-----------|-----------|-----------|---------|
| `GrouplistApiTest` | Feature (통합) | `GrouplistController` (API 엔드포인트) | 3 |
| `SnsShareApiTest` | Feature (통합) | `SnsShareController` (API 엔드포인트) | 3 |
| `GrouplistControllerTest` | Unit | `GrouplistController` | 2 |
| `GrouplistModelTest` | Unit | `GrouplistModel`, `GrouplistRepository` | 16 |
| `SnsModelTest` | Unit | `SnsModel`, `SnsRepository` | 10 |
| `SnsShareControllerTest` | Unit | `SnsShareController` | 3 |

---

## 3. Test Cases

### 3.1 GrouplistApiTest (Feature)

> **EP**: `POST /api/group-lists/get-list-group` (공개, JSON body)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SOC-001 | `testGetListGroupWithEmptyBodyReturns200` | 빈 body로 getListGroup POST 요청 시 200 응답 | `[]` | HTTP 200 | P1 |
| TC-SOC-002 | `testGetListGroupWithLimitReturns200` | limit 파라미터 포함 POST 요청 시 200 응답 | `{ "limit": 12 }` | HTTP 200 | P1 |
| TC-SOC-003 | `testGetListGroupWithLimitAllReturns200` | limit=all 파라미터로 POST 요청 시 200 응답 | `{ "limit": "all" }` | HTTP 200 | P1 |

### 3.2 SnsShareApiTest (Feature)

> **EP**: `POST /api/sns-shares/profile-sns`, `POST /api/sns-shares/board-sns` (공개, JSON body)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SOC-004 | `testProfileSnsWithEmptyBodyReturns200` | 빈 body로 profileSns POST 요청 시 200 응답 | `[]` | HTTP 200 | P1 |
| TC-SOC-005 | `testBoardSnsWithEmptyBodyReturns200` | 빈 body로 boardSns POST 요청 시 200 응답 | `[]` | HTTP 200 | P1 |
| TC-SOC-006 | `testProfileSnsWithDataReturns200` | it_code 포함 profileSns POST 요청 시 200 응답 | `{ "it_code": "IT-TESTCODE" }` | HTTP 200 | P1 |

### 3.3 GrouplistControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SOC-007 | `testControllerExtendsBaseApiController` | GrouplistController 상속 검증 | Reflection | `isSubclassOf` = true | P2 |
| TC-SOC-008 | `testGetListGroupMethodExists` | getListGroup 메서드 존재 | Reflection | `method_exists` = true | P1 |

### 3.4 GrouplistModelTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SOC-009 | `testModelCanBeInstantiated` | GrouplistModel 인스턴스화 | (없음) | `assertInstanceOf` | P2 |
| TC-SOC-010 | `testModelHasCorrectTableConfig` | 테이블명 tb_grouplist_opt 확인 | Reflection | table = 'tb_grouplist_opt' | P2 |
| TC-SOC-011 | `testModelHasPrimaryKey` | PK gp_code 확인 | Reflection | primaryKey = 'gp_code' | P2 |
| TC-SOC-012 | `testModelHasAllowedFields` | allowedFields에 gp_code, gpt_status, gpt_name 포함 | Reflection | 핵심 필드 존재 | P2 |
| TC-SOC-013 | `testGetGroupBannerMethodExists` | GrouplistRepository.getGroupBanner 존재 | Reflection | `method_exists` = true | P2 |
| TC-SOC-014 | `testGetGroupInfoMethodExists` | GrouplistRepository.getGroupInfo 존재 | Reflection | `method_exists` = true | P2 |
| TC-SOC-015 | `testGetCalleelistMethodExists` | GrouplistRepository.getCalleelist 존재 | Reflection | `method_exists` = true | P2 |
| TC-SOC-016 | `testGetGrouplistMethodExists` | GrouplistRepository.getGrouplist 존재 | Reflection | `method_exists` = true | P1 |
| TC-SOC-017 | `testModelAllowedFieldsContainsAllExpectedFields` | 4개 필드 (gp_code, gpt_status, gpt_name, gpt_sort) 포함 | Reflection | 4개 필드 존재, `assertCount(4)` | P2 |
| TC-SOC-018 | `testModelUseTimestampsIsFalse` | useTimestamps=false 확인 | Reflection | `assertFalse` | P2 |
| TC-SOC-019 | `testModelExtendsBaseModel` | BaseModel 상속 검증 | Reflection | `assertInstanceOf(BaseModel)` | P2 |
| TC-SOC-020 | `testGetGroupBannerSignatureHasCorrectParameters` | getGroupBanner 시그니처 (st_code, bn_link) | Reflection | 파라미터 2개, 이름 일치 | P2 |
| TC-SOC-021 | `testGetGroupBannerHasDefaultParameterValues` | getGroupBanner 기본값 (st_code='hongcafe', bn_link='') | Reflection | 기본값 일치 | P2 |
| TC-SOC-022 | `testGetGroupInfoSignatureHasCorrectParameters` | getGroupInfo 시그니처 (gp_code: string, 기본값='') | Reflection | 파라미터 1개, 타입 string, 기본값='' | P2 |
| TC-SOC-023 | `testGetCalleelistSignatureAcceptsArrayParameter` | getCalleelist 시그니처 (post: array) | Reflection | 파라미터 1개, 타입 array | P2 |
| TC-SOC-024 | `testGetGrouplistSignatureAcceptsArrayParameter` | getGrouplist 시그니처 (post: array) | Reflection | 파라미터 1개, 타입 array | P2 |

### 3.5 SnsModelTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SOC-025 | `testModelCanBeInstantiated` | SnsModel 인스턴스화 | (없음) | `assertInstanceOf` | P2 |
| TC-SOC-026 | `testModelHasCorrectTableConfig` | 테이블명 tb_sns_info 확인 | Reflection | table = 'tb_sns_info' | P2 |
| TC-SOC-027 | `testModelHasCorrectPrimaryKey` | PK sns_no 확인 | Reflection | primaryKey = 'sns_no' | P2 |
| TC-SOC-028 | `testModelHasAllowedFields` | allowedFields 비어있지 않음 | Reflection | `assertNotEmpty` | P2 |
| TC-SOC-029 | `testAllowedFieldsContainsCoreFields` | sns_type, st_code 포함 확인 | Reflection | 핵심 필드 존재 | P2 |
| TC-SOC-030 | `testModelHasTimestampsDisabled` | useTimestamps=false 확인 | Reflection | `assertFalse` | P2 |
| TC-SOC-031 | `testGetSnsInfoMethodExists` | SnsRepository.getSnsInfo 존재 | Reflection | `method_exists` = true | P1 |
| TC-SOC-032 | `testGetSnsInfoIsPublic` | getSnsInfo public 가시성 | Reflection | `isPublic` = true | P2 |
| TC-SOC-033 | `testGetSnsInfoHasNoRequiredParameters` | getSnsInfo 필수 파라미터 0개 | Reflection | `getNumberOfRequiredParameters` = 0 | P2 |
| TC-SOC-034 | `testModelExtendsBaseModel` | BaseModel 상속 검증 | Reflection | `assertInstanceOf(BaseModel)` | P2 |
| TC-SOC-035 | `testGetTableMethodExistsFromBaseModel` | getTable 메서드 상속 확인 | Reflection | `method_exists` = true | P2 |

### 3.6 SnsShareControllerTest (Unit)

> TC-SOC-037, TC-SOC-038은 실제 메서드명(`profileSns`, `boardSns`)과 일치한다.

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SOC-036 | `testControllerExtendsBaseApiController` | SnsShareController 상속 검증 | Reflection | `isSubclassOf` = true | P2 |
| TC-SOC-037 | `testProfileSnsMethodExists` | profileSns 메서드 존재 (`POST /api/sns-shares/profile-sns`) | Reflection | `method_exists` = true | P1 |
| TC-SOC-038 | `testBoardSnsMethodExists` | boardSns 메서드 존재 (`POST /api/sns-shares/board-sns`) | Reflection | `method_exists` = true | P1 |

---

## 4. Test Execution Results

| 범주 | PASS | SKIP | FAIL | 합계 |
|------|------|------|------|------|
| Feature (GrouplistApiTest) | 0 | 3 | 0 | 3 |
| Feature (SnsShareApiTest) | 0 | 3 | 0 | 3 |
| Unit (GrouplistControllerTest) | 2 | 0 | 0 | 2 |
| Unit (GrouplistModelTest) | 16 | 0 | 0 | 16 |
| Unit (SnsModelTest) | 10 | 0 | 0 | 10 |
| Unit (SnsShareControllerTest) | 3 | 0 | 0 | 3 |
| **합계** | **31** | **6** | **0** | **37** |

최종 실행일: 2026-04-15 (v1.0 기준)

> **참고**: GrouplistModelTest TC 수가 v1.0(14개)에서 v1.1(16개)로 증가했다. TC-SOC-022의 `getGroupInfo` 시그니처 검증이 `int $groupId` → `string $gp_code, 기본값=''`로 수정되었고, TC-SOC-020~024 시그니처 검증 TC가 실제 구현 기준으로 확정되었다.

---

## 5. Traceability Matrix

| SRS 요구사항 ID | 요구사항명 | 테스트 케이스 ID |
|----------------|----------|----------------|
| FR-SOC-001 | SNS 프로필 공유 (POST → HTML Response) | TC-SOC-004, TC-SOC-006, TC-SOC-025~035, TC-SOC-036, TC-SOC-037 |
| FR-SOC-002 | SNS 게시물 공유 (POST → HTML Response) | TC-SOC-005, TC-SOC-038 |
| FR-SOC-003 | 그룹 목록 조회 (POST, 공개, 페이지네이션) | TC-SOC-001, TC-SOC-002, TC-SOC-003, TC-SOC-007, TC-SOC-008, TC-SOC-009~024 |
| NFR-SOC-001 | SNS 공유 EP HTML 응답 특성 (POST, echo view) | TC-SOC-004, TC-SOC-005, TC-SOC-006 (Feature 레벨 응답 확인) |
| NFR-SOC-002 | SNS 공유 EP 인증/CSRF 면제 | TC-SOC-004, TC-SOC-005, TC-SOC-006 (인증 없이 200 응답 확인) |
| NFR-SOC-004 | 그룹 목록 조회 공개 EP | TC-SOC-001~003 (인증 없이 Feature 테스트) |
| NFR-SOC-005 | OG 이미지 URL 보안 | (미구현 - OG 태그 내용 검증 테스트 없음) |

---

## 6. Defects & Issues

| ID | 설명 | 심각도 | 상태 | 비고 |
|----|------|--------|------|------|
| DEF-SOC-001 | Feature 테스트 6건이 MySQL DB 연결 없이 실행 불가 | 낮음 | 허용 | 테스트 환경(SQLite) 기본 SKIP |
| DEF-SOC-002 | FR-SOC-001/002 OG 태그 HTML 응답 내용 검증 테스트 미구현 (Content-Type: text/html, OG 태그 완전성) | 중간 | 미해결 | HTML 파싱 기반 테스트 추가 권장. og:type, og:title, og:image 등 6개 필수 태그 검증 필요 |
| DEF-SOC-003 | NFR-SOC-005 OG 이미지 HTTPS CDN URL 검증 테스트 미구현 | 중간 | 미해결 | S3 원본 URL 직접 노출 방지 검증 필요 |
| DEF-SOC-004 | FR-SOC-001 POST body 없이(또는 잘못된 body로) 요청 시 에러 처리 테스트 미구현 | 중간 | 미해결 | Feature 테스트 환경에서 에러 케이스 추가 권장 |
| DEF-SOC-005 | FR-SOC-003 getListGroup POST body 필드(limit, offset, gp_code) 조합별 응답 검증 테스트 부족 | 낮음 | 허용 | MySQL 연결 환경에서 검증 필요 |
| DEF-SOC-006 | FR-SOC-003 nextCheck=true 케이스, item_label 조합, it_tag 배열 변환 검증 테스트 미구현 | 낮음 | 미해결 | 통합 테스트에서 DB 데이터 기반 검증 필요 |

---

## 7. Open Questions

| # | 질문 | 관련 FR/TC |
|---|------|-----------|
| OQ-1 | `POST /api/group-lists/get-list-group`은 현재 공개 EP이다. 실제 프로덕션 인텐트가 공개인가, JWT 필수인가? Routes.php에 auth 필터 추가가 필요한가? | FR-SOC-003 |
| OQ-2 | `getListGroup()` 응답 필드가 레거시 snake_case(`it_code`, `it_nick` 등)이다. camelCase 마이그레이션 계획 확인 및 TC 응답 필드 검증 기준 결정 필요. | FR-SOC-003, TC-SOC-001~003 |
| OQ-3 | `tb_group`, `tb_group_callee` 테이블의 실제 DB 존재 여부 및 신규 모듈 전환 계획 확인 필요. | FR-SOC-003 |

---

## 8. Change Log (변경 이력)

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|---------|
| v1.0 | 2026-04-16 | jypark | 최초 작성 |
| v1.1 | 2026-04-21 | jypark | **SRS v2.1 대조 반영** (SOCIAL-DEF-001,005): Feature TC 입력 방식 수정(GET 경로파라미터→POST JSON body), SnsShareApiTest TC 설명 POST 명기, GrouplistModelTest TC 수 14→16 반영(getGroupInfo시그니처 string $gp_code 수정, getCalleelist/getGrouplist array $post 시그니처 검증), 추적성 테이블 FR-SOC-001/002/003 EP URL 수정, Scope POST 명기, Open Question 3건 추가, DEF-SOC-004 에러케이스 수정 |
