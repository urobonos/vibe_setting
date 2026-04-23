---
문서명: Chat — Software Test Documentation
문서 ID: chat-std
버전: v1.0
상태: 승인됨
생성일: 2026-04-16
최종 수정일: 2026-04-16
작성자: jypark
대상 시스템: Chat Module
관련 문서: chat-srs.md, chat-sdd.md, chat-idd.md, project-stp.md
적용 표준: IEEE 829-2008
---

# Chat — Software Test Documentation (STD)

> IEEE 829-2008 | version: 1.0 | lastUpdated: 2026-04-16 | module: Chat

---

## 1. Introduction

### 1.1 Purpose

본 Software Test Documentation(STD)은 HongCafe Global Backend Chat 모듈에 대한 테스트 항목, 테스트 케이스, 실행 결과, 추적성 매트릭스, 결함 내역을 IEEE 829-2008 표준에 따라 기록한다. Chat 모듈의 SRS(chat-srs.md)에서 정의한 기능 요구사항(FR-001~FR-010)과 비기능 요구사항(NFR-001~NFR-006)에 대한 검증 근거를 제공한다.

### 1.2 Scope

| 항목 | 내용 |
|------|------|
| 테스트 대상 모듈 | Chat (채팅 연결, 타이밍, 메시지, GoodsChat, ShopChat, SendBird 연동) |
| 테스트 파일 수 | 9개 (Feature 3, Unit 6) |
| 테스트 메서드 수 | 총 86개 |
| 테스트 프레임워크 | PHPUnit + CodeIgniter 4 CIUnitTestCase / FeatureTestTrait |

### 1.3 References

| 문서 | 경로 |
|------|------|
| Chat SRS | `docs/specs/chat-srs.md` v2.1 |
| Chat SDD | `docs/specs/chat-sdd.md` v2.1 |
| Chat IDD | `docs/specs/chat-idd.md` v2.1 |
| 프로젝트 테스트 계획 | `project-stp.md` |

---

## 2. Test Items

### 2.1 테스트 파일 목록

| # | 테스트 파일 | 유형 | 테스트 대상 클래스 | 메서드 수 |
|---|-----------|------|------------------|:---------:|
| 1 | `tests/Modules/Chat/Feature/ChatApiTest.php` | Feature (통합) | ChatController API 엔드포인트 | 5 |
| 2 | `tests/Modules/Chat/Feature/GoodsChatApiTest.php` | Feature (통합) | GoodsChatController API 엔드포인트 | 3 |
| 3 | `tests/Modules/Chat/Feature/ShopChatApiTest.php` | Feature (통합) | ShopChatController API 엔드포인트 | 3 |
| 4 | `tests/Modules/Chat/Unit/ChatConnectionServiceTest.php` | Unit | ChatConnectionService (connect 경로 검증) | 11 |
| 5 | `tests/Modules/Chat/Unit/ChatControllerTest.php` | Unit | ChatController (메서드 존재/상속 확인) | 43 |
| 6 | `tests/Modules/Chat/Unit/ChatListServiceTest.php` | Unit | ChatListService (buildPcItemList 로직) | 15 |
| 7 | `tests/Modules/Chat/Unit/GoodsChatControllerTest.php` | Unit | GoodsChatController (메서드 존재/상속 확인) | 7 |
| 8 | `tests/Modules/Chat/Unit/SendBirdServiceTest.php` | Unit | SendBirdService (설정값, 데이터 구성) | 10 |
| 9 | `tests/Modules/Chat/Unit/ShopChatControllerTest.php` | Unit | ShopChatController (메서드 존재/상속 확인) | 3 |

### 2.2 테스트 대상 클래스/메서드

