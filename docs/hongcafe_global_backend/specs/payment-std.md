---
문서명: Payment — Software Test Documentation
문서 ID: payment-std
버전: v1.1
상태: 승인됨
생성일: 2026-04-16
최종 수정일: 2026-04-21
작성자: jypark
대상 시스템: Payment Module
관련 문서: payment-srs.md, payment-sdd.md, payment-idd.md, project-stp.md
적용 표준: IEEE 829-2008
---

# Payment — Software Test Documentation (STD)

> IEEE 829-2008 | version: 1.1 | lastUpdated: 2026-04-21 | module: Payment

---

## 1. Introduction

### 1.1 Purpose

본 문서는 HongCafe Global Backend Payment 모듈의 테스트 케이스, 실행 결과, 요구사항 추적성을 IEEE 829-2008 표준에 따라 기록한다.

### 1.2 Scope

Payment 모듈의 Stripe 결제, 간편결제, 자동결제, Naver Pay/Toss Pay 연동, 코인 충전, 페이백, 코인백 기능을 대상으로 한다. 12개 테스트 파일에 포함된 총 98개 테스트 메서드를 검증 범위로 한다.

### 1.3 References

| 문서 | 경로 |
|------|------|
| SRS | `docs/specs/payment-srs.md` v2.0 |
| SDD | `docs/specs/payment-sdd.md` |
| IDD | `docs/specs/payment-idd.md` |
| STP | `project-stp.md` |

---

## 2. Test Items

### 2.1 테스트 대상 클래스/메서드 목록

**SRS 범위 내 (11개 EP 기준)**

| 테스트 파일 | 테스트 유형 | 대상 클래스 | 테스트 수 |
|-----------|-----------|-----------|---------|
| `PayApiTest` | Feature (통합) | `PayController` (API 엔드포인트) | 5 |
| `PaybackApiTest` | Feature (통합) | `PaybackController` (API 엔드포인트) | 3 |
| `StripeApiTest` | Feature (통합) | `StripeController` (API 엔드포인트) | 5 |
| `AutopayServiceTest` | Unit | `AutopayService` | 22 |
| `PayControllerTest` | Unit | `PayController`, `PayViewController` | 11 |
| `PaybackControllerTest` | Unit | `PaybackController` | 2 |
| `PaymentNotifierTest` | Unit | `PaymentNotifier` | 12 |
| `PaymentServiceTest` | Unit | `PaymentService` | 28 |
| `SimplepayModelTest` | Unit | `SimplepayModel`, `SimplepayRepository` | 22 |
| `StripeControllerTest` | Unit | `StripeController` | 4 |
| `StripePaymentServiceTest` | Unit | `StripePaymentService` | 15 |

**범위 외 (레거시 / Open Question Q-02)**

| 테스트 파일 | 테스트 유형 | 대상 클래스 | 테스트 수 | 비고 |
|-----------|-----------|-----------|---------|------|
| `PaypalTest` | Unit | `PaypalService` | 7 | PayPal은 SRS §1.2 의존 외부 서비스 목록에 없고 API 문서에 EP가 없다. 레거시 코드 추정. Q-02: PayPal 지원 여부 확인 후 SRS 범위 추가 또는 영구 레거시 분리 결정 필요 |

---

## 3. Test Cases

### 3.1 PayApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-PAY-001 | `testSaveSimplepayWithoutActFieldReturnsError` | act 필드 없이 saveSimplepay 요청 시 에러 응답 | `{}` | HTTP 200 + 비어있지 않은 본문 | P1 |
| TC-PAY-002 | `testSaveSimplepayRegistWithMissingFieldsReturnsError` | registSimeplePay act에 필수 필드 누락 시 에러 | `{ act, sp_type }` (setupIntent_id, sp_password 누락) | HTTP 200 + 비어있지 않은 본문 | P1 |
| TC-PAY-003 | `testDeleteSimplepayWithoutSpNoReturnsError` | sp_no 없이 deleteSimplepay 요청 시 에러 | `{}` | HTTP 200 + 비어있지 않은 본문 | P1 |
| TC-PAY-004 | `testInsertInAppCoinOrderWithoutPdCodeReturnsError` | pd_code 없이 insertInAppCoinOrder 요청 시 에러 | `{}` | HTTP 200 + 비어있지 않은 본문 | P1 |
| TC-PAY-005 | `testDelAutoPayCardWithoutLoginReturnsError` | 비인증 상태로 delAutoPayCard 요청 시 에러 | `{}` | HTTP 200 + 비어있지 않은 본문 | P1 |

