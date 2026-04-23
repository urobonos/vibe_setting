---
문서명: reservation 모듈 API ↔ IEEE 대조 — 2026-04-21
상태: 초안
생성일: 2026-04-21
SSOT 방향: API → IEEE
작성자: jypark (agent: general-purpose, sonnet)
---

# reservation 모듈 API ↔ IEEE 대조 리포트

---

## 요약

| 항목 | 값 |
|------|-----|
| API 문서 | `api-docs/reservation/reservation-api.md` + `.yaml` (2026-04-15 기준) |
| IEEE 문서 | SRS v2.0, SDD v2.0, IDD v2.0, STD v1.0 (모두 2026-04-15 기준) |
| 실제 코드 | `app/Modules/Reservation/Controllers/` + `Config/Routes.php` |
| 검토 EP 수 | API 기준 8개 |
| 발견 이슈 수 | 17건 (Critical 4 / High 6 / Medium 5 / Low 2) |
| 즉시 수정 필요 | Critical 4건 (EP URL 불일치, 응답 포맷, HTTP 메서드, 인증 불일치) |

### 핵심 발견사항

1. **EP URL 구조 전면 불일치 (Critical)**: API 문서의 8개 EP URL이 SRS/SDD/IDD에 기술된 EP URL과 전면 불일치한다. API 문서는 `kebab-case` + 동사 포함(`/get-schedule`, `/insert-reservation`)을 사용하고, IEEE 문서는 RESTful 설계(`/reservations/schedule`, `/reservations`, `/callees/reservations`)를 사용한다. 실제 Routes.php 코드는 API 문서와 일치한다. SSOT 원칙에 따라 IEEE를 수정해야 한다.

2. **HTTP 메서드 불일치 (Critical)**: API 문서는 조회용 EP에 POST를 사용하는 반면, IEEE SRS/SDD는 RESTful에 따라 GET을 명세한다. 실제 코드는 API 문서(POST)와 일치한다.

3. **인증 불일치 — get-schedule, calendars/calendar (Critical)**: API 문서는 두 EP가 공개 EP(인증 불필요)라고 명세하지만, SRS(§2.4)는 "모든 EP는 JWT 필수"라고 제약을 기술한다. 코드는 API 문서와 일치(인증 없음)한다. IEEE SRS 제약사항 수정 필요.

4. **응답 필드 구조 불일치 (High)**: IDD §7.2가 명세하는 슬롯 응답(`time` 필드가 ISO 8601 UTC 형식 `YYYY-MM-DDTHH:MM:SSZ`)과 API 문서 응답 예시(`time: "10:00"`, `min: 30`)가 다르다. 코드를 확인한 결과 `min`(분), 슬롯당 `time`(`H:i` 형식)을 그대로 반환한다. IEEE IDD를 API/코드 기준으로 수정 필요.

---

## 항목별 판정표

| # | 대조 항목 | API ↔ IEEE | API ↔ 코드 | 판정 | 이슈 ID |
|---|-----------|-----------|-----------|------|---------|
| 1 | EP 목록 | 불일치 | 일치 | FAIL | RESV-DEF-001 |
| 2 | EP-SRS 매핑 (FR-RESV-*) | 부분 불일치 | — | WARN | RESV-DEF-002 |
| 3 | 인증/CSRF | 부분 불일치 | 일치 | WARN | RESV-DEF-003, 004 |
| 4 | X-Forwarded-Proto | 일치 | — | PASS | — |
| 5 | 응답 스키마 | 불일치 | API ≒ 코드 | FAIL | RESV-DEF-005, 006 |
| 6 | 환경별 URL (servers) | 일치 | — | PASS | — |
| 7 | 비즈니스 규칙 | 부분 불일치 | 불일치 | WARN | RESV-DEF-007~010 |
| 8 | IDD 매핑 | 불일치 | — | FAIL | RESV-DEF-011~014 |
| 9 | STD TC 커버리지 | 부분 불일치 | — | WARN | RESV-DEF-015~017 |

---

## 이슈 상세 (RESV-DEF-NNN)

---

### [A] API 내부 일관성 이슈

---

#### RESV-DEF-001 — EP URL 구조 전면 불일치 (Critical)
**유형**: API 우선 (IEEE를 수정해야 함)
**근거**: SSOT = API 문서 + 실제 Routes.php 코드

