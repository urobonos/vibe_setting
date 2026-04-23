# API 필드 매핑 — FFS 교정본

> FFS의 API 필드명은 추정값이므로 이 문서의 값을 사용한다.
> as-is(hongcafe-japan) 실제 필드명 기준.

## 인증

### 로그인 (/api/member/loginuser)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| email | **ac_id** | request |
| password | **ac_password** | request |
| success | **response === 'success'** | response |
| message | **msg** | response |
| token | **data.ac_code** (사용자 코드) | response |

### 회원가입 (/api/member/joinuser)

| FFS 추정 | as-is 실제 |
|---------|-----------|
| email | **ac_id** |
| password | **ac_password** |
| confirmPassword | **ac_password_re** |
| nickname | **ac_nick** |
| phone | **cr_phone** |
| countryCode | **ac_country** |
| dobYear | **ac_birth_year** |
| dobMonth | **ac_birth_month** |
| dobDay | **ac_birth_day** |
| agreeTerms | **agree_service** |
| agreePrivacy | **agree_privacy** |
| agreeAge | **agree_age** |

### 이메일 유니크 체크 (/api/member/checkid)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| email | **ac_id** | request |
| — | **response === 'success'** | response (사용 가능) |
| — | **response === 'error'** + **msg** | response (이미 사용 중) |

### 닉네임 유니크 체크 (/api/member/checknick)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| nickname | **ac_nick** | request |
| — | **response === 'success'** | response (사용 가능) |
| — | **msg** | response (금칙어 등 에러 메시지) |

### 비밀번호 형식 검증 (/api/member/checkpassword)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| password | **ac_password** | request |
| — | **response === 'success'** | response |

### 비밀번호 확인 일치 (/api/member/checkpasswordre)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| password | **ac_password** | request |
| confirmPassword | **ac_password_re** | request |
| — | **response === 'success'** | response |

### 이메일 인증 발송 (/api/member/sendMailCert)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| email | **ac_id** | request |
| — | **response === 'success'** | response (인증코드 발송됨) |

### 이메일 인증 확인 (/api/member/confirmMailCert)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| email | **ac_id** | request |
| verificationCode | **ac_cert_num** | request |
| — | **response === 'success'** | response |

### SMS 인증 (/api/member/sendglobalcert → confirmglobalcert)

| FFS 추정 | as-is 실제 |
|---------|-----------|
| phone | **cr_phone** |
| countryCode | **ac_country** |
| verificationCode | **ac_cert_num** |

### 아이디 찾기 (/api/member/findidcert → confirmidcert)

| FFS 추정 | as-is 실제 |
|---------|-----------|
| phone | **cr_phone** |
| countryCode | **ac_country** |
| verificationCode | **ac_cert_num** |

### 비밀번호 찾기 (/api/member/findpasswordcert)

| FFS 추정 | as-is 실제 |
|---------|-----------|
| email | **ac_id** |
| phone | **cr_phone** |

### 닉네임 변경 (/api/member/changenick)

| FFS 추정 | as-is 실제 |
|---------|-----------|
| nickname | **ac_nick** |

### 비밀번호 변경 (/api/member/changepasswd)

| FFS 추정 | as-is 실제 |
|---------|-----------|
| currentPassword | **ac_password_old** |
| newPassword | **ac_password** |
| confirmPassword | **ac_password_re** |

## 상품/상담사

### 목록 조회 (/api/items/getListMobile)

| FFS 추정 | as-is 실제 |
|---------|-----------|
| offset | **offset** |
| limit | **limit** |
| category | **cate** (= cate code) |
| sort | **sort_type** |
| styleFilter | **tag_style** (콤마 구분) |
| fieldFilter | **tag_field** (콤마 구분) |
| consultationType | **sale_type** (call/chat) |

### 상세 조회 (/api/items/getItem)

| FFS 추정 | as-is 실제 |
|---------|-----------|
| counselorId | **it_code** |

## 결제

### Stripe 결제 (/api/stripe/createPaymentIntent)

| FFS 추정 | as-is 실제 |
|---------|-----------|
| amount | **pd_code** (상품 코드, 금액은 서버에서 계산) |
| currency | 서버에서 국가 기반 자동 설정 |
| couponCode | **cu_code** |

---

## 상품/상담사 목록 (Items) — 확장

### 목록 조회 모바일 (/api/items/getListMobile)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| offset | **offset** | request |
| limit | **limit** (기본값 24) | request |
| category | **cate** (카테고리 코드, 빈값이면 전체) | request |
| sort | **order** (suggest/itemNew/newRegist/recent/calling) | request |
| part | **part** (hot = 인기) | request |
| keyword | **keyword** (필수, 검색어 또는 빈 문자열) | request |
| styleFilter | **style** (콤마 구분) | request |
| counselField | **counsel** (콤마 구분) | request |
| — | **response === 'success'** | response |
| — | **items[]** | response (상담사 배열) |
| — | **next** (boolean, 다음 페이지 존재 여부) | response |

**items[] 응답 필드 (실제 DB 컬럼):**

| 필드명 | 설명 |
|--------|------|
| **it_code** | 아이템(상담사) 고유 코드 |
| **it_nick** | 상담사 닉네임 |
| **it_nick_kana** | 상담사 닉네임 카나 (일본어) |
| **it_main_pic** | 프로필 이미지 URL |
| **it_subject** | 한줄 소개 |
| **it_category_name** | 카테고리명 (타로, 사주, 신점 등) |
| **it_category_code** | 카테고리 코드 |
| **it_060_code** | 060 상담 번호 |
| **it_coin_price** | 코인 분당 단가 |
| **it_tag[]** | 태그 배열 (서버에서 콤마 split) |
| **it_notice_string_cnt** | 공지 문자열 길이 |
| **it_notice_new** | 공지 신규 여부 (시간 차이) |
| **it_counsel_field** | 상담 분야 (JSON 디코딩) |
| **it_counsel_field_search** | 상담 분야 검색용 (콤마 split) |
| **it_style** | 상담 스타일 (콤마 split) |
| **it_win_point** | 평점 (3개월 기준 계산) |
| **it_cmt_cnt** | 누적 후기 수 |
| **it_comment[]** | 후기 배열 (리스트 내 프리뷰) |
| **call_status** | 통화 상태 (on/off) |
| **call_type** | 통화 유형 (standby/chat 등) |
| **item_label{}** | 라벨 객체 (partner/star/review/counsel) |
| **view_win_point** | 표시용 평점 |
| **view_win_comment** | 표시용 후기 수 |
| **view_like_cnt** | 표시용 좋아요 수 |
| **he_code** | Hermes 상담사 코드 |
| **ce_code** | 상담사(callee) 코드 |

### 상세 조회 (/api/items/getItem)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| counselorId | **it_code** | request |
| siteCode | **st_code** (선택, 기본값 ST_CODE) | request |

### 좋아요 목록 (/api/items/getLikeList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ac_id** | request (로그인 필수) |
| — | **limit** (기본값 24) | request |
| — | **offset** | request |
| — | **items[]** | response |
| — | **next** | response |

### 좋아요 추가/삭제 (/api/items/itemAddLike, /api/items/itemDeleteLike)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **it_code** | request |
| — | **ac_id** | request (서버에서 세션 확인) |

### 좋아요 전체 삭제 (/api/items/itemAllDeleteLike)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | (로그인 세션만 필요) | request |

### Q&A 목록 (/api/items/getItemQnaList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **it_code** | request |
| — | **limit** | request |
| — | **offset** | request |
| — | **items[]** | response |

### Q&A 작성 (/api/items/insertItemQna)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **it_code** | request |
| — | **qa_content** | request (문의 내용) |