### 3.2 PaybackApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-PAY-006 | `testGetListWithEmptyBodyReturns200` | 빈 body로 getList 요청 시 200 응답 | `[]` | HTTP 200 | P2 |
| TC-PAY-007 | `testGetListWithEpCodeReturns200` | ep_code 포함 getList 요청 시 200 응답 | `{ ep_code, st_code, keyword }` | HTTP 200 | P2 |
| TC-PAY-008 | `testGetListWithKeywordReturns200` | keyword 포함 getList 요청 시 200 응답 | `{ ep_code, keyword }` | HTTP 200 | P2 |

### 3.3 StripeApiTest (Feature)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-PAY-009 | `testCreatePaymentIntentRequiresAuthentication` | 비인증 상태 createPaymentIntent 호출 시 clientSecret 미반환 | `[]` | HTTP 200 + clientSecret 키 없음 | P1 |
| TC-PAY-010 | `testCreateSetupIntentRequiresAuthentication` | 비인증 상태 createSetupIntent 호출 시 clientSecret 미반환 | `[]` | HTTP 200 + clientSecret 키 없음 | P1 |
| TC-PAY-011 | `testWebhookWithoutSignatureHeaderReturns400` | 서명 헤더 없이 webhook 요청 시 400 반환 | 빈 body, content-type: application/json | HTTP 400 | P1 |
| TC-PAY-012 | `testWebhookWithInvalidSignatureReturns400` | 잘못된 Stripe-Signature로 webhook 요청 시 400 반환 | `Stripe-Signature: invalid`, `{ type: payment_intent.succeeded }` | HTTP 400 + error 키 존재 | P1 |
| TC-PAY-013 | `testWebhookWithEmptyPayloadReturns400` | 빈 페이로드로 webhook 요청 시 400 반환 | `Stripe-Signature: t=...,v1=fakesig`, 빈 body | HTTP 400 | P1 |

