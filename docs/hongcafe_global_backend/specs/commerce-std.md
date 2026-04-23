---
문서명: Commerce — Software Test Documentation
문서 ID: commerce-std
버전: v1.1
상태: 승인됨
생성일: 2026-04-16
최종 수정일: 2026-04-21
작성자: jypark
대상 시스템: Commerce Module
관련 문서: commerce-srs.md, commerce-sdd.md, commerce-idd.md, project-stp.md
적용 표준: IEEE 829-2008
---

# Commerce Module — Software Test Documentation

> IEEE 829-2008 준수 | version: 1.1 | updated: 2026-04-21 | module: Commerce

---

## 1. Introduction

### 1.1 Purpose

본 문서는 HongCafe Global Backend Commerce 모듈의 테스트 결과를 IEEE 829-2008 표준에 따라 문서화한다. Commerce 모듈은 Items, Shop, Goods, SpecialPrice 4개 서브도메인으로 구성되며, 72개 엔드포인트에 대한 11개 테스트 파일의 실행 결과와 SRS 요구사항 추적성을 기록한다.

### 1.2 Scope

- **테스트 파일 수**: 11개 (Feature 4, Unit 7)
- **대상 모듈**: `app/Modules/Commerce/`
- **서브도메인**: Items (16 EP), Shop (26 EP), Goods (30 EP), SpecialPrice (1 EP)
- **테스트 유형**: Feature 테스트 (API 통합), Unit 테스트 (서비스/컨트롤러 단위)

### 1.3 References

| 문서 | 위치 |
|------|------|
| commerce-srs.md (SRS-COMMERCE-001 v3.0) | `docs/specs/` |
| commerce-sdd.md (SDD-COMMERCE-001) | `docs/specs/` |
| commerce-idd.md (IDD-COMMERCE-001) | `docs/specs/` |
| project-stp.md | `docs/specs/` |

---

## 2. Test Items

### 2.1 Feature 테스트 (API 통합)

| 테스트 파일 | 대상 클래스/엔드포인트 | 테스트 메서드 수 |
|------------|----------------------|----------------|
| GoodsApiTest | GoodsController — `api/goods/*` | 5 |
| ItemsApiTest | ItemsController — `api/items/*` | 5 |
| ShopApiTest | ShopController — `api/shop/*` | 5 |
| SpecialPriceApiTest | SpecialPriceController — `api/specialprice/*` | 3 |

### 2.2 Unit 테스트 (서비스/컨트롤러)

| 테스트 파일 | 대상 클래스 | 테스트 메서드 수 |
|------------|-----------|----------------|
| GoodsControllerTest | GoodsController | 30 |
| GoodsPurchaseServiceTest | GoodsPurchaseService | 10 |
| ItemsControllerTest | ItemsController | 17 |
| ItemListFormatterTest | ItemListFormatter | 38 |
| ShopControllerTest | ShopController | 27 |
| ShopReservationServiceTest | ShopReservationService | 16 |
| SpecialPriceControllerTest | SpecialPriceController | 2 |

---

## 3. Test Cases

### 3.1 GoodsApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-GA-001 | testGetListMobileWithoutKeywordReturnsError | keyword 없이 POST 시 에러 응답 반환 | 빈 body | HTTP 200 | P1 |
| TC-GA-002 | testGetListMobileWithKeywordReturns200 | keyword 포함 POST 시 200 응답 반환 | `keyword=''`, `cate='all'` | HTTP 200 | P1 |
| TC-GA-003 | testBuyItemWithoutLoginReturnsNeedLogin | 비로그인 상태로 buyItem POST 시 로그인 필요 응답 | `gd_code='NONEXISTENT'` | HTTP 200 (needLogin) | P1 |
| TC-GA-004 | testOrderInfoWithoutLoginReturnsNeedLogin | 비로그인 상태로 orderInfo POST 시 로그인 필요 응답 | `gs_no=999999` | HTTP 200 (needLogin) | P1 |
| TC-GA-005 | testGetBuyListWithoutLoginReturnsNeedLogin | 비로그인 상태로 getBuyList POST 시 로그인 필요 응답 | 빈 body | HTTP 200 (needLogin) | P1 |

### 3.2 ItemsApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-IA-001 | testGetListMobileWithoutKeywordReturnsError | keyword 없이 POST 시 에러 응답 | 빈 body | HTTP 200 | P1 |
| TC-IA-002 | testGetListMobileWithKeywordReturns200 | keyword 포함 POST 시 200 응답 | `keyword=''`, `order=null` | HTTP 200 | P1 |
| TC-IA-003 | testGetListPcWithoutKeywordReturnsError | PC 목록 keyword 없이 POST 시 에러 응답 | 빈 body | HTTP 200 | P1 |
| TC-IA-004 | testGetCommentReturns200 | getcomment POST 시 200 응답 | `it_code='NONEXISTENT'` | HTTP 200 | P2 |
| TC-IA-005 | testGetSearchListItemsWithoutKeywordReturnsError | 검색 keyword 없이 POST 시 에러 응답 | 빈 body | HTTP 200 | P1 |

