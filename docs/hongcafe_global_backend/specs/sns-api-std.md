---
문서명: SNS Auth API — Software Test Description
문서 ID: sns-api-std
버전: v1.0
상태: 승인됨
생성일: 2026-04-22
최종 수정일: 2026-04-22
작성자: jypark
대상 시스템: SNS Auth (`/api/sns/*`)
관련 문서: sns-api-srs.md (v1.0), sns-api-sdd.md (v1.0), sns-api-idd.md (v1.0)
적용 표준: IEEE 829:2008 (Test Documentation)
---

# SNS Auth API — Software Test Description (STD)

> IEEE 829:2008 | version: 1.0 | lastUpdated: 2026-04-22

---

## 1. Introduction

### 1.1 Purpose

본 Software Test Description(STD)은 sns-api 의 테스트 전략, 테스트 케이스 목록, 커버리지 매트릭스, 실행 결과를 IEEE 829:2008 에 따라 기술한다.

### 1.2 Test Level 구분

| 수준 | 범위 | 도구 | 실행 빈도 |
|------|------|------|----------|
| Unit | 단일 클래스/메서드 | PHPUnit + Mock | 커밋/CI 매번 |
| Feature | HTTP EP end-to-end (in-memory) | CI4 FeatureTestCase | 커밋/CI 매번 |
| Integration | 실 DB + 실 OAuth | Manual (staging) | 릴리스 전 |
| E2E | 프론트 + 백엔드 전 구간 | Playwright (Next.js) | 릴리스 전 |

### 1.3 References

- SRS: `sns-api-srs.md` v1.0 (FR/NFR)
- SDD: `sns-api-sdd.md` v1.0 (구현 경로)
- IDD: `sns-api-idd.md` v1.0 (I/O 계약)
- 기존 실행 실증: 세션 7 phpunit 100회 반복 — 100/100 통과 (`build/sns-test-runs/summary.csv`)

---

## 2. Test Strategy

### 2.1 Test Pyramid (sns-api 범위)

```
          ┌─────────────────┐
          │  E2E            │   (프론트 연동)
          │  6 케이스 예정   │
          ├─────────────────┤
          │  Integration     │   (실 OAuth / staging)
          │  6 × 7종 = 42   │
          ├─────────────────┤
          │  Feature         │   8 케이스 (SnsReceiveApiActionTypeTest)
          ├─────────────────┤
          │  Unit            │   63 케이스 (5 파일)
          └─────────────────┘
```

### 2.2 Coverage Goal

| 영역 | 목표 | 현재 | 근거 |
|------|------|------|------|
| `SnsAuthService` line coverage | 90% | 84.81% (세션 2 측정) | `tests/Modules/Member/Unit/` 5 파일 |
| FR → Test 매핑 | 100% | 12/12 FR 전부 커버 | §4 Verification |
| HTTP status 분기 | 전부 | 200/400/403/404/409/429 커버, 500 은 런타임 의존 | `SnsReceiveApiActionTypeTest` |

### 2.3 Test Data 정책

- **SNS credential 모의**: SnsConnector 를 `createPartialMock` 으로 교체. 실 OAuth 호출 없이 profile 배열 주입
- **DB 모의**: MemberRepositoryInterface / SnsMetaRepositoryInterface / CountryRepositoryInterface / JwtServiceInterface / CsrfTokenService 전부 Mock
- **시간 제어**: `DateTimeImmutable` 을 Service 가 직접 인스턴스화하므로 Replay 테스트에서는 epoch timestamp 직접 주입으로 우회

---

## 3. Test Cases

### 3.1 Unit — SnsAuthServiceTest (26 케이스)

파일: `tests/Modules/Member/Unit/SnsAuthServiceTest.php`