### 게시글 목록 (/api/items/getPostingList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ce_code** | request (상담사 코드) |
| — | **limit** | request |
| — | **offset** | request |

### 게시글 상세 (/api/items/postingDetail)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **bc_id** | request (게시글 ID) |

### 가격 수정 (/api/items/saveItemPrice) — Callee 전용

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **it_code** | request |
| — | **it_coin_price** | request (코인 분당 단가) |

---

## 전화 상담 (Call)

### 전화 연결 (/api/call/callConnect)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **it_code** | request (필수) |
| — | **country_code** | request (필수, 국가 코드) |
| — | **st_code** | request (선택, 기본값 ST_CODE) |
| — | **response === 'success'** | response |
| — | **connect_number** | response (전화 연결 번호 — `tel:` 프로토콜 사용) |
| — | **is_login === 'false'** | response (미로그인 시) |
| — | **msg** | response (에러 메시지) |

### 전화 팝업 정보 (/api/call/getPopupInfo)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **it_code** | request (필수) |
| — | **st_code** | request (선택) |
| — | **item{}** | response |

**item{} 응답 필드:**

| 필드명 | 설명 |
|--------|------|
| **it_nick** | 상담사 닉네임 |
| **it_nick_kana** | 닉네임 카나 |
| **it_coin_price** | 코인 분당 단가 |
| **it_coin_price_text** | 포맷된 단가 (number_format) |
| **it_category_name** | 카테고리명 |
| **it_category_code** | 카테고리 코드 |
| **it_main_pic** | 프로필 이미지 |
| **it_nick_icon** | 닉네임 아이콘 |
| **remain_time** | 남은 통화 가능 시간 (포맷된 문자열) |
| **remain_coin** | 남은 코인 (포맷) |
| **ac_id** | 로그인 사용자 ID (미로그인 시 false) |
| **coin_number** | 코인 전화 번호 |
| **paybackMark** | 페이백 이벤트 적용 여부 (boolean) |
| **specialPriceMark** | 특가 이벤트 적용 여부 (boolean) |

### 알림 등록 (/api/call/insertAlarm)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **item_code** | request (필수, it_code 또는 ch_code) |
| — | **ra_type** | request (필수, 'comeback' 또는 'consulting') |
| — | **item_flag** | request (선택, 'call'/'chat'/'video', 기본 'call') |
| — | **st_code** | request (선택) |

### 알림 삭제 (/api/call/deleteAlarm)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **item_code** | request (필수) |
| — | **ra_type** | request (필수) |
| — | **item_flag** | request (선택) |

### 좋아요 추가/삭제 (/api/call/callerAddLike, /api/call/callerDeleteLike)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **it_code** | request |

### 좋아요 전체 삭제 (/api/call/allDeleteLike)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | (로그인 세션만 필요) | request |

### 좋아요 목록 (/api/call/getCalleeLikeList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ac_id** | request |
| — | **limit** | request |
| — | **offset** | request |

### 상담 중 목록 (/api/call/getCalleeIngList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ac_id** | request |
| — | **limit** | request |
| — | **offset** | request |

### 메모 저장 (/api/call/memosave)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **it_code** | request |
| — | **memo** | request (메모 내용) |

### 상담사 온라인 상태 전환 (/api/call/calleeOnlineCall)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **it_online** | request ('on'/'off') |

---

## 채팅 상담 (Chat)

### 채팅 목록 모바일 (/api/chat/getListMobile)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **keyword** | request (필수) |
| — | **order** | request (suggest/itemNew/recent/calling) |
| — | **part** | request (hot = 인기) |
| — | **cate** | request (카테고리) |
| — | **limit** (기본값 24) | request |
| — | **offset** | request |
| — | **counsel** | request (콤마 구분 상담 분야 필터) |
| — | **style** | request (콤마 구분 스타일 필터) |
| — | **items[]** | response |
| — | **next** | response |

**items[] 채팅 고유 필드:**

| 필드명 | 설명 |
|--------|------|
| **ch_code** | 채팅 아이템 코드 |
| **ch_win_point** | 채팅 평점 |
| **ch_cm_point** | 채팅 누적 포인트 |
| **ch_point_cnt** | 채팅 평가 수 |

### 채팅 프로필 (/api/chat/getItem)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **it_code** | request (필수) |
| — | **st_code** | request (선택) |
| — | **items** | response (상담사 상세 객체) |

### 채팅 연결 시작 (/api/chat/chatConnect)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ce_code** | request (필수, 상담사 코드) |
| — | **country_code** | request |
| — | **duration** | request (요청 통화 시간) |
| — | **st_code** | request (선택) |
| — | **response** | response ('success'/'fail') |
| — | **result** | response (실패 사유: 'item_empty'/'away'/'reject'/'on_call'/'same') |
| — | **room_code** | response (성공 시 채팅방 코드) |
| — | **cr_room_code** | response (상담사용 채팅방 코드) |

### 채팅 세션 시작 (/api/chat/chatStart)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **room_code** | request (필수) |

### 과금 타이머 (/api/chat/chatTimer)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **room_code** | request |

### 잔여 코인 (/api/chat/getRemainCoin)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ac_id** | request (필수) |
| — | **ac_remain_coin** | response (잔여 코인) |

### 잔여 시간 (/api/chat/getRemainTime)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **room_code** | request |

### 시간 연장 요청 — 회원 (/api/chat/chatRequestTimeAdd)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **room_code** | request (필수) |
| — | **add_time** | request (연장 분 단위) |

### 시간 연장 승인/거절 — 상담사 (/api/chat/chatTimeAdd)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **room_code** | request (필수) |
| — | **status** | request (1=승인, 그 외=거절) |

### 메시지 로깅 (/api/chat/messageLog, /api/chat/messageLogV2)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **room_code** | request (필수) |
| — | **message** | request (필수, 메시지 내용) |

### 읽음 처리 (/api/chat/markAsRead)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **room_code** | request (필수) |
| — | **groupChannel** | request (필수, SendBird 채널) |

### 파일 업로드 (/api/chat/fileUpload)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **fileId** | request (FILE, 이미지 파일) |

### 채팅 종료/취소/실패 (/api/chat/chatClosed, /api/chat/chatCancel, /api/chat/chatFail)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **room_code** | request |

### 채팅 거절 — 상담사 (/api/chat/chatReject)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **room_code** | request |

### 상담사 상태 확인 (/api/chat/getCalleeStatus)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ce_code** | request |

### 부재 확인 (/api/chat/absenceCheck)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ce_code** | request |

### 재연결/연결 확인 (/api/chat/reConnect, /api/chat/connectCheck)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **room_code** | request |

### 좋아요 추가/삭제 (/api/chat/chatAddLike, /api/chat/chatDeleteLike)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ch_code** | request (채팅 아이템 코드) |

### 좋아요 목록 (/api/chat/getLikeList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ac_id** | request |
| — | **limit** | request |
| — | **offset** | request |

### 인사말 수정 — 상담사 (/api/chat/updateGreeting)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **greeting** | request (인사말 내용) |

### 상품 채팅 푸시 (/api/chat/sendGoodsChatPush)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **gs_no** | request (상품 주문 번호) |

### 숍 채팅 푸시 (/api/chat/sendShopChatPush)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **os_no** | request (숍 주문 번호) |

---

## 결제 (Pay/Coin) — 확장