| 구분 | API 문서 / 코드 (Routes.php) | IEEE (SRS §6, SDD §3.1, IDD EP수) |
|------|----------------------------|---------------------------------|
| EP 1 | `GET /api/reservations/get-schedule` | `GET /api/reservations/schedule` |
| EP 2 | `POST /api/reservations/insert-reservation` | `POST /api/reservations` |
| EP 3 | `POST /api/reservations/get-my-reservation` | `GET /api/reservations/{id}` |
| EP 4 | `POST /api/reservations/get-my-reservation-list` | `GET /api/reservations` |
| EP 5 | `POST /api/reservations/get-callee-reservation-list` | `GET /api/callees/reservations` |
| EP 6 | `POST /api/reservations/call` | `PUT /api/reservations/{id}/call-status` |
| EP 7 | `POST /api/o2o-calendars/o2o-calendar` | `POST /api/callees/o2o-calendar` |
| EP 8 | `POST /api/calendars/calendar` | `GET /api/calendar/monthly` |

**조치**: SRS §6, SDD §3.1~3.3, IDD §1.1(EP 총수 기술 포함) 전체를 API 문서 기준으로 업데이트한다.

---

#### RESV-DEF-002 — HTTP 메서드 불일치 (Critical)
**유형**: API 우선 (IEEE를 수정해야 함)

API 문서 및 실제 코드는 조회(목록, 상세, 캘린더 등)에 POST를 사용한다. IEEE SDD §3.1(메서드 목록)과 SRS §6(엔드포인트 목록)은 GET 기반 RESTful 설계를 명세하고 있다.

**영향**: SRS §6 엔드포인트 표, SDD §3.1~3.3 메서드 목록, IDD §5 이벤트 트리거 URL.
**조치**: IEEE 전 문서의 HTTP 메서드를 Routes.php 코드와 동일하게 POST로 수정한다.

---

#### RESV-DEF-003 — get-schedule / calendars/calendar 인증 명세 불일치 (Critical)
**유형**: API 우선 (IEEE SRS 수정 필요)

| EP | API 문서 | 코드 (`checkNeedLogin`) | SRS §2.4 |
|----|---------|------------------------|---------|
| `GET /api/reservations/get-schedule` | 공개 (인증 불필요) | `checkNeedLogin` 없음 | "모든 EP는 JWT 필수" |
| `POST /api/calendars/calendar` | 공개 (인증 불필요) | `checkNeedLogin` 없음 | "모든 EP는 JWT 필수" |

**조치**: SRS §2.4 제약사항 "모든 EP는 JWT 필수" → "공개 EP(get-schedule, calendars/calendar) 제외" 문구 추가.

---

#### RESV-DEF-004 — CSRF 면제 표기 누락 (High)
**유형**: API 내부 불일치 [B]

API 문서(`reservation-api.md`)는 CSRF 면제 관련 항목을 헤더 섹션에 일반 설명으로만 기재했고, 개별 EP 설명에서 공개 EP가 CSRF 면제임을 비고란에 명시하지 않았다. CLAUDE.md 문서 작성 규칙: "CSRF 면제 EP는 비고란에 면제 사유 명시" 요건과 불일치.

**영향**: `reservation-api.md` EP 1(get-schedule), EP 8(calendars/calendar).
**조치**: 해당 EP의 인증 비고란에 `CSRF 면제: 공개 EP` 명시.

---

### [B] API ↔ IEEE 불일치 이슈

---

#### RESV-DEF-005 — 슬롯 응답 구조 불일치 (High)
**유형**: API 우선 (IDD 수정 필요)

| 항목 | API 문서 응답 예시 | 코드 실제 반환 | IDD §7.2 명세 |
|------|-----------------|-------------|--------------|
| time 필드 | `"time": "10:00"` (HH:mm) | `$post['week_day']`, `rs_time` 기반 | `"time": "2026-04-15T09:00:00Z"` (ISO 8601 UTC) |
| min 필드 | `"min": 30` | 존재함 (`rv_min`) | 없음 |
| available | `"available": true` | `status: 'able'/'com'/'end'` | `"available": bool` |