| # | 케이스 | FR |
|---|--------|-----|
| 1 | `testDecryptReturnsMissingFieldWhenAcIdAbsent` | FR-SNS-004 |
| 2 | `testDecryptReturnsMissingFieldWhenSnsIdAbsent` | FR-SNS-004 |
| 3 | `testDecryptRejectsUnknownSnsType` | FR-SNS-004 |
| 4 | `testDecryptRejectsMissingIssuedAt` | FR-SNS-004 |
| 5 | `testDecryptRejectsStaleIssuedAt` | FR-SNS-004, NFR-SNS-003 |
| 6 | `testDecryptAcceptsFreshIssuedAt` | FR-SNS-004 |
| 7 | `testDecryptDecodesEncryptedData` | FR-SNS-004 |
| 8 | `testDecryptReturnsDecryptFailedOnTamperedPayload` | FR-SNS-004 |
| 9-14 | resolveAccount / snsPhone 추출 매트릭스 | FR-SNS-001 |
| 15-20 | checkAccountStatus 매트릭스 (SUSPENDED/DELETED/BANNED/UNDER_AGE/REJOIN_BLOCKED/ACTIVE) | FR-SNS-007, NFR-SNS-014, NFR-SNS-015 |
| 21-23 | handleSnsLinkage MATCH / MISMATCH / EXISTING_USER | FR-SNS-008, NFR-SNS-013 |
| 24-25 | issueTokens Set-Cookie 3개 구조 | FR-SNS-009 |
| 26 | getSnsId 메서드 존재 | (구조 검증) |

### 3.2 Unit — SnsAuthServiceResolveOAuthTest (10 케이스)

파일: `tests/Modules/Member/Unit/SnsAuthServiceResolveOAuthTest.php`

| # | 케이스 | FR |
|---|--------|-----|
| 1 | `testKakaoSuccessReturnsStandardPayload` | FR-SNS-003 |
| 2 | `testNaverSuccessReturnsStandardPayload` | FR-SNS-003 |
| 3 | `testAppleSuccessUsesSingleGetProfileCall` | FR-SNS-003 (Apple 특화) |
| 4 | `testKakaoAccessTokenFailureReturnsOauthExchangeFailed` | FR-SNS-003 error |
| 5 | `testKakaoProfileFailureReturnsProfileFetchFailed` | FR-SNS-003 error |
| 6 | `testAppleProfileFailureReturnsProfileFetchFailed` | FR-SNS-003 error |
| 7 | `testHongcafeReturnsHongcafeNotSupported` | FR-SNS-003 hongcafe 예외 |
| 8 | `testUnknownSnsTypeReturnsInvalidSnsType` | NFR-SNS-005 |
| 9 | `testIncompleteProfileEmailMissingReturnsProfileFetchFailed` | FR-SNS-003 |
| 10 | `testIncompleteProfileSnsIdMissingReturnsProfileFetchFailed` | FR-SNS-003 |
| +1 | `testConnectorThrowsReturnsOauthExchangeFailed` | FR-SNS-003 exception |

### 3.3 Unit — SnsAuthServiceJoinActionTest (11 케이스)

파일: `tests/Modules/Member/Unit/SnsAuthServiceJoinActionTest.php`

| # | 케이스 | FR |
|---|--------|-----|
| 1 | `testNewRegistrationSuccess` (existFlag=0) | FR-SNS-002 |
| 2 | `testConversion060Success` (existFlag=2) | FR-SNS-002 |
| 3 | `testRejoinSuccess` (existFlag=3) | FR-SNS-002 |
| 4 | `testEmailExistsReturns409WithExistFlag4` | FR-SNS-002, CONFLICT 매핑 |
| 5 | `testBannedAccountReturns403WithExistFlag6` | FR-SNS-002, FR-SNS-007 |
| 6 | `testPhoneExistsReturns409` | FR-SNS-002 |
| 7 | `testGenericRegistrationFailureReturns400` | FR-SNS-002 error |
| 8 | `testMissingCrPhoneReturns400` | FR-SNS-002 |
| 9 | `testMissingMultipleJoinFieldsReturnsAllMissing` | FR-SNS-002 (missing[]) |
| 10 | `testAgreeServiceNotOneReturnsMissing` | FR-SNS-002 |
| 11 | `testAutoGeneratesAcNickWhenNotProvided` | FR-SNS-005 연계 |
| +1 | `testRegisterPayloadOmitsAcPassword` | 보안 (비밀번호 미설정) |