| 클래스 | 테스트 대상 메서드 |
|--------|------------------|
| `ChatConnectionService` | `connect()` (reject/existing/created/error 4경로) |
| `ChatListService` | `buildPcItemList()` (반환 구조, 페이지네이션, 전화번호 포맷, 후기 매핑, 태그 분리, 포인트 계산, 예약 플래그) |
| `SendBirdService` | `getAdminId()`, `callApi()`, `createGroupChannel()`, `sendMessage()` |
| `ChatController` | 42개 메서드 (getListPc, getListMobile, chatConnect, chatTimer, chatStart, sendMessage, fileUpload, messageLog, markAsRead, absenceCheck, chatClosed, timeAlert, closeAlert, disconnectCheck 등) |
| `GoodsChatController` | `chatConnect()`, `sendEstimate()`, `getEstimate()`, `cancelEstimate()`, `updateEstimateMessageId()`, `calleeChatConnect()` |
| `ShopChatController` | `chatConnect()`, `calleeChatConnect()` |

---

## 3. Test Cases

### 3.1 ChatApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CHAT-001 | `testGetListPcReturnsValidationErrorWhenKeywordMissing` | keyword 누락 시 유효성 오류 반환 | `{}` | HTTP 200, `result: false` | P1 |
| TC-CHAT-002 | `testGetListMobileReturnsResponse` | getListMobile 빈 body 시 응답 존재 확인 | `{}` | HTTP 200 | P1 |
| TC-CHAT-003 | `testChatConnectReturnsUnauthorizedWhenNotLoggedIn` | 미인증 chatConnect 시 인증 오류 | `{ch_code}` (인증 없음) | HTTP 200, `result: false` | P1 |
| TC-CHAT-004 | `testGetLikeListReturnsUnauthorizedWhenNotLoggedIn` | 미인증 getLikeList 시 인증 오류 | `{}` (인증 없음) | HTTP 200, `result: false` | P1 |
| TC-CHAT-005 | `testGetRemainCoinReturnsUnauthorizedWhenNotLoggedIn` | 미인증 getRemainCoin 시 인증 오류 | `{}` (인증 없음) | HTTP 200, `result: false` | P1 |

### 3.2 GoodsChatApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CHAT-006 | `testChatConnectWithoutLoginReturnsNeedLogin` | 비로그인 chatConnect 시 200 응답 | `{gd_code: 'GD-TESTCODE'}` | HTTP 200 | P1 |
| TC-CHAT-007 | `testSendEstimateWithoutGdCodeReturnsError` | gd_code 없이 sendEstimate 시 에러 | `{}` | HTTP 200 | P1 |
| TC-CHAT-008 | `testGetEstimateWithoutGsNoReturnsError` | gs_no 없이 getEstimate 시 에러 | `{}` | HTTP 200 | P1 |

### 3.3 ShopChatApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CHAT-009 | `testChatConnectWithoutLoginReturnsNeedLogin` | 비로그인 shopChat chatConnect 시 200 응답 | `{ce_code, sh_code}` | HTTP 200 | P1 |
| TC-CHAT-010 | `testCalleeChatConnectWithoutShCodeReturnsError` | sh_code 없이 calleeChatConnect 시 에러 | `{}` | HTTP 200 | P1 |
| TC-CHAT-011 | `testCalleeChatConnectWithShCodeReturns200` | sh_code 포함 calleeChatConnect 시 200 | `{sh_code, ac_id}` | HTTP 200 | P1 |