### Stripe 결제 (/api/stripe/createPaymentIntent)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **chk_product** | request (필수, pd_code 상품 코드) |
| — | **cui_code** | request (선택, 쿠폰 인스턴스 코드) |
| — | **cu_code** | request (선택, 쿠폰 코드) |
| — | **pd_type** | request (선택, 'goods'/'shop'/빈값=코인) |
| — | **gd_code** | request (pd_type=goods 시, 상품 코드) |
| — | **gs_no** | request (pd_type=goods 시, 주문 번호) |
| — | **sh_code** | request (pd_type=shop 시, 숍 코드) |
| — | **pd_name** | request (pd_type 지정 시, 상품명) |
| — | **fail_url** | request (pd_type 지정 시, 실패 리다이렉트 URL) |
| — | **pay_method** | request (선택) |
| — | **simplepay** | request ('true' 시 간편결제 카드 사용) |
| — | **pt_callee_ce_code** | request (선택, 추천 상담사 코드) |
| — | **pt_caller_ac_nick** | request (선택, 추천인 닉네임) |
| — | **clientSecret** | response (Stripe client_secret) |

### Stripe 카드 등록 (/api/stripe/createSetupIntent)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **type** | request |
| — | **clientSecret** | response (SetupIntent client_secret) |

### 간편결제 — 저장 카드 조회 (/api/pay/GetMyCard) — 한국 전용

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **email** | request (ac_id와 일치 확인) |
| — | **data{}** | response |
| — | **birth_check** | response (생년월일 등록 여부) |

**data{} 응답 필드 (민감정보 필터링 후):**

| 필드명 | 설명 |
|--------|------|
| **sp_no** | 간편결제 등록 번호 |
| **sp_card_name** | 카드사 이름 |
| **sp_card_no** | 카드번호 끝 4자리 |
| **last_update_date** | 마지막 수정일 |

### 간편결제 — 카드 등록/수정 (/api/pay/SaveSimplepay) — 한국 전용

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **act** | request (필수, 'registSimeplePay'/'updateSimeplePayPassword'/'checkSimeplePayPassword') |
| — | **sp_card_no** | request (카드번호 16자리) |
| — | **cr_birth_year** | request (생년월일 8자리 YYYYMMDD) |
| — | **sp_exp_year** | request (유효기간 연도) |
| — | **sp_exp_month** | request (유효기간 월) |
| — | **sp_card_pwd** | request (카드 비밀번호 앞 2자리) |
| — | **sp_password** | request (결제 비밀번호 6자리) |
| — | **cr_phone** | request (전화번호) |
| — | **cr_phone_cert** | request (전화 인증 여부) |
| — | **sp_type** | request ('insert'/'update') |

### 간편결제 — 카드 삭제 (/api/pay/DeleteSimplepay) — 한국 전용

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **sp_no** | request (필수, 간편결제 등록 번호) |

### 자동충전 카드 삭제 (/api/pay/delAutoPayCard)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | (로그인 세션만 필요) | request |

### 네이버페이 결제 (/api/pay/Naverpayorder) — 한국 전용

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **chk_product** | request (필수, pd_code) |
| — | **cu_code** | request (선택, 쿠폰 코드) |
| — | **coupon** | request (선택, 쿠폰 인스턴스 코드) |
| — | **item_code** | request (선택) |
| — | **ge_genre** | request (선택, 'mom_class' 등 할인 상품 분류) |
| — | **gd_category_code** | request (선택, 'academyclass' 등) |
| — | **gd_dis_price** | request (할인가, ge_genre 지정 시) |
| — | **gd_price** | request (원가, ge_genre 지정 시) |
| — | **od_code** | response (주문 코드) |
| — | **od_pay_amount** | response (결제 금액) |
| — | **pd_code** | response (상품 코드) |
| — | **pd_name** | response (상품명) |

### 토스페이 결제 (/api/pay/Tosspayorder) — 한국 전용

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **chk_product** | request (필수) |
| — | **cu_code** | request (선택) |
| — | **coupon** | request (선택) |
| — | **item_code** | request (선택) |
| — | **od_code** | response |
| — | **od_pay_amount** | response |

### 카카오페이 결제 (/api/pay/kakaopayorder) — 한국 전용

네이버페이/토스페이와 동일 구조. `pg_code = 'kakao_pay'`.

### 인앱 코인 구매 (/api/pay/insertInAppCoinOrder)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **chk_product** | request (pd_code) |
| — | **receipt** | request (인앱결제 영수증) |

---

## 마이페이지 (Mypage)

### 상담 이력 (/api/mypage/getCounselList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** (기본값 10) | request |
| — | **offset** | request |
| — | **items[]** | response |
| — | **next** (boolean) | response |

**items[] 응답 필드:**

| 필드명 | 설명 |
|--------|------|
| **ca_type** | 상담 유형 코드 |
| **ca_type_name** | 상담 유형 한글명 (서버에서 변환) |
| **ca_duration** | 상담 시간 (초) |
| **ca_duration_name** | 상담 시간 포맷 (서버에서 변환) |
| **ca_request_time** | 상담 요청 시각 |
| **ca_request_ymd** | 날짜 (Y.m.d) |
| **it_nick** | 상담사 닉네임 |
| **it_main_pic** | 상담사 프로필 이미지 |
| **it_code** | 아이템 코드 |

### 코인 이력 (/api/mypage/getCoinList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **term** | request (선택, 기간 필터) |
| — | **st_code** | request (선택) |
| — | **limit** (기본값 10) | request |
| — | **offset** | request |
| — | **items[]** | response |
| — | **next** | response |

**items[] 응답 필드:**

| 필드명 | 설명 |
|--------|------|
| **ci_type** | 코인 유형 ('use'/'charge'/'refund'/'return') |
| **ci_charge_type** | 충전 유형 ('pay'/'free'/'event') |
| **ci_category** | 카테고리 ('adminpay' 등) |
| **ci_use_total** | 사용 코인 |
| **ci_charge_total** | 충전 코인 |
| **ci_current** | 잔여 코인 |
| **ci_content** | 내용 |
| **regist_date** | 등록일 |
| **regist_ymd** | 날짜 (Y.m.d, 서버 변환) |
| **regist_hi** | 시간 (H:i, 서버 변환) |
| **type** | 표시용 유형명 |
| **coin_type** | 표시용 코인 유형명 |
| **coin** | 표시용 코인 수량 (포맷) |
| **desc** | 부가 설명 |
| **isAdd** | 증감 여부 (boolean) |
| **current** | 잔여 코인 (포맷) |

### 코인 이력 상세 (/api/mypage/getMyCoinHistoryDetail)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ci_no** | request (코인 이력 번호) |
| — | **detailType** | request ('use'/'charge'/'refund'/'return') |

### 결제 이력 (/api/mypage/getPayList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **term** | request (선택) |
| — | **st_code** | request (선택) |
| — | **limit** (기본값 10) | request |
| — | **offset** | request |
| — | **items[]** | response |
| — | **next** | response |

**items[] 응답 필드:**

| 필드명 | 설명 |
|--------|------|
| **ci_type** | 유형 ('charge'/'refund'/'part_refund'/'paid'/'cancelled') |
| **od_pay_amount** | 결제 금액 |
| **od_refund_amount** | 환불 금액 |
| **od_pay_method** | 결제 수단 코드 |
| **regist_date** | 등록일 |
| **regist_ymd** | 날짜 (Y.m.d) |
| **regist_hi** | 시간 (H:i) |

### 내 상담 문의 (/api/mypage/getMyQuestion)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** (기본값 10) | request |
| — | **offset** | request |
| — | **items[]** | response |

**items[] 응답 필드:**

| 필드명 | 설명 |
|--------|------|
| **qa_reply** | 답변 내용 (있으면 '답변완료', 없으면 '답변대기') |
| **reply_status** | 상태 텍스트 |
| **regist_date_day** | 작성일 (Y.m.d) |
| **regist_date_time** | 작성시간 (H:i) |
| **reply_date_day** | 답변일 |
| **reply_date_time** | 답변시간 |