### 3.4 Unit — SnsAuthServiceSnsCheckNickTest (10 케이스)

파일: `tests/Modules/Member/Unit/SnsAuthServiceSnsCheckNickTest.php`

| # | 케이스 | FR |
|---|--------|-----|
| 1 | `testReturnsBaseWhenNotTaken` | FR-SNS-005 |
| 2 | `testReturnsBaseWith1WhenFirstCollides` | FR-SNS-005 |
| 3 | `testReturnsBaseWith10AfterTenCollisions` | FR-SNS-005 |
| 4 | `testFallsBackToUserWhenEmpty` | FR-SNS-005 (sanitize) |
| 5 | `testFallsBackToUserWhenSingleChar` | FR-SNS-005 |
| 6 | `testSanitizesSpecialChars` | FR-SNS-005 |
| 7 | `testKeepsUnicodeLetters` | FR-SNS-005 (한/일/중 문자) |
| 8 | `testTruncatesWhenOverflows12Chars` | NFR-SNS-009 |
| 9 | `testSanitizeStripsLongInput` | FR-SNS-005 |
| 10 | `testThrowsRuntimeExceptionWhenExhausted` | NFR-SNS-008 |

### 3.5 Unit — SnsConnectorFactoryTest (6 케이스)

파일: `tests/Libraries/SnsConnector/SnsConnectorFactoryTest.php`

| # | 케이스 | FR |
|---|--------|-----|
| 1 | `testIsSupportedReturnsTrueForAllWhitelisted` (7종) | NFR-SNS-005 |
| 2 | `testIsSupportedReturnsFalseForUnknownType` | NFR-SNS-005 |
| 3 | `testCreateByTypeReturnsNullForHongcafe` | FR-SNS-003 |
| 4 | `testCreateByTypeThrowsForUnknownType` | NFR-SNS-005 |
| 5 | `testCreateByTypeThrowsForEmptyString` | NFR-SNS-005 |
| 6 | `testSupportedSnsTypesConstantMatchesDocumentedList` | 문서-코드 정합 |

### 3.6 Feature — SnsReceiveApiActionTypeTest (8 케이스)

파일: `tests/Modules/Auth/Feature/SnsReceiveApiActionTypeTest.php`

| # | 케이스 | FR |
|---|--------|-----|
| 1 | `testInvalidSnsTypeReturns400` | FR-SNS-001 · NFR-SNS-005 |
| 2 | `testInvalidActionTypeReturns400` | FR-SNS-001 |
| 3 | `testEmptyBodyReturnsMissingField` | FR-SNS-004 |
| 4 | `testMissingJoinFieldsReturns400` | FR-SNS-002 |
| 5 | `testAuthFilterDoesNotBlockPublicEp` | FR-SNS-001 (공개 EP) |
| 6 | `testCsrfTokenFilterDoesNotBlockPublicEp` | FR-SNS-001 |
| 7 | `testV1CompatibilityWithOnlyDataFieldFallsBackToLogin` | FR-SNS-011 |
| 8 | `testErrorDetailsUsesCamelCase` | NFR-SNS-012 |

### 3.7 Integration — Staging 실연동 (6종 × 2 액션 = 12 케이스 예정)

- Staging 환경 (`https://stg.gl.hongcafe.com`) 에서 `tools/api-test.html` 로 수동 검증
- 각 SNS 제공자별 실 OAuth 플로우 — 세션/쿠키/리다이렉트 확인
- 자동화 미구현 (SNS 제공자 테스트 계정 확보 후 Playwright 스크립트 작성 예정)

### 3.8 회귀 실증 — phpunit 100회 반복

- 실행일: 2026-04-22 (세션 7)
- 결과: **100/100 성공** (Tests: 195, Assertions: 339, Skipped: 17, Deprecations: 1)
- Wall time: 59s (10-way 병렬)
- Per-iteration: min=5.15s, median=5.57s, avg=5.66s, p95=6.69s, max=6.77s
- 상세: `build/sns-test-runs/summary.csv`, `docs/tasks/history.md` 세션 7