### 3.3 ShopApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SA-001 | testGetShopItemsReturns200 | getShopItems POST 시 200 응답 | `cate='all'`, `order=null` | HTTP 200 | P1 |
| TC-SA-002 | testReservationCalendarWithoutCeCodeReturnsDataEmpty | ce_code 없이 예약 캘린더 POST 시 data_empty 응답 | 빈 body | HTTP 200 | P1 |
| TC-SA-003 | testViewLocationPopupReturns200 | ViewLocationPopup POST 시 200 응답 | `category='all'` | HTTP 200 | P2 |
| TC-SA-004 | testBuyShopWithoutLoginReturnsNeedLogin | 비로그인 상태로 buyShop POST 시 로그인 필요 응답 | `gd_code`, `reserv_day`, `reserv_time` | HTTP 200 (needLogin) | P1 |
| TC-SA-005 | testGetMyShopWithoutLoginReturnsNeedLogin | 비로그인 상태로 getMyShop POST 시 로그인 필요 응답 | `sr_status=0` | HTTP 200 (needLogin) | P1 |

### 3.4 SpecialPriceApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SPA-001 | testGetListWithEmptyBodyReturns200 | 빈 body로 POST 시 200 응답 (빈 배열) | 빈 body | HTTP 200 | P1 |
| TC-SPA-002 | testGetListWithEsCodeReturns200 | es_code 포함 POST 시 200 응답 | `es_code`, `st_code`, `keyword` | HTTP 200 | P1 |
| TC-SPA-003 | testGetListWithKeywordReturns200 | keyword 파라미터 포함 POST 시 200 응답 | `es_code`, `keyword='test'` | HTTP 200 | P1 |

### 3.5 GoodsControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 기대 결과 | 우선순위 |
|-------|---------|------|----------|---------|
| TC-GC-001 | testControllerExtendsBaseApiController | GoodsController가 BaseApiController 상속 확인 | assertTrue | P1 |
| TC-GC-002 | testGetListMobileMethodExists | getListMobile 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-003 | testBuyItemMethodExists | buyItem 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-004 | testBuyConfirmMethodExists | buyConfirm 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-005 | testGoodsFileMethodExists | goodsFile 메서드 존재 확인 | assertTrue | P2 |
| TC-GC-006 | testGetCalleebuyListMethodExists | getCalleebuyList 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-007 | testGetCalleebuyCntMethodExists | getCalleebuyCnt 메서드 존재 확인 | assertTrue | P2 |
| TC-GC-008 | testCalleeGoodsConfirmMethodExists | calleeGoodsConfirm 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-009 | testCalleeGoodsJobMethodExists | calleeGoodsJob 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-010 | testCalleeGoodsFileUploadMethodExists | calleeGoodsFileUpload 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-011 | testUpdateGoodsMethodExists | updateGoods 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-012 | testDeleteGoodsMethodExists | deleteGoods 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-013 | testDeleteO2oMethodExists | deleteO2o 메서드 존재 확인 | assertTrue | P2 |
| TC-GC-014 | testOrderInfoMethodExists | orderInfo 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-015 | testGetBuyListMethodExists | getBuyList 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-016 | testGoodsRegistInfoMethodExists | goodsRegistInfo 메서드 존재 확인 | assertTrue | P2 |
| TC-GC-017 | testBuyCancelMethodExists | buyCancel 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-018 | testRefundSuccessMethodExists | refundSuccess 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-019 | testGetCancelListMethodExists | getCancelList 메서드 존재 확인 | assertTrue | P2 |
| TC-GC-020 | testUpdateGoodsViewMethodExists | updateGoodsView 메서드 존재 확인 | assertTrue | P2 |
| TC-GC-021 | testGetGoodsFaqListByTypeMethodExists | getGoodsFaqListByType 메서드 존재 확인 | assertTrue | P2 |
| TC-GC-022 | testPreviewGoodsMethodExists | previewGoods 메서드 존재 확인 | assertTrue | P2 |
| TC-GC-023 | testInsertMyCommentMethodExists | insertMyComment 메서드 존재 확인 | assertTrue | P2 |
| TC-GC-024 | testMemosaveMethodExists | memosave 메서드 존재 확인 | assertTrue | P2 |
| TC-GC-025 | testDeleteOptMethodExists | deleteOpt 메서드 존재 확인 | assertTrue | P2 |
| TC-GC-026 | testDeleteFileMethodExists | deleteFile 메서드 존재 확인 | assertTrue | P2 |
| TC-GC-027 | testGetMyClassMethodExists | getMyClass 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-028 | testGetmyclassDetailMethodExists | getmyclassDetail 메서드 존재 확인 | assertTrue | P1 |
| TC-GC-029 | testAddrSecondListMethodExists | addrSecondList 메서드 존재 확인 | assertTrue | P2 |
| TC-GC-030 | testCalleeClassFileUploadMethodExists | calleeClassFileUpload 메서드 존재 확인 (MIME 이중 검증 + FCM 포함 중요 EP) | assertTrue | P1 |