### 내 후기 수 (/api/mypage/getMyCommentCnt)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **st_code** | request (선택) |

### 내 후기 목록 (/api/mypage/getMyCommentList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |
| — | **items[]** | response |

### 후기 작성 가능 목록 (/api/mypage/getMyCommentAbleList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |
| — | **items[]** | response |

### 리뷰 작성 (/api/mypage/insertMyComment)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **it_code** | request |
| — | **cm_content** | request (후기 내용) |
| — | **cm_point** | request (평점) |
| — | **cm_counsel_field** | request (선택, 상담 분야) |
| — | **cm_style** | request (선택, 스타일) |
| — | **cm_photo** | request (선택, FILE 이미지) |

### 첫 리뷰 쿠폰 (/api/mypage/couponIssueByFirstCommentWrite)

서버 내부 호출. insertMyComment 성공 후 자동 실행.

### 알림 목록 (/api/mypage/getMyAlarm)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** (기본값 10) | request |
| — | **offset** | request |
| — | **items[]** | response |
| — | **next** | response |

**items[] 응답 필드:**

| 필드명 | 설명 |
|--------|------|
| **al_part** | 알림 파트 ('notice'/'after'/'qna'/'goods') |
| **al_title** | 알림 제목 (서버에서 파트별 변환) |
| **al_content** | 알림 내용 |
| **al_link** | 이동 URL |
| **regist_day** | 날짜 (Y.m.d) |
| **regist_time** | 시간 (H:i) |

### 자동충전 규칙 저장 (/api/mypage/AutopayRuleSave)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **pd_code** | request (충전 금액 상품 코드) |
| — | **min_coin** | request (잔액 기준값) |

### 자동충전 카드 저장 (/api/mypage/AutopayCardSave)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | Stripe SetupIntent 플로우와 동일 | request |

### 자동충전 토글 (/api/mypage/AutopayUsechange)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ap_use** | request ('Y'/'N') |

### 쿠폰 등록 (/api/mypage/Registcoupon)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **cui_code** | request (필수, 쿠폰 인스턴스 코드) |
| — | **type** | response (쿠폰 유형) |
| — | **amount** | response (보상 금액) |

**특수 응답**: `response === 'couponAlready'` — 이미 등록된 쿠폰

### 쿠폰 사용 (코인 전환) (/api/mypage/insertCoinByCoupon)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **cui_code** | request |
| — | **type** | response (rewards/shop) |
| — | **amount** | response (지급 코인) |

### 내 쿠폰 목록 (/api/mypage/getMyCouponList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** (기본값 10) | request |
| — | **offset** | request |
| — | **items[]** | response |
| — | **next** | response |

### 리워드 이력 (/api/mypage/getRewardHistory)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |

### 채팅 이력 (/api/mypage/getChatList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |
| — | **items[]** | response |
| — | **next** | response |

### 영상통화 이력 (/api/mypage/getVideoList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |

---

## 리뷰/댓글 (Comment)

### 상품별 댓글 조회 (/api/comment/getItemComment)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **item_code** | request (필수, it_code) |
| — | **keyword** | request (필수) |
| — | **limit** (기본값 20) | request |
| — | **offset** | request |
| — | **type** | request (선택, 'best'/'photo') |
| — | **comment_keyword** | request (선택, '#태그' 또는 검색어) |
| — | **items[]** | response |
| — | **total** | response (전체 댓글 수, 포맷됨) |
| — | **next** | response |
| — | **isFixedItem** | response ('Y'/'N', 고정 후기 존재 여부) |

**items[] 응답 필드:**

| 필드명 | 설명 |
|--------|------|
| **cm_no** | 댓글 번호 |
| **cm_content** | 댓글 내용 |
| **cm_point** | 평점 |
| **cm_counsel_field** | 상담 분야 배열 (서버에서 콤마 split) |
| **cm_style** | 스타일 배열 (서버에서 콤마 split) |
| **cm_child_exist** | 답글 존재 여부 ('y'/'n') |
| **cm_reply[]** | 답글 배열 |
| **cm_gubun_code** | 작성자 코드 (cr_code 또는 ce_code) |
| **regist_date** | 등록일 (Y.m.d) |
| **is_fixed** | 고정 여부 ('Y'/'N') |
| **counselTagSearchMark[]** | 상담 태그 활성 표시 |
| **styleTagSearchMark[]** | 스타일 태그 활성 표시 |

### 댓글 도움 (좋아요) (/api/comment/updateCommentHelp)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **cm_no** | request (댓글 번호) |
| — | **response** | response ('success'/'del'/'needLogin') |

---

## 게시판 (Board)

### 칼럼 댓글 작성 (/api/board/insertColumnComment)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **bcc_content** | request (필수, 최소 5글자) |
| — | **bd_id** | request (필수, 게시판 ID) |
| — | **bc_id** | request (필수, 칼럼 ID) |
| — | **bcc_no** | request (선택, 대댓글 시 부모 번호) |
| — | **bcc_anonymous** | request (선택, 익명 여부) |

**특수 응답**: `response === 'test'` — 30초 이내 연속 댓글 차단
**특수 응답**: `response === 'textLimit'` — 5글자 미만

### 칼럼 댓글 삭제 (/api/board/deleteColumnComment)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **bcc_no** | request (댓글 번호) |

### 댓글 신고 (/api/board/commentReport)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **bcc_no** | request (댓글 번호) |

### 문의 목록 (/api/board/getInquiry)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** (기본값 10) | request |
| — | **offset** | request |
| — | **items[]** | response |
| — | **next** | response |

**items[] 응답 필드:**

| 필드명 | 설명 |
|--------|------|
| **qa_subject** | 문의 제목 |
| **qa_content** | 문의 내용 |
| **qa_part** | 문의 유형 (서버에서 한글/일본어 변환) |
| **qa_status** | 상태 ('standby'/'complete') |
| **status** | 표시용 상태 텍스트 |
| **color** | UI 색상 클래스 ('wait'/'com') |
| **regist_date** | 등록일 (Y.m.d) |
| **regist_time** | 등록시간 (H:i) |

**문의 유형 (qa_part) 코드:**

| 코드 | 한국어 | 일본어 |
|------|--------|--------|
| normal | 일반문의 | 一般問い合わせ |
| refund | 환불문의 | 払い戻しのお問い合わせ |
| require | 개선요청 | 改善要請 |
| report | 불량상담신고 | 不良鑑定申告 |
| info | 정보변경 | 情報変更 |
| block | 차단요청 | ブロック要請 |

### 문의 작성 (/api/board/insertInquiry)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **qa_part** | request (필수, 문의 유형 코드) |
| — | **qa_subject** | request (필수, 제목) |
| — | **qa_content** | request (필수, 내용) |
| — | **qa_type** | request (선택) |
| — | **qa_status** | request (선택) |

### 공지사항 목록 (/api/board/getNotice)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |
| — | **items[]** | response |
| — | **next** | response |

### 게시글 목록 (/api/board/getPosting)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **bd_id** | request (게시판 ID) |
| — | **limit** | request |
| — | **offset** | request |

### 게시글 좋아요 (/api/board/postingtLike)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **bc_id** | request (게시글 ID) |

### 채용 지원 (/api/board/insertRecruit)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | 지원 정보 필드 (상세 TBD) | request |

---

## 이벤트 (Event)

### 이벤트 목록 (/api/event/getEvent)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** (기본값 20) | request |
| — | **offset** | request |
| — | **items[]** | response |
| — | **next** | response |

**items[] 응답 필드:**

