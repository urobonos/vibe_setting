---
문서명: Board — Software Test Documentation
문서 ID: board-std
버전: v1.0
상태: 승인됨
생성일: 2026-04-16
최종 수정일: 2026-04-16
작성자: jypark
대상 시스템: Board Module
관련 문서: board-srs.md, board-sdd.md, board-idd.md, project-stp.md
적용 표준: IEEE 829-2008
---

# Board — Software Test Documentation (STD)

> IEEE 829-2008 | version: 1.0 | lastUpdated: 2026-04-16 | module: Board

---

## 1. Introduction

### 1.1 Purpose

본 Software Test Documentation(STD)은 HongCafe Global Backend Board 모듈에 대한 테스트 항목, 테스트 케이스, 실행 결과, 추적성 매트릭스, 결함 내역을 IEEE 829-2008 표준에 따라 기록한다. Board 모듈의 SRS(board-srs.md)에서 정의한 기능 요구사항(FR-001~FR-012)에 대한 검증 근거를 제공한다.

### 1.2 Scope

| 항목 | 내용 |
|------|------|
| 테스트 대상 모듈 | Board (문의, 공지, 댓글, 포스팅, 채용 신청) |
| 테스트 파일 수 | 7개 (Feature 2, Unit 5) |
| 테스트 메서드 수 | 총 107개 |
| 테스트 프레임워크 | PHPUnit + CodeIgniter 4 CIUnitTestCase / FeatureTestTrait |

### 1.3 References

| 문서 | 경로 |
|------|------|
| Board SRS | `docs/specs/board-srs.md` v2.0 |
| Board SDD | `docs/specs/board-sdd.md` v2.0 |
| Board IDD | `docs/specs/board-idd.md` v2.0 |
| 프로젝트 테스트 계획 | `project-stp.md` |

---

## 2. Test Items

### 2.1 테스트 파일 목록

| # | 테스트 파일 | 유형 | 테스트 대상 클래스 | 메서드 수 |
|---|-----------|------|------------------|:---------:|
| 1 | `tests/Modules/Board/Feature/BoardApiTest.php` | Feature (통합) | BoardController API 엔드포인트 | 5 |
| 2 | `tests/Modules/Board/Feature/CommentApiTest.php` | Feature (통합) | CommentController API 엔드포인트 | 4 |
| 3 | `tests/Modules/Board/Unit/BoardControllerTest.php` | Unit | BoardController (메서드 존재/상속 확인) | 11 |
| 4 | `tests/Modules/Board/Unit/BoardModelTest.php` | Unit | BoardModel + BoardRepository (모델 설정/시그니처 검증) | 42 |
| 5 | `tests/Modules/Board/Unit/BoardServiceTest.php` | Unit | BoardService (비즈니스 로직) | 32 |
| 6 | `tests/Modules/Board/Unit/CommentControllerTest.php` | Unit | CommentController (메서드 존재/상속 확인) | 3 |
| 7 | `tests/Modules/Board/Unit/CommentFormatterTest.php` | Unit | CommentFormatter (댓글 포맷팅/자식 매핑) | 10 |

### 2.2 테스트 대상 클래스/메서드

