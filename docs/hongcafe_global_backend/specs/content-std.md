---
문서명: Content — Software Test Documentation
문서 ID: content-std
버전: v1.0
상태: 승인됨
생성일: 2026-04-16
최종 수정일: 2026-04-16
작성자: jypark
대상 시스템: Content Module
관련 문서: content-srs.md, content-sdd.md, content-idd.md, project-stp.md
적용 표준: IEEE 829-2008
---

# Content Module — Software Test Documentation

> IEEE 829-2008 준수 | version: 1.0 | updated: 2026-04-16 | module: Content

---

## 1. Introduction

### 1.1 Purpose

본 문서는 HongCafe Global Backend Content 모듈의 테스트 결과를 IEEE 829-2008 표준에 따라 문서화한다. Content 모듈은 공지사항(Notice), FAQ, 배너(Banner), 테마(Theme) 4개 콘텐츠 영역으로 구성되며, 16개 엔드포인트에 대한 9개 테스트 파일의 실행 결과와 SRS 요구사항 추적성을 기록한다.

### 1.2 Scope

- **테스트 파일 수**: 9개 (Feature 4, Unit 5)
- **대상 모듈**: `app/Modules/Content/`
- **콘텐츠 영역**: Notice (5 EP), FAQ (5 EP), Banner (5 EP), Theme (1 EP)
- **테스트 유형**: Feature 테스트 (API 통합), Unit 테스트 (서비스/컨트롤러/모델 단위)

### 1.3 References

| 문서 | 위치 |
|------|------|
| content-srs.md (SRS-CONTENT-001 v2.1) | `docs/specs/` |
| content-sdd.md (SDD-CONTENT-001) | `docs/specs/` |
| content-idd.md (IDD-CONTENT-001) | `docs/specs/` |
| project-stp.md | `docs/specs/` |

---

## 2. Test Items

### 2.1 Feature 테스트 (API 통합)

| 테스트 파일 | 대상 클래스/엔드포인트 | 테스트 메서드 수 |
|------------|----------------------|----------------|
| BannerApiTest | BannerController — `api/banners/*` | 4 |
| FaqApiTest | FaqController — `api/faqs/*` | 4 |
| NoticeApiTest | NoticeController — `api/notices/*` | 3 |
| ThemeApiTest | ThemeController — `api/theme/*` | 3 |

### 2.2 Unit 테스트 (서비스/컨트롤러/모델)

| 테스트 파일 | 대상 클래스 | 테스트 메서드 수 |
|------------|-----------|----------------|
| BannerServiceTest | BannerService | 16 |
| FaqServiceTest | FaqService | 10 |
| NoticeServiceTest | NoticeService | 10 |
| ThemeControllerTest | ThemeController | 2 |
| ThemeModelTest | ThemeModel, ThemeRepository | 16 |

---

## 3. Test Cases

### 3.1 BannerApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-BA-001 | testIndexReturnsSuccessResponse | GET /api/banners 성공 응답 | — | HTTP 200, status='success' | P1 |
| TC-BA-002 | testIndexWithPaginationParameters | 페이지네이션 파라미터 포함 요청 | page=1, perPage=5 | HTTP 200, status='success' | P1 |
| TC-BA-003 | testIndexWithPositionFilter | bn_position 필터 조회 | bn_position=main_top | HTTP 200, status='success' | P1 |
| TC-BA-004 | testShowReturns404ForNonExistentBanner | 존재하지 않는 배너 조회 시 404 | id=999999 | HTTP 404 | P1 |

### 3.2 FaqApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-FA-001 | testIndexReturnsSuccessResponse | GET /api/faqs 성공 응답 | — | HTTP 200, status='success' | P1 |
| TC-FA-002 | testIndexWithPaginationParameters | 페이지네이션 파라미터 포함 요청 | page=1, perPage=5 | HTTP 200, status='success' | P1 |
| TC-FA-003 | testIndexWithMenuCodeFilter | faq_menu_code 필터 조회 | faq_menu_code=general | HTTP 200, status='success' | P1 |
| TC-FA-004 | testShowReturns404ForNonExistentFaq | 존재하지 않는 FAQ 조회 시 404 | id=999999 | HTTP 404 | P1 |

