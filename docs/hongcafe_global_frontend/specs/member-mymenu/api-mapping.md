# MyPage 도메인 — 백엔드 API 매핑 (파이프라인 진입 가이드)

| 항목 | 내용 |
|------|------|
| 작성자 | 명우현 |
| 작성일 | 2026-04-17 |
| 버전 | v2.0 |
| 상태 | Active — Profile API v1.1.0 반영 완료, Figma 핸드오프 대기 중 |
| 캐노니컬 명세 (1순위) | `docs/specs/profile-api.yaml` v1.1.0 (2026-04-17, jypark) |
| 캐노니컬 명세 (2순위) | `docs/specs/member-api.yaml` v1.2.0 (Profile API 미포함 EP만) |
| 선행 문서 | `docs/audits/2026-04-17-profile-api-v1.1.0-integration-plan.md` |

> 본 문서는 MyPage 하위 페이지를 정규 파이프라인으로 구현할 때 1차 참조용 매핑이다.
> 프로필 관련 기능은 **`profile-api.yaml`**이 canonical이며, 중복되던 `member-api.yaml`의 5개 EP는 deprecated 상태로 전환되었다.
> 명세 변경 시 본 문서가 아니라 원본 YAML이 우선한다.

---

## 1. MyPage 메뉴 구조 (현 상태)

`app/[locale]/mypage/_components/MyPageContent.js:202-220` 10개 메뉴 + 2개 회원 도메인 관리 영역(`/mypage/info`, `/mypage/notification`).

| MenuItem href | 메뉴 라벨 | 도메인 | Profile API 매핑 | 상태 |
|---------------|-----------|--------|------------------|------|
| `/mypage/info` | 계정 정보 | 프로필 | ✅ 본 가이드 §2 | profile-api v1.1.0 |
| `/mypage/notification` | 알람 설정 | 프로필 | ✅ 본 가이드 §3 | profile-api v1.1.0 |
| `/mypage/consult-history` | 상담 내역 | 내역 | ✅ §7 history(type=counsel) | profile-api v1.1.0 |
| `/mypage/coin-history` | 코인 내역 | 내역 | ✅ §7 history(type=coin) | profile-api v1.1.0 |
| `/mypage/payment-history` | 결제 내역 | 내역 | ✅ §7 history(type=payment) | profile-api v1.1.0 |
| `/mypage/chat-consult` | 채팅 상담 | chat | ❌ 미사용 | **별도 명세 대기** |
| `/mypage/my-review` | 내 리뷰 | review | ❌ 미사용 | **별도 명세 대기** |
| `/mypage/my-inquiry` | 내 문의 | inquiry | ❌ 미사용 | **별도 명세 대기** |
| `/mypage/auto-charge` | 자동 충전 | autopay | ❌ 미사용 | **별도 명세 대기** |
| `/mypage/customer-service` | 고객센터 | cs | ❌ 미사용 | **별도 명세 대기** |
| `/mypage/event` | 프로모션 | event | ❌ 미사용 | **별도 명세 대기** |

> ⚠️ 모든 href가 가리키는 페이지는 **현재 미존재**. V5.8 §22-37 Link href 실재 검증 위반 상태. 본 작업 범위는 프로필 도메인(2개) + 내역 3종 + Phase E 옵션. 비회원 도메인 페이지는 백엔드 명세 도착 후 별도 Task.

---

## 2. `/mypage/info` (계정 정보) — Profile API 매핑