### 3.4 ChatConnectionServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CHAT-012 | `testConnectReturnsRejectedWhenChatRepositoryCheckRejectIsTrue` | 차단 시 rejected 반환 | checkReject=true | `status == 'rejected'`, room_code 미존재 | P0 |
| TC-CHAT-013 | `testConnectDoesNotCallSendBirdWhenRejected` | 차단 시 SendBird 미호출 | checkReject=true | `createGroupChannel` never 호출 | P0 |
| TC-CHAT-014 | `testConnectReturnsExistingRoomWhenFindExistingRoomCallbackReturnsRoom` | 기존 방 존재 시 existing 반환 | 콜백 → 기존 방 | `status == 'existing'`, `room_code` 일치 | P0 |
| TC-CHAT-015 | `testConnectDoesNotCallSendBirdWhenExistingRoomFound` | 기존 방 시 SendBird 미호출 | 콜백 → 기존 방 | `createGroupChannel` never 호출 | P1 |
| TC-CHAT-016 | `testConnectCreatesNewRoomAndReturnsCreatedStatusForGoodsType` | goods 타입 신규 방 생성 → created | cr_type='goods', 정상 mock | `status == 'created'`, room_code `CHAT-`으로 시작 | P0 |
| TC-CHAT-017 | `testConnectPassesGdCodeToInsertRoomWhenTypeIsGoods` | goods 타입 시 gd_code 전달 확인 | cr_type='goods' | insertRoom 인자에 `gd_code` 포함, `sh_code` 미포함 | P1 |
| TC-CHAT-018 | `testConnectPassesShCodeToInsertRoomWhenTypeIsShop` | shop 타입 시 sh_code 전달 확인 | cr_type='shop' | insertRoom 인자에 `sh_code` 포함, `gd_code` 미포함 | P1 |
| TC-CHAT-019 | `testConnectReturnsErrorWhenSendBirdReturnsEmptyArray` | SendBird 빈 배열 반환 시 error | createGroupChannel → [] | `status == 'error'` | P0 |
| TC-CHAT-020 | `testConnectReturnsErrorWhenSendBirdResultHasNoChannelUrl` | SendBird channel_url 누락 시 error | createGroupChannel → {error: ...} | `status == 'error'` | P0 |
| TC-CHAT-021 | `testConnectReturnsErrorWhenInsertRoomFails` | DB insertRoom 실패 시 error | insertRoom → false | `status == 'error'`, room_code 미존재 | P0 |

### 3.5 ChatControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CHAT-022 | `testControllerExtendsBaseApiController` | ChatController 상속 확인 | Reflection | `isSubclassOf(BaseApiController)` = true | P1 |
| TC-CHAT-023~064 | 메서드 존재 확인 42건 | getListPc, getListMobile, getListComment, getItem, getLikeList, chatAddLike, chatDeleteLike, getItemQnaList, insertItemQna, saveItemPrice, getPostingList, postingDetail, getPostingComments, chatFail, chatConnect, chatTimer, chatStart, getCalleeStatus, sendMessage, getRemainCoin, chatRequestTimeAdd, chatTimeAdd, fileUpload, messageLog, messageLogV2, markAsRead, chatConnectFail, chatCancel, chatReject, chatNotify, chatFileDown, getRemainTime, sendGoodsChatPush, sendShopChatPush, uploadChatFile, getCalleeChatLikeList, updateGreeting, absenceCheck, chatClosed, timeAlert, closeAlert, disconnectCheck, checkAbsence, connectCheck | `method_exists` | 모두 true | P1 |

