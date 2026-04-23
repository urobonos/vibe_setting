# API 인증 불일치 EP 분류 및 수정 체크리스트

> 90건 High 인증 불일치 EP를 컨트롤러 코드 기반으로 "공개(72건)" vs "인증 필요(19건)"로 분류하고, Critical 소스 수정 + P1 문서/소스 수정을 수행한 결과

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-15 |
| 유형 | result |
| 상태 | 확정 |

## 내용

### Part A: 공개 EP (AuthFilter EXCLUDED_PATHS 추가 대상) — 72건

컨트롤러 내부에서 사용자 식별 없이 동작하는 EP. EXCLUDED_PATHS에 추가하여 비로그인 접근을 허용해야 함.

### A-1. Chat 모듈 (35건)

| # | EP | 컨트롤러 | 근거 |
|---|-----|---------|------|
| 1 | `GET api/chats/get-list-pc` | ChatController::getListPc | member 미사용, 키워드 기반 목록 |
| 2 | `POST api/chats/get-list-mobile` | ChatController::getListMobile | member 미사용, 모바일 목록 |
| 3 | `POST api/chats/get-list-comment` | ChatController::getListComment | member 미사용, 댓글 목록 |
| 4 | `GET api/chats/get-item` | ChatController::getItem | member 미사용, 아이템 상세 |
| 5 | `POST api/chats/get-item-qna-list` | ChatController::getItemQnaList | is_login 조건부, 비로그인도 공개글 조회 가능 |
| 6 | `POST api/chats/get-posting-list` | ChatController::getPostingList | member 미사용 |
| 7 | `POST api/chats/posting-detail` | ChatController::postingDetail | ac_id ?? null 옵셔널 |
| 8 | `POST api/chats/get-posting-comments` | ChatController::getPostingComments | member 미사용 |
| 9 | `POST api/chats/chat-fail` | ChatController::chatFail | member 미사용, 서버 내부 콜백 |
| 10 | `POST api/chats/chat-timer` | ChatController::chatTimer | member 미사용, room_code 기반 |
| 11 | `POST api/chats/chat-start` | ChatController::chatStart | member 미사용, room_code 기반 |
| 12 | `POST api/chats/chat-time-add` | ChatController::chatTimeAdd | member 미사용, room_code 기반 |
| 13 | `POST api/chats/file-upload` | ChatController::fileUpload | member 미사용 |
| 14 | `POST api/chats/message-log` | ChatController::messageLog | member 미사용, 서버 내부 로깅 |
| 15 | `POST api/chats/message-log-v2` | ChatController::messageLogV2 | member 미사용, 서버 내부 로깅 |
| 16 | `POST api/chats/chat-connect-fail` | ChatController::chatConnectFail | member 미사용, 서버 콜백 |
| 17 | `POST api/chats/chat-cancel` | ChatController::chatCancel | member 미사용, room_code 기반 |
| 18 | `POST api/chats/chat-reject` | ChatController::chatReject | member 미사용, room_code 기반 |
| 19 | `POST api/chats/chat-notify` | ChatController::chatNotify | member 미사용 |
| 20 | `GET api/chats/chat-file-down` | ChatController::chatFileDown | member 미사용, 파일 다운로드 |
| 21 | `POST api/chats/get-remain-time` | ChatController::getRemainTime | member 미사용, ca_id 기반 |
| 22 | `POST api/chats/send-goods-chat-push` | ChatController::sendGoodsChatPush | member 미사용, 서버 내부 FCM |
| 23 | `POST api/chats/send-shop-chat-push` | ChatController::sendShopChatPush | member 미사용, 서버 내부 FCM |
| 24 | `POST api/chats/upload-chat-file` | ChatController::uploadChatFile | member 미사용, S3 업로드 |
| 25 | `POST api/chats/absence-check` | ChatController::absenceCheck | member 미사용, 서버 내부 |
| 26 | `POST api/chats/chat-closed` | ChatController::chatClosed | member 미사용, Hermes 콜백 |
| 27 | `POST api/chats/time-alert` | ChatController::timeAlert | member 미사용, 서버 내부 |
| 28 | `POST api/chats/close-alert` | ChatController::closeAlert | member 미사용, 서버 내부 |
| 29 | `POST api/chats/disconnect-check` | ChatController::disconnectCheck | member 미사용, 서버 내부 |
| 30 | `POST api/chats/check-absence` | ChatController::checkAbsence | member 미사용, 서버 내부 |
| 31 | `POST api/chats/connect-check` | ChatController::connectCheck | member 미사용, 서버 내부 |
| 32 | `POST api/goods-chats/get-estimate` | GoodsChatController::getEstimate | member 미사용, gs_no 기반 |
| 33 | `POST api/goods-chats/cancel-estimate` | GoodsChatController::cancelEstimate | member 미사용 |
| 34 | `POST api/goods-chats/update-estimate-message-id` | GoodsChatController::updateEstimateMessageId | member 미사용 |
| 35 | `POST api/goods-chats/callee-chat-connect` | GoodsChatController::calleeChatConnect | member 미사용, post[ac_id] 파라미터 |