**관련 코드 확인**: `ReservationService::buildScheduleSlots()` 및 `ReservationController::getSchedule()`는 `min`, `weekDay`, `date` 등의 추가 필드를 반환하며, ISO 8601 UTC 형식이 아닌 `H:i` 형식(`rs_time`)을 사용한다.

또한 코드는 슬롯 상태를 `available: bool` 대신 `status: 'able'|'com'|'end'` 문자열로 반환한다. API 문서의 `available: bool` 명세와도 불일치한다.

**이슈**: API 문서의 응답 예시도 코드 실제 반환과 완전히 일치하지 않음 (API 문서 수정도 필요 — [B] 분류).
**조치**: IDD §7.2를 코드 실제 반환 구조(`time: H:i`, `min: int`, `status: string`)로 업데이트. API 문서 응답 예시도 동일하게 갱신.

---

#### RESV-DEF-006 — 예약 등록 응답 및 요청 필드명 불일치 (High)
**유형**: API 우선 (IDD 수정 필요)

| 항목 | API 문서 | 코드 실제 | IDD §7.3 |
|------|---------|---------|---------|
| 요청 필드 | `revRow[].date`, `revRow[].time`, `revRow[].min` | `rev_row[].date`, `rev_row[].time`, `rev_row[].min` | `slotTime` (ISO 8601) |
| 응답 | `{ "data": { "rvNo": 12345 } }` | `{ "rv_no": result }` | `{ "data": { "id": ..., "calleeCode": ..., "slotTime": ... } }` |

코드(`insertReservation()`)는 `rv_no`를 snake_case로 반환한다. API 문서는 `rvNo`(camelCase)로 명세한다. IDD는 더 확장된 응답 필드를 명세하고 있다.

**조치**:
- IDD §7.3을 API 문서 기준(`revRow`, `rvNo`)으로 수정.
- 코드는 `rv_no` → `rvNo` camelCase 변환 적용 필요 (CLAUDE.md 규칙: DB snake_case → API camelCase 필수).

---

#### RESV-DEF-007 — 멱등성/중복 예약 차단 명세 불일치 (High)
**유형**: API 우선 (IEEE SRS/SDD 수정 필요)

**API 문서**: `409 CONFLICT` — 중복 예약 에러를 명세한다.

**SRS/SDD**: `SELECT FOR UPDATE` + `(callee_code, slot_time)` UNIQUE 인덱스로 동시성 제어를 명세한다.

**코드 실제 구현**: `ReservationController::insertReservation()`은 `validateReservationRows()`를 호출하며, STD TC 분석(TC-RES-030~034)에서 확인되는 검증 로직은 다음과 같다:
- `checkReservation`: 기존 동일 예약 존재 여부
- `checkReservationDateTimeCnt`: 동일 날짜+시간 슬롯당 예약 건수 제한
- `checkReservationDateCnt`: 동일 날짜 최대 예약 건수 제한(2건 초과 거부)

즉, 실제 코드는 SRS/SDD가 명세한 `SELECT FOR UPDATE` 행 잠금 방식이 아니라, **슬롯당 카운트 제한 + 날짜별 카운트 제한** 방식으로 중복을 차단한다. 멱등 키(idempotency key)는 미구현이다.

**조치**: SRS FR-RES-002-5(SELECT FOR UPDATE)와 SDD §4.2(알고리즘)의 슬롯 잠금 방식을 실제 코드 방식(카운트 기반 검증)으로 현행화한다.

---

#### RESV-DEF-008 — role:callee 필터 IEEE 표기 불일치 (Medium)
**유형**: API 우선 (IEEE SRS/SDD 수정 필요)

SRS §6 및 SDD §3.1의 EP 5(`GET /api/callees/reservations`)에 `callee` 역할 필터가 명시되어 있으나, 해당 EP URL 자체가 RESV-DEF-001에서 지적한 대로 불일치한다. 실제 코드는 `POST /api/reservations/get-callee-reservation-list`에 `['filter' => 'role:callee']`가 정확히 적용되어 있다.

EP 7(`POST /api/o2o-calendars/o2o-calendar`)도 Routes.php에서 `['filter' => 'role:callee']` 적용 확인됨. SDD §3.2(O2oCalendarController) 역할 필터 표기는 정확하나 EP URL 불일치가 동반된다.

**조치**: RESV-DEF-001 조치 시 역할 필터 표기도 동시 업데이트.