| 클래스 | 테스트 대상 메서드 |
|--------|------------------|
| `BoardController` | `insertColumnComment()`, `deleteColumnComment()`, `commentReport()`, `commentReportNotify()`, `getInquiry()`, `insertInquiry()`, `getNotice()`, `insertRecruit()`, `getPosting()`, `postingLike()` |
| `CommentController` | `getItemComment()`, `updateCommentHelp()` |
| `BoardModel` | 모델 설정 (table, primaryKey, allowedFields, useTimestamps) |
| `BoardRepository` | `getCounselLike()`, `getBoardColumnComment()`, `insertColumnComment()`, `deleteColumnComment()`, `boardCommentReportUpdate()`, `getBoardFaq()`, `getBoardFaqHeader()`, `getBoardInquiry()`, `getQnaGroup()`, `InsertInquiry()`, `getBoardNotice()`, `getNoticePrev()`, `getNoticeNext()`, `InsertCast()`, `getBoardPosting()`, `getBoardBestPosting()`, `getPostingDetail()`, `getRejectUser()`, `UpdatePostingContentHit()`, `addPostingLike()`, `deletePostingLike()`, `getPostingPrev()`, `getPostingNext()`, `updatePostingCommentCnt()`, `updatePostingCommentMinusCnt()`, `getSearchPostingExmCount()`, `getCommentInfo()`, `getCommentReportYesNo()`, `getCommentUserReportYesNo()`, `getnotifierInfo()`, `insertCommentNotify()`, `getCastInfo()` |
| `BoardService` | `buildCommentData()`, `buildCommentNotifyData()`, `resolveNotifierId()`, `formatInquiryList()`, `buildInquiryData()`, `formatNoticeList()`, `buildRecruitData()`, `formatPostingList()` |
| `CommentFormatter` | `formatCommentList()` |

---

## 3. Test Cases

### 3.1 BoardApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-BRD-001 | `testGetInquiryReturns200` | getInquiry POST 시 200 응답 반환 | `{limit: 10}` | HTTP 200, `status` 키 존재 | P1 |
| TC-BRD-002 | `testGetNoticeReturns200` | getNotice POST 시 200 응답 반환 | `{limit: 10}` | HTTP 200, `status` 키 존재 | P1 |
| TC-BRD-003 | `testInsertInquiryWithoutRequiredFieldsReturnsError` | 필수 필드 없이 insertInquiry 시 에러 반환 | `{}` | HTTP 200, `status: error` | P1 |
| TC-BRD-004 | `testInsertColumnCommentWithoutAuthReturnsError` | 미인증 댓글 등록 시 에러 반환 | `{bcc_content, bd_id, bc_id, bcc_no}` (인증 없음) | HTTP 200, `status: error` | P1 |
| TC-BRD-005 | `testPostingLikeWithoutAuthReturnsError` | 미인증 좋아요 시 에러 반환 | `{code, id}` (인증 없음) | HTTP 200, `status: error` | P1 |

### 3.2 CommentApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-BRD-006 | `testGetItemCommentWithoutItemCodeReturnsError` | item_code 없이 조회 시 에러 | `{keyword: ''}` | HTTP 200, `status: error` | P1 |
| TC-BRD-007 | `testGetItemCommentWithoutKeywordReturnsError` | keyword 없이 조회 시 에러 | `{item_code: 'TEST001'}` | HTTP 200, `status: error` | P1 |
| TC-BRD-008 | `testGetItemCommentWithRequiredParamsReturns200` | 필수 파라미터 포함 시 200 응답 | `{item_code, keyword, offset, limit}` | HTTP 200, `status` 키 존재 | P1 |
| TC-BRD-009 | `testUpdateCommentHelpWithoutAuthReturnsError` | 미인증 도움 토글 시 에러 | `{cm_no: 1}` (인증 없음) | HTTP 200, `status: error` | P1 |

### 3.3 BoardControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-BRD-010 | `testControllerExtendsBaseApiController` | BoardController가 BaseApiController 상속 확인 | Reflection | `isSubclassOf(BaseApiController)` = true | P1 |
| TC-BRD-011 | `testInsertColumnCommentMethodExists` | insertColumnComment 메서드 존재 확인 | `method_exists` | true | P1 |
| TC-BRD-012 | `testDeleteColumnCommentMethodExists` | deleteColumnComment 메서드 존재 확인 | `method_exists` | true | P1 |
| TC-BRD-013 | `testCommentReportMethodExists` | commentReport 메서드 존재 확인 | `method_exists` | true | P1 |
| TC-BRD-014 | `testCommentReportNotifyMethodExists` | commentReportNotify 메서드 존재 확인 | `method_exists` | true | P1 |
| TC-BRD-015 | `testGetInquiryMethodExists` | getInquiry 메서드 존재 확인 | `method_exists` | true | P1 |
| TC-BRD-016 | `testInsertInquiryMethodExists` | insertInquiry 메서드 존재 확인 | `method_exists` | true | P1 |
| TC-BRD-017 | `testGetNoticeMethodExists` | getNotice 메서드 존재 확인 | `method_exists` | true | P1 |
| TC-BRD-018 | `testInsertRecruitMethodExists` | insertRecruit 메서드 존재 확인 | `method_exists` | true | P1 |
| TC-BRD-019 | `testGetPostingMethodExists` | getPosting 메서드 존재 확인 | `method_exists` | true | P1 |
| TC-BRD-020 | `testPostingLikeMethodExists` | postingLike 메서드 존재 확인 | `method_exists` | true | P1 |