### 2.1 사용 EP
| # | Method | URL | 인증 | 용도 |
|---|--------|-----|------|------|
| P1 | GET | `/api/profile` | 🔒 jwt | 현재 프로필 조회 (페이지 진입 시) |
| P2 | PUT | `/api/profile` | 🔒 jwt | 닉네임/홈설정 수정 (화이트리스트) |
| P3 | PUT | `/api/profile/password` | 🔒 jwt | 비밀번호 변경 (현재 비밀번호 검증) |
| P4 | DELETE | `/api/profile` | 🔒 jwt | 회원 탈퇴 |
| P6 | POST | `/api/profile/link-sns` | 🔒 jwt | SNS 계정 연동 (§8) |
| P7 | POST | `/api/profile/unlink-sns` | 🔒 jwt | SNS 연동 해제 (§8) |
| M14 | POST | `/api/members/verify-phone` | 🔒 jwt | 번호 변경 인증 발송 (Profile API 미포함 — member-api 유지) |
| M15 | POST | `/api/members/update-phone` | 🔒 jwt | 번호 변경 실행 (Profile API 미포함 — member-api 유지) |

### 2.2 필드 매핑 핵심

#### P1 GET /api/profile
```
Response 14필드: acId, acNick, crCode, crPhone, countryCode,
  acRemainCoin, acRemainFreeCoin, acRemainPayCoin,
  acHomeSet, acSmsCf, acEmailCf, acNotiCf,
  acRegPath, registDate, lastLoginDate
Success: HTTP 200 { data: {...14필드...} }
401 UNAUTHORIZED / 404 NOT_FOUND
```

#### P2 PUT /api/profile (화이트리스트)
```
Body (최소 1개 필수): {
  acNick?:     string (2~12자),
  acHomeSet?:  string ("hongcafe" | "call" 등),
  acSmsCf?:    "Y" | "N",
  acEmailCf?:  "Y" | "N",
  acNotiCf?:   "Y" | "N"
}
허용 필드 외 전달 시 무시됨 (백엔드 whitelist).
Success: HTTP 200 []
400 INVALID_INPUT — 수정 가능한 필드 없음 또는 검증 실패
401 UNAUTHORIZED
```

#### P3 PUT /api/profile/password
```
Body: {
  currentPassword: string (required),
  newPassword:     string (8~128자),
  newPasswordRe:   string (matches[newPassword])
}
Success: HTTP 200 []
400 INVALID_INPUT — 검증 실패 (길이, 형식, 불일치)
401 UNAUTHORIZED — 현재 비밀번호 불일치 또는 로그인 필요

⚠️ member-api v1.2.0 `POST /api/members/change-passwd`의
   `acPassword` 필드와 다름 — 필드명 마이그레이션 주의.
```

#### P4 DELETE /api/profile
```
Body: 없음
Success: HTTP 200 [] + Set-Cookie로 hc_access/hc_refresh 즉시 만료
401 UNAUTHORIZED / 500 INTERNAL

구 member-api `DELETE /api/members/delete-user`와 동작 동일.
```

#### M14 verify-phone / M15 update-phone
Profile API에 전화번호 변경 EP가 **없으므로** member-api 잔존 EP를 그대로 사용.
```
M14 Body: { acCountry: 'US'|'JP'|'KR', newPhone (numeric) } → 204
M15 Body: { acCountry, newPhone, acCertNum } → 204
비프로덕션 인증번호: 222222
```

### 2.3 UI 구성 권고 (Figma 도착 전 임시)
- 닉네임 영역: 표시(`profile.acNick`) + 변경 버튼 → 변경 모달 (2~12자 검증)
- 이메일 영역: 표시(`profile.acId`, readOnly) — 변경 불가 (Profile API에 update-email 없음)
- 전화번호 영역: 표시(`profile.crPhone`) + 변경 버튼 → 인증 모달 (M14 → M15 2단계)
- 비밀번호 변경 영역: currentPassword/newPassword/newPasswordRe 3필드 (P3)
- 홈 화면 설정: `profile.acHomeSet` 표시 + 선택 UI (P2)
- SNS 연동: `profile.acRegPath` 기반 연동 상태 표시 + 연동/해제 (P6/P7)
- 회원 탈퇴: 하단 텍스트 링크 + 확인 모달 (P4)