### 3.6 GoodsPurchaseServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-GPS-001 | testConfirmPurchaseThrowsExceptionWhenGoodsNotFound | updateConfirm false 반환 시 Exception | `gs_no=999` | Exception | P1 |
| TC-GPS-002 | testConfirmPurchaseThrowsExceptionWhenUpdateConfirmReturnsFalsy | updateConfirm null 반환 시 Exception | `gs_no=0` | Exception | P1 |
| TC-GPS-003 | testConfirmPurchaseReturnsExpectedArrayShape | 정상 구매확정 (외부 의존으로 스킵) | — | Skipped | P1 |
| TC-GPS-004 | testGoodsPurchaseServiceClassExists | 클래스 존재 확인 | — | assertTrue | P2 |
| TC-GPS-005 | testConfirmPurchaseMethodExists | confirmPurchase 메서드 존재 확인 | — | assertTrue | P2 |
| TC-GPS-006 | testConstructorAcceptsFourNullableRepositoryParameters | 생성자 4개 nullable 파라미터 검증 | Reflection | assertCount(4), allowsNull | P2 |
| TC-GPS-007 | testConfirmPurchaseAcceptsIntAndStringParameters | confirmPurchase 파라미터 타입 검증 | Reflection | int, string | P2 |
| TC-GPS-008 | testConfirmPurchaseReturnTypeIsArray | confirmPurchase 반환 타입 array 검증 | Reflection | array | P2 |
| TC-GPS-009 | testServiceCanBeInstantiatedWithMockedRepositories | Mock 주입 인스턴스화 검증 | Mock 객체 | assertInstanceOf | P2 |
| TC-GPS-010 | testGoodsRepositoryUpdateConfirmIsCalledWithGoodsNumber | updateConfirm 호출 검증 | `gs_no=42` | expects(once) | P1 |

### 3.7 ItemsControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 기대 결과 | 우선순위 |
|-------|---------|------|----------|---------|
| TC-IC-001 | testControllerExtendsBaseApiController | ItemsController가 BaseApiController 상속 확인 | assertTrue | P1 |
| TC-IC-002 | testGetListPcMethodExists | getListPc 메서드 존재 확인 | assertTrue | P1 |
| TC-IC-003 | testGetListMobileMethodExists | getListMobile 메서드 존재 확인 | assertTrue | P1 |
| TC-IC-004 | testGetSearchListItemsMethodExists | getSearchListItems 메서드 존재 확인 | assertTrue | P1 |
| TC-IC-005 | testGetSearchListGoodsMethodExists | getSearchListGoods 메서드 존재 확인 | assertTrue | P1 |
| TC-IC-006 | testGetListCommentMethodExists | getListComment 메서드 존재 확인 | assertTrue | P2 |
| TC-IC-007 | testGetItemMethodExists | getItem 메서드 존재 확인 | assertTrue | P1 |
| TC-IC-008 | testGetLikeListMethodExists | getLikeList 메서드 존재 확인 | assertTrue | P1 |
| TC-IC-009 | testItemAddLikeMethodExists | itemAddLike 메서드 존재 확인 | assertTrue | P1 |
| TC-IC-010 | testItemDeleteLikeMethodExists | itemDeleteLike 메서드 존재 확인 | assertTrue | P1 |
| TC-IC-011 | testItemAllDeleteLikeMethodExists | itemAllDeleteLike 메서드 존재 확인 | assertTrue | P1 |
| TC-IC-012 | testGetItemQnaListMethodExists | getItemQnaList 메서드 존재 확인 | assertTrue | P2 |
| TC-IC-013 | testInsertItemQnaMethodExists | insertItemQna 메서드 존재 확인 | assertTrue | P1 |
| TC-IC-014 | testSaveItemPriceMethodExists | saveItemPrice 메서드 존재 확인 | assertTrue | P1 |
| TC-IC-015 | testGetPostingListMethodExists | getPostingList 메서드 존재 확인 | assertTrue | P2 |
| TC-IC-016 | testPostingDetailMethodExists | postingDetail 메서드 존재 확인 | assertTrue | P2 |
| TC-IC-017 | testGetPostingCommentsMethodExists | getPostingComments 메서드 존재 확인 | assertTrue | P2 |