### 3.4 BoardModelTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-BRD-021 | `testModelCanBeInstantiated` | BoardModel 인스턴스 생성 확인 | `new BoardModel()` | `instanceof BoardModel` | P1 |
| TC-BRD-022 | `testModelHasCorrectTableConfig` | 테이블명 `tb_posting` 확인 | Reflection | `table == 'tb_posting'` | P1 |
| TC-BRD-023 | `testModelHasPrimaryKey` | PK `pt_id` 확인 | Reflection | `primaryKey == 'pt_id'` | P1 |
| TC-BRD-024 | `testModelHasAllowedFields` | allowedFields에 st_code, pt_title, pt_content 포함 확인 | Reflection | 해당 필드 존재 | P1 |
| TC-BRD-025 | `testUseTimestampsIsFalse` | useTimestamps = false 확인 | Reflection | false | P2 |
| TC-BRD-026 | `testAllowedFieldsContainsAllExpectedFields` | allowedFields 13개 필드 전체 확인 | Reflection | 13개 필드 일치 | P1 |
| TC-BRD-027 | `testAllowedFieldsCountIs13` | allowedFields 개수 = 13 확인 | Reflection | count = 13 | P1 |
| TC-BRD-028~062 | Repository 메서드 존재/시그니처 검증 (35개) | BoardRepository 메서드 존재 여부 및 파라미터/반환타입 시그니처 확인 | `method_exists` / `ReflectionMethod` | 각각 true / 시그니처 일치 | P1 |