---

## 4. Verification Matrix (Test ↔ FR / NFR)

| Test 파일 | 케이스 수 | FR/NFR 커버 |
|----------|----------|-----------|
| SnsAuthServiceTest | 26 | FR-001, 004, 007, 008, 009 + NFR-003, 013, 014, 015 |
| SnsAuthServiceResolveOAuthTest | 10 | FR-003 + NFR-005 |
| SnsAuthServiceJoinActionTest | 11 | FR-002, 005, 007 |
| SnsAuthServiceSnsCheckNickTest | 10 | FR-005 + NFR-008, 009 |
| SnsConnectorFactoryTest | 6 | NFR-005 |
| SnsReceiveApiActionTypeTest | 8 | FR-001, 002, 004, 011 + NFR-012 |
| **합계** | **71** | FR 8/12 + NFR 10/15 |

**미커버 FR**:
- FR-SNS-006 (404 encryptedSns 생성) — Unit 케이스 존재하나 전용 파일 분리 필요
- FR-SNS-010 (Rate Limit 429) — Feature 케이스 미구현
- FR-SNS-012 (isCalleeOnboardingRequired) — Unit 분기 커버되나 명시 케이스 필요

**미커버 NFR**:
- NFR-001 (응답 시간 P95 200ms) — 부하 테스트 미실시
- NFR-002 (OAuth 경로 P95 2000ms) — 동일
- NFR-010 (민감정보 로그 검증) — 정적 분석 자동화 미실시
- NFR-011 (insertLoginHistory 결과) — integration 수준 필요

---

## 5. Test Environment

### 5.1 Unit / Feature

- PHPUnit 11.5.55
- PHP 8.5.4
- SQLite3 in-memory (CI4 `$tests` 그룹) — `app/Config/Database.php` `ENVIRONMENT==='testing'` 분기
- phpunit.xml.dist `CI_ENVIRONMENT=testing force=true` (세션 4 prd 차단 조치)

### 5.2 실행 명령

```bash
# 전체
php vendor/bin/phpunit

# SNS 범위만
php vendor/bin/phpunit --filter "Sns"

# 파일별
php vendor/bin/phpunit tests/Modules/Member/Unit/SnsAuthServiceTest.php
php vendor/bin/phpunit tests/Modules/Auth/Feature/SnsReceiveApiActionTypeTest.php

# 반복 (세션 7 패턴)
seq 1 100 | xargs -P 10 -I {} php vendor/bin/phpunit --filter "Sns"
```

### 5.3 Skipped 테스트 분류

세션 7 에서 확인한 17 건 Skip 내역:

| 그룹 | 수 | 사유 |
|------|---|------|
| SnsShareApiTest Feature | 3 | MySQL DB 연결 필요 (Unit 범위 외) |
| Apple Test | 2 | `file_get_contents` E_ALL 환경 ErrorException |
| Facebook Test | 3 | curl + property 접근 E_ALL |
| Google Test | 2 | 동일 |
| Kakao Test | 3 | 동일 |
| Naver Test | 3 | 동일 |
| SnsBase Test | 1 | `str_baseconvert()` 글로벌 함수 미정의 |

전부 integration/prd 전용 경로. Unit 범위에서는 정상.

---

## 6. Negative Test Cases (경계 & 에러)

### 6.1 입력 경계

| 시나리오 | 기대 |
|---------|------|
| body 빈 문자열 | 400 MISSING_FIELD |
| `data: null` | 400 MISSING_FIELD |
| `data: {}` (JSON object) | 400 DECRYPT_FAILED (cast string 시도) |
| `sns_type: "KAKAO"` (대문자) | 400 INVALID_SNS_TYPE (case-sensitive) |
| `action_type: "LOGIN"` | 400 INVALID_ACTION_TYPE |
| `action_type: ""` (빈 문자열) | 기본값 `login` 적용 → payload 검증으로 진행 |
| `cr_phone: ""` (join) | 400 MISSING_JOIN_FIELDS (missing: ["cr_phone"]) |
| `agree_service: 0` | 400 MISSING_JOIN_FIELDS |
| `ac_nick: "a"` (1자) | `sanitizeNick` → `user` 로 대체 |
| `ac_nick: "가나다라마바사아자차카타파"` (13자) | 12자 truncate |