### 3.4 AutopayServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-PAY-014 | `testServiceClassCanBeInstantiated` | AutopayService 인스턴스화 확인 | Mock Repository 2개 | `assertInstanceOf` | P2 |
| TC-PAY-015 | `testRegistCardMethodExists` | registCard 메서드 존재 확인 | Reflection | `method_exists` = true | P2 |
| TC-PAY-016 | `testInsertRulesMethodExists` | insertRules 메서드 존재 확인 | Reflection | `method_exists` = true | P2 |
| TC-PAY-017 | `testUpdateRulesMethodExists` | updateRules 메서드 존재 확인 | Reflection | `method_exists` = true | P2 |
| TC-PAY-018 | `testSendPayMethodExists` | sendPay 메서드 존재 확인 | Reflection | `method_exists` = true | P2 |
| TC-PAY-019 | `testUpdateUseMethodExists` | updateUse 메서드 존재 확인 | Reflection | `method_exists` = true | P2 |
| TC-PAY-020 | `testCheckinCardMethodExists` | checkinCard 메서드 존재 확인 | Reflection | `method_exists` = true | P2 |
| TC-PAY-021 | `testAutopaySendMethodExists` | autopaySend 메서드 존재 확인 | Reflection | `method_exists` = true | P2 |
| TC-PAY-022 | `testRegistCardReturnsFalseWhenGetProductFails` | getProduct 실패 시 registCard false 반환 + err_msg | Mock: getProduct=false | `assertFalse` + `assertSame(err_msg)` | P1 |
| TC-PAY-023 | `testRegistCardReturnsFalseWhenCheckinCardFails` | checkinCard 실패 시 registCard false 반환 | Partial Mock: checkinCard=false | `assertFalse` | P1 |
| TC-PAY-024 | `testRegistCardReturnsFalseWhenInsertAutopayCardFails` | 신규 카드 등록 실패 시 false + err_msg | Mock: insertAutopayCard=false | `assertFalse` + `assertNotEmpty(err_msg)` | P1 |
| TC-PAY-025 | `testRegistCardReturnsFalseWhenUpdateAutopayCardFails` | 기존 카드 업데이트 실패 시 false + err_msg | Mock: updateAutopayCard=false | `assertFalse` + `assertNotEmpty(err_msg)` | P1 |
| TC-PAY-026 | `testInsertRulesReturnsFalseWhenGetProductFails` | getProduct 실패 시 insertRules false 반환 | Mock: getProduct=false | `assertFalse` + `assertSame(err_msg)` | P1 |
| TC-PAY-027 | `testInsertRulesReturnsFalseWhenInsertAutopayCardFails` | insertAutopayCard 실패 시 false + err_msg | Mock: insertAutopayCard=false | `assertFalse` + `assertNotEmpty(err_msg)` | P1 |
| TC-PAY-028 | `testInsertRulesCalculatesChargePriceCorrectly` | 금액 계산 로직: charge_price = pd_price * 1.1 | pd_price=1000, pd_coin=300, pd_bonus_coin=100 | charge_price=1100.0, charge_coin=400 | P1 |
| TC-PAY-029 | `testUpdateRulesReturnsFalseWhenPayCardNotFound` | getPayCard null 시 false + err_msg | Mock: getPayCard=null | `assertFalse` + `assertNotEmpty(err_msg)` | P1 |
| TC-PAY-030 | `testUpdateRulesReturnsFalseWhenGetProductFails` | getProduct 실패 시 updateRules false | Mock: getProduct=false | `assertFalse` + `assertSame(err_msg)` | P1 |
| TC-PAY-031 | `testUpdateRulesReturnsFalseWhenUpdateAutopayCardFails` | updateAutopayCard 실패 시 false + err_msg | Mock: updateAutopayCard=false | `assertFalse` + `assertNotEmpty(err_msg)` | P1 |
| TC-PAY-032 | `testSendPayReturnsFalseWhenAutopayNotFound` | 카드 없음 시 sendPay false + err_msg | Mock: getAutopay=null | `assertFalse` + `assertNotEmpty(err_msg)` | P1 |
| TC-PAY-033 | `testSendPayReturnsFalseWhenAutopayIsDisabled` | ap_use='N' 시 false (결제 건너뜀) | card.ap_use='N' | `assertFalse` | P1 |
| TC-PAY-034 | `testSendPayReturnsTrueWhenRemainCoinExceedsMinCoin` | 잔여코인 > min_coin 시 true (결제 불필요) | ac_remain_coin=500, min_coin=100 | `assertTrue` | P1 |
| TC-PAY-035 | `testSendPayStripeFlowIsSkipped` | Stripe SDK 의존 결제 흐름 SKIP | - | `markTestSkipped` | P1 |
| TC-PAY-036 | `testUpdateUseReturnsFalseWhenAutopayNotFound` | 카드 없음 시 updateUse false | Mock: getAutopay=null | `assertFalse` + `assertNotEmpty(err_msg)` | P1 |
| TC-PAY-037 | `testUpdateUseReturnsTrueWhenValueIsAlreadySame` | 동일 값 시 업데이트 없이 true | ap_use='N' (현재=N) | `assertTrue` + `expects(never)->updateAutopayUse` | P1 |
| TC-PAY-038 | `testUpdateUseReturnsFalseWhenRepositoryUpdateFails` | updateAutopayUse 실패 시 false | Mock: updateAutopayUse=false | `assertFalse` + `assertNotEmpty(err_msg)` | P1 |
| TC-PAY-039 | `testUpdateUseReturnsTrueWhenDisablingAutopay` | 'N' 변경 성공 시 true (sendPay 미호출) | ap_use 'Y'->'N' | `assertTrue` | P1 |
| TC-PAY-040 | `testCheckinCardIsSkippedDueToExternalCurlDependency` | checkinCard 외부 cURL 의존 SKIP | - | `markTestSkipped` | P1 |
| TC-PAY-041 | `testAutopaySendIsSkippedDueToExternalCurlDependency` | autopaySend 외부 cURL 의존 SKIP | - | `markTestSkipped` | P1 |

### 3.5 PayControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-PAY-042 | `testControllerExtendsBaseApiController` | PayController 상속 검증 | Reflection | `isSubclassOf` = true | P2 |
| TC-PAY-043 | `testGetMyCardMethodExists` | getMyCard 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-044 | `testViewSimplepayRegistMethodExistsInWebController` | viewSimplepayRegist 존재 (PayViewController) | Reflection | `method_exists` = true | P2 |
| TC-PAY-045 | `testViewSimplepayCardMethodExistsInWebController` | viewSimplepayCard 존재 (PayViewController) | Reflection | `method_exists` = true | P2 |
| TC-PAY-046 | `testViewSimplepayUpdateMethodExistsInWebController` | viewSimplepayUpdate 존재 (PayViewController) | Reflection | `method_exists` = true | P2 |
| TC-PAY-047 | `testViewSimplepayPasswordMethodExistsInWebController` | viewSimplepayPassword 존재 (PayViewController) | Reflection | `method_exists` = true | P2 |
| TC-PAY-048 | `testSaveSimplepayMethodExists` | saveSimplepay 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-049 | `testDeleteSimplepayMethodExists` | deleteSimplepay 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-050 | `testDelAutoPayCardMethodExists` | delAutoPayCard 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-051 | `testNaverpayorderMethodExists` | naverpayorder 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-052 | `testTosspayorderMethodExists` | tosspayorder 메서드 존재 | Reflection | `method_exists` = true | P2 |

### 3.6 PaybackControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-PAY-053 | `testControllerExtendsBaseApiController` | PaybackController 상속 검증 | Reflection | `isSubclassOf` = true | P2 |
| TC-PAY-054 | `testGetListMethodExists` | getList 메서드 존재 | Reflection | `method_exists` = true | P2 |