> **주의**: A-1 #22~23 (send-goods-chat-push, send-shop-chat-push)은 이미 CsrfTokenFilter EXCLUDED에 등록됨. AuthFilter EXCLUDED에도 추가 필요.

### A-2. Commerce 모듈 (15건)

| # | EP | 컨트롤러 | 근거 |
|---|-----|---------|------|
| 36 | `GET api/items/get-list-pc` | ItemsController::getListPc | member 미사용, 키워드 검색 |
| 37 | `POST api/items/get-list` | ItemsController::getListMobile | member 미사용, 모바일 목록 |
| 38 | `POST api/items/get-comment` | ItemsController::getListComment | member 미사용, 후기 목록 |
| 39 | `POST api/items/get-search-list-items` | ItemsController::getSearchListItems | member 미사용, 검색 |
| 40 | `POST api/items/get-search-list-goods` | ItemsController::getSearchListGoods | member 미사용, 검색 |
| 41 | `POST api/items/get-posting-list` | ItemsController::getPostingList | member 미사용 |
| 42 | `POST api/items/posting-detail` | ItemsController::postingDetail | ac_id ?? null 옵셔널 |
| 43 | `POST api/items/get-posting-comments` | ItemsController::getPostingComments | login_ac_id ?? '' 옵셔널 |
| 44 | `POST api/goods/get-list-mobile` | GoodsController::getListMobile | member 미사용, 상품 목록 |
| 45 | `POST api/goods/get-goods-faq-list-by-type` | GoodsController::getGoodsFaqListByType | member 미사용, FAQ 조회 |
| 46 | `POST api/goods/addr-second-list` | GoodsController::addrSecondList | member 미사용, 주소 목록 |
| 47 | `POST api/shop/get-shop-items` | ShopController::getShopItems | member 미사용, 대면상품 목록 |
| 48 | `POST api/shop/reservation-calendar` | ShopController::reservationCalendar | member 미사용, 달력 조회 |
| 49 | `POST api/shop/order-reservation-time` | ShopController::orderReservationTime | member 미사용, 시간 조회 |
| 50 | `POST api/shop/view-location-popup` | ShopController::viewLocationPopup | ac_home_set 옵셔널 처리 |

### A-3. Content 모듈 (7건)

| # | EP | 컨트롤러 | 근거 |
|---|-----|---------|------|
| 51 | `GET api/notices` | NoticeController::index | member/ac_id 미사용, 공지 목록 |
| 52 | `GET api/notices/{id}` | NoticeController::show | member/ac_id 미사용, 공지 상세 |
| 53 | `GET api/faqs` | FaqController::index | member/ac_id 미사용, FAQ 목록 |
| 54 | `GET api/faqs/{id}` | FaqController::show | member/ac_id 미사용, FAQ 상세 |
| 55 | `GET api/banners` | BannerController::index | member/ac_id 미사용, 배너 목록 |
| 56 | `GET api/banners/{id}` | BannerController::show | member/ac_id 미사용, 배너 상세 |
| 57 | `POST api/themes/get-theme-list` | ThemeController::getThemeList | member/ac_id 미사용, 테마 목록 |