### 2.4 §22-50 readOnly 주의
- profile-api.yaml에 readOnly **명시 없음**
- 이메일이 변경 불가인 것은 **Profile API에 update-email EP가 없기 때문**이지, `acId` 필드가 readOnly라서가 아님
- SDD에 `readOnly: true`가 명시되지 않으면 publisher가 HTML `readOnly` 속성 추가 금지 (§22-50 ABSOLUTE)
- Figma에서 이메일 필드가 회색/disabled로 표시되면 design-normalizer가 SDD에 `readOnly: true`를 명시해야 함

---

## 3. `/mypage/notification` (알람 설정) — Profile API 매핑

### 3.1 사용 EP
| # | Method | URL | 인증 | 용도 |
|---|--------|-----|------|------|
| P2 | PUT | `/api/profile` | 🔒 jwt | 알람 설정 토글 (화이트리스트) |

### 3.2 필드 매핑 핵심

```
Body: {
  acSmsCf?:   "Y" | "N",   // SMS 알림
  acEmailCf?: "Y" | "N",   // 이메일 알림
  acNotiCf?:  "Y" | "N"    // 푸시 알림
}
Success: HTTP 200 []
```

> ✅ **v1.0 역전 매핑 이슈 해소**: 이전 `POST /api/members/setting-alarm`의 `value:"true"→"N"`/`기타→"Y"` 반직관 매핑이 **Profile API에서 제거됨**. 이제 `true → "Y"` / `false → "N"` 직관적 매핑 사용.

### 3.3 UI 구성 권고
- SMS 알람 토글 → `onChange: isOn => PUT /api/profile { acSmsCf: isOn ? "Y" : "N" }`
- 이메일 알람 토글 → `onChange: isOn => PUT /api/profile { acEmailCf: isOn ? "Y" : "N" }`
- 푸시 알람 토글 → `onChange: isOn => PUT /api/profile { acNotiCf: isOn ? "Y" : "N" }`
- 각 토글 변경 시 즉시 EP 호출 → 성공 시 `useProfileStore.profile.acSmsCf` 등 업데이트
- 페이지 진입 시 `GET /api/profile` 호출로 현재 설정 동기화

---

## 4. 이메일 변경 플로우 (별도 Task 후보)

### 4.1 사용 EP (member-api 유지)
| # | Method | URL | 인증 | 용도 |
|---|--------|-----|------|------|
| M20 | POST | `/api/members/send-mail-cert` | 불필요 | 이메일 인증번호 발송 (미등록 이메일만) |
| M21 | POST | `/api/members/confirm-mail-cert` | 불필요 | 이메일 인증번호 확인 (TTL 3분) |

### 4.2 사용 시나리오
- 회원가입 시: 현재 미사용 (가입은 SMS 인증만 사용)
- 이메일 변경 시: 신규 이메일 인증 → **DB 업데이트 EP 부재** (Profile API와 member-api 모두 `update-email` 없음)
- **결정 보류**: 이메일 변경이 회원가입 후 가능한 기능인지 백엔드 확인 필요

### 4.3 비프로덕션 인증번호: `333333` 고정

---

## 5. 공통 보안/헤더 사항

| 항목 | 처리 위치 | 비고 |
|------|----------|------|
| `X-Forwarded-Proto: https` | `lib/sessionBridge.js:84` | 자동 |
| `X-CSRF-TOKEN` | `lib/fetchWithAuth.js:82` + `lib/csrf.js` | secureFetch 사용 시 자동 |
| JWT (`hc_access`) | HttpOnly 쿠키 | 자동 동봉 (credentials: 'same-origin') |
| 응답 정규화 | `lib/errorMapper.js` | `{data,error}` → `{response,msg,data,is_login}` |
| 프록시 레이어 | `app/api/profile/*/route.js` | 단계 2에서 신규 생성 |

> 모든 `/mypage/*` 페이지는 로그인 필수 — 페이지 진입 시 `useAuthStore.isLoggedIn` 검증 + 미로그인 시 `/login` 리다이렉트 패턴 (현재 `MyPageContent.js`에 부분 구현됨, 진입 가드 보강 필요).

---