### 3.7 PaymentNotifierTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-PAY-055 | `testSendCoinPaymentMailMethodExists` | sendCoinPaymentMail 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-056 | `testProcessCalleePointMethodExists` | processCalleePoint 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-057 | `testUpdateLastPaydateMethodExists` | updateLastPaydate 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-058 | `testSendCoinChargeAlimTalkMethodExists` | sendCoinChargeAlimTalk 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-059 | `testSendCoinPaymentMailAcceptsArrayArrayStringParams` | sendCoinPaymentMail 시그니처 검증 (account, order, payMethod) | Reflection | 파라미터 3개, 이름 일치 | P2 |
| TC-PAY-060 | `testProcessCalleePointAcceptsSingleStringParam` | processCalleePoint 시그니처 검증 (odCode) | Reflection | 파라미터 1개, 이름 일치 | P2 |
| TC-PAY-061 | `testUpdateLastPaydateAcceptsPayModelAndStringParams` | updateLastPaydate 시그니처 검증 (payRepository, crCode) | Reflection | 파라미터 2개, 이름 일치 | P2 |
| TC-PAY-062 | `testSendCoinChargeAlimTalkAcceptsMemberAndOrderDataParams` | sendCoinChargeAlimTalk 시그니처 검증 (member, orderData) | Reflection | 파라미터 2개, 이름 일치 | P2 |
| TC-PAY-063 | `testUpdateLastPaydateCallsModelWithCrCodeAndCurrentDate` | PayModel.updateLastPaydate Mock 호출 검증 | Mock PayModel, crCode='CR001' | `expects(once)->method('updateLastPaydate')` + 날짜 패턴 매칭 | P1 |
| TC-PAY-064 | `testSendCoinChargeAlimTalkReturnsEarlyForUsCountry` | US 국가 코드 시 AlimTalk 조기 반환 | country_code='US' | `expectNotToPerformAssertions` | P1 |
| TC-PAY-065 | `testPaymentNotifierCanBeInstantiated` | PaymentNotifier 인스턴스화 확인 | (없음) | `assertInstanceOf` | P2 |