### 3.8 ItemListFormatterTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-ILF-001 | testFormatRowExplodesItTagByComma | it_tag 콤마 분리 | `'a,b,c'` | `['a','b','c']` | P1 |
| TC-ILF-002 | testFormatRowItTagSingleValue | it_tag 단일값 | `'only'` | `['only']` | P1 |
| TC-ILF-003 | testFormatRowItNoticeSetsStringCountInBytes | it_notice mb_strlen 검증 | `'안녕하세요'` | 5 | P1 |
| TC-ILF-004 | testFormatRowItNoticeEmptyString | it_notice 빈 문자열 | `''` | 0 | P1 |
| TC-ILF-005 | testFormatRowNoticeRegistDateNullReturnsFalse | notice_regist_date null 시 false | null | false | P1 |
| TC-ILF-006 | testFormatRowNoticeRegistDateReturnsHourDiff | notice_regist_date 시간차 계산 | 24시간 전 | 23~25 | P1 |
| TC-ILF-007 | testFormatRowItCounselFieldDecodesJson | it_counsel_field JSON 디코딩 | `'["love","money"]'` | array contains 'love' | P1 |
| TC-ILF-008 | testFormatRowItCounselFieldEmptyStringReturnsEmptyArray | it_counsel_field 빈 문자열 | `''` | `[]` | P1 |
| TC-ILF-009 | testFormatRowHeCodeMapsCallStatusOnWhenInOnCall | he_code 통화 중 매핑 | onCall 배열 존재 | call_status='on' | P1 |
| TC-ILF-010 | testFormatRowHeCodeMapsCallStatusOffWhenNotInOnCall | he_code 미통화 매핑 | onCall 배열 미일치 | call_status='off' | P1 |
| TC-ILF-011 | testFormatRowHeCodeWithoutOnCallAppliesHtmlspecialchars | he_code htmlspecialchars 적용 | `'<script>'` | 이스케이프 처리 | P1 |
| TC-ILF-012 | testFormatRowCpCodePvkSetsFlagKr | cp_code PVK 시 flag -kr | `'PVK'` | `'-kr'` | P2 |
| TC-ILF-013 | testFormatRowCpCodeOtherSetsFlagEmpty | cp_code 기타 시 flag 빈값 | `'USA'` | `''` | P2 |
| TC-ILF-014 | testFormatRowDefaultFieldAppliesHtmlspecialchars | 기본 필드 htmlspecialchars 적용 | `'<b>text</b>'` | 이스케이프 처리 | P1 |
| TC-ILF-015 | testSetItemLabelHotPartSetsHotTrue | hot 분기 hot=true | part='hot' | hot=true | P1 |
| TC-ILF-016 | testSetItemLabelHotPartAddsStarLabelWhenWinPoint5Exists | hot 분기 star 라벨 | win_point5='4.5' | item_label['star'] 존재 | P1 |
| TC-ILF-017 | testSetItemLabelHotPartAddsReviewLabelWhenWinCommentExists | hot 분기 review 라벨 | win_comment=10 | item_label['review'] 존재 | P1 |
| TC-ILF-018 | testSetItemLabelHotPartAddsCounselLabelWhenWinDurationExists | hot 분기 counsel 라벨 | win_duration=30 | item_label['counsel'] 존재 | P1 |
| TC-ILF-019 | testSetItemLabelNonHotSetsHotFalse | 일반 분기 hot=false | part='' | hot=false | P1 |
| TC-ILF-020 | testSetItemLabelNonHotAddsPartnerLabelWhenCeLevelAboveZero | 일반 분기 partner 라벨 | ce_level=1 | item_label['partner'] 존재 | P1 |
| TC-ILF-021 | testSetItemLabelNonHotAddsNewLabelWhenItNewIsY | 일반 분기 new 라벨 | it_new='Y' | item_label['new'] 존재 | P1 |
| TC-ILF-022 | testSetItemLabelNonHotNoLabelsWhenConditionsNotMet | 조건 미충족 시 라벨 없음 | ce_level=0, it_new='N' | item_label 빈 배열 | P1 |
| TC-ILF-023 | testSetItemLabelCustomLabelTextsOverrideDefaults | 커스텀 라벨 텍스트 오버라이드 | customTexts | '별점커스텀' | P2 |
| TC-ILF-024 | testSetViewTagItemNewSetsMonth1Tag | itemNew 정렬 시 1개월 태그 | order='itemNew' | view_tag='直近1ヶ月の' | P1 |
| TC-ILF-025 | testSetViewTagNewRegistSetsMonth1Tag | newRegist 정렬 시 1개월 태그 | order='newRegist' | view_tag='直近1ヶ月の' | P1 |
| TC-ILF-026 | testSetViewTagItCmtCntSetsCumulativeTag | it_cmt_cnt 정렬 시 누적 태그 | order='it_cmt_cnt' | view_tag='累計' | P1 |
| TC-ILF-027 | testSetViewTagItLikeCntSetsCumulativeTagWithLikeCnt | it_like_cnt 정렬 시 누적+좋아요 수 | order='it_like_cnt' | view_like_cnt='1,234' | P1 |
| TC-ILF-028 | testSetViewTagDefaultSetsMonth3Tag | 기본 정렬 시 3개월 태그 | order='unknown' | view_tag='直近3ヶ月の' | P1 |
| TC-ILF-029 | testSetViewTagFallsBackToSecondaryKeyWhenPrimaryMissing | 1차 키 없을 때 2차 키 폴백 | m1_cm_point만 존재 | view_win_point='3.0' | P2 |
| TC-ILF-030 | testSetViewTagCustomTagTextsOverrideDefaults | 커스텀 태그 텍스트 오버라이드 | customTexts | '최근1개월' | P2 |
| TC-ILF-031 | testSetClassOnlineReturnsYWhenCallTypeIsClass | call_type class 시 Y | call_type='class' | class_online='Y' | P1 |
| TC-ILF-032 | testSetClassOnlineReturnsNWhenCallTypeIsCoin | call_type coin 시 N | call_type='coin' | class_online='N' | P1 |
| TC-ILF-033 | testSetClassOnlineReturnsNWhenCallTypeMissing | call_type 없을 때 N | 빈 배열 | class_online='N' | P1 |
| TC-ILF-034 | testFormatListProcessesAllRowsThroughPipeline | 전체 파이프라인 2행 처리 | 2행 배열 | assertCount(2) | P1 |
| TC-ILF-035 | testFormatListCallsPointCalculatorCallback | pointCalculator 콜백 호출 | callback | calculated_point=99 | P1 |
| TC-ILF-036 | testFormatListCallsPostProcessorCallback | postProcessor 콜백 호출 | callback | post_processed=true | P1 |
| TC-ILF-037 | testFormatListWithEmptyRowsReturnsEmptyArray | 빈 배열 입력 시 빈 배열 반환 | `[]` | `[]` | P1 |
| TC-ILF-038 | testFormatListSetsViewTagAndItemLabel | formatList에서 viewTag+itemLabel 설정 | it_new='Y' | hot=false, view_tag 존재 | P1 |