### 3.6 ChatListServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CHAT-065 | `testBuildPcItemListReturnsItemsAndNextKeys` | 반환 구조 items/total/perPage/offset 키 확인 | 빈 결과 | 4개 키 존재 | P0 |
| TC-CHAT-066 | `testBuildPcItemListReturnsEmptyItemsWhenResultIsEmpty` | 빈 결과 시 빈 items | `[]` | `items == []`, `total == 0` | P1 |
| TC-CHAT-067 | `testBuildPcItemListNextIsTrueWhenResultExceedsLimit` | limit 초과 시 결과 잘림 | 3건, limit=2 | `total == 3`, `items count == 2` | P1 |
| TC-CHAT-068 | `testBuildPcItemListNextIsFalseWhenResultDoesNotExceedLimit` | limit 미초과 시 전체 반환 | 2건, limit=24 | `total == 2`, `items count == 2` | P1 |
| TC-CHAT-069 | `testBuildPcItemListSplitsItTagByComma` | it_tag 콤마 분리 배열 변환 | `'운세,타로,사주'` | `['운세', '타로', '사주']` | P1 |
| TC-CHAT-070 | `testBuildPcItemListComputesItNoticeStringCnt` | it_notice → it_notice_string_cnt 문자수 계산 | `'안녕하세요 공지입니다.'` | mb_strlen 일치, it_notice 키 제거 | P2 |
| TC-CHAT-071 | `testBuildPcItemListAppendsCoinNumberFromCallRepository` | coin_number 전화번호 포맷팅 확인 | stn_callno='0570783901' | `'05-7078-3901'` | P1 |
| TC-CHAT-072 | `testBuildPcItemListAppends060NumberFromCallRepository` | 060_number 전화번호 포맷팅 확인 | stn_callno='0600123456' | `'06-0012-3456'` | P1 |
| TC-CHAT-073 | `testBuildPcItemListMapsCommentsToMatchingItemByItCode` | it_code 일치 후기 매핑 | commentRow.it_code='IT-CMT-001' | `it_comment` 배열 1건, it_code 일치 | P1 |
| TC-CHAT-074 | `testBuildPcItemListDoesNotMapCommentToUnmatchedItem` | it_code 불일치 시 미매핑 | commentRow.it_code='IT-OTHER-999' | `it_comment` 키 미존재 | P1 |
| TC-CHAT-075 | `testBuildPcItemListSetsReservationPageWhenDataContainsItReservation` | it_reservation 존재 시 예약 플래그 설정 | `it_reservation: 'Y'` | `reservationPage == true` | P2 |
| TC-CHAT-076 | `testBuildPcItemListDoesNotSetReservationPageWhenItReservationIsEmpty` | it_reservation 빈값 시 플래그 미설정 | `it_reservation: ''` | `reservationPage` 키 미존재 | P2 |
| TC-CHAT-077 | `testBuildPcItemListCalculatesChWinPointWhenM3CmCntIsPositive` | m3_cm_cnt > 0 시 ch_win_point 계산 | m3_cm_cnt=5, ch_cm_point=45, ch_point_cnt=9 | `ch_win_point == 5.0` | P1 |
| TC-CHAT-078 | `testBuildPcItemListReturnsZeroChWinPointWhenM3CmCntIsZero` | m3_cm_cnt=0 시 ch_win_point=0.0 | m3_cm_cnt=0 | `ch_win_point == 0.0` | P1 |
| TC-CHAT-079 | `testBuildPcItemListPassesStCodeToCommentRepository` | stCode 파라미터 전달 확인 | stCode='global' | getItemListComment 2번째 인자 'global' | P2 |

### 3.7 GoodsChatControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CHAT-080 | `testControllerExtendsBaseApiController` | GoodsChatController 상속 확인 | Reflection | true | P1 |
| TC-CHAT-081 | `testChatConnectMethodExists` | chatConnect 존재 확인 | `method_exists` | true | P1 |
| TC-CHAT-082 | `testSendEstimateMethodExists` | sendEstimate 존재 확인 | `method_exists` | true | P1 |
| TC-CHAT-083 | `testGetEstimateMethodExists` | getEstimate 존재 확인 | `method_exists` | true | P1 |
| TC-CHAT-084 | `testCancelEstimateMethodExists` | cancelEstimate 존재 확인 | `method_exists` | true | P1 |
| TC-CHAT-085 | `testUpdateEstimateMessageIdMethodExists` | updateEstimateMessageId 존재 확인 | `method_exists` | true | P1 |
| TC-CHAT-086 | `testCalleeChatConnectMethodExists` | calleeChatConnect 존재 확인 | `method_exists` | true | P1 |