---

#### RESV-DEF-009 — O2O 캘린더 실제 구현과 IEEE 설계 불일치 (High)
**유형**: API 우선 (IEEE SDD/IDD 수정 필요)

**SDD §3.2 / IDD IF-INT-001**: `O2oCalendarController`가 `ReservationServiceInterface`를 통해 `createO2oEvent()`를 호출한다고 명세한다.

**실제 코드** (`O2oCalendarController.php`):
- `ReservationServiceInterface` 대신 `shopRepository`를 직접 주입한다.
- `createO2oEvent()` 메서드를 호출하지 않고 `shopRepository->calendarSchedule()` + `shopRepository->standbyCalendarSchedule()`를 호출한다.
- `CalendarHelper::buildMonthData($month)` static 메서드를 직접 호출한다 (SDD 명세와 일치하는 부분).
- **O2O 일정 등록 기능이 없다**: 현재 구현은 조회 전용이며, SDD/IDD가 설계한 "오프라인 일정 등록 → 슬롯 차단" 기능이 구현되어 있지 않다.

**조치**: SDD §3.2, IDD §3.1.5, SRS FR-RES-007을 실제 코드 기준으로 수정한다. 또는 구현을 SDD 설계에 맞게 완성해야 한다 — 이 판단은 담당자 결정 필요 (Checkpoint).

---

#### RESV-DEF-010 — 타임존 처리 불일치 (High)
**유형**: API 우선 (IEEE SRS/SDD 수정 필요)

**SRS NFR-RES-005, SDD §4.2**: 모든 날짜/시간은 UTC, `DateTimeImmutable` 사용 필수, `date()`/`time()` 금지.

**실제 코드** (`ReservationController.php`):
- `date('Y-m-d', time())` — L76: `date()`, `time()` 직접 사용
- `date('Y年 m月 d日', strtotime(...))` — L77: `date()` 사용
- `strtotime(date('Y-m-d H:i:s'))` — L248: `date()`, `strtotime()` 사용
- `date('Y-m-d H:i', $endTimestamp)` — L209: `date()` 사용
- `CalendarController::calendar()`: `date('Y-m')` 사용 (L23)
- `O2oCalendarController::O2oCalendar()`: `date('Y-m')` 사용 (L29)

NFR 전면 위반. `DateTimeImmutable` 미사용, UTC 기준 처리 보장 불가.

**조치**: SRS NFR-RES-005 및 CLAUDE.md 코딩 표준(`DateTimeImmutable` 강제)에 따라 코드 수정이 필요하다. IEEE 산출물은 현행 코드를 반영하되 개선 필요 사항으로 기록한다.

---

### [C] IDD 매핑 이슈

---

#### RESV-DEF-011 — IDD EP 수 불일치 (Medium)
**유형**: IDD 수정 필요

IDD §1.1에 "EP 총수: 8개 (ReservationController 5 + O2oCalendarController 2 + CalendarController 1)"로 기술되어 있다.

실제 Routes.php:
- `ReservationController`: 6개 (`getSchedule`, `insertReservation`, `getMyReservation`, `getMyReservationList`, `getCalleeReservationList`, `call`)
- `O2oCalendarController`: 1개 (`o2oCalendar`)
- `CalendarController`: 1개 (`calendar`)

IDD의 "O2oCalendarController 2" 기술이 틀렸다(실제 1개). "ReservationController 5"도 실제 6개와 불일치.
**조치**: IDD §1.1 EP 수 표를 `ReservationController 6 + O2oCalendarController 1 + CalendarController 1`로 수정.

---

#### RESV-DEF-012 — IDD 이벤트 트리거 URL 불일치 (Medium)
**유형**: IDD 수정 필요

IDD §5 Events and Signals 표의 이벤트 트리거 URL:
- EVT-RES-001: `POST /api/reservations/create` → 실제: `POST /api/reservations/insert-reservation`
- EVT-RES-002~004: `PUT /api/reservations/{id}/status` → 실제: `POST /api/reservations/call`
- EVT-RES-005: `POST /api/o2o-calendar/create` → 실제: `POST /api/o2o-calendars/o2o-calendar`
- EVT-RES-006: `DELETE /api/o2o-calendar/{id}` → 실제 라우트 없음