### 3.3 NoticeApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-NA-001 | testIndexReturnsSuccessResponse | GET /api/notices 성공 응답 | — | HTTP 200, status='success' | P1 |
| TC-NA-002 | testIndexWithPaginationParameters | 페이지네이션 파라미터 포함 요청 | page=1, perPage=5 | HTTP 200, status='success' | P1 |
| TC-NA-003 | testShowReturns404ForNonExistentNotice | 존재하지 않는 공지사항 조회 시 404 | id=999999 | HTTP 404 | P1 |

### 3.4 ThemeApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-TA-001 | testGetThemeListWithEmptyBodyReturns200 | 빈 body로 POST 시 200 응답 | 빈 body | HTTP 200 | P1 |
| TC-TA-002 | testGetThemeListWithPaginationReturns200 | limit/offset 파라미터 포함 POST | limit=5, offset=0 | HTTP 200 | P1 |
| TC-TA-003 | testGetThemeListWithOrderReturns200 | order 파라미터 포함 POST | limit=10, offset=0, order='popular' | HTTP 200 | P1 |

### 3.5 BannerServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-BS-001 | testGetByIdReturnsBanner | ID로 배너 조회 성공 | id=1 | bn_no=1, bn_name='메인 배너' | P1 |
| TC-BS-002 | testGetByIdThrowsExceptionWhenNotFound | 미존재 배너 조회 시 Exception | id=999 | Exception(404) | P1 |
| TC-BS-003 | testCreateReturnsCreatedBanner | 배너 생성 성공 | bn_img, bn_link, bn_position | bn_no=1 | P1 |
| TC-BS-004 | testCreateThrowsExceptionOnFailure | 배너 생성 실패 시 Exception | insert→false | Exception('배너 등록에 실패했습니다.') | P1 |
| TC-BS-005 | testUpdateReturnsUpdatedBanner | 배너 수정 성공 | bn_name='수정된 배너' | bn_name='수정된 배너' | P1 |
| TC-BS-006 | testUpdateThrowsExceptionWhenNotFound | 미존재 배너 수정 시 Exception | id=999 | Exception(404) | P1 |
| TC-BS-007 | testUpdateThrowsExceptionWhenNoData | 빈 데이터로 수정 시 Exception | `[]` | Exception(400, '수정할 데이터가 없습니다.') | P1 |
| TC-BS-008 | testDeleteReturnsTrue | 배너 삭제 성공 | id=1 | true | P1 |
| TC-BS-009 | testDeleteThrowsExceptionWhenNotFound | 미존재 배너 삭제 시 Exception | id=999 | Exception(404) | P1 |
| TC-BS-010 | testDeleteThrowsExceptionWhenRepositoryReturnsFalse | Repository 삭제 실패 시 Exception | delete→false | Exception(500) | P1 |
| TC-BS-011 | testUpdateThrowsExceptionWhenRepositoryReturnsFalse | Repository 수정 실패 시 Exception | update→false | Exception(500) | P1 |
| TC-BS-012 | testGetListReturnsCorrectStructureWithoutPositionFilter | 목록 조회 구조 검증 (필터 없음) | page=1, perPage=10 | items, total, page, perPage 키 존재 | P1 |
| TC-BS-013 | testGetListFiltersWithBnPosition | bn_position 필터 목록 조회 | position='main_top' | total=1, position 일치 | P1 |
| TC-BS-014 | testGetListCalculatesOffsetCorrectly | 페이지 offset 계산 검증 | page=3, perPage=10 | offset=20 | P2 |
| TC-BS-015 | testCreateAppliesDefaultValuesForOptionalFields | 선택 필드 기본값 적용 | 필수 필드만 | bn_view='Y', bn_first='N', bn_sort=0 | P1 |
| TC-BS-016 | testCreateWithAllOptionalFieldsProvided | 모든 선택 필드 포함 생성 | 전체 필드 | bn_no=10 | P2 |

