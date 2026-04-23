# API 문서-소스 정합성 종합 보고서

> 13개 모듈 308 EP의 API 문서(MD/YAML)와 소스 코드(Routes.php/AuthFilter) 간 정합성을 5축 대조하여 Critical 8건, High 90건, Medium 11건 불일치를 식별하고 P0/P1을 수정 완료한 결과 보고서

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-15 |
| 유형 | result |
| 상태 | 확정 |

## 실행 결과

### 1. 통계 요약

| 모듈 | Routes EP | MD EP | YAML EP | Critical | High | Medium | Low |
|------|-----------|-------|---------|----------|------|--------|-----|
| Auth | 4 | 4 | 4 | 0 | 1 | 1 | 0 |
| Notification | 2 | 2 | 2 | 0 | 1 | 0 | 0 |
| Social | 3 | 3 | 3 | 0 | 1 | 1 | 0 |
| Board | 12 | 12 | 12 | 0 | 2 | 1 | 0 |
| Service | 7 | 7 | 7 | 1 | 1 | 1 | 0 |
| Reservation | 8 | 8 | 8 | 2 | 1 | 0 | 0 |
| Event | 10 | 10 | 10 | 0 | 3 | 2 | 0 |
| Payment | 11 | 11 | 11 | 1* | 0 | 1 | 0 |
| Content | 16 | 16 | 16 | 0 | 7 | 0 | 0 |
| Member | 49 | 49 | 49 | 0 | 0 | 2 | 0 |
| Commerce | 69 | 69 | 69 | 0 | 27 | 1 | 1 |
| Chat | 51 | 51 | 51 | 0 | 45 | 0 | 0 |
| Call | 66 | 66 | 66 | 4 | 1 | 1 | 0 |
| **합계** | **308** | **308** | **308** | **8** | **90** | **11** | **1** |