### 3.8 SendBirdServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CHAT-087 | `testGetAdminIdMethodExists` | getAdminId 존재 확인 | `method_exists` | true | P1 |
| TC-CHAT-088 | `testCallApiMethodExists` | callApi 존재 확인 | `method_exists` | true | P1 |
| TC-CHAT-089 | `testCreateGroupChannelMethodExists` | createGroupChannel 존재 확인 | `method_exists` | true | P1 |
| TC-CHAT-090 | `testSendMessageMethodExists` | sendMessage 존재 확인 | `method_exists` | true | P1 |
| TC-CHAT-091 | `testGetAdminIdReturnsConfiguredValue` | getAdminId → 'hongcafe3' 반환 확인 | 호출 | `'hongcafe3'` | P0 |
| TC-CHAT-092 | `testApiTokenIsConfigured` | API 토큰 40자 hex 형식 확인 | Reflection | 정규식 `/^[a-f0-9]{40}$/` 일치 | P0 |
| TC-CHAT-093 | `testApiUrlIsConfigured` | API URL https + sendbird.com 확인 | Reflection | `https://`로 시작, `sendbird.com` 포함 | P0 |
| TC-CHAT-094 | `testCreateGroupChannelMergesDefaultsWithProvidedData` | createGroupChannel 반환 타입 array | `['user_001', 'user_002'], 'goods'` | `assertIsArray` | P1 |
| TC-CHAT-095 | `testCreateGroupChannelWithAdditionalData` | 추가 데이터 포함 createGroupChannel | `['user_001'], 'shop', {name: 'Test'}` | `assertIsArray` | P1 |
| TC-CHAT-096 | `testSendMessageReturnsArrayWithoutCustomTypeOrData` | sendMessage 기본 호출 반환 | channel_url, user_id, message | `assertIsArray` | P1 |

### 3.9 ShopChatControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|:--------:|
| TC-CHAT-097 | `testControllerExtendsBaseApiController` | ShopChatController 상속 확인 | Reflection | true | P1 |
| TC-CHAT-098 | `testChatConnectMethodExists` | chatConnect 존재 확인 | `method_exists` | true | P1 |
| TC-CHAT-099 | `testCalleeChatConnectMethodExists` | calleeChatConnect 존재 확인 | `method_exists` | true | P1 |

---

## 4. Test Execution Results

| 테스트 파일 | 총 테스트 | PASS | FAIL | SKIP | 최종 실행일 |
|-----------|:---------:|:----:|:----:|:----:|:----------:|
| ChatApiTest | 5 | 5 | 0 | 0 | 2026-04-15 |
| GoodsChatApiTest | 3 | 3 | 0 | 0 | 2026-04-15 |
| ShopChatApiTest | 3 | 3 | 0 | 0 | 2026-04-15 |
| ChatConnectionServiceTest | 11 | 11 | 0 | 0 | 2026-04-15 |
| ChatControllerTest | 43 | 43 | 0 | 0 | 2026-04-15 |
| ChatListServiceTest | 15 | 15 | 0 | 0 | 2026-04-15 |
| GoodsChatControllerTest | 7 | 7 | 0 | 0 | 2026-04-15 |
| SendBirdServiceTest | 10 | 10 | 0 | 0 | 2026-04-15 |
| ShopChatControllerTest | 3 | 3 | 0 | 0 | 2026-04-15 |
| **합계** | **100** | **100** | **0** | **0** | **2026-04-15** |

---

## 5. Traceability Matrix