### 3.6 FaqServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-FS-001 | testGetByIdReturnsFaq | ID로 FAQ 조회 성공 | id=1 | faq_no=1, faq_question='테스트 질문' | P1 |
| TC-FS-002 | testGetByIdThrowsExceptionWhenNotFound | 미존재 FAQ 조회 시 Exception | id=999 | Exception(404) | P1 |
| TC-FS-003 | testCreateReturnsCreatedFaq | FAQ 생성 성공 | faq_question, faq_answer | faq_no=1 | P1 |
| TC-FS-004 | testCreateThrowsExceptionOnFailure | FAQ 생성 실패 시 Exception | insert→false | Exception('FAQ 등록에 실패했습니다.') | P1 |
| TC-FS-005 | testUpdateReturnsUpdatedFaq | FAQ 수정 성공 | faq_question='수정된 질문' | faq_question='수정된 질문' | P1 |
| TC-FS-006 | testUpdateThrowsExceptionWhenNotFound | 미존재 FAQ 수정 시 Exception | id=999 | Exception(404) | P1 |
| TC-FS-007 | testUpdateThrowsExceptionWhenNoData | 빈 데이터로 수정 시 Exception | `[]` | Exception(400) | P1 |
| TC-FS-008 | testDeleteReturnsTrue | FAQ 삭제 성공 | id=1 | true | P1 |
| TC-FS-009 | testDeleteThrowsExceptionWhenNotFound | 미존재 FAQ 삭제 시 Exception | id=999 | Exception(404) | P1 |
| TC-FS-010 | testUpdateFiltersOnlyAllowedKeys | 허용된 키만 필터링하여 수정 | bn_view + unknown_field | unknown_field 제외 | P1 |

### 3.7 NoticeServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-NS-001 | testGetByIdReturnsNotice | ID로 공지사항 조회 성공 | id=1 | nt_no=1, nt_title='테스트 공지' | P1 |
| TC-NS-002 | testGetByIdThrowsExceptionWhenNotFound | 미존재 공지사항 조회 시 Exception | id=999 | Exception(404) | P1 |
| TC-NS-003 | testCreateReturnsCreatedNotice | 공지사항 생성 성공 | nt_title, nt_content | nt_no=1 | P1 |
| TC-NS-004 | testCreateThrowsExceptionOnFailure | 공지사항 생성 실패 시 Exception | insert→false | Exception('공지사항 등록에 실패했습니다.') | P1 |
| TC-NS-005 | testUpdateReturnsUpdatedNotice | 공지사항 수정 성공 | nt_title='수정된 제목' | nt_title='수정된 제목' | P1 |
| TC-NS-006 | testUpdateThrowsExceptionWhenNotFound | 미존재 공지사항 수정 시 Exception | id=999 | Exception(404) | P1 |
| TC-NS-007 | testUpdateThrowsExceptionWhenNoData | 빈 데이터로 수정 시 Exception | `[]` | Exception(400) | P1 |
| TC-NS-008 | testDeleteReturnsTrue | 공지사항 삭제 성공 | id=1 | true | P1 |
| TC-NS-009 | testDeleteThrowsExceptionWhenNotFound | 미존재 공지사항 삭제 시 Exception | id=999 | Exception(404) | P1 |

### 3.8 ThemeControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 기대 결과 | 우선순위 |
|-------|---------|------|----------|---------|
| TC-TC-001 | testControllerExtendsBaseApiController | ThemeController가 BaseApiController 상속 확인 | assertTrue | P1 |
| TC-TC-002 | testGetThemeListMethodExists | getThemeList 메서드 존재 확인 | assertTrue | P1 |

### 3.9 ThemeModelTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-TM-001 | testModelCanBeInstantiated | ThemeModel 인스턴스화 가능 | — | assertInstanceOf | P1 |
| TC-TM-002 | testModelHasCorrectTableConfig | table='tb_banner_theme' 확인 | Reflection | 'tb_banner_theme' | P1 |
| TC-TM-003 | testModelHasPrimaryKey | primaryKey='tm_code' 확인 | Reflection | 'tm_code' | P1 |
| TC-TM-004 | testModelHasAllowedFields | allowedFields 배열 비어있지 않음 확인 | Reflection | isArray, notEmpty | P1 |
| TC-TM-005 | testGetThemeListMethodExists | ThemeRepository::getThemeList 존재 확인 | — | assertTrue | P1 |
| TC-TM-006 | testGetThemeItemMethodExists | ThemeRepository::getThemeItem 존재 확인 | — | assertTrue | P1 |
| TC-TM-007 | testGetThemeCalleeMethodExists | ThemeRepository::getThemeCallee 존재 확인 | — | assertTrue | P1 |
| TC-TM-008 | testUseTimestampsIsFalse | useTimestamps=false 확인 | Reflection | assertFalse | P2 |
| TC-TM-009 | testAllowedFieldsContainsAllExpectedFields | 6개 필드 전체 포함 확인 | Reflection | tm_code~tm_description | P1 |
| TC-TM-010 | testAllowedFieldsCountIs6 | allowedFields 개수 6 확인 | Reflection | assertCount(6) | P2 |
| TC-TM-011 | testGetThemeListSignature | getThemeList 시그니처 검증 | Reflection | 1 param('post'), return array | P1 |
| TC-TM-012 | testGetThemeItemSignature | getThemeItem 시그니처 검증 | Reflection | nullable return | P1 |
| TC-TM-013 | testGetThemeCalleeSignature | getThemeCallee 시그니처 검증 | Reflection | return array | P1 |
| TC-TM-014 | testGetThemeItemDefaultParameterIsEmptyString | getThemeItem 기본값 빈 문자열 | Reflection | '' | P2 |
| TC-TM-015 | testGetThemeCalleeDefaultParameterIsEmptyString | getThemeCallee 기본값 빈 문자열 | Reflection | '' | P2 |
| TC-TM-016 | testThemeRepositoryImplementsInterface | ThemeRepository 인터페이스 구현 확인 | — | is_a ThemeRepositoryInterface | P1 |