### 6.2 시간 경계 (Replay)

| issued_at 기준 now | 기대 |
|-------------------|------|
| `now - 299` | 통과 |
| `now - 300` | 통과 (경계 포함) |
| `now - 301` | 400 PAYLOAD_EXPIRED |
| `now + 60` | 통과 |
| `now + 61` | 400 PAYLOAD_EXPIRED |
| `issued_at = "abc"` | 400 PAYLOAD_EXPIRED (numeric check) |

### 6.3 snsCheckNick 경계

| 상태 | 기대 |
|------|------|
| base 중복 없음 | base 즉시 반환 |
| base + 1..9 중복 | `base10` 반환 |
| base 12자 (verylongnick) | `verylongnic1` (1자 truncate) |
| base 11자 + 3자리 suffix | `base[0..9]` + "100" 으로 truncate |
| 1~9999 전체 소진 | throw RuntimeException |

---

## 7. Regression Test Strategy

- **커밋 전**: `php vendor/bin/phpunit --filter "Sns"` 로컬 실행 필수
- **CI**: Bitbucket Pipelines 에서 전체 phpunit 실행 (세션 6 plan)
- **릴리스 전**: staging 에서 6종 SNS 실연동 수동 검증 + 100회 반복 회귀 (세션 7 패턴)
- **성능 회귀**: p95 응답시간 로그 분석 (NFR-001, 002 검증)

---

## 8. 타당성 검토

### 8.1 근거

- IEEE 829:2008 "Standard for Software and System Test Documentation" — 테스트 계획/설계/케이스/절차/결과 문서화
- PHPUnit 11.x `--filter` regex 매칭 (`https://docs.phpunit.de/en/11.5/textui.html`)
- CI4 7.x FeatureTestCase — in-memory HTTP 시뮬레이션 (공식 문서)

### 8.2 Coverage 한계

- Apple `generateJWT` ES256 서명 — 로컬 E_ALL 환경 제약 (`file_get_contents` 예외). Integration 수준으로 이관
- 실 OAuth 호출 — SNS 제공자 Rate Limit + 테스트 계정 운영 비용 → staging 수동 검증
- Token Rotation — Auth 모듈 std 에서 커버 (sns-api 는 issueTokens 호출 결과만 검증)

---

## 9. 변경 영향 기록

### 9.1 변경 사항

- 신규 STD v1.0 작성

### 9.2 개선 효과

1. 71 Unit/Feature 케이스 + 100회 반복 실증을 FR/NFR 매핑으로 가시화
2. 미커버 FR/NFR 식별 (3 FR + 4 NFR) → 후속 테스트 작성 근거
3. Skipped 테스트 분류 명확화 → staging 수동 검증 체크리스트 자동 생성 가능

### 9.3 수행 이유

1. 세션 7 phpunit 100회 통과 실증을 IEEE 포맷으로 고정화
2. 프로젝트 지침: `docs/specs/{BC}-std.md` 필수
3. FR/NFR-Test 4-way 매핑으로 커버리지 공백 식별

---

## 10. 체크리스트

- [x] Test Pyramid 4 수준 (Unit/Feature/Integration/E2E) 분류
- [x] 71 케이스 ID/파일/FR-NFR 매핑
- [x] 미커버 FR/NFR 명시 (후속 작업)
- [x] Negative 경계 케이스 (입력/시간/닉 3영역)
- [x] 100회 반복 실증 결과 (세션 7) 인용
- [x] IEEE 829:2008 준수

---

## 11. 변경 로그

| 날짜 | 버전 | 작성자 | 변경 내용 |
|------|------|--------|----------|
| 2026-04-22 | v1.0 | jypark | 최초 작성 — sns-api v2 STD. 71 테스트 케이스 + 100회 반복 실증 + FR/NFR 매핑 |