| 필드명 | 설명 |
|--------|------|
| **ev_id** | 이벤트 ID |
| **ev_title** | 이벤트 제목 |
| **ev_link** | PC 링크 |
| **ev_mobile_link** | 모바일 링크 |
| **ev_app_link** | 앱 링크 |
| **ev_img** | 이벤트 이미지 |
| **redirectUrl** | 디바이스별 최종 리다이렉트 URL (서버 계산) |
| **regist_date** | 등록일 (Y.m.d) |
| **regist_time** | 등록시간 (H:i) |

### 키워드 이벤트 코인 지급 (/api/event/keywordEvent/{eventId})

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **eventKeyword** | request (키워드) |
| — | **content** | request (선택, 이벤트 내용) |
| — | **eventType** | request (선택, 'comment' 등) |
| — | **ekContent** | request (선택, 추가 내용) |

### 쿠폰 이벤트 (/api/event/couponEvent/{eventId}/{couponCode})

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **eventKeyword** | request (키워드) |
| — | **content** | request (선택) |

### 출석 이벤트 (/api/event/attendEventJoin)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | (로그인 세션만 필요) | request |

### 코인충전 이벤트 (/api/event/coinChargeEvent)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | (로그인 세션만 필요) | request |

### 이벤트 팝업 쿠키 (/api/event/setAppCookie)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **time** | request (쿠키 유효 일수) |

### 이벤트 콘텐츠 표시 (/api/event/showEventContents)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ev_id** | request |

---

## 상담사 관리 (Callee) — Callee 인증 필수

### 활동 정보 조회 (/api/callee/getActivityInfo)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **st_code** | request (선택) |
| — | **it_online** | response (상담 상태 'on'/'off') |
| — | **replyAll** | response (전체 답글 수) |
| — | **replyDone** | response (완료 답글 수) |
| — | **replyNeed** | response (미답글 수) |
| — | **qnaAll** | response (전체 문의 수) |
| — | **qnaStandby** | response (대기 문의 수) |
| — | **finance{}** | response (금월 상담 현황) |

**finance{} 응답 필드:**

| 필드명 | 설명 |
|--------|------|
| **fdr_total** | 총 상담 시간 (포맷) |
| **fdr_money** | 수익 금액 (포맷) |
| **onDur** | 접속 시간 |

### 상담 상태 조회 (/api/callee/getCallStatus)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **st_code** | request (선택) |
| — | **it_online** | response ('on'/'off') |

### 상담 상태 변경 (/api/callee/updateCallStatus)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **it_online** | request (필수, 'on'/'off') |
| — | **st_code** | request (선택) |

### 답글 현황 (/api/callee/getReplyCommentCnt)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **st_code** | request (선택) |
| — | **replyDone** | response |
| — | **replyNeed** | response |

### 문의 현황 (/api/callee/getReplyQnaCnt)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **st_code** | request (선택) |

### 공지 수정 (/api/callee/updateItemNotice)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **it_notice** | request (필수, 최소 4글자) |
| — | **st_code** | request (선택) |
| — | **isImgUpdate** | request ('true' 시 이미지 업데이트) |
| — | **notice_img** | request (FILE, isImgUpdate='true' 시) |

### FAQ 답변 조회 (/api/callee/getFaqAnswer)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **faq_no** | request |

### FAQ 목록 (/api/callee/getFaqList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |

### FAQ 답변 수정 (/api/callee/updateFaqAnswer)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **faq_no** | request |
| — | **faq_answer** | request |

### 내 후기 목록 (/api/callee/getMyCommentList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |
| — | **type** | request (선택, 'need'/'done') |

### 후기 답글 작성 (/api/callee/insertCommentReply)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **cm_no** | request (부모 댓글 번호) |
| — | **cm_content** | request (답글 내용) |

### 내 문의 목록 (/api/callee/getMyQnaList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |

### 문의 답글 작성 (/api/callee/updateItemQnaReply)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **qa_no** | request |
| — | **qa_reply** | request |

### 게시글 목록 (/api/callee/getPostingList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |

### 게시글 작성 (/api/callee/postInsert)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **bc_title** | request (제목) |
| — | **bc_content** | request (내용) |
| — | **bc_img** | request (선택, FILE) |

### 게시글 수정 (/api/callee/postModify)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **bc_id** | request (게시글 ID) |
| — | **bc_title** | request |
| — | **bc_content** | request |

### 게시글 삭제 (/api/callee/postDelete)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **bc_id** | request |

### 채팅 상태 변경 (/api/callee/updateChatStatus)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ch_online** | request ('on'/'off') |

### 견적서 목록 (/api/callee/getEstimateList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |

### 상담 이력 (/api/callee/getCounselList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |
| — | **search_type** | request (선택) |

### 상담사 포인트 목록 (/api/callee/getPointCalleeList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |

### 기프트카드 구매 (/api/callee/CalleeBuyGiftCard)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **gc_code** | request (기프트카드 코드) |

### 후기 고정 (/api/callee/updateCommentToFix)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **cm_no** | request (댓글 번호) |

### 상담 시간 수정 (/api/callee/updateCounselTime)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | 상담 시간 관련 필드 | request |

---

## 상품 (Goods) — 디지털 상품/작명

### 상품 목록 모바일 (/api/goods/getListMobile)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **keyword** | request (필수) |
| — | **cate** | request (카테고리, 'all' → 빈값) |
| — | **order** | request (정렬 기준) |
| — | **part** | request (hot = 인기) |
| — | **limit** (기본값 24) | request |
| — | **offset** | request |
| — | **items[]** | response |
| — | **next** | response |

**items[] 응답 필드 (상품 전용):**

| 필드명 | 설명 |
|--------|------|
| **gd_code** | 상품 코드 |
| **gd_name** | 상품명 |
| **gd_price** | 가격 |
| **gd_img** | 상품 이미지 |
| **it_tag[]** | 태그 배열 |
| **it_counsel_field** | 상담 분야 (JSON) |
| **view_win_point** | 표시 평점 |
| **view_win_comment** | 표시 후기 수 |
| **view_like_cnt** | 표시 좋아요 수 |
| **item_label{}** | 라벨 객체 |

### 상품 구매 (/api/goods/buyItem)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **gd_code** | request (필수, 상품 코드) |
| — | **gd_qty** | request (수량) |
| — | **opt_no** | request (선택, 옵션 번호) |
| — | **is_quote** | request ('Y' 시 견적 구매) |
| — | **gs_no** | request (is_quote='Y' 시, 견적 주문번호) |
| — | **st_code** | request (선택) |
| — | **gs_no** | response (주문 번호) |

### 구매 확정 (/api/goods/buyConfirm)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **gs_no** | request (주문 번호) |

### 구매 취소 (/api/goods/buyCancel)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **gs_no** | request |

### 주문 정보 (/api/goods/orderInfo)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **gs_no** | request |

### 구매 목록 (/api/goods/getBuyList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |

### 환불 완료 (/api/goods/refundSuccess)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **gs_no** | request |

### 취소 목록 (/api/goods/getCancelList)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |

### 상품 파일 (/api/goods/goodsFile)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **gs_no** | request |
| — | **file_url** | response |

### 상품 FAQ 목록 (/api/goods/getGoodsFaqListByType)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **type** | request (FAQ 유형) |

### 상품 리뷰 작성 (/api/goods/insertMyComment)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **gd_code** | request |
| — | **cm_content** | request |
| — | **cm_point** | request |

### 내 클래스 목록 (/api/goods/getMyClass)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |

### 내 클래스 상세 (/api/goods/getmyclassDetail)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **gc_code** | request (클래스 코드) |

### 상담사 — 구매 목록 (/api/goods/getCalleebuyList) — Callee 전용

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **limit** | request |
| — | **offset** | request |
| — | **status** | request (선택, 주문 상태 필터) |

### 상담사 — 구매 수 (/api/goods/getCalleebuyCnt) — Callee 전용

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | (로그인 세션만 필요) | request |