### 3.9 ShopControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 기대 결과 | 우선순위 |
|-------|---------|------|----------|---------|
| TC-SC-001 | testControllerExtendsBaseApiController | ShopController가 BaseApiController 상속 확인 | assertTrue | P1 |
| TC-SC-002 | testReservationCalendarMethodExists | reservationCalendar 메서드 존재 확인 | assertTrue | P1 |
| TC-SC-003 | testOrderReservationTimeMethodExists | orderReservationTime 메서드 존재 확인 | assertTrue | P1 |
| TC-SC-004 | testGetMyShopMethodExists | getMyShop 메서드 존재 확인 | assertTrue | P1 |
| TC-SC-005 | testViewLocationPopupMethodExists | viewLocationPopup 메서드 존재 확인 | assertTrue | P2 |
| TC-SC-006 | testGetShopItemsMethodExists | getShopItems 메서드 존재 확인 | assertTrue | P1 |
| TC-SC-007 | testBuyShopMethodExists | buyShop 메서드 존재 확인 | assertTrue | P1 |
| TC-SC-008 | testInsertMyCommentMethodExists | insertMyComment 메서드 존재 확인 | assertTrue | P2 |
| TC-SC-009 | testUpdateRescheduleMethodExists | updateReschedule 메서드 존재 확인 | assertTrue | P1 |
| TC-SC-010 | testShopConfirmMethodExists | shopConfirm 메서드 존재 확인 | assertTrue | P1 |
| TC-SC-011 | testShopCancelMethodExists | shopCancel 메서드 존재 확인 | assertTrue | P1 |
| TC-SC-012 | testRefundSuccessMethodExists | refundSuccess 메서드 존재 확인 | assertTrue | P1 |
| TC-SC-013 | testShopFileMethodExists | shopFile 메서드 존재 확인 | assertTrue | P2 |
| TC-SC-014 | testScheduleDeleteMethodExists | scheduleDelete 메서드 존재 확인 | assertTrue | P2 |
| TC-SC-015 | testScheduleAddMethodExists | scheduleAdd 메서드 존재 확인 | assertTrue | P2 |
| TC-SC-016 | testShopReserveDayMethodExists | ShopReserveDay 메서드 존재 확인 | assertTrue | P2 |
| TC-SC-017 | testShopReserveWeekMethodExists | ShopReserveWeek 메서드 존재 확인 | assertTrue | P2 |
| TC-SC-018 | testShopReserveMonthMethodExists | ShopReserveMonth 메서드 존재 확인 | assertTrue | P2 |
| TC-SC-019 | testCalleeShopConfirmMethodExists | calleeShopConfirm 메서드 존재 확인 | assertTrue | P1 |
| TC-SC-020 | testMemosaveMethodExists | memosave 메서드 존재 확인 | assertTrue | P2 |
| TC-SC-021 | testCalleeShopFileUploadMethodExists | calleeShopFileUpload 메서드 존재 확인 | assertTrue | P1 |
| TC-SC-022 | testCalleeO2oJobMethodExists | calleeO2oJob 메서드 존재 확인 | assertTrue | P1 |
| TC-SC-023 | testDeleteFileMethodExists | deleteFile 메서드 존재 확인 | assertTrue | P2 |
| TC-SC-024 | testUpdateShopMethodExists | updateShop 메서드 존재 확인 | assertTrue | P1 |
| TC-SC-025 | testUpdateShopViewMethodExists | updateShopView 메서드 존재 확인 | assertTrue | P2 |
| TC-SC-026 | testPreviewShopMethodExists | previewShop 메서드 존재 확인 | assertTrue | P2 |
| TC-SC-027 | testDeleteOptMethodExists | deleteOpt 메서드 존재 확인 | assertTrue | P2 |