> *Payment Critical은 AuthFilter URL 케이스 불일치 (#2번, 사전 발견)

---

### 2. Critical 불일치 (8건) — 즉시 수정 필요

### 2.1 AuthFilter URL 케이스 불일치 (Payment)

| 항목 | AuthFilter EXCLUDED | Routes.php |
|------|-------------------|------------|
| 등록 | `api/pay/view-simplepay-regist` | `api/pay/viewSimplepayRegist` |
| 등록 | `api/pay/view-simplepay-card` | `api/pay/viewSimplepayCard` |
| 등록 | `api/pay/view-simplepay-update` | `api/pay/viewSimplepayUpdate` |
| 등록 | `api/pay/view-simplepay-password` | `api/pay/viewSimplepayPassword` |

**영향**: exact match 실패 → 간편결제 WebView 페이지가 인증 필터를 통과하지 못해 401 반환
**조치**: AuthFilter EXCLUDED_PATHS를 Routes.php URL과 일치시킴

### 2.2 Routes.php role:callee 필터 누락 (5건)

| EP | 모듈 | MD 표기 | Routes 필터 | 영향 |
|----|------|---------|------------|------|
| `POST api/calls/get-callee-like-list` | Call | `jwt, role:callee` | 없음 (jwt만) | 일반 사용자가 상담사 즐겨찾기 접근 가능 |
| `POST api/calls/get-callee-ing-list` | Call | `jwt, role:callee` | 없음 | 진행중 통화 목록 노출 |
| `POST api/calls/callee-online-call` | Call | `jwt, role:callee` | 없음 | 온라인 통화 상태 노출 |
| `POST api/rejects/get-callee-reject-list` | Service | `jwt, role:callee` | 없음 | 차단 목록 접근 가능 |
| `POST api/reservations/get-callee-reservation-list` | Reservation | `jwt, role:callee` | 없음 | 상담사 예약 목록 접근 |
| `POST api/o2o-calendars/o2o-calendar` | Reservation | `jwt, role:callee` | 없음 | O2O 캘린더 접근 |

**조치**: Routes.php에 `['filter' => 'role:callee']` 추가

### 2.3 문서-소스 역방향 불일치 (1건)

| EP | 모듈 | MD 표기 | Routes 필터 | 현상 |
|----|------|---------|------------|------|
| `POST api/callees/callee-goods-search` | Call | `—` (공개) | `role:callee` | MD/YAML이 공개로 표기, 실제는 상담사 전용 |

**조치**: MD/YAML 인증 표기를 `jwt, role:callee`로 수정

---

### 3. High 불일치 (90건) — 인증 표기 패턴 오류

### 핵심 원인

글로벌 AuthFilter가 `api/*` 전체에 적용되므로, `EXCLUDED_PATHS`에 등록되지 않은 EP는 **모두 jwt 인증이 필요**하다. 그러나 다수 MD/YAML 문서에서 이 EP들을 `—`(공개)로 표기하고 있다.

레거시 컨트롤러의 `checkNeedLogin()` 메서드로 내부 인증을 처리하던 시절의 표기가 글로벌 AuthFilter 도입 후 업데이트되지 않은 것으로 추정된다.

### 모듈별 분포

| 모듈 | 공개 표기(MD) but jwt 필요 (EP 수) | 대표 EP |
|------|-----------------------------------|---------|
| Chat | 37개 (chat) + 5개 (goodschat) + 1개 (shopchat) = **43개** | get-list-mobile, chat-timer, message-log 등 |
| Commerce | items 9개 + goods 13개 + shop 4개 = **27건** (중복 제거) | get-list-mobile, get-shop-items 등 |
| Content | **7개** | GET notices, faqs, banners + themes |
| Board | **5개** | get-inquiry, get-notice, get-posting 등 |
| Service | **4개** | get-service-list-mobile, hermes/* |
| Event | **3개** | get-event, show-event-contents, set-app-cookie |
| Social | **3개** | profile-sns, board-sns, get-list-group |
| Notification | **1개** (2 EP이나 동일 패턴) | fcm/index, korea-callee-fcm |
| Reservation | **2개** | get-schedule, calendar |

### 조치 방향 (사용자 결정 필요)

두 가지 방향 중 하나를 선택해야 합니다:

**방향 A**: 해당 EP들이 실제로 공개 접근이 필요하다면 → `AuthFilter::EXCLUDED_PATHS`에 추가
**방향 B**: 해당 EP들이 인증이 필요하다면 → MD/YAML 문서의 인증 표기를 `🔒 jwt`로 수정

> 대부분의 EP(목록 조회, 상세 조회 등)는 설계 의도상 공개 접근이 맞을 가능성이 높으나, 서버 호출 테스트로 실제 동작을 확인한 후 결정하는 것이 안전합니다.

---

### 4. Medium 불일치 (11건)

| # | 모듈 | 현상 |
|---|------|------|
| 1 | Auth | `POST /api/auth/logout` MD 상세설명 "인증: 불필요(공개)" 오기 |
| 2-6 | Auth/Board/Social/Service/Payment | MD 인증 우선순위에 "Bearer 헤더 폴백" 표기 (CLAUDE.md: Bearer 폴백 없음) |
| 7 | Call | `api/calls/get-popup-info` MD "jwt (선택)" — 실제 jwt 강제 |
| 8 | Event | YAML에 CSRF 파라미터가 공개 EP에 표기 (모순) |
| 9-10 | Chat/Commerce | `save-item-price`, `get-callee-chat-like-list` Routes에 role:callee 누락 |
| 11 | Member | `change-passwd` 비밀번호 찾기 플로우에서 미로그인 접근 설계 검토 |

---

### 5. Low 불일치 (1건)

| # | 모듈 | 현상 |
|---|------|------|
| 1 | Commerce | `special-prices/get-list`가 goods-api.md/yaml에 혼재 (별도 그룹인데 같은 문서) |

---

### 6. EP 존재/HTTP 메서드/URL 경로 대조 결과

**전 모듈 완전 일치**: A(EP 존재), B(HTTP 메서드), C(URL 경로) 3개 축에서 Routes.php ↔ MD ↔ YAML 간 308개 EP 모두 정확히 일치합니다. 불일치는 **D(인증 정보) 축에 집중**되어 있습니다.

---

### 7. 수정 우선순위 및 처리 현황

| 순위 | 유형 | 건수 | 조치 | 상태 |
|------|------|------|------|------|
| P0 | AuthFilter URL 케이스 | 4+4 EP | EXCLUDED_PATHS camelCase+PascalCase 수정 | **완료** |
| P0 | Routes role:callee 누락 | 6 EP | Routes.php 필터 추가 | **완료** |
| P1 | 공개 EP EXCLUDED 추가 | 72 EP | AuthFilter EXCLUDED_PATHS 추가 | **완료** |
| P1 | 인증 표기 문서 수정 | 19 EP | MD/YAML 인증 `—` → `🔒 jwt` 수정 | **완료** |
| P2 | Bearer 폴백 표기 | ~6 문서 | MD/YAML 인증 설명 수정 | 미착수 |
| P2 | 특수 EP 설계 확인 | 5 EP | hermes/fcm apikey, get-schedule 결정 | 미착수 |
| P3 | 기타 문서 오기 | 5건 | MD 상세설명 수정 | 미착수 |

## 체크리스트

- [x] Phase 1: 13개 모듈 5축 정합성 대조 완료
- [x] Phase 1.5: 90건 EP 공개/인증 분류 완료 (컨트롤러 코드 근거)
- [x] Phase 3-1: P0 Critical 소스 수정 — AuthFilter URL 케이스 + role:callee 6건
- [x] Phase 3-2: P1 AuthFilter EXCLUDED_PATHS 72건 공개 EP 추가
- [x] Phase 3-3: P1 MD/YAML 19건 인증 표기 수정
- [x] Unit 테스트 통과: 1022 tests, 1192 assertions, 0 failures
- [ ] Phase 3-4: P2 Medium 문서 수정 (Bearer 폴백, logout 표기)
- [ ] Phase 3-5: P2 특수 EP 설계 확인 (hermes/fcm/get-schedule)
- [ ] Phase 2: dev 서버 호출 테스트 (배포 후)

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-15 | 최초 작성: 13개 모듈 정합성 대조 + P0/P1 수정 완료 | jypark |