### 3.5 BoardServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-BRD-063 | `testBuildCommentDataSetsRequiredFields` | 댓글 데이터 조립 시 필수 필드 설정 | `{bcc_content, member, st_code}` | st_code, ac_id, bcc_nick, cr_code, bcc_use 설정 | P1 |
| TC-BRD-064 | `testBuildCommentDataSetsBccParentFromBccNo` | bcc_no → bcc_parent 변환 확인 | `{bcc_no: 42}` | `bcc_parent == 42`, `bcc_no` 키 미존재 | P1 |
| TC-BRD-065 | `testBuildCommentDataSetsBccParentNullWhenNoBccNo` | bcc_no 미제공 시 bcc_parent = null | `{bcc_content}` (bcc_no 없음) | `bcc_parent == null` | P1 |
| TC-BRD-066 | `testBuildCommentDataSetsBccAnonymousNullWhenEmpty` | 빈 bcc_anonymous 시 null 설정 | `{bcc_anonymous: ''}` | `bcc_anonymous == null` | P2 |
| TC-BRD-067 | `testBuildCommentDataPreservesBccAnonymousWhenProvided` | bcc_anonymous 값 유지 | `{bcc_anonymous: 'Y'}` | `bcc_anonymous == 'Y'` | P2 |
| TC-BRD-068 | `testBuildCommentDataSetsRegistDateAndLastUpdateDate` | regist_date/last_update_date 자동 설정 확인 | 호출 전후 시각 비교 | 범위 내 | P1 |
| TC-BRD-069 | `testBuildCommentNotifyDataUsesCalleeTypeWhenMemberHasCeCode` | ce_code 존재 시 callee 타입 | `{ce_code: 'CE-001'}` | `tn_type == 'callee'`, `tn_register_id == 'CE-001'` | P1 |
| TC-BRD-070 | `testBuildCommentNotifyDataUsesCallerTypeWhenMemberHasNoCeCode` | ce_code null 시 caller 타입 | `{ce_code: null}` | `tn_type == 'caller'` | P1 |
| TC-BRD-071 | `testBuildCommentNotifyDataSetsTnNotifyTextNullWhenBlank` | 빈 tn_notify_text 시 null | `{tn_notify_text: ''}` | `tn_notify_text == null` | P2 |
| TC-BRD-072 | `testBuildCommentNotifyDataSetsStatusToStandby` | 상태 standby 설정 확인 | 정상 입력 | `tn_status == 'standby'` | P1 |
| TC-BRD-073 | `testResolveNotifierIdReturnsCeCodeWhenPresent` | ce_code 존재 시 ce_code 반환 | `{ce_code: 'CE-111'}` | `'CE-111'` | P1 |
| TC-BRD-074 | `testResolveNotifierIdReturnsCrCodeWhenCeCodeEmpty` | ce_code 빈값 시 cr_code 반환 | `{ce_code: '', cr_code: 'CR-222'}` | `'CR-222'` | P1 |
| TC-BRD-075 | `testResolveNotifierIdReturnsEmptyStringWhenInfoNull` | null 입력 시 빈 문자열 | `null` | `''` | P2 |
| TC-BRD-076 | `testResolveNotifierIdReturnsEmptyStringWhenInfoEmptyArray` | 빈 배열 시 빈 문자열 | `[]` | `''` | P2 |
| TC-BRD-077 | `testFormatInquiryListReturnsCorrectTotalWhenCountWithinLimit` | 문의 목록 total 값 확인 | 1건 rawResult, limit=10 | `total == 1`, `items count == 1` | P1 |
| TC-BRD-078 | `testFormatInquiryListTruncatesItemsToLimit` | limit 초과 시 잘림 확인 | 6건, limit=5 | `total == 6`, `items count == 5` | P1 |
| TC-BRD-079 | `testFormatInquiryListMapsStandbyStatusCorrectly` | standby 상태 매핑 (color=wait, class=re-waiting) | `qa_status: 'standby'` | `color == 'wait'`, `class == 're-waiting'` | P1 |
| TC-BRD-080 | `testFormatInquiryListMapsDoneStatusCorrectly` | done 상태 매핑 (color=com, class=re-fin) | `qa_status: 'done'` | `color == 'com'`, `class == 're-fin'` | P1 |
| TC-BRD-081 | `testFormatInquiryListReturnsEmptyItemsForEmptyInput` | 빈 입력 시 빈 결과 | `[]` | `items == []`, `total == 0` | P2 |
| TC-BRD-082 | `testBuildInquiryDataSetsRequiredFields` | 문의 데이터 필수 필드 설정 | 정상 입력 | st_code, ac_id, ac_no, ac_nick, qa_status=standby | P1 |
| TC-BRD-083 | `testBuildInquiryDataSetsCeCodeWhenQaTypeIsTtob` | qa_type='ttob' 시 ce_code 설정 | `{qa_type: 'ttob', ce_code: 'CE-020'}` | `ce_code == 'CE-020'` | P1 |
| TC-BRD-084 | `testBuildInquiryDataDoesNotSetCeCodeWhenQaTypeIsNotTtob` | qa_type!='ttob' 시 ce_code 미설정 | `{qa_type: 'general'}` | ce_code 키 미존재 | P1 |
| TC-BRD-085 | `testBuildInquiryDataJoinsUploadedCodesWithComma` | 업로드 코드 콤마 조인 확인 | `['CODE1', 'CODE2', 'CODE3']` | `uf_code == 'CODE1,CODE2,CODE3'`, `fa_use == 'Y'` | P1 |
| TC-BRD-086~089 | formatNoticeList 4건 | 공지 목록 total, 잘림, regist_ymd, 빈 입력 | 다양한 입력 | 각 조건별 기대값 | P1~P2 |
| TC-BRD-090 | `testBuildRecruitDataGeneratesCasCode` | cas_code 자동 생성 확인 | `{cas_name}` | `'CAS-'`로 시작 | P1 |
| TC-BRD-091 | `testBuildRecruitDataSetsFixedFields` | 채용 고정 필드 설정 확인 | 정상 입력 | cas_status=1, regist_type='caller' | P1 |
| TC-BRD-092 | `testBuildRecruitDataSetsImgCodeWhenProvided` | 이미지 코드 설정 확인 | `imgCode='IMG-CODE-001'` | `cas_img_code == 'IMG-CODE-001'` | P2 |
| TC-BRD-093 | `testBuildRecruitDataOmitsImgCodeWhenNull` | 이미지 코드 null 시 키 미존재 | `imgCode=null` | cas_img_code 키 미존재 | P2 |
| TC-BRD-094 | `testFormatPostingListMergesBestAndNormalPosts` | 베스트+일반 포스팅 병합 확인 | best 1건 + normal 1건 | `items count == 2`, `bestLength == 1` | P1 |