### 상담사 — 상품 확정 (/api/goods/calleeGoodsConfirm) — Callee 전용

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **gs_no** | request |

### 상담사 — 상품 등록/수정/삭제 (Callee 전용)

| 엔드포인트 | 주요 필드 |
|-----------|----------|
| /api/goods/updateGoods | **gd_code**, **gd_name**, **gd_price**, **gd_content** 등 |
| /api/goods/deleteGoods | **gd_code** |
| /api/goods/updateGoodsView | **gd_code** |
| /api/goods/previewGoods | **gd_code** |

---

## 숍 (Shop) — 오프라인 예약 상품

### 예약 캘린더 (/api/shop/reservationCalendar)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ce_code** | request (필수, 상담사 코드) |
| — | **ym** | request (선택, 'YYYY-MM', 기본 현재 월) |
| — | **select_on** | request (선택, 선택된 날짜) |
| — | **items{}** | response (캘린더 데이터) |

**items{} 응답 필드:**

| 필드명 | 설명 |
|--------|------|
| **select_month** | 선택 월 (YYYY-MM) |
| **now_month** | 현재 월 |
| **now_day** | 현재 일 |
| **now** | 표시 문자열 (YYYY년 MM월) |
| **last_day** | 해당 월 마지막 일 |
| **prev_month** | 이전 월 |
| **next_month** | 다음 월 |
| **ableDate[]** | 예약 가능 날짜 배열 |

### 예약 시간 조회 (/api/shop/orderReservationTime)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ce_code** | request (필수) |
| — | **ymd** | request (날짜 YYYY-MM-DD) |
| — | **today** | request ('true' 시 오늘 날짜) |
| — | **items{}** | response |

**items{} 응답 필드:**

| 필드명 | 설명 |
|--------|------|
| **sales_times[]** | 영업 시간 배열 |
| **rest_times[]** | 휴게 시간 배열 |
| **can_reserv_times[]** | 예약 가능 시간 배열 |
| **can_reserv_time_am[]** | 오전 시간 |
| **can_reserv_time_pm[]** | 오후 시간 |
| **can_reserv_time_able_fmt[]** | 예약 가능 시간 (포맷) |

### 내 숍 조회 (/api/shop/getMyShop)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | (로그인 세션 필요) | request |

### 숍 상품 목록 (/api/shop/getShopItems)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **ce_code** | request |
| — | **limit** | request |
| — | **offset** | request |

### 숍 구매 (/api/shop/buyShop)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **sh_code** | request (숍 상품 코드) |
| — | **rv_date** | request (예약 날짜) |
| — | **rv_time** | request (예약 시간) |

### 숍 리뷰 작성 (/api/shop/insertMyComment)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **sh_code** | request |
| — | **cm_content** | request |
| — | **cm_point** | request |

### 일정 변경 (/api/shop/updateReschedule)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **os_no** | request (주문 번호) |
| — | **rv_date** | request (새 날짜) |
| — | **rv_time** | request (새 시간) |

### 숍 확정/취소/환불

| 엔드포인트 | 주요 필드 |
|-----------|----------|
| /api/shop/shopConfirm | **os_no** |
| /api/shop/shopCancel | **os_no** |
| /api/shop/refundSuccess | **os_no** |

### 상담사 — 스케줄 관리 (Callee 전용)

| 엔드포인트 | 주요 필드 |
|-----------|----------|
| /api/shop/scheduleAdd | 스케줄 데이터 |
| /api/shop/scheduleDelete | 스케줄 ID |
| /api/shop/ShopReserveDay | 일별 예약 조회 |
| /api/shop/ShopReserveWeek | 주별 예약 조회 |
| /api/shop/ShopReserveMonth | 월별 예약 조회 |

---

## 예약 (Reservation) — 전화 예약 상담

### 스케줄 조회 (/api/reservation/getSchedule)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **it_code** | request (필수) |
| — | **weekDay** | request (필수, 요일 영문명: 'Mon'/'Tue'/...) |
| — | **date** | request (필수, YYYY-MM-DD) |
| — | **st_code** | request (선택) |
| — | **items[][]** | response (시간대별 슬롯 2차원 배열) |

**items[][] 슬롯 응답 필드:**

| 필드명 | 설명 |
|--------|------|
| **date** | 날짜 |
| **weekDay** | 요일 |
| **time** | 시간 |
| **min** | 분 (00/20/40 — 20분 단위) |
| **start** | 시작 시간 (HH:MM) |
| **end** | 종료 시간 |
| **text** | 상태 텍스트 (예약가능/예약완료/예약종료) |
| **status** | 상태 코드 ('able'/'com'/'end') |

**추가 응답 필드:**

| 필드명 | 설명 |
|--------|------|
| **dayCnt** | 내 예약 건수 |
| **todayCheck** | 오늘 여부 (boolean) |
| **today** | 오늘 날짜 포맷 |
| **weekDay** | 요일 |
| **weekDayLang** | 요일 로케일 텍스트 |

---

## 검색 (Search)

### 통합 검색 (/api/items/getSearchListItems)

| FFS 추정 | as-is 실제 | 방향 |
|---------|-----------|------|
| — | **keyword** | request (필수, 검색어) |
| — | **limit** | request |
| — | **offset** | request |
| — | **type** | request (선택, 검색 대상 유형) |
| — | **items[]** | response |
| — | **next** | response |

> 검색은 독립 컨트롤러 없이 `/api/items/getSearchListItems`와 `/api/goods/getListMobile` (keyword 파라미터)로 처리됨.
> 채팅 상담사 검색도 `/api/chat/getListMobile`의 keyword 파라미터로 동일 패턴.

---

## 카테고리 (Category)

### 카테고리별 목록 — Items/Chat/Goods 공통 패턴

카테고리 전용 API는 없으며, 기존 목록 API의 **cate** 파라미터로 필터링:

| 엔드포인트 | cate 값 예시 | 설명 |
|-----------|-------------|------|
| /api/items/getListMobile | 타로, 사주, 신점 등 카테고리 코드 | 전화 상담사 카테고리 필터 |
| /api/chat/getListMobile | 동일 | 채팅 상담사 카테고리 필터 |
| /api/goods/getListMobile | 'all' 또는 상품 카테고리 코드 | 상품 카테고리 필터 |

**카테고리 코드**: 서버에서 `it_category_code` 필드로 관리. 프론트엔드에서는 URL 파라미터 또는 Zustand 스토어(`useCateStore`)로 관리.

---

## 응답 형식 (전체 공통)

```json
{
    "response": "success" | "error",
    "msg": "에러 시 메시지, 성공 시 빈 문자열",
    "data": { ... },
    "is_login": "true" | "false"
}
```

### 응답 변형 패턴

| 패턴 | 사용 도메인 | 설명 |
|------|-----------|------|
| `items[]` + `next` | Items, Chat, Mypage, Board, Event, Goods, Shop | 리스트형 응답 (페이지네이션) |
| `item{}` | Call (getPopupInfo), Items (getItem) | 단일 객체 응답 |
| `data{}` | Pay (GetMyCard) | 데이터 래핑 |
| `result` | Chat (chatConnect) | 실패 사유 코드 |
| `response === 'login'` | Board, Chat | 미로그인 리다이렉트 |
| `response === 'couponAlready'` | Mypage | 쿠폰 중복 등록 |
| `response === 'needLogin'` | Comment, Pay | 로그인 필요 |
| `response === 'data_empty'` | Shop | 데이터 없음 |
| `response === 'no_reservation'` | Shop | 예약 불가 |