### 3.8 PaymentServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-PAY-066 | `testServiceClassCanBeInstantiated` | PaymentService 인스턴스화 | Mock PayRepository | `assertInstanceOf` | P2 |
| TC-PAY-067 | `testSetPgMethodExists` | setPg 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-068 | `testGetProductMethodExists` | getProduct 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-069 | `testCalculatePaymentAmountMethodExists` | calculatePaymentAmount 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-070 | `testGetCouponPriceMethodExists` | getCouponPrice 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-071 | `testCheckCouponMethodExists` | checkCoupon 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-072 | `testApplyCouponMethodExists` | applyCoupon 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-073 | `testInsertCoinOrderMethodExists` | insertCoinOrder 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-074 | `testUpdateOrderResultMethodExists` | updateOrderResult 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-075 | `testCleanOrderMethodExists` | cleanOrder 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-076 | `testSetPgReturnsTrueAndSetsPgState` | PG 조회 성공 시 true + pg 상태 세팅 | getPgInfo='stripe' | `assertTrue` + `assertSame(pgData)` | P1 |
| TC-PAY-077 | `testSetPgReturnsFalseWhenPgNotFound` | PG 정보 없음 시 false + err_msg | getPgInfo=null | `assertFalse` + `assertNotEmpty(err_msg)` | P1 |
| TC-PAY-078 | `testGetProductReturnsTrueWhenProductFoundInProductTable` | tb_product 상품 조회 성공 시 true + pd 세팅 | getProductInfo=productData | `assertTrue` + `assertSame(pd)` | P1 |
| TC-PAY-079 | `testGetProductReturnsTrueWhenFoundInGoodsSellTable` | tb_goods_sell 조회 성공 시 변환 후 true | getGoodsSellInfo=goodsData | `assertTrue` + pd_type='goods' | P1 |
| TC-PAY-080 | `testGetProductReturnsTrueWhenFoundInShopReservationTable` | tb_shop_reservation 조회 성공 시 변환 후 true | getShopReservationInfo=shopData | `assertTrue` + pd_type='shop' | P1 |
| TC-PAY-081 | `testGetProductReturnsFalseWhenNotFoundAnywhere` | 세 테이블 모두 없음 시 false + err_msg | 모든 getInfo=null | `assertFalse` + `assertNotEmpty(err_msg)` | P1 |
| TC-PAY-082 | `testCalculatePaymentAmountReturnsFlooredAmountForCardPayment` | card 결제: pd_price * 1.1, floor | pd_price=1000, pg='inicis' | od_pay_amount=1100, ori_price=1100.0 | P1 |
| TC-PAY-083 | `testCalculatePaymentAmountDividesBy1000ForPayletterAndPaypal` | payletter/paypal: USD 적용 | pd_price=1000, pd_usd_price=8.50, pg='payletter' | od_pay_amount=1, ori_price=8.50 | P1 |
| TC-PAY-084 | `testCalculatePaymentAmountMultipliesByRvNoCountForReservation` | 예약 결제: pd_price * count(rv_no) * 1.1 | pd_type='reserve', rv_no 2건 | od_pay_amount=2200, ori_price=2200.0 | P1 |
| TC-PAY-085 | `testGetCouponPriceDelegatesToRepository` | getCouponPrice Repository 위임 검증 | CUI-001, 1000, inicis | 800 (Mock) | P2 |
| TC-PAY-086 | `testGetCouponPriceReturnsOriginalPriceWhenNoCouponDiscount` | 할인 없는 경우 원래 금액 반환 | CUI-NONE, 1000 | 1000 | P2 |
| TC-PAY-087 | `testCheckCouponReturnsTrueWhenCouponIsValid` | 유효 쿠폰 시 true | CUI-001 | `assertTrue` | P2 |
| TC-PAY-088 | `testCheckCouponReturnsFalseAndSetsErrMsgWhenInvalid` | 무효 쿠폰 시 false + err_msg | CUI-INVALID | `assertFalse` + `assertNotEmpty(err_msg)` | P2 |
| TC-PAY-089 | `testApplyCouponUpdatesPdPriceAndOdPayAmount` | 쿠폰 적용 시 pd_price/od_pay_amount 갱신 | CUI-001, inicis | pd_price=700, od_pay_amount=700 | P1 |
| TC-PAY-090 | `testApplyCouponReturnsFalseWhenCheckCouponFails` | checkCoupon 실패 시 false | CUI-INVALID | `assertFalse` | P1 |
| TC-PAY-091 | `testInsertCoinOrderReturnsFalseWhenSetPgFails` | setPg 실패 시 false 즉시 반환 | pg='unknown_pg', getPgInfo=null | `assertFalse` + `assertNotEmpty(err_msg)` | P1 |
| TC-PAY-092 | `testInsertCoinOrderReturnsFalseWhenGetProductFails` | 상품 없음 시 false | 모든 getInfo=null | `assertFalse` | P1 |
| TC-PAY-093 | `testInsertCoinOrderCallsInsertOrderForCoinProduct` | 코인 상품 주문 생성 성공 | stripe, PD-001, insertOrder=true | `assertTrue` + `expects(once)->insertOrder` | P1 |
| TC-PAY-094 | `testInsertCoinOrderReturnsFalseWhenCouponCheckFails` | 쿠폰 실패 시 insertOrder 미호출 + false | checkCoupon=false | `assertFalse` + `expects(never)->insertOrder` | P1 |
| TC-PAY-095 | `testUpdateOrderResultReturnsFalseWhenOdCodeMissing` | od_code 미포함 시 false + err_msg | `{ pay_success, od_status }` | `assertFalse` + `assertNotEmpty(err_msg)` | P1 |
| TC-PAY-096 | `testUpdateOrderResultReturnsFalseWhenOrderInfoNotFound` | 주문 정보 없음 시 false | getOrderInfo=null | `assertFalse` 또는 SKIP | P1 |
| TC-PAY-097 | `testUpdateOrderResultCoinGrantFlowIsSkipped` | 코인 지급 흐름 서비스 컨테이너 의존 SKIP | - | `markTestSkipped` | P1 |
| TC-PAY-098 | `testCleanOrderIncludesCardFieldsForCardMethod` | card 결제: od_card_quota, od_card_bank 포함 | method='card' | `assertArrayHasKey('od_card_quota')` | P2 |
| TC-PAY-099 | `testCleanOrderIncludesVbankFieldsForVbankMethod` | vbank 결제: 가상계좌 필드 포함, 카드 필드 미포함 | method='vbank' | `assertArrayHasKey('od_va_bank')` | P2 |
| TC-PAY-100 | `testCleanOrderIncludesPhoneFieldForPhoneMethod` | phone 결제: od_phone_id 포함 | method='phone' | `assertArrayHasKey('od_phone_id')` | P2 |
| TC-PAY-101 | `testCleanOrderReturnsDefaultValuesForEmptyData` | 빈 data 시 기본값 반환 | method='card', data=[] | od_code='', od_income=0 | P2 |
| TC-PAY-102 | `testCleanOrderAlwaysReturnsRequiredCommonKeys` | 공통 필수 키 항상 존재 | method=null | 9개 필수 키 존재 확인 | P2 |