**조치**: IDD §5 이벤트 트리거 URL을 Routes.php 기준으로 전면 수정. EVT-RES-006(O2O 삭제)는 현재 구현되지 않은 기능으로 "미구현" 상태로 표기.

---

#### RESV-DEF-013 — IDD 요구사항 추적성 매트릭스 FR 번호 오류 (Medium)
**유형**: IDD 수정 필요

IDD §10(Requirements Traceability Matrix)의 FR 매핑이 SRS §6 엔드포인트 목록 번호와 교차 확인 시 불일치한다:

| IDD §10 | SRS FR ID | SRS 실제 내용 | 불일치 |
|---------|----------|------------|--------|
| FR-RES-004 | 예약 목록 조회 (상담사) | SRS §3: FR-RES-005가 상담사 예약 조회 | FR 번호 오류 |
| FR-RES-005 | CallStatus 전이 관리 | SRS §3: FR-RES-006이 CallStatus 관리 | FR 번호 오류 |
| FR-RES-006 | O2O 캘린더 관리 | SRS §3: FR-RES-007이 O2O 캘린더 | FR 번호 오류 |
| FR-RES-007 | 월간 캘린더 조회 | SRS §3: FR-RES-008이 월간 캘린더 | FR 번호 오류 |

IDD §10의 FR-RES-004~007이 SRS §3의 FR-RES-005~008을 각각 1씩 뒤바뀐 채로 참조하고 있다.
**조치**: IDD §10 추적성 매트릭스 FR 번호를 SRS §3 기준으로 교정.

---

#### RESV-DEF-014 — IDD DTO 필드 vs API 응답 예시 불일치 (Low)
**유형**: IDD 수정 필요

IDD §7.7 예약 DTO에 `id` 필드가 있으나, API 문서의 `insert-reservation` 응답은 `rvNo`만 반환한다. IDD §7.3 예약 생성 응답은 `id`, `acId`, `calleeCode`, `slotTime` 등 전체 필드를 명세한다. API 문서와 IDD DTO 간 응답 필드 범위가 다르다.
**조치**: IDD §7.3을 API 문서의 `{ "data": { "rvNo": int } }` 기준으로 단순화하거나, API 문서를 확장 응답으로 수정한다(담당자 결정 필요).

---

### [D] STD TC 커버리지 이슈

---

#### RESV-DEF-015 — STD TC 에러 응답 형식 불일치 (High)
**유형**: [B] API 내부 + STD 수정 필요

STD TC-RES-007~011(ReservationApiTest Feature)의 기대 결과가 `HTTP 200 + status='error'`로 기술되어 있다. CLAUDE.md API 응답 표준은 "HTTP 상태코드가 성공/실패의 SSOT"이고, 에러 시 `4xx/5xx` + `{ "error": { "code": ..., "message": ... } }` 응답이어야 한다.

실제 코드(`ReservationController.php`)의 에러 응답:
```php
return $this->respondError('INTERNAL', lang('Error.items.list.empty'), 500);
```
HTTP 500을 반환한다. 그러나 STD의 기대 결과는 `HTTP 200 + status='error'`로 기술되어 있어 테스트 케이스 자체가 레거시 응답 패턴(HTTP 200 + 에러 body)을 검증하고 있다.

**조치**: STD TC-RES-007~011의 기대 결과를 `HTTP 4xx/5xx + { "error": { "code": "...", "message": "..." } }`로 수정. 코드의 에러 응답도 `respondError('INVALID_INPUT', ..., 400)` 등 적절한 HTTP 코드로 개선 권장.

---

#### RESV-DEF-016 — role:callee 필터 통합 테스트 미구현 (Medium)
**유형**: STD 보완 필요

STD DEF-RES-002에서 이미 자체 기록: "FR-RES-005 상담사 예약 조회의 RoleFilter:callee 필터 검증 테스트가 메서드 존재 확인 수준에 한정". TC-RES-021 단 1건만 존재.

API 문서 및 실제 코드에서 `role:callee` 필터가 Routes.php에 적용되어 있음을 확인했다. 최소한 다음 TC가 추가되어야 한다:
- 일반 사용자(Caller)가 `get-callee-reservation-list` 호출 시 `403 FORBIDDEN` 반환 검증
- 일반 사용자가 `o2o-calendars/o2o-calendar` 호출 시 `403 FORBIDDEN` 반환 검증