### A-4. Board 모듈 (4건)

| # | EP | 컨트롤러 | 근거 |
|---|-----|---------|------|
| 58 | `GET api/boards/get-inquiry` | BoardController::getInquiry | member 미사용, 문의 목록 |
| 59 | `GET api/boards/get-notice` | BoardController::getNotice | member 미사용, 공지 목록 |
| 60 | `POST api/boards/insert-recruit` | BoardController::insertRecruit | member 미참조, 비회원 지원 |
| 61 | `GET api/boards/get-posting` | BoardController::getPosting | member 미사용, 포스팅 목록 |

### A-5. Event 모듈 (3건)

| # | EP | 컨트롤러 | 근거 |
|---|-----|---------|------|
| 62 | `GET api/events/get-event` | EventController::getEvent | member 미사용, 이벤트 목록 |
| 63 | `POST api/events/show-event-contents` | EventController::showEventContents | ac_id 미사용, 콘텐츠 조회 |
| 64 | `POST api/events/set-app-cookie` | EventController::setAppCookie | ac_id 미사용, 쿠키 설정 |

### A-6. Service 모듈 (2건)

| # | EP | 컨트롤러 | 근거 |
|---|-----|---------|------|
| 65 | `POST api/services/get-service-list-mobile` | ServiceController::getServiceListMobile | ac_id 미사용, 서비스 목록 |
| 66 | `POST api/services/get-service-list-mobile-new` | ServiceController::getServiceListMobileNew | ac_id 미사용, 서비스 목록 |

### A-7. Social 모듈 (3건)

| # | EP | 컨트롤러 | 근거 |
|---|-----|---------|------|
| 67 | `POST api/sns-shares/profile-sns` | SnsShareController::profileSns | ac_id 미사용, OG 렌더링 |
| 68 | `POST api/sns-shares/board-sns` | SnsShareController::boardSns | ac_id 미사용, OG 렌더링 |
| 69 | `POST api/group-lists/get-list-group` | GrouplistController::getListGroup | ac_id 미사용, 그룹 목록 |

### A-8. Reservation 모듈 (1건)

| # | EP | 컨트롤러 | 근거 |
|---|-----|---------|------|
| 70 | `POST api/calendars/calendar` | CalendarController::calendar | ac_id 미사용, CalendarHelper만 호출 |

### A-9. Call 모듈 (1건)

| # | EP | 컨트롤러 | 근거 |
|---|-----|---------|------|
| 71 | `POST api/calls/get-call-connect-able-list` | CallController::getCallConnectAbleList | member 미사용, 연결 가능 목록 |

### A-10. ShopChat 모듈 (1건)

| # | EP | 컨트롤러 | 근거 |
|---|-----|---------|------|
| 72 | `POST api/shop-chats/callee-chat-connect` | ShopChatController::calleeChatConnect | member 미사용, post[ac_id] 파라미터 |

---

## Part B: 인증 필요 EP (MD/YAML 문서 수정 대상) — 19건

컨트롤러 내부에서 ac_id / member를 사용하는 EP. MD/YAML 인증 표기를 `—`(공개)에서 `🔒 jwt`로 수정해야 함.

### B-1. Commerce 모듈 (10건)