### 3.9 PaypalTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-PAY-103 | `testCurlRequestMethodExists` | curlRequest 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-104 | `testAuthorizationMethodExists` | authorization 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-105 | `testClientIdPropertyIsInitialized` | client_id 프로퍼티 초기화 확인 | Reflection | string 또는 null | P2 |
| TC-PAY-106 | `testSecretPropertyIsInitialized` | secret 프로퍼티 초기화 확인 | Reflection | string 또는 null | P2 |
| TC-PAY-107 | `testRestApiUrlPropertyIsInitialized` | rest_api_url 프로퍼티 초기화 확인 | Reflection | string 또는 null | P2 |
| TC-PAY-108 | `testAuthorizationReturnsCachedTokenWhenNotExpired` | 캐시 토큰 미만료 시 캐시 반환 | access_token 주입, 만료시간=+3600 | 캐시 토큰 값 일치 | P1 |
| TC-PAY-109 | `testCurlRequestSignatureHasCorrectParameters` | curlRequest 시그니처 검증 | Reflection | 파라미터 4개, 타입 확인 | P2 |

### 3.10 SimplepayModelTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-PAY-110 | `testModelCanBeInstantiated` | SimplepayModel 인스턴스화 | (없음) | `assertInstanceOf` | P2 |
| TC-PAY-111 | `testModelExtendsModel` | CI4 Model 상속 검증 | Reflection | `assertInstanceOf(Model::class)` | P2 |
| TC-PAY-112 | `testModelHasCorrectTableConfig` | 테이블명 tb_simplepay 확인 | Reflection | table = 'tb_simplepay' | P2 |
| TC-PAY-113 | `testModelHasPrimaryKey` | PK sp_no 확인 | Reflection | primaryKey = 'sp_no' | P2 |
| TC-PAY-114 | `testModelHasAllowedFields` | allowedFields 비어있지 않음 | Reflection | `assertNotEmpty` | P2 |
| TC-PAY-115 | `testGetSimplePayMethodExists` | SimplepayRepository.GetSimplePay 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-116 | `testAutopaySendMethodExists` | SimplepayRepository.AutopaySend 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-117 | `testInsertSimplepayMethodExists` | InsertSimplepay 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-118 | `testUpdateSimplepayMethodExists` | UpdateSimplepay 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-119 | `testUpdateSimplepayPasswordMethodExists` | UpdateSimplepayPassword 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-120 | `testCheckSimplepayErrorMethodExists` | CheckSimplepayError 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-121 | `testCheckSimplepayPasswordMethodExists` | CheckSimplepayPassword 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-122 | `testClearSimplepayErrorMethodExists` | ClearSimplepayError 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-123 | `testDeleteSimplePayMethodExists` | DeleteSimplePay 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-124 | `testPayRepositoryHasPaymentMethods` | PayRepository 결제 메서드 존재 | Reflection | getProductInfo, insertOrder, updateOrderData 존재 | P2 |
| TC-PAY-125 | `testAllowedFieldsContainsRequiredColumns` | 필수 컬럼 13개 포함 확인 | Reflection | 13개 컬럼 존재 | P2 |
| TC-PAY-126 | `testAllowedFieldsCountMatchesExpected` | allowedFields 수 13개 | Reflection | `assertCount(13)` | P2 |
| TC-PAY-127 | `testUseTimestampsIsFalse` | useTimestamps=false 확인 | Reflection | `assertFalse` | P2 |
| TC-PAY-128 | `testGetSimplePayReflectionSignature` | GetSimplePay 시그니처 (cr_code, ac_id) | Reflection | 파라미터 2개, 반환 array | P2 |
| TC-PAY-129 | `testCheckSimplepayErrorReflectionSignature` | checkSimplepayError 시그니처 | Reflection | 파라미터 3개, card_data 선택적 | P2 |
| TC-PAY-130 | `testCheckSimplepayPasswordReflectionSignature` | checkSimplepayPassword 시그니처 | Reflection | 파라미터 4개, 반환 bool | P2 |
| TC-PAY-131 | `testUpdateSimplepayPasswordReflectionSignature` | updateSimplepayPassword 시그니처 | Reflection | 파라미터 4개, 반환 bool | P2 |
| TC-PAY-132 | `testDeleteSimplePayReflectionSignature` | deleteSimplePay 시그니처 | Reflection | 파라미터 3개, 반환 bool | P2 |
| TC-PAY-133 | `testRepositoryImplementsInterface` | SimplepayRepository implements SimplepayRepositoryInterface | Reflection | `is_a` = true | P2 |
| TC-PAY-134 | `testRepositoryErrMsgPropertyIsPublic` | err_msg public, 기본값 null | Reflection | isPublic, defaultValue=null | P2 |

