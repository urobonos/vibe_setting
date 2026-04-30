---
name: global-context
description: >
  HongCafe Global 프로젝트 전용 — 다국가 서비스 컨텍스트 스킬.
  국가코드 전달, Country Resolver, 국가별 Config, Feature Flag,
  i18n, 타임존, 배포 환경 분리 규칙. 다른 프로젝트(infra, frontend 외부 등)
  에서는 본 스킬을 호출하지 않는다.
triggers:
  - "국가" + (hongcafe / global / backend) 컨텍스트
  - "country", "i18n", "다국어", "타임존", "timezone"
    (hongcafe_global_* 레포 또는 ~/.claude 작업 컨텍스트일 때)
  - "Country Resolver", "ISO 3166", "JWT claim country"
  - "currency", "locale" (HongCafe Global 컨텍스트 동반 시)
  - "Feature Flag", "피처플래그"
  - "배포 환경", "deploy" (HongCafe Global 한정)
  - app/Config/Countries/ 하위 파일 생성/수정 시
  - Language/ 하위 파일 생성/수정 시
version: 1.0.0
user-invocable: false
depends_on: [php8]
conflicts_with: []
min_claude_md_version: "4.0"
---

# 글로벌 다국가 서비스 컨텍스트

HongCafe Global 프로젝트의 다국가 서비스 운영에 필요한 국가 컨텍스트, 국제화, 타임존, Feature Flag, 배포 환경 분리 규칙.

> **[프로젝트 한정]** 본 스킬은 HongCafe Global(`hongcafe_global_backend` / `hongcafe_global_frontend`) 프로젝트 전용. 다른 프로젝트(`infra` 외부 등) 에서 트리거 매칭 시 활성화하지 않는다. 본문에 등장하는 `app/Config/Countries/`, `Services::country()`, `tb_feature_flags`, Aurora MySQL 등은 모두 HongCafe Global 코드 패턴이다.

---

## 1. 국가코드 전달 (6-1)

클라이언트 → 서버 국가코드 전달 방식:

| 방식 | 설명 | 우선순위 |
|------|------|---------|
| **JWT claim** | 토큰 내 `country` 클레임 | 1순위 (인증된 사용자) |
| **X-Country-Code 헤더** | 커스텀 HTTP 헤더 | 2순위 (비인증 요청) |
| **.env 기본값** | `app.defaultCountry` | 3순위 (fallback) |

- 국가코드는 **ISO 3166-1 alpha-2** (대문자 2자리: `US`, `KR`, `JP`)
- 모든 API 요청에서 국가 컨텍스트를 결정한 후 비즈니스 로직 실행

---

## 2. Country Resolver (6-2)

국가 컨텍스트 결정 우선순위:

```
JWT country claim  →  X-Country-Code 헤더  →  .env 기본값  →  Accept-Language 추론
```

- Country Resolver는 CI4 Filter로 구현하여 모든 요청에 자동 적용
- 결정된 국가코드는 `Services::country()` 또는 `service('country')` 로 접근
- Controller/Service/Repository 어디서든 현재 국가 컨텍스트 참조 가능

---

## 3. 국가별 Config (6-3)

```
app/Config/Countries/
├── US.php      # 미국 설정
├── KR.php      # 한국 설정
└── JP.php      # 일본 설정
```

각 국가 Config 파일 구조:

```php
<?php

declare(strict_types=1);

return [
    'currency'     => 'USD',
    'timezone'     => 'America/New_York',
    'locale'       => 'en_US',
    'dateFormat'   => 'M d, Y',
    'phonePrefix'  => '+1',
    'taxRate'      => 0.0,
    'features'     => [],  // 국가별 Feature Flag 오버라이드
];
```

- 국가 Config는 Country Resolver가 결정한 국가코드로 자동 로드
- `config('Countries/' . $countryCode)` 로 접근

---

## 4. Feature Flag (6-4)

국가별/기능별 Feature Flag 관리:

| 저장소 | 역할 |
|--------|------|
| **DB** (`tb_feature_flags`) | SSOT — 기능명, 국가, 활성 여부, 시작/종료일 |
| **Redis 캐시** | 읽기 성능 — TTL 5분, DB 변경 시 캐시 무효화 |

- Feature Flag 조회: `service('featureFlag')->isEnabled('feature_name', $countryCode)`
- 새 기능 배포 시 DB에 Flag 등록 → 국가별 점진적 활성화
- Flag 미등록 기능은 기본 비활성(fail-closed)

---

## 5. i18n 파일 구조 (6-5)

```
app/Language/
├── en/
│   └── Messages.php
├── ko/
│   └── Messages.php
└── ja/
    └── Messages.php
```