**조치**: STD에 `TC-RES-S01`, `TC-RES-S02` 추가 계획 기록.

---

#### RESV-DEF-017 — STD TC 수 불일치 (Low)
**유형**: STD 내부 불일치 [B]

STD §1.2: "7개 테스트 파일에 포함된 총 40개 테스트 메서드를 검증 범위로 한다."
STD §4 실행 결과 합계: PASS 40 + SKIP 11 = 51개.
STD §3 TC 목록: TC-RES-001 ~ TC-RES-052 = 52건.

"40개 테스트 메서드"와 실제 TC 목록(52건), 실행 합계(51건)가 불일치한다. STD ReservationControllerTest 단위에 TC-RES-022(`call` 메서드 존재)가 추가로 있어 "6개" → "7개" 불일치도 있다.

**조치**: STD §1.2 및 §2.1 테스트 수, §4 합계를 실제 TC 목록과 일치하도록 수정.

---

## 엔드포인트 매트릭스

| # | HTTP | API 문서 URL | Routes.php 코드 | SRS/SDD URL | 인증(API) | role:callee | CSRF | FR 매핑 |
|---|------|-------------|----------------|------------|----------|------------|------|---------|
| 1 | GET | `/api/reservations/get-schedule` | 일치 | `/api/reservations/schedule` | 공개 | — | — | FR-RES-001 |
| 2 | POST | `/api/reservations/insert-reservation` | 일치 | `POST /api/reservations` | JWT | — | Y | FR-RES-002 |
| 3 | POST | `/api/reservations/get-my-reservation` | 일치 | `GET /api/reservations/{id}` | JWT | — | Y | FR-RES-004 |
| 4 | POST | `/api/reservations/get-my-reservation-list` | 일치 | `GET /api/reservations` | JWT | — | Y | FR-RES-003 |
| 5 | POST | `/api/reservations/get-callee-reservation-list` | 일치 | `GET /api/callees/reservations` | JWT | Y | Y | FR-RES-005 |
| 6 | POST | `/api/reservations/call` | 일치 | `PUT /api/reservations/{id}/call-status` | JWT | — | Y | FR-RES-006 |
| 7 | POST | `/api/o2o-calendars/o2o-calendar` | 일치 | `POST /api/callees/o2o-calendar` | JWT | Y | Y | FR-RES-007 |
| 8 | POST | `/api/calendars/calendar` | 일치 | `GET /api/calendar/monthly` | 공개 | — | — | FR-RES-008 |

**범례**: 인증(API) — API 문서 기준 / role:callee — Routes.php 코드 기준 / FR 매핑 — SRS §3 기준

---

## 특이 사항 점검 결과

### 1. 예약 생성 멱등성 (중복 예약 차단)
- **API 문서**: `409 CONFLICT` 에러 코드로 중복 예약 차단 명세 — 확인됨.
- **실제 코드**: `validateReservationRows()`에서 `checkReservation`(동일 예약 존재), `checkReservationDateTimeCnt`(슬롯당 1건 제한), `checkReservationDateCnt`(날짜당 2건 제한) 3단계 검증으로 중복 방지.
- **SRS/SDD 명세**: `SELECT FOR UPDATE` + `(callee_code, slot_time)` UNIQUE 인덱스 기반 멱등성 → 코드와 불일치(RESV-DEF-007).
- **판정**: 멱등성은 구현되어 있으나 방식이 SRS/SDD 명세와 다름. SRS/SDD 수정 필요.

### 2. 상담사 역할 필터 (role:callee) 적용 EP
Routes.php 코드에서 `role:callee` 필터가 적용된 EP:
- `POST /api/reservations/get-callee-reservation-list` — 적용 확인
- `POST /api/o2o-calendars/o2o-calendar` — 적용 확인

API 문서 표기와 일치한다.

### 3. 타임존 처리
- **코드**: `date()`, `time()`, `strtotime()` 함수 다수 사용 — CLAUDE.md 및 SRS NFR-RES-005 위반.
- **API 응답**: 슬롯 `time` 필드가 ISO 8601 UTC(`YYYY-MM-DDTHH:MM:SSZ`) 형식이 아닌 `H:i` 형식으로 반환됨 — IDD §7.2 명세와 불일치.
- **판정**: 타임존 처리 전면 개선 필요 (RESV-DEF-010).