### 3.11 StripeControllerTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-PAY-135 | `testControllerExtendsBaseApiController` | StripeController 상속 검증 | Reflection | `isSubclassOf` = true | P2 |
| TC-PAY-136 | `testCreatePaymentIntentMethodExists` | createPaymentIntent 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-137 | `testCreateSetupIntentMethodExists` | createSetupIntent 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-138 | `testWebhookMethodExists` | webhook 메서드 존재 | Reflection | `method_exists` = true | P2 |

### 3.12 StripePaymentServiceTest (Unit)

| TC ID | 메서드명 | 설명 | 입력 | 기대 결과 | 우선순위 |
|-------|---------|------|------|----------|---------|
| TC-PAY-139 | `testStripePaymentServiceClassExists` | StripePaymentService 클래스 존재 | Reflection | `class_exists` = true | P2 |
| TC-PAY-140 | `testGetClientMethodExists` | getClient 메서드 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-141 | `testFindOrCreateCustomerMethodExists` | findOrCreateCustomer 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-142 | `testCreatePaymentIntentMethodExists` | createPaymentIntent 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-143 | `testCreateSetupIntentMethodExists` | createSetupIntent 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-144 | `testRetrievePaymentMethodMethodExists` | retrievePaymentMethod 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-145 | `testRetrievePaymentIntentMethodExists` | retrievePaymentIntent 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-146 | `testCancelPaymentIntentMethodExists` | cancelPaymentIntent 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-147 | `testCancelOldReadyOrdersMethodExists` | cancelOldReadyOrders 존재 | Reflection | `method_exists` = true | P2 |
| TC-PAY-148 | `testFindOrCreateCustomerAcceptsStringEmailParameter` | findOrCreateCustomer 시그니처 (email) | Reflection | 파라미터 1개, 이름 'email' | P2 |
| TC-PAY-149 | `testCreatePaymentIntentAcceptsArrayParameter` | createPaymentIntent 시그니처 (params, idempotencyKey) | Reflection | 파라미터 2개, idempotencyKey 선택적 | P2 |
| TC-PAY-150 | `testCreateSetupIntentAcceptsCustomerIdParameter` | createSetupIntent 시그니처 (customerId) | Reflection | 파라미터 1개, 이름 'customerId' | P2 |
| TC-PAY-151 | `testCancelOldReadyOrdersAcceptsThreeParameters` | cancelOldReadyOrders 시그니처 | Reflection | 파라미터 3개 (payRepository, currentPaymentIntentId, acId) | P2 |
| TC-PAY-152 | `testCanInstantiateStripePaymentService` | Stripe 환경 의존 인스턴스화 (조건부 SKIP) | STRIPE_SECRET_KEY 상수 | `assertInstanceOf` 또는 SKIP | P1 |
| TC-PAY-153 | `testGetClientReturnsStripeClientInstance` | getClient 반환 StripeClient 인스턴스 (조건부 SKIP) | STRIPE_SECRET_KEY 상수 | `assertInstanceOf(StripeClient)` 또는 SKIP | P1 |

---

## 4. Test Execution Results

| 범주 | PASS | SKIP | FAIL | 합계 |
|------|------|------|------|------|
| Feature (PayApiTest) | 0 | 5 | 0 | 5 |
| Feature (PaybackApiTest) | 0 | 3 | 0 | 3 |
| Feature (StripeApiTest) | 0 | 5 | 0 | 5 |
| Unit (AutopayServiceTest) | 19 | 3 | 0 | 22 |
| Unit (PayControllerTest) | 11 | 0 | 0 | 11 |
| Unit (PaybackControllerTest) | 2 | 0 | 0 | 2 |
| Unit (PaymentNotifierTest) | 12 | 0 | 0 | 12 |
| Unit (PaymentServiceTest) | 25 | 3 | 0 | 28 |
| Unit (PaypalTest) | 7 | 0 | 0 | 7 |
| Unit (SimplepayModelTest) | 22 | 0 | 0 | 22 |
| Unit (StripeControllerTest) | 4 | 0 | 0 | 4 |
| Unit (StripePaymentServiceTest) | 13 | 2 | 0 | 15 |
| **합계** | **115** | **21** | **0** | **136** |

최종 실행일: 2026-04-15

---

## 5. Traceability Matrix