### 3.6 CommentControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-BRD-095 | `testControllerExtendsBaseApiController` | CommentController 상속 확인 | Reflection | `isSubclassOf(BaseApiController)` = true | P1 |
| TC-BRD-096 | `testGetItemCommentMethodExists` | getItemComment 존재 확인 | `method_exists` | true | P1 |
| TC-BRD-097 | `testUpdateCommentHelpMethodExists` | updateCommentHelp 존재 확인 | `method_exists` | true | P1 |

### 3.7 CommentFormatterTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-BRD-098 | `testFormatCommentListReturnsStructuredArray` | comments/hasNext 키 반환 구조 확인 | 1건 댓글 (child_exist=n) | `comments` 1건, `hasNext == false` | P1 |
| TC-BRD-099 | `testFormatCommentListHasNextTrueWhenRawCountExceedsLimit` | limit 초과 시 hasNext=true + limit 개수 잘림 | 6건, limit=5 | `hasNext == true`, `comments count == 5` | P1 |
| TC-BRD-100 | `testFormatCommentListReturnsEmptyArrayWhenNoRawComments` | 빈 입력 시 빈 comments | `[]` | `comments == []`, `hasNext == false` | P2 |
| TC-BRD-101 | `testFormatCommentListAttachesChildComments` | child_exist='y' 시 자식 댓글 매핑 | parent cm_no=10, child cm_parent=10 | `cm_reply` 배열 1건 | P1 |
| TC-BRD-102 | `testFormatCommentListSkipsChildQueryWhenNoChildExists` | child_exist='n' 시 자식 쿼리 미호출 | cm_child_exist='n' | `getItemChildComment()` never 호출 | P1 |
| TC-BRD-103 | `testFormatCommentListDoesNotAttachChildToWrongParent` | 부모-자식 불일치 시 미매핑 | child cm_parent=99, parent cm_no=10 | `cm_reply` 키 미존재 | P1 |
| TC-BRD-104 | `testFormatCommentListAppliesCustomFieldFormatter` | 커스텀 포맷터 콜백 적용 | `cm_content` → `'custom_' + value` | `cm_content == 'custom_original'` | P2 |
| TC-BRD-105 | `testFormatCommentListCustomFormatterReturningArraySetsMultipleFields` | 배열 반환 포맷터 시 다중 필드 설정 | 콜백 배열 반환 | `cm_content == 'modified'`, `extra_field == 'extra_value'` | P2 |
| TC-BRD-106 | `testFormatCommentListWithNullFormatterUsesDefaultConversion` | null 포맷터 시 기본 stripslashes 적용 | `"it\\'s a test"` | `stripslashes()` 적용 결과 | P2 |

---

## 4. Test Execution Results

| 테스트 파일 | 총 테스트 | PASS | FAIL | SKIP | 최종 실행일 |
|-----------|:---------:|:----:|:----:|:----:|:----------:|
| BoardApiTest | 5 | 5 | 0 | 0 | 2026-04-15 |
| CommentApiTest | 4 | 4 | 0 | 0 | 2026-04-15 |
| BoardControllerTest | 11 | 11 | 0 | 0 | 2026-04-15 |
| BoardModelTest | 42 | 42 | 0 | 0 | 2026-04-15 |
| BoardServiceTest | 32 | 32 | 0 | 0 | 2026-04-15 |
| CommentControllerTest | 3 | 3 | 0 | 0 | 2026-04-15 |
| CommentFormatterTest | 10 | 10 | 0 | 0 | 2026-04-15 |
| **합계** | **107** | **107** | **0** | **0** | **2026-04-15** |

