# HTTP Status Code & Error Code 명세

> 프로젝트 API 응답 표준. `BaseApiController` 기반.

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-14 |
| 유형 | report |
| 상태 | 승인됨 |

---

## 응답 구조

```
// 성공 (200, 201)
{ "data": { ... } }

// 성공 + 페이지네이션 (200)
{ "data": [...], "meta": { "currentPage": 1, "perPage": 20, "total": 100, "lastPage": 5 } }

// 성공 + body 없음 (204)
(empty body)

// 에러 (4xx, 5xx)
{ "error": { "code": "ERROR_CODE", "message": "사용자 노출 메시지", "details": [...] } }
```

---

## 성공 응답 (2xx)

| HTTP | 의미 | 메서드 | body |
|------|------|--------|------|
| 200 | 조회/처리 성공 | `respondSuccess($data)` | `{ "data": {...} }` |
| 201 | 리소스 생성 | `respondCreated($data)` | `{ "data": {...} }` |
| 204 | 성공, 반환 데이터 없음 | `respondNoContent()` | 없음 |

### 204 사용 기준

body로 돌려줄 데이터가 없는 성공 응답:
- 인증번호 발송
- 비밀번호 변경
- 알림 읽음 처리
- 로그아웃
- 리소스 삭제 (반환할 내용 없을 때)

---

## 클라이언트 에러 (4xx)

### 400 Bad Request — 입력값 오류

요청 형식/값이 유효하지 않을 때.