| SRS 요구사항 ID | 요구사항명 | 테스트 케이스 ID |
|----------------|----------|----------------|
| FR-PAY-001 | Stripe 신용카드 결제 | TC-PAY-009, TC-PAY-010, TC-PAY-076~077, TC-PAY-082~084, TC-PAY-091~094, TC-PAY-135~153 |
| FR-PAY-002 | Stripe 웹훅 처리 | TC-PAY-011, TC-PAY-012, TC-PAY-013, TC-PAY-138 |
| FR-PAY-003 | 간편결제 (Simplepay) | TC-PAY-001, TC-PAY-002, TC-PAY-003, TC-PAY-044~049, TC-PAY-110~134 |
| FR-PAY-004 | 자동결제 (Autopay) | TC-PAY-005, TC-PAY-014~041, TC-PAY-050 |
| FR-PAY-005 | Naver Pay 연동 | TC-PAY-051 |
| FR-PAY-006 | Toss Pay 연동 | TC-PAY-052 |
| FR-PAY-007 | 인앱 구매 (코인 충전) | TC-PAY-004, TC-PAY-078~081, TC-PAY-093, TC-PAY-095~097 |
| FR-PAY-008 | 페이백 (Payback) | TC-PAY-006, TC-PAY-007, TC-PAY-008, TC-PAY-053, TC-PAY-054 |
| FR-PAY-009 | 코인백 (Coin Back) | TC-PAY-055~065 (PaymentNotifier 알림 관련) |
| NFR-PAY-001 | 멱등성 | TC-PAY-093, TC-PAY-094, TC-PAY-149 |
| NFR-PAY-002 | PG 안정성 | TC-PAY-035, TC-PAY-040, TC-PAY-041 |
| NFR-PAY-003 | 보안 | TC-PAY-009, TC-PAY-010, TC-PAY-011, TC-PAY-012, TC-PAY-013 |

---

## 6. Defects & Issues

| ID | 설명 | 심각도 | 상태 | 비고 |
|----|------|--------|------|------|
| DEF-PAY-001 | Feature 테스트 13건이 MySQL DB 연결 없이 실행 불가 | 낮음 | 허용 | 테스트 환경(SQLite) 기본 동작으로 SKIP 처리 |
| DEF-PAY-002 | AutopayService.checkinCard/autopaySend 외부 PG cURL 의존으로 단위 테스트 불가 | 중간 | 허용 | Mock HTTP Client 도입 시 해결 가능 |
| DEF-PAY-003 | StripePaymentService 인스턴스화가 STRIPE_SECRET_KEY 상수에 의존 | 중간 | 허용 | 환경변수 미설정 환경에서 SKIP |
| DEF-PAY-004 | updateOrderResult 코인 지급 흐름이 CI4 서비스 컨테이너 의존으로 단위 테스트 불가 | 중간 | 미해결 | DI 리팩토링 또는 통합 테스트 환경에서 검증 필요 |
| DEF-PAY-005 | FR-PAY-005 Naver Pay, FR-PAY-006 Toss Pay의 비즈니스 로직 테스트가 메서드 존재 확인 수준에 한정 | 중간 | 미해결 | PG API Mock 기반 테스트 추가 권장 |
| DEF-PAY-006 | PaypalTest 7건(TC-PAY-103~109)은 SRS §1.2 및 API 문서 범위 외다 | 낮음 | 미해결 | Q-02: PayPal 지원 여부 확인 후 SRS 범위 추가 또는 영구 레거시 분리 결정 필요 |

---

## 7. Open Questions

| ID | 질문 | 관련 이슈 |
|----|------|-----------|
| Q-01 | `api/pay/viewSimplepayPassword`는 Routes.php 미등록이지만 CsrfTokenFilter EXCLUDED_PATHS에 존재한다. 레거시 제거 예정인가, Routes.php에 추가해야 하는가? | PAYMENT-DEF-004 |
| Q-02 | `PaypalTest` 7건은 SRS/API 범위 외다. PayPal 지원 여부를 확인하여 SRS 범위 추가 또는 STD 레거시 분리가 필요하다. | PAYMENT-DEF-010 |
| Q-03 | SRS/SDD에 기재된 `POST /api/stripe/confirmPayment`, `POST /api/pay/cancelOrder`, `GET /api/pay/getOrderList`, `GET /api/pay/getOrderDetail`은 Routes.php에 없다. 미구현 상태인가, 레거시 경로를 사용하는가? | PAYMENT-DEF-002 |
| Q-04 | `api/payback/get-list`는 POST 메서드이나 CSRF 면제다. 보안 정책상 의도적인지 확인이 필요하다. | PAYMENT-DEF-004 |

---

## 8. 변경 기록 (Revision History)

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| v1.0 | 2026-04-16 | 최초 작성 — 12개 테스트 파일, 136개 TC 기록 | jypark |
| v1.1 | 2026-04-21 | API ↔ IEEE 대조 리포트 반영 — §2.1 PaypalTest를 "범위 외 (레거시)" 별도 섹션으로 분리(PAYMENT-DEF-010, Q-02), §6 DEF-PAY-006 신설, §7 Open Questions(Q-01~Q-04) 신설 | jypark |