---

## 5. Traceability Matrix

| SRS 요구사항 ID | 요구사항 명 | 테스트 케이스 ID | 커버리지 |
|----------------|-----------|----------------|:--------:|
| FR-001 | 문의 조회 (Inquiry Retrieve) | TC-BRD-001, TC-BRD-077~081 | 커버 |
| FR-002 | 문의 등록 (Inquiry Insert) | TC-BRD-003, TC-BRD-082~085 | 커버 |
| FR-003 | 공지 조회 (Notice Retrieve) | TC-BRD-002, TC-BRD-086~089 | 커버 |
| FR-004 | 컬럼 댓글 등록 (Column Comment Insert) | TC-BRD-004, TC-BRD-063~068 | 커버 |
| FR-005 | 컬럼 댓글 삭제 (Column Comment Delete) | TC-BRD-012 (메서드 존재), TC-BRD-028~ (Repository 메서드) | 부분 커버 |
| FR-006 | 댓글 신고 (Comment Report) | TC-BRD-013 (메서드 존재) | 부분 커버 |
| FR-007 | 댓글 신고 알림 (Comment Report Notify) | TC-BRD-014, TC-BRD-069~072 | 커버 |
| FR-008 | 채용 신청 (Recruit Insert) | TC-BRD-018, TC-BRD-090~093 | 커버 |
| FR-009 | 포스팅 목록 조회 (Posting Retrieve) | TC-BRD-019, TC-BRD-094 | 커버 |
| FR-010 | 포스팅 좋아요 토글 (Posting Like Toggle) | TC-BRD-005, TC-BRD-020 | 부분 커버 |
| FR-011 | 아이템 댓글 조회 (Item Comment Retrieve) | TC-BRD-006~008, TC-BRD-098~106 | 커버 |
| FR-012 | 댓글 도움 토글 (Comment Help Toggle) | TC-BRD-009, TC-BRD-097 | 부분 커버 |
| NFR-001 | XSS 방어 | TC-BRD-106 (stripslashes 기본 변환) | 부분 커버 |
| NFR-005 | 페이지네이션 | TC-BRD-078, TC-BRD-099 (hasNext/limit 잘림) | 커버 |
| NFR-007 | 소유권 검증 | TC-BRD-004 (미인증 에러 확인) | 부분 커버 |
| NFR-010 | API 응답 camelCase | (전용 테스트 미구현) | 미커버 |

---

## 6. Defects & Issues

| # | 결함 ID | 심각도 | 설명 | 발견일 | 상태 |
|---|--------|:------:|------|-------|:----:|
| 1 | BRD-DEF-001 | Medium | FR-005(컬럼 댓글 삭제) 소유권 검증 로직의 동작 테스트 미구현. 소유자/비소유자 분기 검증 Feature 테스트 필요 | 2026-04-16 | Open |
| 2 | BRD-DEF-002 | Medium | FR-006(댓글 신고) enum 화이트리스트 검증 로직 테스트 미구현. 유효/유효하지 않은 report_type 분기 테스트 필요 | 2026-04-16 | Open |
| 3 | BRD-DEF-003 | Low | FR-010(좋아요 토글) add/del 동작 분기 테스트 미구현. Feature 테스트에서 인증 + 좋아요 add/del 확인 필요 | 2026-04-16 | Open |
| 4 | BRD-DEF-004 | Low | NFR-010(camelCase 응답) 전용 검증 테스트 미구현 | 2026-04-16 | Open |

---

## 변경 로그

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|-------|
| 2026-04-16 | 1.0.0 | 초기 작성. IEEE 829-2008 기반 STD 문서 생성. 테스트 파일 7개, 테스트 케이스 107개 기록 | jypark |