---

## Open Questions

| # | 질문 | 관련 이슈 | 답변 요청자 |
|---|------|----------|-----------|
| OQ-001 | `O2oCalendarController`는 현재 조회 전용으로 구현되어 있으며 O2O 일정 등록(`createO2oEvent`) 기능이 없다. SRS/SDD 설계대로 등록 기능을 구현할 것인지, 아니면 현행 조회 전용으로 IEEE를 수정할 것인지? | RESV-DEF-009 | jypark |
| OQ-002 | 예약 등록 응답에서 `rv_no`(snake_case) → `rvNo`(camelCase) 변환이 누락되어 있다. 코드 수정 대상인지, 아니면 기존 프론트엔드 연동 관계로 유지할 것인지? | RESV-DEF-006 | jypark |
| OQ-003 | 슬롯 상태 응답이 API 문서의 `available: bool`과 코드의 `status: 'able'|'com'|'end'` 중 어느 쪽을 표준으로 확정할 것인지? | RESV-DEF-005 | jypark |
| OQ-004 | `ReservationController::getSchedule()`의 `todayCheck` 계산 및 `today` 날짜 포맷에 `date()`, `time()` 사용이 있다. DateTimeImmutable 전환 우선순위를 어떻게 설정할 것인지? | RESV-DEF-010 | jypark |
| OQ-005 | IDD §7.3의 예약 생성 응답이 전체 예약 데이터를 반환하는 확장 응답으로 설계되어 있으나, 실제 코드는 `rv_no`만 반환한다. API 응답 범위를 확장할 계획이 있는지? | RESV-DEF-014 | jypark |

---

## 조치 우선순위 요약

| 우선순위 | 이슈 ID | 조치 대상 | 유형 |
|---------|---------|---------|------|
| P0 (즉시) | RESV-DEF-001 | SRS §6, SDD §3.1~3.3, IDD §1.1 EP URL 전면 수정 | IEEE 수정 |
| P0 (즉시) | RESV-DEF-002 | SRS §6, SDD §3.1~3.3 HTTP 메서드 수정 | IEEE 수정 |
| P0 (즉시) | RESV-DEF-003 | SRS §2.4 인증 제약사항 공개 EP 예외 추가 | IEEE 수정 |
| P0 (즉시) | RESV-DEF-015 | STD TC-RES-007~011 기대 결과 에러 코드 수정 | STD 수정 |
| P1 (이번 스프린트) | RESV-DEF-005 | IDD §7.2 슬롯 응답 구조 현행화 + API 문서 수정 | IEEE+API 수정 |
| P1 | RESV-DEF-007 | SRS FR-RES-002-5, SDD §4.2 중복 차단 방식 현행화 | IEEE 수정 |
| P1 | RESV-DEF-009 | OQ-001 답변 후 SDD/IDD O2O 섹션 수정 또는 구현 완성 | 결정 필요 |
| P1 | RESV-DEF-010 | 코드 DateTimeImmutable 전환 계획 수립 | 코드 개선 |
| P2 (다음 스프린트) | RESV-DEF-011 | IDD §1.1 EP 수 수정 | IEEE 수정 |
| P2 | RESV-DEF-012 | IDD §5 이벤트 트리거 URL 수정 | IEEE 수정 |
| P2 | RESV-DEF-013 | IDD §10 FR 번호 교정 | IEEE 수정 |
| P2 | RESV-DEF-016 | STD TC role:callee 통합 TC 추가 | STD 보완 |
| P3 (백로그) | RESV-DEF-004 | API 문서 CSRF 면제 비고란 추가 | API 문서 수정 |
| P3 | RESV-DEF-006 | IDD §7.3 응답 필드 정합 + 코드 camelCase 변환 | 코드+IEEE 수정 |
| P3 | RESV-DEF-008 | SRS/SDD role:callee URL 동시 수정 (DEF-001과 묶음) | IEEE 수정 |
| P3 | RESV-DEF-014 | IDD §7.7 DTO 범위 확정 | 결정 필요 |
| P3 | RESV-DEF-017 | STD §1.2, §2.1, §4 TC 수 일치 | STD 수정 |