- CI4 기본 Language 디렉토리 구조 활용
- `lang('Messages.welcome')` 형태로 호출
- 로케일은 Country Resolver가 결정한 국가 Config의 `locale` 값으로 자동 설정
- API 응답 메시지(에러/성공)는 반드시 i18n 키 사용, 하드코딩 금지
**Why:** 다국가 서비스에서 메시지를 코드에 하드코딩하면 신규 국가 추가 시 전체 코드를 뒤져 번역해야 하고, 한 언어 사용자에게 다른 언어 문자열이 노출되는 사고가 발생한다.

---

## 6. DB 타임존 (6-6)

| 구간 | 타임존 | 비고 |
|------|--------|------|
| **DB 저장** | **UTC 고정** (SSOT) | 모든 DATETIME/TIMESTAMP 컬럼은 UTC |
| **서버 처리** | UTC | PHP `date_default_timezone_set('UTC')` |
| **API 응답** | UTC (ISO 8601) | `2026-04-08T09:30:00Z` 형식 |
| **클라이언트 표시** | 사용자 타임존 | 프론트엔드에서 변환 |

- DB `SET time_zone = '+00:00'` 연결 시 강제
- Aurora MySQL 서버 타임존도 UTC 고정

---

## 7. DateTimeImmutable 강제 (6-7)

| 허용 | 금지 |
|------|------|
| `new \DateTimeImmutable()` | `date()` |
| `\DateTimeImmutable::createFromFormat()` | `time()` |
| `CarbonImmutable` (사용 시) | `strtotime()` |
| | `DateTime` (mutable) |

- 모든 날짜/시간 처리는 **`\DateTimeImmutable`** 전용
- mutable `DateTime` 사용 금지 — 의도치 않은 상태 변경 방지
**Why:** 다국가 타임존 변환 중 mutable `DateTime` 객체가 다른 함수에서 `setTimezone()` 으로 원본까지 바뀌면, UTC 저장값이 로컬 타임존으로 오염되어 DB 에 잘못된 시각이 기록되는 사고가 발생한다.
- 타임존 변환: `$dt->setTimezone(new \DateTimeZone($userTz))`

---

## 8. 배포 환경 분리 (6-8)

```
deploy/
├── us/
│   ├── .env
│   └── deploy.sh
├── kr/
│   ├── .env
│   └── deploy.sh
└── jp/
    ├── .env
    └── deploy.sh
```

- 국가별 `.env` 파일로 DB 접속, API 키, 외부 서비스 엔드포인트 분리
- 배포 스크립트(`deploy.sh`)도 국가별 분리 — 리전, 인스턴스 ID 등 차이
- CI/CD 파이프라인에서 `COUNTRY` 환경변수로 대상 국가 지정

---

## 9. Ubiquitous Language (도메인 용어 통일)

다국가 서비스에서 **코드·DB·API·문서·기획서가 동일 도메인 용어를 사용**하도록 통일한다. 서로 다른 표현이 혼재하면 번역/i18n/검색 정확도가 하락한다.

### 원칙

- **전체 단어 사용** — 축약어 금지 (`str`, `idx`, `pwd`, `usr` 등)
- **영문 단일 표기** — 코드상 용어는 영문만. 번역은 i18n 파일에서 처리
- **도메인 주도 명명** — 기술 용어(`processRow`)보다 비즈니스 용어(`confirmOrder`) 우선
- **일관성** — 같은 개념에 하나의 이름. `user`/`member`/`account` 를 문맥에 따라 섞지 않는다

### snake_case ↔ camelCase 변환

| 계층 | 표기 | 예시 |
|------|------|------|
| DB 컬럼 | `snake_case` | `counselor_id`, `created_at` |
| PHP 변수/메서드 | `camelCase` | `$counselorId`, `findById()` |
| API 응답 키 | `camelCase` | `counselorId`, `createdAt` |
| i18n 키 | `namespace.camelCase` | `order.confirmButton` |

Entity 의 `toApiResponse()` 에서 수동 변환 — 자동 변환 라이브러리 사용 금지.

### 프로젝트별 용어 매핑

프로젝트 고유 도메인 용어(레거시 약어 → 신규 표준 매핑 등)는 프로젝트 `CLAUDE.md` 의 "Ubiquitous Language" 섹션을 SSOT 로 따른다. 글로벌 스킬에는 하드코딩하지 않는다.

---

## 자가 검증 체크리스트

- [ ] 국가코드는 ISO 3166-1 alpha-2를 사용하는가
- [ ] Country Resolver 우선순위(JWT → 헤더 → .env → Accept-Language)를 준수하는가
- [ ] 국가별 Config 파일이 `app/Config/Countries/{CODE}.php`에 존재하는가
- [ ] Feature Flag 조회 시 캐시(Redis) → DB fallback 순서인가
- [ ] 모든 DB DATETIME 컬럼이 UTC로 저장되는가
- [ ] `date()`, `time()`, `strtotime()`, `DateTime` 사용이 없는가
- [ ] API 응답 메시지가 i18n 키를 사용하는가 (하드코딩 없음)
- [ ] 배포 환경이 국가별로 분리되어 있는가