| # | EP | 컨트롤러 | 근거 | 현재 MD |
|---|-----|---------|------|---------|
| 1 | `POST api/goods/order-info` | GoodsController::orderInfo | `checkNeedLogin()` 호출 | `—` |
| 2 | `POST api/goods/get-buy-list` | GoodsController::getBuyList | `checkNeedLogin()` 호출, ac_id 암호화 | `—` |
| 3 | `POST api/goods/goods-regist-info` | GoodsController::goodsRegistInfo | `checkNeedLogin()` 호출 | `—` |
| 4 | `POST api/goods/get-cancel-list` | GoodsController::getCancelList | `checkNeedLogin()` 호출, ac_id 암호화 | `—` |
| 5 | `POST api/goods/update-goods-view` | GoodsController::updateGoodsView | `checkNeedLogin()` 호출 | `—` |
| 6 | `POST api/goods/memosave` | GoodsController::memosave | `checkNeedLogin()` 호출 | `—` |
| 7 | `DELETE api/goods/delete-opt` | GoodsController::deleteOpt | `checkNeedLogin()` 호출 | `—` |
| 8 | `DELETE api/goods/delete-file` | GoodsController::deleteFile | `checkNeedLogin()` 호출 | `—` |
| 9 | `POST api/goods/get-my-class` | GoodsController::getMyClass | `checkNeedLogin()` 호출, ac_id 암호화 | `—` |
| 10 | `POST api/goods/get-my-class-detail` | GoodsController::getmyclassDetail | `checkNeedLogin()` 호출, ac_id 암호화 | `—` |

### B-2. Chat 모듈 (6건)

| # | EP | 컨트롤러 | 근거 | 현재 MD |
|---|-----|---------|------|---------|
| 11 | `POST api/chats/get-callee-status` | ChatController::getCalleeStatus | `$this->member['cr_code']` 직접 접근 | `—` |
| 12 | `POST api/chats/get-remain-coin` | ChatController::getRemainCoin | `$this->member['ac_remain_coin']` 반환 | `—` |
| 13 | `POST api/chats/chat-request-time-add` | ChatController::chatRequestTimeAdd | `$this->member['ac_remain_coin']`, `ac_nick` 접근 | `—` |
| 14 | `POST api/chats/mark-as-read` | ChatController::markAsRead | `$this->member['ac_id']` 직접 접근 | `—` |
| 15 | `POST api/chats/update-greeting` | ChatController::updateGreeting | 상담사 안내말 수정, ce_code 복호화 | `—` |
| 16 | `POST api/goods-chats/send-estimate` | GoodsChatController::sendEstimate | `$this->member['it_code']` 직접 접근 | `—` |

### B-3. Board 모듈 (1건)

| # | EP | 컨트롤러 | 근거 | 현재 MD |
|---|-----|---------|------|---------|
| 17 | `POST api/boards/insert-inquiry` | BoardController::insertInquiry | `$this->member` 전달하여 문의 데이터 구성 | `—` |

### B-4. Commerce/Items 모듈 (1건)

| # | EP | 컨트롤러 | 근거 | 현재 MD |
|---|-----|---------|------|---------|
| 18 | `POST api/items/get-item-qna-list` | ItemsController::getItemQnaList | `$this->is_login`, `$this->member['ac_id']`, `ce_code` 조건부 사용. 비밀글 마스킹 로직 의존 | `—` → `🔒 jwt (optional)` |

---

## Part C: 특수 처리 EP — 5건

### C-1. 내부 서비스 EP (apikey 인증 검토)

| # | EP | 현재 | 권장 |
|---|-----|------|------|
| 1 | `POST api/hermes/get-on-call-callee` | auth 필터 (jwt) | `auth:apikey` — 내부 서비스 전용 |
| 2 | `POST api/hermes/get-on-call-callee-hecode` | auth 필터 (jwt) | `auth:apikey` — 내부 서비스 전용 |
| 3 | `POST api/fcm/index` | auth 필터 (jwt) | `auth:apikey` or jwt 유지 — FCM 토큰 갱신 |
| 4 | `POST api/fcm/korea-callee-fcm` | auth 필터 (jwt) | `auth:apikey` — 서버-서버 FCM 발송 |

### C-2. 반공개 EP (설계 의도 확인 필요)

| # | EP | 현재 | 비고 |
|---|-----|------|------|
| 5 | `GET api/reservations/get-schedule` | auth 필터 (jwt) | ac_id ?? '' 옵셔널 처리. 비로그인도 기술적 동작. 서비스 정책에 따라 결정 |

---

## Part D: Critical 수정 (Routes.php 필터 누락) — 8건