### 특이사항
- **모든 응답 HTTP 200**: 성공/실패 구분은 `response` 필드로만 판별
- **is_login**: 문자열 `"true"` / `"false"` (boolean이 아님)
- **number_format**: 서버에서 포맷된 숫자 문자열 (콤마 포함)이 반환되는 경우 있음
- **날짜 포맷**: 서버에서 `Y.m.d`, `H:i` 형식으로 변환된 문자열 반환

**클라이언트 처리 패턴:**
```js
const data = await secureFetch('/api/auth/login', {
    method: 'POST',
    body: JSON.stringify({ ac_id: email, ac_password: password }),
});

if (data.response === 'success') {
    // 성공 처리
} else {
    setError(data.msg); // 서버 에러 메시지 그대로 표시
}
```

---

## PG 게이트웨이 국가별 매핑

| PG | 코드 | 한국 | 일본 | 비고 |
|----|------|------|------|------|
| NicePay | `nice_bis` | O | X | 한국 주력 (카드, 가상계좌, 휴대폰) |
| KakaoPay | `kakao_pay` | O | X | 한국 모바일 월렛 |
| NaverPay | `naver_pay` | O | X | 한국 모바일 월렛 |
| TossPay | `toss_pay` | O | X | 한국 모바일 월렛 |
| Mcash | `mo_card`/`mcash` | O | X | 휴대폰 소액결제 |
| Stripe | — | X | O | 일본 주력 |
| PayLetter | `payletter` | O | X | 해외 사용자 국제결제 |
| PayPal | `paypal` | O | O | USD 결제 |

### od_pay_method 코드 참조

서버에서 `lang('Field.pay.od_pay_method.{코드}')` 으로 현지화.

| 코드 | 설명 |
|------|------|
| `nice_bis` | NicePay 카드 |
| `naver_pay` | 네이버페이 |
| `toss_pay` | 토스페이 |
| `kakao_pay` | 카카오페이 |
| `mo_card` | 모바일카드 |
| `mcash` | 휴대폰소액결제 |
| `stripe` | Stripe 카드 |
| `paypal` | PayPal |
| `payletter` | PayLetter |
| `simplepay` | 간편결제 |
| `autopay` | 자동충전 |

---

## 신규 RESTful API (v2) — 2026-04-10 추가

> 기존 as-is PHP API와 병기. 전환기 참조용.
> 스펙 원본: `docs/specs/auth-api.yaml`, `docs/specs/member-api.yaml`
> 백엔드 미확인 사항: `docs/specs/backend-api-questions.md` 참조

### 응답 형식 변경 (BREAKING)

| 항목 | as-is (v1) | 신규 (v2) |
|------|-----------|----------|
| 성공 | `{ response: "success", msg: "", data: {...}, is_login: "true" }` | `{ data: {...} }` |
| 에러 | `{ response: "error", msg: "메시지", data: {}, is_login: "false" }` | `{ error: { code: "CODE", message: "메시지" } }` |
| HTTP Status | 항상 200 | RESTful (200, 201, 400, 401, 403, 404, 409, 429, 500) |

### 에러 코드 목록 (v2)

| code | HTTP Status | 의미 |
|------|------------|------|
| `UNAUTHORIZED` | 401 | 인증 실패 / 토큰 만료 |
| `FORBIDDEN` | 403 | 비활성 계정 / 강제 탈퇴 / SNS 전용 계정 |
| `NOT_FOUND` | 404 | 리소스 없음 |
| `CONFLICT` | 409 | 중복 (이미 존재하는 계정, 이미 연동된 SNS) |
| `VALIDATION_FAILED` | 400 | 입력 검증 실패 |

### 인증 방식 변경

| 항목 | as-is | 신규 |
|------|-------|------|
| 쿠키 이름 | `hc_token` | `hc_access` |
| 쿠키 유형 | JWT HttpOnly | JWT HttpOnly (동일) |
| Content-Type | `application/x-www-form-urlencoded` | `application/json` |
| HTTP 메서드 | POST 전용 | RESTful (GET/POST/PUT/DELETE) |
| 필수 헤더 | — | `X-Forwarded-Proto: https` (개발 환경) |

---

### 로그인 — POST /api/auth/login

| as-is 필드 | 신규 필드 | 방향 | 비고 |
|-----------|---------|------|------|
| ac_id | **ac_id** | request | 동일 |
| ac_password | **ac_password** | request | 동일 |
| response === 'success' | **HTTP 200** | response | 형식 변경 |
| data.ac_code | **data.ac_nick** | response | 반환 필드 변경 |
| data.ac_nick | **data.ac_nick** | response | 동일 |
| — | **data.ac_home_set** | response | 신규 |
| msg | **error.message** | response (에러) | 형식 변경 |

**에러 응답**:
- 401: 인증 실패 (비밀번호 불일치)
- 403: 비활성 계정 (정지/탈퇴)
- 404: 회원 정보 없음

---

### 로그아웃 — POST /api/auth/logout

| as-is | 신규 | 비고 |
|-------|------|------|
| 별도 엔드포인트 없음 | **POST /api/auth/logout** | 신규 추가 |
| 프론트엔드 쿠키 삭제 | **백엔드 Max-Age=0 설정** | 역할 변경 |

**인증**: cookieAuth (hc_access) 필수

---

### Token 갱신 — POST /api/auth/refresh

| as-is | 신규 | 비고 |
|-------|------|------|
| 프론트엔드 자체 갱신 | **POST /api/auth/refresh** | 백엔드 위임 |

**인증**: hc_refresh 쿠키 자동 전송
**응답**: 새 hc_access 쿠키 (Set-Cookie)
**에러**: 401 — Refresh Token 없음/만료

---

### 회원가입 — POST /api/auth/register

| as-is 필드 (joinuser) | 신규 필드 | 방향 | 비고 |
|---------------------|---------|------|------|
| ac_id | **ac_id** | request | 동일 |
| ac_password | **ac_password** | request | 동일 |
| ac_password_re | **ac_password_re** | request | 동일 |
| ac_nick | **ac_nick** | request | 동일 |
| cr_phone | **cr_phone** | request | 동일 |
| ac_country | **ac_country** | request | 동일 |
| — | **ac_sns_id** | request | SNS 가입 시 |
| — | **sns_type** | request | google/kakao/naver/facebook/apple/line |
| ac_birth_year | **(미포함)** | request | **주의: 생년월일 필드 누락** |
| ac_birth_month | **(미포함)** | request | **주의: 생년월일 필드 누락** |
| ac_birth_day | **(미포함)** | request | **주의: 생년월일 필드 누락** |
| agree_service | **(미포함)** | request | **주의: 약관동의 필드 누락** |
| agree_privacy | **(미포함)** | request | **주의: 약관동의 필드 누락** |
| agree_age | **(미포함)** | request | **주의: 약관동의 필드 누락** |

**에러 응답**:
- 400: 입력 검증 실패
- 403: 강제 탈퇴 계정
- 409: 이미 존재하는 계정

**⚠️ 누락 필드**: 생년월일(ac_birth_year/month/day), 약관동의(agree_service/privacy/age)가 신규 스펙에 없음. 백엔드 확인 필요.

---

### SMS 인증 발송 — POST /api/verify/sms

| as-is 필드 (sendglobalcert) | 신규 필드 | 비고 |
|---------------------------|---------|------|
| cr_phone | **ac_phone_no** | **필드명 변경** |
| ac_country | **ac_country** | 동일 |
| — | **purpose** | 신규 (register/findid/findpw/phoneno) |
| — | **ac_id** | 신규 (선택적) |

**에러**: 429 — 일일 인증 횟수 초과

---

### SMS 인증 확인 — **스펙 누락**

| as-is (confirmglobalcert) | 신규 | 비고 |
|--------------------------|------|------|
| ac_cert_num | **없음** | **CRITICAL: 엔드포인트 누락** |