## 6. 파이프라인 진입 체크리스트 (페이지별 반복)

각 페이지마다 별도 Task_ID 발급 + 정규 파이프라인 진입:

- [ ] Figma URL + node-id 수신
- [ ] project-planner: Task_ID 부여 + 의존 페이지 선후관계 결정
- [ ] design-normalizer: SDD 추출 (`/mypage/info`는 모달이 많아 INSTANCE 노드 다수 — uiRole 자동 분류 필수)
- [ ] compile_build_spec: 본 문서의 EP 매핑을 `[API_MAPPING]` 마커로 Build Spec에 주입 — **canonical source는 profile-api.yaml**
- [ ] publisher: 컴포넌트 생성 + i18n 키 추가 + JWT 가드 구현 + `useProfileStore` 연동
- [ ] qa-engineer: EP mock 기반 functional test (특히 §22-50 readOnly 검증, §22-22 toggle 4패턴 동기화)
- [ ] static_audit + cross_reference_audit + functional_audit
- [ ] Visual Regression
- [ ] Phase 3.5 component-refactor (모달 패턴 공유 컴포넌트 추출 — `/mypage/info`는 변경 모달 4종)
- [ ] FINAL_REPORT

---

## 7. 내역 페이지 3종 — 통합 history EP 매핑

`/mypage/consult-history`, `/mypage/coin-history`, `/mypage/payment-history` 세 페이지는 모두 `GET /api/profile/history` 통합 EP를 사용하며, `type` 파라미터만 다르다.

### 7.1 공통 요청
```
GET /api/profile/history?type={type}&limit={limit}&offset={offset}&term={term}
```

| Query 필드 | 타입 | 필수 | 기본값 | 설명 |
|-----------|------|------|--------|------|
| type | string | N | `counsel` | `counsel` / `coin` / `payment` |
| limit | integer | N | `20` | 페이지당 항목 수 |
| offset | integer | N | `0` | 시작 오프셋 (페이지네이션) |
| term | integer | N | `3` | 조회 기간 (월 단위) |

### 7.2 페이지별 매핑
| 페이지 | type | 용도 |
|--------|------|------|
| `/mypage/consult-history` | `counsel` | 상담 내역 (Voice/Chat 상담 기록) |
| `/mypage/coin-history` | `coin` | 코인 적립/사용 내역 |
| `/mypage/payment-history` | `payment` | 결제 내역 (충전/환불) |

### 7.3 응답 스키마 (v1.1.0 현황)
```
200 { data: [ { ...type별 항목 스키마... } ] }
```

> ⚠️ profile-api.yaml v1.1.0은 response items schema를 `type: object` (임의 필드)로만 정의. type별 상세 필드 명세는 Figma 핸드오프 시점에 백엔드에 별도 요청 필요.

### 7.4 UI 구성 권고
- 공통: 기간 필터(1/3/6개월), 무한 스크롤 또는 페이지네이션 (`offset` + `limit`)
- 상태: 빈 상태, 로딩 skeleton, 에러 상태 3종 필수

---

## 8. SNS 연동 관리 — `/mypage/info` 내 하위 섹션

### 8.1 사용 EP
| # | Method | URL | 인증 | 용도 |
|---|--------|-----|------|------|
| P6 | POST | `/api/profile/link-sns` | 🔒 jwt | SNS 계정 연동 |
| P7 | POST | `/api/profile/unlink-sns` | 🔒 jwt | SNS 연동 해제 |

### 8.2 P6 link-sns
```
Body: {
  snsType: "google" | "kakao" | "naver" | "facebook" | "apple" | "line",
  acSnsId: string (required)
}
Success: HTTP 200 { data: { snsType: "..." } }
409 CONFLICT — 이미 다른 SNS 연동됨 (단일 SNS 연동 정책)
```

### 8.3 P7 unlink-sns
```
Body: 없음
Success: HTTP 200 []
403 FORBIDDEN — SNS 전용 계정 (비밀번호 미설정) → 해제 불가
400 INVALID_INPUT — SNS 연동 없음
```