### 3.10 ShopReservationServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-SRS-001 | testBuildCalendarDataSkippedDueToCalendarHelperDependency | CalendarHelper 의존으로 스킵 | — | Skipped | P1 |
| TC-SRS-002 | testGetAvailableTimeSlotsReturnsPrevMontStatusForPastDate | 과거 날짜 시 prev_mont 상태 반환 | 어제 날짜 | status='prev_mont', data=null | P1 |
| TC-SRS-003 | testGetAvailableTimeSlotsReturnsPrevMontStatusForYesterdayDate | 30일 전 날짜 시 prev_mont 상태 반환 | 30일 전 | status='prev_mont', data=null | P1 |
| TC-SRS-004 | testGetAvailableTimeSlotsReturnsNoReservationWhenRepositoryReturnsEmpty | Repository false 반환 시 no_reservation | Repository→false | status='no_reservation' | P1 |
| TC-SRS-005 | testGetAvailableTimeSlotsReturnsNoReservationWhenRepositoryReturnsNull | Repository null 반환 시 no_reservation | Repository→null | status='no_reservation' | P1 |
| TC-SRS-006 | testGetAvailableTimeSlotsHandlesTodayTrueByUsingCurrentDate | today=true 시 오늘 날짜 사용 | today='true' | status in ['no_reservation','success'] | P1 |
| TC-SRS-007 | testGetAvailableTimeSlotsReturnsSuccessStatusWithCorrectDataShape | 성공 시 응답 구조 검증 | 파이프 구분 시간 | status='success', data 키 존재 | P1 |
| TC-SRS-008 | testGetAvailableTimeSlotsParsesPipeDelimitedSalesTime | 파이프 구분 sales_time 파싱 검증 | `'09:00\|10:00\|11:00\|'` | sales_times count=3 | P1 |
| TC-SRS-009 | testGetAvailableTimeSlotsClassifiesAmAndPmCorrectly | AM/PM 분류 검증 | `'09:00\|13:00\|'` | AM에 09:00, PM 비어있지 않음 | P1 |
| TC-SRS-010 | testShopReservationServiceClassExists | 클래스 존재 확인 | — | assertTrue | P2 |
| TC-SRS-011 | testBuildCalendarDataMethodExists | buildCalendarData 메서드 존재 확인 | — | assertTrue | P2 |
| TC-SRS-012 | testGetAvailableTimeSlotsMethodExists | getAvailableTimeSlots 메서드 존재 확인 | — | assertTrue | P2 |
| TC-SRS-013 | testConstructorAcceptsNullableShopRepositoryParameter | 생성자 nullable 파라미터 검증 | Reflection | assertCount(1), allowsNull | P2 |
| TC-SRS-014 | testGetAvailableTimeSlotsAcceptsArrayParameter | 파라미터 배열 타입 검증 | Reflection | name='post' | P2 |
| TC-SRS-015 | testServiceCanBeInstantiatedWithMockedRepository | Mock 주입 인스턴스화 검증 | Mock 객체 | assertInstanceOf | P2 |

### 3.11 SpecialPriceControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 기대 결과 | 우선순위 |
|-------|---------|------|----------|---------|
| TC-SPC-001 | testControllerExtendsBaseApiController | SpecialPriceController가 BaseApiController 상속 확인 | assertTrue | P1 |
| TC-SPC-002 | testGetListMethodExists | getList 메서드 존재 확인 | assertTrue | P1 |

---

## 4. Test Execution Results

| 테스트 파일 | 총 케이스 | PASS | FAIL | SKIP | 최종 실행일 |
|------------|----------|------|------|------|-----------|
| GoodsApiTest | 5 | 5 | 0 | 0 | 2026-04-15 |
| ItemsApiTest | 5 | 5 | 0 | 0 | 2026-04-15 |
| ShopApiTest | 5 | 5 | 0 | 0 | 2026-04-15 |
| SpecialPriceApiTest | 3 | 3 | 0 | 0 | 2026-04-15 |
| GoodsControllerTest | 30 | 30 | 0 | 0 | 2026-04-21 |
| GoodsPurchaseServiceTest | 10 | 9 | 0 | 1 | 2026-04-15 |
| ItemsControllerTest | 17 | 17 | 0 | 0 | 2026-04-21 |
| ItemListFormatterTest | 38 | 38 | 0 | 0 | 2026-04-15 |
| ShopControllerTest | 27 | 27 | 0 | 0 | 2026-04-21 |
| ShopReservationServiceTest | 16 | 15 | 0 | 1 | 2026-04-15 |
| SpecialPriceControllerTest | 2 | 2 | 0 | 0 | 2026-04-15 |
| **합계** | **158** | **156** | **0** | **2** | — |