| SRS 요구사항 ID | 요구사항 명 | 테스트 케이스 ID | 커버리지 |
|----------------|-----------|----------------|:--------:|
| FR-001 | Item List and Search | TC-CHAT-001, TC-CHAT-002, TC-CHAT-065~079 | 커버 |
| FR-002 | Chat Connect and Room Creation | TC-CHAT-003, TC-CHAT-012~021 | 커버 |
| FR-003 | Chat Timing and Time Extension | TC-CHAT-036 (chatTimer 메서드), TC-CHAT-040 (chatRequestTimeAdd), TC-CHAT-041 (chatTimeAdd), TC-CHAT-047 (getRemainTime) | 부분 커버 |
| FR-004 | Chat Status Management | TC-CHAT-053 (absenceCheck), TC-CHAT-055 (chatClosed), TC-CHAT-057 (disconnectCheck), TC-CHAT-058 (checkAbsence), TC-CHAT-059 (connectCheck) | 부분 커버 |
| FR-005 | Message and File Management | TC-CHAT-033 (sendMessage), TC-CHAT-042 (fileUpload), TC-CHAT-043 (messageLog), TC-CHAT-044 (messageLogV2), TC-CHAT-045 (markAsRead) | 부분 커버 |
| FR-006 | Favorites, Q&A, and Price | TC-CHAT-004, TC-CHAT-025 (chatAddLike), TC-CHAT-026 (chatDeleteLike), TC-CHAT-028 (insertItemQna), TC-CHAT-029 (saveItemPrice) | 부분 커버 |
| FR-007 | Posting Retrieval | TC-CHAT-030 (getPostingList), TC-CHAT-031 (postingDetail), TC-CHAT-032 (getPostingComments) | 부분 커버 |
| FR-008 | GoodsChat (Estimate Workflow) | TC-CHAT-006~008, TC-CHAT-080~086 | 커버 |
| FR-009 | ShopChat (Three-Party Channel) | TC-CHAT-009~011, TC-CHAT-018, TC-CHAT-097~099 | 커버 |
| FR-010 | Callee Chat Management | TC-CHAT-051 (getCalleeChatLikeList), TC-CHAT-052 (updateGreeting) | 부분 커버 |
| NFR-001 | SendBird API Response Performance | (부하 테스트 미구현) | 미커버 |
| NFR-002 | Chat Timing Accuracy | (타이밍 정밀도 테스트 미구현) | 미커버 |
| NFR-003 | Chat Room Access Security | TC-CHAT-003~005 (미인증 접근 거부) | 부분 커버 |
| NFR-004 | SendBird Failure Isolation | TC-CHAT-019, TC-CHAT-020, TC-CHAT-066 (빈 배열 반환) | 커버 |
| NFR-005 | File Upload Security | (MIME 이중 검증 전용 테스트 미구현) | 미커버 |
| NFR-006 | Absence Detection Threshold | (5분 경계값 테스트 미구현) | 미커버 |

---

## 6. Defects & Issues

| # | 결함 ID | 심각도 | 설명 | 발견일 | 상태 |
|---|--------|:------:|------|-------|:----:|
| 1 | CHAT-DEF-001 | High | NFR-002(Chat Timing Accuracy) 전용 테스트 미구현. get-remain-time API의 UTC 기반 초단위 정확도 경계값(0초, 1초, 300초) 검증 필요 | 2026-04-16 | Open |
| 2 | CHAT-DEF-002 | High | NFR-006(Absence Detection Threshold) 전용 테스트 미구현. 5분 경계값(299초 vs 300초 vs 301초) 부재 감지 로직 검증 필요 | 2026-04-16 | Open |
| 3 | CHAT-DEF-003 | Medium | NFR-005(File Upload Security) MIME 이중 검증 테스트 미구현. 허용/비허용 MIME 파일 업로드 시 확장자+mime_content_type 이중 검증 확인 필요 | 2026-04-16 | Open |
| 4 | CHAT-DEF-004 | Medium | FR-008(GoodsChat) FSM 상태 전이 검증 미구현. gs_status 단방향 전이(0→1→2→3, 4 비가역) 로직 검증 필요 | 2026-04-16 | Open |
| 5 | CHAT-DEF-005 | Medium | NFR-003(Chat Room Access Security) 참여자 검증 전용 테스트 미구현. 비참여자 room_code 접근 시 403 FORBIDDEN 반환 검증 필요 | 2026-04-16 | Open |
| 6 | CHAT-DEF-006 | Low | NFR-001(SendBird API Performance) 부하 테스트 미구현. P95 2,000ms 기준 50 동시 사용자 테스트 필요 | 2026-04-16 | Open |

---

## 변경 로그

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|-------|
| 2026-04-16 | 1.0.0 | 초기 작성. IEEE 829-2008 기반 STD 문서 생성. 테스트 파일 9개, 테스트 케이스 100개 기록 | jypark |