| error.code | 사용 상황 | message 예시 |
|------------|----------|-------------|
| `VALIDATION_FAILED` | 필수값 누락, 형식 오류, 범위 초과 | "전화번호 형식이 올바르지 않습니다." |
| `INVALID_PARAMETER` | 쿼리 파라미터/경로 파라미터 오류 | "page는 1 이상이어야 합니다." |
| `MALFORMED_REQUEST` | JSON 파싱 실패, Content-Type 불일치 | "요청 본문을 파싱할 수 없습니다." |

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "입력값이 유효하지 않습니다.",
    "details": [
      { "field": "phone", "reason": "required" },
      { "field": "email", "reason": "invalid_format" }
    ]
  }
}
```

---

### 401 Unauthorized — 인증 실패

토큰 없음, 만료, 변조.

| error.code | 사용 상황 | message 예시 |
|------------|----------|-------------|
| `UNAUTHORIZED` | JWT 없음 또는 만료 | "인증이 필요합니다." |
| `TOKEN_EXPIRED` | Access Token 만료 (Refresh 유도) | "인증 토큰이 만료되었습니다." |
| `TOKEN_INVALID` | 토큰 변조/서명 불일치 | "유효하지 않은 인증 토큰입니다." |

---

### 403 Forbidden — 권한 없음

인증은 됐지만 해당 리소스/행위에 대한 권한 부족.

| error.code | 사용 상황 | message 예시 |
|------------|----------|-------------|
| `FORBIDDEN` | 범용 권한 부족 | "접근 권한이 없습니다." |
| `OWNERSHIP_REQUIRED` | 본인 리소스가 아님 | "본인의 리소스만 수정할 수 있습니다." |
| `ROLE_REQUIRED` | 역할(callee 등) 미등록 | "등록된 사업자만 이용할 수 있습니다." |
| `CSRF_FAILED` | CSRF 토큰 검증 실패 | "요청 검증에 실패했습니다." |

---

### 404 Not Found — 리소스 없음

요청한 리소스가 존재하지 않을 때.

| error.code | 사용 상황 | message 예시 |
|------------|----------|-------------|
| `RESOURCE_NOT_FOUND` | 범용 리소스 없음 | "요청하신 항목을 찾을 수 없습니다." |
| `MEMBER_NOT_FOUND` | 회원 조회 실패 | "회원 정보를 찾을 수 없습니다." |
| `SHOP_NOT_FOUND` | 매장 조회 실패 | "매장 정보를 찾을 수 없습니다." |
| `ORDER_NOT_FOUND` | 주문 조회 실패 | "주문 정보를 찾을 수 없습니다." |

---

### 409 Conflict — 충돌/중복

현재 리소스 상태와 충돌하는 요청.

| error.code | 사용 상황 | message 예시 |
|------------|----------|-------------|
| `CONFLICT` | 범용 충돌 | "요청이 현재 상태와 충돌합니다." |
| `DUPLICATE_ENTRY` | 중복 등록 (이메일, 전화번호 등) | "이미 등록된 이메일입니다." |
| `ALREADY_PROCESSED` | 이미 처리된 작업 재요청 | "이미 처리된 요청입니다." |
| `STATE_CONFLICT` | 상태 전이 불가 (취소된 주문 결제 등) | "취소된 주문은 결제할 수 없습니다." |

---

### 422 Unprocessable Entity — 비즈니스 규칙 위반

형식은 맞지만 비즈니스 로직상 처리 불가.

| error.code | 사용 상황 | message 예시 |
|------------|----------|-------------|
| `UNPROCESSABLE` | 범용 처리 불가 | "요청을 처리할 수 없습니다." |
| `COUPON_ALREADY_USED` | 사용 완료 쿠폰 | "이미 사용된 쿠폰입니다." |
| `COUPON_EXPIRED` | 만료 쿠폰 | "유효기간이 만료된 쿠폰입니다." |
| `INSUFFICIENT_BALANCE` | 잔액 부족 | "잔액이 부족합니다." |
| `RESERVATION_FULL` | 예약 마감 | "예약 가능 인원이 초과되었습니다." |
| `VERIFICATION_FAILED` | 인증번호 불일치 | "인증번호가 일치하지 않습니다." |
| `VERIFICATION_EXPIRED` | 인증번호 만료 | "인증번호가 만료되었습니다." |

---

### 429 Too Many Requests — 요청 한도 초과

일정 시간 내 허용 횟수 초과.

| error.code | 사용 상황 | message 예시 |
|------------|----------|-------------|
| `RATE_LIMIT_EXCEEDED` | API 호출 빈도 초과 | "요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요." |
| `SEND_LIMIT_EXCEEDED` | 인증번호/알림 발송 한도 | "발송 한도를 초과했습니다. 3분 후 다시 시도해주세요." |
| `ACTION_THROTTLED` | 특정 행위 제한 (댓글, 신고 등) | "잠시 후 다시 시도해주세요." |

---

## 서버 에러 (5xx)

### 500 Internal Server Error — 서버 내부 오류

| error.code | 사용 상황 | message 예시 |
|------------|----------|-------------|
| `SERVER_ERROR` | 범용 서버 오류 | "서버 내부 오류가 발생했습니다." |
| `DATABASE_ERROR` | DB 쿼리/커넥션 실패 | "데이터 처리 중 오류가 발생했습니다." |

> 500 에러의 message는 사용자에게 안전한 메시지만 노출. 상세 원인은 서버 로그에만 기록.

---

### 502 Bad Gateway — 외부 서비스 장애

| error.code | 사용 상황 | message 예시 |
|------------|----------|-------------|
| `EXTERNAL_SERVICE_ERROR` | 외부 API 호출 실패 (SMS, PG 등) | "외부 서비스 연동 중 오류가 발생했습니다." |
| `SMS_DELIVERY_FAILED` | SMS 발송 실패 | "인증번호 발송에 실패했습니다." |
| `PAYMENT_GATEWAY_ERROR` | PG사 응답 오류 | "결제 처리 중 오류가 발생했습니다." |

---

### 503 Service Unavailable — 서비스 이용 불가

| error.code | 사용 상황 | message 예시 |
|------------|----------|-------------|
| `SERVICE_UNAVAILABLE` | 서비스 점검/일시 중단 | "서비스 점검 중입니다." |
| `MAINTENANCE` | 정기 점검 | "정기 점검 중입니다. 잠시 후 다시 이용해주세요." |

---

## 400 vs 422 구분 기준

| 구분 | 400 | 422 |
|------|-----|-----|
| **원인** | 요청 형식/값 자체가 잘못됨 | 형식은 맞지만 비즈니스 규칙 위반 |
| **예시** | 이메일 형식 오류, 필수값 누락 | 만료된 쿠폰 사용, 잔액 부족 |
| **error.code** | `VALIDATION_FAILED` | 도메인별 구체적 코드 |
| **판단 시점** | 컨트롤러 진입 직후 (validation) | 서비스 레이어 (비즈니스 로직) |

---

## error.code 네이밍 규칙

1. **UPPER_SNAKE_CASE** 고정
2. **현상 서술형** — suffix 없음 (`_ERROR`, `_EXCEPTION` 붙이지 않음. 단, `SERVER_ERROR`/`DATABASE_ERROR`는 예외)
3. **도메인 prefix 허용** — 범용 코드로 부족할 때만 (`COUPON_EXPIRED`, `SMS_DELIVERY_FAILED`)
4. **간결하게** — 3단어 이내 권장

## 체크리스트

- [x] 문서 작성 완료

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-14 | 최초 작성 | jypark |
| 2026-04-15 | doc-template 양식 적용 | jypark |