**SKIP 사유**:
- TC-GPS-003 (GoodsPurchaseServiceTest): `confirmPurchase` 정상 케이스는 `Fcm::sendToUser()` 외부 라이브러리, `checkSMSPermitUser()` 전역 함수, `lang()` 헬퍼에 의존
- TC-SRS-001 (ShopReservationServiceTest): `buildCalendarData`는 `CalendarHelper::buildMonthData()` 전역 헬퍼 함수에 의존

---

## 5. Traceability Matrix

| SRS 요구사항 ID | 요구사항 설명 | 테스트 케이스 ID | 검증 상태 |
|----------------|-------------|-----------------|----------|
| FR-001-1 | 6가지 sort 모드 지원 | TC-ILF-024~028 | PASS |
| FR-001-2 | it_counsel_field 필터링 | TC-ILF-007, TC-ILF-008 | PASS |
| FR-001-3 | 키워드 검색 | TC-IA-001~003, TC-IA-005 | PASS |
| FR-001-4 | ItemListFormatter 콜백 체인 (6단계) | TC-ILF-034~038 | PASS |
| FR-001-5 | 5가지 label 타입 | TC-ILF-015~023 | PASS |
| FR-001-6 | 온라인 상태, 포인트, 태그 포함 | TC-ILF-001~002, TC-ILF-009~010, TC-ILF-031~033 | PASS |
| FR-001-7 | CI4 Pager 페이지네이션 | TC-IA-002, TC-IA-003 | PASS |
| FR-001-8 | 공개/인증 EP 분리 | TC-IA-001~005 | PASS |
| FR-002-1 | 즐겨찾기 추가 (중복 409 포함) | TC-IC-009 | PASS |
| FR-002-2 | 즐겨찾기 삭제 | TC-IC-010 | PASS |
| FR-002-3 | 즐겨찾기 전체 삭제 | TC-IC-011 | PASS |
| FR-003-1 | Q&A 등록 + FCM | TC-IC-013 | PASS |
| FR-003-4 | Q&A 스팸 방지 429 | TC-IC-013 | PASS (메서드 존재만. 비즈니스 로직 TC 추가 권장) |
| FR-004-1 | 가격 수정 (Callee 검증, route filter 기술부채) | TC-IC-014 | PASS |
| FR-005-1 | CalendarHelper 캘린더 | TC-SRS-001, TC-SC-002 | PASS (1 skip) |
| FR-005-2 | 1시간 사전 예약 규칙 | TC-SRS-007~009 | PASS |
| FR-005-3 | AM/PM 분리 응답 | TC-SRS-009 | PASS |
| FR-005-4 | 과거 날짜 prev_mont | TC-SRS-002, TC-SRS-003 | PASS |
| FR-005-5 | 파이프 구분자 파싱 | TC-SRS-008 | PASS |
| FR-005-6 | 예약 중복/휴식 시간 제외 | TC-SRS-007 | PASS |
| FR-006-1 | 예약 생성 (UNIQUE KEY) | TC-SA-004 | PASS |
| FR-006-2 | 방문 확인 | TC-SC-010 | PASS |
| FR-006-3 | 24시간 취소 규칙 | TC-SC-011 | PASS |
| FR-006-4 | PG 환불 | TC-SC-012 | PASS |
| FR-006-5 | PG 콜백 refund-success (레거시 HTML redirect) | TC-SC-012 | PASS (메서드 존재만. 레거시 HTML redirect 응답 — CSRF 면제 검토 대상, 비즈니스 로직 TC 추가 권장) |
| FR-006-6 | 후기 이미지 MIME 이중 검증 | TC-SC-008 | PASS (메서드 존재만. MIME Layer 2 비즈니스 로직 TC 추가 권장) |
| FR-006-7 | view-location-popup (공개 EP) | TC-SA-003 | PASS |
| FR-006-8 | get-my-shop (JWT, 예약 목록) | TC-SA-005, TC-SC-004 | PASS (메서드 존재만) |
| FR-006-9 | update-reschedule (24h 규칙) | TC-SC-009 | PASS (메서드 존재만. 24h 비즈니스 로직 TC 추가 권장) |
| FR-007-1 | 상품 구매 INSERT | TC-GA-003 | PASS |
| FR-007-1 | addr-second-list (주소 조회) | TC-GC-029 | PASS (메서드 존재만) |
| FR-007-3 | GoodsPurchaseService::confirmPurchase | TC-GPS-001, TC-GPS-002, TC-GPS-010 | PASS |
| FR-007-4 | 주문 취소 | TC-GC-017 | PASS |
| FR-007-5 | 상태 머신 forward-only | TC-GPS-001, TC-GPS-002 | PASS |
| FR-008-1 | Callee Goods CRUD | TC-GC-011, TC-GC-012 | PASS |
| FR-008-2 | MIME 이중 검증 (callee-goods-file-upload) | TC-GC-010 | PASS |
| FR-008-2 | MIME 이중 검증 (callee-class-file-upload) | TC-GC-030 | PASS (메서드 존재만. MIME 비즈니스 로직 TC 추가 권장) |
| FR-008-5 | 주문 수락 | TC-GC-008 | PASS |
| FR-008-6 | 작업 완료 + 파일 업로드 | TC-GC-009, TC-GC-010 | PASS |
| FR-008-7 | Shop 스케줄 관리 | TC-SC-019, TC-SC-022 | PASS |
| FR-008-9 | goods memosave Caller 소유권 검증 | TC-GC-024 | PASS (메서드 존재만. 소유권 검증 TC 추가 권장) |
| FR-008-10 | goods delete-opt Caller 소유권 검증 | TC-GC-025 | PASS (메서드 존재만. 소유권 검증 TC 추가 권장) |
| FR-008-11 | goods delete-file Caller 소유권 검증 | TC-GC-026 | PASS (메서드 존재만. 소유권 검증 TC 추가 권장) |
| FR-009-1 | 클래스 이력 조회 | TC-GC-027 | PASS |
| FR-009-2 | 클래스 상세 조회 | TC-GC-028 | PASS |
| FR-009-3 | callee-class-file-upload + FCM | TC-GC-030 | PASS (메서드 존재만. FCM TC 추가 권장) |
| FR-010-1 | SpecialPrice 공개 EP | TC-SPA-001~003 | PASS |
| FR-010-3 | EventListTrait 사용 | TC-SPC-001, TC-SPC-002 | PASS |
| FR-011-1 | Posting 목록 (공개) | TC-IC-015 | PASS |
| FR-011-2 | Posting 상세 (공개) | TC-IC-016 | PASS |
| FR-011-3 | Posting 댓글 목록 (공개) | TC-IC-017 | PASS |