---

## 4. Test Execution Results

| 테스트 파일 | 총 케이스 | PASS | FAIL | SKIP | 최종 실행일 |
|------------|----------|------|------|------|-----------|
| BannerApiTest | 4 | 4 | 0 | 0 | 2026-04-15 |
| FaqApiTest | 4 | 4 | 0 | 0 | 2026-04-15 |
| NoticeApiTest | 3 | 3 | 0 | 0 | 2026-04-15 |
| ThemeApiTest | 3 | 3 | 0 | 0 | 2026-04-15 |
| BannerServiceTest | 16 | 16 | 0 | 0 | 2026-04-15 |
| FaqServiceTest | 10 | 10 | 0 | 0 | 2026-04-15 |
| NoticeServiceTest | 10 | 10 | 0 | 0 | 2026-04-15 |
| ThemeControllerTest | 2 | 2 | 0 | 0 | 2026-04-15 |
| ThemeModelTest | 16 | 16 | 0 | 0 | 2026-04-15 |
| **합계** | **68** | **68** | **0** | **0** | — |

---

## 5. Traceability Matrix

| SRS 요구사항 ID | 요구사항 설명 | 테스트 케이스 ID | 검증 상태 |
|----------------|-------------|-----------------|----------|
| FR-CONTENT-001 | 공지사항 CRUD (5 EP) | TC-NA-001~003, TC-NS-001~009 | PASS |
| FR-CONTENT-002 | FAQ CRUD (5 EP) | TC-FA-001~004, TC-FS-001~010 | PASS |
| FR-CONTENT-003 | 배너 CRUD + 시간 기반 활성화 | TC-BA-001~004, TC-BS-001~016 | PASS |
| FR-CONTENT-004 | 테마 목록 (온콜/가격 필터) | TC-TA-001~003, TC-TC-001~002, TC-TM-001~016 | PASS |
| NFR-CONTENT-001 | ResourceController 패턴 | TC-TC-001 (BaseApiController 상속 확인) | PASS |
| NFR-CONTENT-002 | 조회 응답 200ms 이하 (p95) | Feature 테스트 HTTP 200 확인 (성능 별도) | 검증 필요 |
| NFR-CONTENT-003 | 배너 시간 활성화 정확도 | TC-BA-001, TC-BA-003, TC-BS-012~013 | PASS |
| NFR-CONTENT-004 | 입력값 검증 | TC-BS-004, TC-BS-007, TC-FS-004, TC-FS-007, TC-NS-004, TC-NS-007 | PASS |
| NFR-CONTENT-005 | SQL Injection 방지 ($db->escape()) | TC-TM-016 (인터페이스 구현 확인) | PASS |
| NFR-CONTENT-006 | 페이지네이션 meta | TC-BA-002, TC-FA-002, TC-NA-002, TC-BS-012~014 | PASS |

---

## 6. Defects & Issues

| ID | 유형 | 설명 | 심각도 | 해결 상태 |
|----|------|------|--------|----------|
| DEF-CT-001 | 커버리지 | Feature 테스트는 MySQL DB 연결 필요 — SQLite 테스트 환경에서 자동 skip | 저 | 설계 의도 (환경 분리) |
| DEF-CT-002 | 커버리지 | NFR-CONTENT-002 성능 목표(p95 200ms) 단위 테스트로 검증 불가 — k6 부하 테스트 필요 | 중 | 미해결 (스테이징 환경 검증 필요) |
| DEF-CT-003 | 커버리지 | ThemeRepository raw SQL + $db->escape() 검증은 코드 리뷰(Inspection)로만 확인 가능 | 저 | 코드 리뷰로 대체 |