---

### 이메일 인증 발송 — POST /api/verify/email (신규)

| 필드 | 방향 | 비고 |
|------|------|------|
| **ac_id** (email) | request | 필수 |

---

### 프로필 조회 — GET /api/members/me (as-is: POST /api/mypage/getMyInfo)

| as-is 필드 | 신규 필드 | 비고 |
|-----------|---------|------|
| ac_id | **data.ac_id** | 동일 |
| ac_nick | **data.ac_nick** | 동일 |
| — | **data.cr_code** | 신규 |
| cr_phone | **data.cr_phone** | 동일 |
| — | **data.country_code** | 신규 |
| ac_remain_coin | **data.ac_remain_coin** | 동일 |
| — | **data.ac_remain_free_coin** | 신규 (무료코인 분리) |
| — | **data.ac_remain_pay_coin** | 신규 (유료코인 분리) |
| — | **data.ac_home_set** | 신규 |
| — | **data.ac_sms_cf** | 신규 (Y/N) |
| — | **data.ac_email_cf** | 신규 (Y/N) |
| — | **data.ac_noti_cf** | 신규 (Y/N) |
| ac_reg_path | **data.ac_reg_path** | 동일 |
| — | **data.regist_date** | 신규 |
| — | **data.last_login_date** | 신규 |

**HTTP 메서드 변경**: POST → **GET** (body 없음)

---

### 프로필 수정 — PUT /api/members/me (as-is: 개별 엔드포인트 통합)

| as-is 엔드포인트 | 신규 필드 | 비고 |
|----------------|---------|------|
| changenick → ac_nick | **ac_nick** | 통합 |
| settingalarm → ac_sms_cf 등 | **ac_sms_cf, ac_email_cf, ac_noti_cf** | 통합 |
| — | **ac_home_set** | 신규 |

**HTTP 메서드 변경**: POST → **PUT**

---

### 비밀번호 변경 — PUT /api/members/me/password (as-is: POST /api/member/changepasswd)

| as-is 필드 | 신규 필드 | 비고 |
|-----------|---------|------|
| ac_password_old | **current_password** | **필드명 변경** |
| ac_password | **new_password** | **필드명 변경** |
| ac_password_re | **new_password_re** | **필드명 변경** |

**HTTP 메서드 변경**: POST → **PUT**

---

### 회원 탈퇴 — DELETE /api/members/me (as-is: POST /api/member/deleteuser)

**HTTP 메서드 변경**: POST → **DELETE** (body 없음)

---

### 코인 잔액 — GET /api/members/me/coin (as-is: POST /api/mypage/getCoinInfo)

| as-is 필드 | 신규 필드 | 비고 |
|-----------|---------|------|
| remain_coin | **data.remain_coin** | 동일 |
| — | **data.remain_free_coin** | 신규 |
| — | **data.remain_pay_coin** | 신규 |
| — | **data.total_charged** | 신규 |
| — | **data.total_used** | 신규 |
| — | **data.total_refunded** | 신규 |

**HTTP 메서드 변경**: POST → **GET**

---

### 이력 조회 — GET /api/members/me/history (as-is: 3개 엔드포인트 통합)

| as-is 엔드포인트 | 신규 query param | 비고 |
|----------------|-----------------|------|
| getCounselList | **type=counsel** | 통합 |
| getCoinList | **type=coin** | 통합 |
| getPayList | **type=payment** | 통합 |
| — | **limit** (기본 20) | 동일 |
| — | **offset** (기본 0) | 동일 |
| — | **term** (기본 "3") | 신규 (단위 미명시) |

**HTTP 메서드 변경**: POST → **GET** (query params)

---

### SNS 연동 — POST /api/members/me/sns (신규)

| 필드 | 방향 | 비고 |
|------|------|------|
| **sns_type** | request | google/kakao/naver/facebook/apple/line |
| **ac_sns_id** | request | SNS 고유 ID |

**에러**: 409 — 이미 SNS 연동됨

---

### SNS 해제 — DELETE /api/members/me/sns (신규)

**body 없음**
**에러**:
- 400: 연동된 SNS 없음
- 403: SNS 전용 계정 — 비밀번호 설정 필요

---

### 엔드포인트 매핑 총괄표 (v1 → v2)

| 기능 | as-is (v1) | 신규 (v2) | Method |
|------|-----------|----------|--------|
| 로그인 | POST /api/member/loginuser | POST /api/auth/login | POST |
| 로그아웃 | (프론트 자체) | POST /api/auth/logout | POST |
| 토큰 갱신 | (프론트 자체) | POST /api/auth/refresh | POST |
| 회원가입 | POST /api/member/joinuser | POST /api/auth/register | POST |
| 이메일 체크 | POST /api/member/checkid | **(미매핑)** | — |
| 닉네임 체크 | POST /api/member/checknick | **(미매핑)** | — |
| 비밀번호 체크 | POST /api/member/checkpassword | **(미매핑)** | — |
| SMS 발송 | POST /api/member/sendglobalcert | POST /api/verify/sms | POST |
| SMS 확인 | POST /api/member/confirmglobalcert | **(누락)** | — |
| 이메일 발송 | POST /api/member/sendMailCert | POST /api/verify/email | POST |
| 이메일 확인 | POST /api/member/confirmMailCert | **(미매핑)** | — |
| 아이디 찾기 | POST /api/member/findidcert | **(미매핑)** | — |
| 비밀번호 찾기 | POST /api/member/findpasswordcert | **(미매핑)** | — |
| 프로필 조회 | POST /api/mypage/getMyInfo | GET /api/members/me | **GET** |
| 닉네임 변경 | POST /api/member/changenick | PUT /api/members/me | **PUT** |
| 알림 설정 | POST /api/member/settingalarm | PUT /api/members/me | **PUT** |
| 비밀번호 변경 | POST /api/member/changepasswd | PUT /api/members/me/password | **PUT** |
| 회원 탈퇴 | POST /api/member/deleteuser | DELETE /api/members/me | **DELETE** |
| 코인 잔액 | POST /api/mypage/getCoinInfo | GET /api/members/me/coin | **GET** |
| 상담 이력 | POST /api/mypage/getCounselList | GET /api/members/me/history?type=counsel | **GET** |
| 코인 이력 | POST /api/mypage/getCoinList | GET /api/members/me/history?type=coin | **GET** |
| 결제 이력 | POST /api/mypage/getPayList | GET /api/members/me/history?type=payment | **GET** |
| SNS 연동 | (미구현) | POST /api/members/me/sns | POST |
| SNS 해제 | (미구현) | DELETE /api/members/me/sns | DELETE |

### v2 스펙에서 누락된 as-is 엔드포인트 (별도 스펙 필요)

| 기능 | as-is 엔드포인트 | 비고 |
|------|----------------|------|
| 이메일 유니크 체크 | /api/member/checkid | 가입 시 실시간 검증 |
| 닉네임 유니크 체크 | /api/member/checknick | 가입 시 실시간 검증 |
| 비밀번호 형식 검증 | /api/member/checkpassword | 서버사이드 검증 |
| 비밀번호 확인 일치 | /api/member/checkpasswordre | 서버사이드 검증 |
| SMS 인증 확인 | /api/member/confirmglobalcert | **CRITICAL** |
| 이메일 인증 확인 | /api/member/confirmMailCert | 인증코드 검증 |
| 아이디 찾기 | /api/member/findidcert | 인증 후 이메일 반환 |
| 비밀번호 찾기 | /api/member/findpasswordcert | 인증 후 비번 재설정 |
| 전화번호 변경 | /api/member/updatephone | 마이페이지 |
| 전화번호 인증 | /api/member/verifyphone | 마이페이지 |