### D-1. AuthFilter URL 케이스 수정 (4건)

| 현재 (AuthFilter) | 수정 후 | 파일 |
|-------------------|---------|------|
| `api/pay/view-simplepay-regist` | `api/pay/viewSimplepayRegist` | AuthFilter.php:67 |
| `api/pay/view-simplepay-card` | `api/pay/viewSimplepayCard` | AuthFilter.php:68 |
| `api/pay/view-simplepay-update` | `api/pay/viewSimplepayUpdate` | AuthFilter.php:69 |
| `api/pay/view-simplepay-password` | `api/pay/viewSimplepayPassword` | AuthFilter.php:70 |

### D-2. Routes role:callee 필터 추가 (6건)

| EP | 모듈 Routes 파일 | 수정 내용 |
|----|-----------------|----------|
| `api/calls/get-callee-like-list` | Call/Config/Routes.php | `['filter' => 'role:callee']` 추가 |
| `api/calls/get-callee-ing-list` | Call/Config/Routes.php | `['filter' => 'role:callee']` 추가 |
| `api/calls/callee-online-call` | Call/Config/Routes.php | `['filter' => 'role:callee']` 추가 |
| `api/rejects/get-callee-reject-list` | Service/Config/Routes.php | `['filter' => 'role:callee']` 추가 |
| `api/reservations/get-callee-reservation-list` | Reservation/Config/Routes.php | `['filter' => 'role:callee']` 추가 |
| `api/o2o-calendars/o2o-calendar` | Reservation/Config/Routes.php | `['filter' => 'role:callee']` 추가 |

### D-3. 문서-소스 역방향 불일치 (1건)

| EP | 현재 MD | 수정 후 MD |
|----|---------|----------|
| `api/callees/callee-goods-search` | `—` (공개) | `🔒 jwt, role:callee` |

---

## 체크리스트

### Phase 3-1: Critical 소스 수정 (P0) — 완료
- [x] AuthFilter.php — EXCLUDED_PATHS URL 케이스 4건 수정 (camelCase + PascalCase 레거시)
- [x] Call/Config/Routes.php — role:callee 필터 3건 추가
- [x] Service/Config/Routes.php — role:callee 필터 1건 추가
- [x] Reservation/Config/Routes.php — role:callee 필터 2건 추가

### Phase 3-2: AuthFilter EXCLUDED_PATHS 추가 (P1) — 완료
- [x] AuthFilter.php — Part A 72건 공개 EP 추가 (모듈별 그룹화)

### Phase 3-3: MD/YAML 문서 수정 (P1) — 완료
- [x] callee-api.md/yaml — callee-goods-search 인증 `—` → `🔒 jwt, role:callee`
- [x] goods-api.md/yaml — 10건 EP 인증 `—` → `🔒 jwt`
- [x] chat-api.md/yaml — 5건 EP 인증 `—` → `🔒 jwt`
- [x] goodschat-api.md/yaml — send-estimate 인증 `—` → `🔒 jwt`
- [x] board-api.md/yaml — insert-inquiry 인증 `—` → `🔒 jwt`
- [x] items-api.md/yaml — get-item-qna-list 인증 `—` → `🔒 jwt (optional)`

### Phase 3-4: Medium 문서 수정 (P2) — 미착수
- [ ] auth-api.md — logout 상세설명 "인증: 불필요(공개)" → "인증: jwt 필수"
- [ ] 전 모듈 MD — Bearer 헤더 폴백 표기 제거 (CLAUDE.md: Bearer 폴백 없음)

### Phase 3-5: 특수 EP 설계 확인 (P2) — 미착수
- [ ] hermes EP 2건 — apikey 인증 전환 여부 결정
- [ ] fcm EP 2건 — apikey vs jwt 인증 결정
- [ ] reservations/get-schedule — 공개 vs 인증 결정

### 검증 — 완료
- [x] Unit 테스트 통과: 1022 tests, 1192 assertions, 0 failures

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-15 | 최초 작성: 90건 EP 분류 + P0/P1 수정 완료 | jypark |