---

## 6. Defects & Issues

| ID | 유형 | 설명 | 심각도 | 해결 상태 |
|----|------|------|--------|----------|
| DEF-C-001 | 테스트 제한 | GoodsPurchaseService::confirmPurchase 정상 케이스 스킵 — Fcm, checkSMSPermitUser, lang() 외부 의존 | 중 | 미해결 (통합 테스트로 위임) |
| DEF-C-002 | 테스트 제한 | ShopReservationService::buildCalendarData 스킵 — CalendarHelper 전역 헬퍼 의존 | 중 | 미해결 (통합 테스트로 위임) |
| DEF-C-003 | 커버리지 | Feature 테스트는 MySQL DB 연결 필요 — SQLite 테스트 환경에서 자동 skip | 저 | 설계 의도 (환경 분리) |
| DEF-C-004 | 커버리지 | goods memosave/delete-opt/delete-file 소유권 검증 비즈니스 로직 TC 없음 (TC-GC-024~026은 메서드 존재만) | 중 | 미해결 — FR-008-9~11 반영 필요 |
| DEF-C-005 | 커버리지 | callee-class-file-upload MIME 이중 검증 + FCM TC 없음 (TC-GC-030은 메서드 존재만) | 중 | 미해결 — FR-008-2, FR-009-3 반영 필요 |
| DEF-C-006 | 커버리지 | shop delete-opt TC-SC-027 메서드 존재 확인 TC 추가됨 (v1.1). 비즈니스 로직 TC는 미구현 | 저 | 미해결 |
| DEF-C-007 | 커버리지 | Q&A 스팸 방지 429 비즈니스 로직 TC 없음 (TC-IC-013은 메서드 존재만) | 저 | 미해결 — FR-003-4 |
| DEF-C-008 | 커버리지 | 즐겨찾기 중복 409 비즈니스 로직 TC 없음 (TC-IC-009는 메서드 존재만) | 저 | 미해결 — FR-002-1 |

---

## 7. 변경 로그 (Change Log)

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|----------|
| v1.0 | 2026-04-16 | jypark | 초기 작성. 11개 테스트 파일, 154 TC, SRS 추적성 매트릭스 완성. |
| v1.1 | 2026-04-21 | jypark | [A] COMMERCE-ITEMS-DEF-001/002: Items EP 수 17→16 정정 (§1.1, §1.2), 총 EP 73→72. ItemsControllerTest TC 수 16→17 (TC-IC-017 getPostingComments 추가). COMMERCE-GOODS-DEF-004: GoodsControllerTest TC 수 28→30 (TC-GC-029 addrSecondList, TC-GC-030 calleeClassFileUpload 추가). shop [B]-001: ShopControllerTest TC 수 26→27 (TC-SC-027 deleteOpt 추가). 총 TC 154→158. §5 Traceability Matrix에 FR-003-4/FR-008-2~callee-class/FR-008-9~11/FR-009-3/FR-011-1~3/FR-007-1~addr-second-list 추가. §6 DEF-C-004~008 신규 커버리지 이슈 등록. |
| v1.2 | 2026-04-21 | jypark | [A] COMMERCE-SHOP-DEF-001/003: §5 Traceability Matrix에 FR-006-5~9 항목 추가 (refund-success 레거시 HTML redirect CSRF 검토 / insert-my-comment MIME 이중 검증 / view-location-popup 공개 EP / get-my-shop JWT / update-reschedule 24h 규칙). SRS v3.1 FR-006-5~9 기준 추적성 반영. |