### 8.4 UI 구성 권고
- `profile.acRegPath`가 `"hongcafe"` → SNS 미연동 상태 → 연동 버튼 6종 노출 (Google/Kakao/Naver/Facebook/Apple/Line)
- `profile.acRegPath`가 SNS 중 하나 → 해당 SNS 연동됨 상태 → 해제 버튼만 노출
- **주의**: SNS 전용 계정(비밀번호 미설정)은 P7 해제 불가 (403). 프론트는 비밀번호 설정 여부를 별도 플래그로 받아야 하나 Profile API에 해당 필드 없음 → **설계 확정 필요**

---

## 9. `useProfileStore` 초기화 정책 (단계 3에서 신설)

| 시점 | 호출 | 목적 |
|------|------|------|
| mypage 진입 시 | `useProfileStore.fetchProfile()` | 14필드 조회 및 store 채우기 |
| mypage 진입 시 | `useProfileStore.fetchCoinSummary()` | 코인 요약 6필드 조회 |
| PUT /api/profile 성공 후 | `fetchProfile()` 재호출 | 서버 정규화 결과 재동기화 |
| 로그아웃 시 | `useProfileStore.clear()` | profile/coinSummary → null |

- **`useAuthStore`는 JWT 3필드(acId/crCode/acNick) 유지** — 인증 경계 불변
- 프로필 확장 데이터는 전부 `useProfileStore`가 소유
- 페이지 간 중복 호출 방지를 위해 store 내부에 `lastFetchedAt` 타임스탬프 추가 검토 (SWR 대체)

---

## 10. Profile API ↔ 기존 API 마이그레이션 매트릭스

| 기능 | Before (member-api v1.1.0) | After (profile-api v1.1.0) | 프론트 작업 |
|------|----------------------------|----------------------------|-------------|
| 비밀번호 변경 | `POST /api/members/change-passwd` + `{acPassword, newPassword, newPasswordRe}` | `PUT /api/profile/password` + `{currentPassword, newPassword, newPasswordRe}` | 필드명 변경 |
| 닉네임 변경 | `POST /api/members/change-nick` + `{acNick}` | `PUT /api/profile` + `{acNick}` | 메서드+URL 변경 |
| 알람 설정 | `POST /api/members/setting-alarm` + `{type, value}` (역전 매핑) | `PUT /api/profile` + `{acSmsCf\|acEmailCf\|acNotiCf}` (직관 매핑) | URL+body 전면 변경 |
| 홈 설정 | `POST /api/members/update-home-set` + `{newHome}` | `PUT /api/profile` + `{acHomeSet}` | URL+field 변경 |
| 회원 탈퇴 | `DELETE /api/members/delete-user` | `DELETE /api/profile` | URL만 변경 |
| 코인 잔액 | `POST /api/mypage/getCoinInfo` (레거시 PHP) | `GET /api/profile/coin` (6필드) | 메서드+URL+스키마 변경 |
| 프로필 조회 | — (없음) | `GET /api/profile` (14필드) | **신규** |
| 내역 조회 | — (없음, 페이지별 별도 EP 필요 예상) | `GET /api/profile/history?type=...` | **신규** (통합) |
| SNS 연동 | — (없음) | `POST /api/profile/link-sns` | **신규** |
| SNS 해제 | — (없음) | `POST /api/profile/unlink-sns` | **신규** |

---

## 11. 변경 이력

| 버전 | 날짜 | 변경 사항 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-04-17 | 최초 작성 — Member API v2026-04-17 기반 mypage 도메인 EP 매핑 문서화 | 명우현 |
| v2.0 | 2026-04-17 | Profile API v1.1.0 반영 — canonical source 전환 (profile-api.yaml), 8 EP 매핑 전면 재작성, §7 history 통합 + §8 SNS 연동 + §9 store 정책 + §10 마이그레이션 매트릭스 신설. §3 역전 매핑 이슈 해소 기록 | 명우현 |
