# HongCafe Global Backend — 종합 개발 레퍼런스

> **최종 갱신:** 2026-04-14  

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-14 |
| 유형 | report |
| 상태 | 승인됨 |

> **브랜치:** `dev/migration`  
> **작성 기준:** 프로젝트 지침(CLAUDE.md), 글로벌 지침, 16개 스킬, c:/works/infra, git 이력

---

## 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [Tech Stack](#2-tech-stack)
3. [아키텍처](#3-아키텍처)
4. [인프라 구성](#4-인프라-구성)
5. [DB 구성](#5-db-구성)
6. [CI/CD 파이프라인](#6-cicd-파이프라인)
7. [Lambda & Data Sync](#7-lambda--data-sync)
8. [보안 정책](#8-보안-정책)
9. [API 응답 표준](#9-api-응답-표준)
10. [라우트 정책](#10-라우트-정책)
11. [글로벌 컨텍스트](#11-글로벌-컨텍스트)
12. [코딩 표준](#12-코딩-표준)
13. [테스트](#13-테스트)
14. [브랜치 전략 & 커밋 컨벤션](#14-브랜치-전략--커밋-컨벤션)
15. [환경 설정](#15-환경-설정)
16. [마이그레이션 현황](#16-마이그레이션-현황)

---

## 1. 프로젝트 개요

HongCafe Global Backend는 다국가(US/KR/JP) 통화 상담 플랫폼의 백엔드 API 서버다. 레거시 CI4 MVC 코드를 Modular Monolith로 점진 마이그레이션 중이며, 단일 EC2 인스턴스에서 3개 환경(prd/stg/dev)을 운영한다.

- **서비스 도메인:** 통화 상담(Call), 채팅(Chat), 상거래(Commerce), 결제(Payment), 예약(Reservation) 등 15개 BC
- **프론트엔드:** Next.js 16 (별도 리포지토리 `peoplev_dev/hongcafe_global_frontend`)
- **백엔드 리포지토리:** Bitbucket `peoplev_dev/hongcafe_global_backend`

| 환경 | URL |
|------|-----|
| Production | `https://prd.gl.hongcafe.com` |
| Staging | `https://stg.gl.hongcafe.com` |
| Development | `https://dev.gl.hongcafe.com` |

---

## 2. Tech Stack

| 항목 | 버전 | 비고 |
|------|------|------|
| PHP | 8.4+ (프로덕션 8.5.3) | Constructor Promotion, Enums, Property Hooks |
| CodeIgniter | 4.7+ | Modular Monolith 기반 |
| MySQL | Aurora MySQL 3.12.0 (Compatible with MySQL 8.0.44) | RDS Proxy IAM Auth |
| Nginx | 1.28.2 | 리버스 프록시 (PHP-FPM + Next.js) |
| PHP-FPM | 8.5.3 | 환경별 Pool 분리 (포트 8080/8081/8082) |
| Next.js | 16 | 프론트엔드, PM2 관리 |
| Node.js | v24.14.0 | PM2 런타임 |
| PM2 | v6.0.14 | Next.js 프로세스 관리 (포트 3000/3001/3002) |
| AWS SDK | PHP + Python (Lambda) | SNS, SQS, RDS Proxy, EC2 |
| Stripe | PHP SDK | 결제 처리 |
| Sendbird | REST API | 채팅 인프라 |

**주요 PHP 버전별 기능 활용:**

| PHP 버전 | 활용 기능 |
|----------|----------|
| 8.0 | Constructor Promotion, Named Arguments, Union Types, match 표현식 |
| 8.1 | Enums, readonly 프로퍼티, Fibers, Intersection Types |
| 8.2 | readonly 클래스, DNF Types |
| 8.4 | Property Hooks, Asymmetric Visibility |

---

## 3. 아키텍처

### 3.1 전체 구조: Modular Monolith (Dual Mode)

레거시 코드와 신규 모듈이 공존하는 듀얼 모드 아키텍처다. 마이그레이션 완료까지 두 모드를 병행 운영한다.

```
┌─────────────────────────────────────────────────────────┐
│                      Nginx (Reverse Proxy)               │
│  /api/* → PHP-FPM    /  → Next.js (PM2)                │
├─────────────────────────────────────────────────────────┤
│                     CI4 Application                      │
│                                                          │
│  ┌──────────────────┐  ┌──────────────────────────────┐ │
│  │   Legacy Mode     │  │       New Mode (Modular)      │ │
│  │                    │  │                                │ │
│  │  Controllers/Api/  │  │  Modules/{BC}/Controllers/    │ │
│  │  Libraries/        │  │  Modules/{BC}/Services/       │ │
│  │  Models/           │  │  Modules/{BC}/Repositories/   │ │
│  │                    │  │  Modules/{BC}/Models/          │ │
│  │  (Flat MVC)        │  │  Modules/{BC}/Entities/       │ │
│  │                    │  │  Modules/{BC}/ValueObjects/   │ │
│  │                    │  │  Modules/{BC}/Interfaces/     │ │
│  └──────────────────┘  └──────────────────────────────┘ │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │              Modules/Shared/                       │   │
│  │  Models, Entities, ValueObjects, Interfaces       │   │
│  └──────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────┤
│              Aurora MySQL (RDS Proxy IAM Auth)           │
└─────────────────────────────────────────────────────────┘
```

### 3.2 Legacy Mode

| 항목 | 설명 |
|------|------|
| 경로 | `app/Controllers/Api/`, `app/Libraries/`, `app/Models/` |
| 패턴 | Flat MVC — Controller가 Library/Model 직접 호출 |
| DI | 유연함 (`new` 허용, `service()` 권장) |
| 수정 원칙 | 기존 패턴 유지. 사이드 이펙트 분석 후 최소 변경 |
| 마이그레이션 | 신규 기능은 반드시 New Mode로 작성 |

### 3.3 New Mode (Modular Monolith)

**레이어 구조 (상위 → 하위, 단방향 참조만 허용):**

```
Controller → Service → Repository → Model
                ↓           ↓
            Entity/VO    Query Builder / Raw SQL
```

| 레이어 | 역할 | 규칙 |
|--------|------|------|
| **Controller** | HTTP 요청/응답 처리 | BaseApiController 상속, 비즈니스 로직 금지, Service만 호출 |
| **Service** | 비즈니스 로직 | Interface 필수, `service()` DI 강제, 트랜잭션 관리 |
| **Repository** | 데이터 접근 | Interface 필수, Query Builder 우선, CTE/Window는 raw query |
| **Model** | CI4 Model (ORM) | DB 테이블 매핑, validation rules, type casting |
| **Entity** | 도메인 객체 | 순수 PHP (Framework/DB import 금지), 비즈니스 규칙 포함 |
| **ValueObject** | 불변 값 객체 | `readonly` 필수, 자기 유효성 검증, 동등성 비교 |

**디렉토리 구조 (모듈당):**

```
app/Modules/{BC}/
├── Config/
│   └── Routes.php          ← 모듈별 라우트 정의
├── Controllers/
│   └── {Name}Controller.php
├── Services/
│   └── {Name}Service.php
├── Repositories/
│   └── {Name}Repository.php
├── Models/
│   └── {Name}Model.php
├── Entities/
│   └── {Name}Entity.php    ← 도메인 규칙이 있을 때만
├── ValueObjects/
│   └── {Name}VO.php        ← readonly, self-validation
├── Interfaces/
│   ├── {Name}ServiceInterface.php
│   └── {Name}RepositoryInterface.php
├── Exceptions/
│   └── {Name}Exception.php ← 모듈 고유 예외
└── Config/
    └── Routes.php
```

**현재 15개 BC 모듈:**
Auth, Board, Call, Chat, Commerce, Content, Event, Member, Notification, Payment, Promotion, Reservation, Service, Shared, Social

### 3.4 모듈 간 통신 규칙

```
[Module A] ──Interface──▶ [Module B Service]
                              │
                         service() DI
```

| 규칙 | 설명 |
|------|------|
| Interface Only | 다른 모듈의 구체 클래스 직접 참조 금지 |
| `service()` DI 강제 | `new Service()` 금지, CI4 DI 컨테이너 사용 |
| Shared 모듈 | `Modules/Shared/`에 공용 Models, Entities, ValueObjects, Interfaces 배치 |
| 네임스페이스 | `App\Modules\{BC}\{Layer}` (예: `App\Modules\Payment\Services\PaymentService`) |

### 3.5 DI (Dependency Injection) 등록

`app/Config/Services.php`에 등록:

```php
// Interface → 구현체 바인딩
public static function boardService(bool $getShared = true): BoardServiceInterface
{
    if ($getShared) return static::getSharedInstance('boardService');
    return new BoardService();
}
```

호출:
```php
// Controller에서
$boardService = service('boardService');
$result = $boardService->getList($params);
```

### 3.6 Outbox Pattern (크로스 도메인 이벤트)

모듈 간 비동기 이벤트는 Outbox 테이블을 통해 발행한다. 트랜잭션 내에서 비즈니스 데이터 + Outbox 레코드를 함께 커밋하여 원자성을 보장한다.

```
┌─────────────────────────────────────────┐
│           PHP Application (CI4)          │
│                                          │
│  BEGIN TRANSACTION                       │
│    INSERT tb_account (비즈니스 데이터)     │
│    INSERT global_sync_pub_log (Outbox)   │
│  COMMIT                                  │
│                                          │
│  GlobalSyncService::publishEvent()       │
│    → SnsPublisher::publish() → SNS FIFO │
│    → UPDATE pub_status = 1 (성공)        │
└──────────────┬──────────────────────────┘
               │
    ┌──────────▼──────────┐
    │   SNS FIFO (KOR)    │
    │ prod_sns_hongcafe_   │
    │ global.fifo          │
    └──────┬──────┬───────┘
           │      │
    ┌──────▼┐  ┌──▼──────┐
    │SQS USA│  │SQS KOR  │  (+ JPN 예정)
    └───┬───┘  └────┬────┘
        │           │
    ┌───▼───┐  ┌────▼────┐
    │Lambda │  │Lambda   │
    │USA    │  │KOR      │
    └───┬───┘  └────┬────┘
        │           │
    ┌───▼───────────▼───┐
    │   Aurora MySQL     │
    │ global_sync_sub_log│
    └───────────────────┘
```

**Outbox 상태 머신:**

| pub_status | 의미 |
|------------|------|
| 0 | 대기 (INSERT 직후) |
| 1 | SNS 발행 성공 |
| 2 | SNS 발행 실패 (재시도 대상) |
| 9 | 영구 실패 (5회 초과) |

**이벤트 타입:**
- `account_create` — 신규 계정 생성
- `account_update` — 계정 정보 변경
- `coin_transfer` — 충전/사용/환불
- `coin_adjust` — 관리자 보정

**메시지 포맷:**
```json
{
  "pub_id": 12345,
  "event_type": "coin_transfer",
  "entity_id": 7,
  "payload": {
    "account_id": 7,
    "amount": 500,
    "currency": "KRW",
    "action": "charge"
  },
  "source_region": "US",
  "timestamp": "2026-04-09T12:00:00Z"
}
```

**MessageGroupId 포맷:** `{REGION}:{ENTITY}:{SUBTYPE}:{ID}` (예: `KR:ACCOUNT:COIN:7`)

### 3.7 멱등성 (Idempotency)

| 대상 | 방식 |
|------|------|
| 정산/결제 | 멱등키(idempotency key) 필수 |
| 트랜잭션 | DB unique 제약으로 중복 방지 |
| Pub/Sub | SQS 메시지 ID 기반 중복 감지 |
| Lambda 수신 | `INSERT IGNORE` + `pub_id` 기반 처리 완료 체크 |

### 3.8 SNS Publisher (3-Tier 구조)

PHP 백엔드에서 SNS FIFO로 이벤트를 발행하는 3계층:

| 계층 | 클래스 | 역할 |
|------|--------|------|
| Library | `SnsPublisher` | AWS SDK 래퍼, 순수 PHP |
| Service | `GlobalSyncService` | 비즈니스 로직 오케스트레이션 |
| Model | `GlobalSyncPubLogModel` | `global_sync_pub_log` CRUD |

**발행 흐름:**
1. MessageGroupId 생성 (`{REGION}:{TYPE}:{SUBTYPE}:{ID}`)
2. `global_sync_pub_log` INSERT (pub_status=0)
3. SNS `publish()` 호출
4. 성공 시 pub_status=1, 실패 시 pub_status=2

**실패 처리:**
- pub_status=2 + retry_count 증가
- 배치 재시도: pub_status=2 AND retry_count < 5
- 5회 초과: pub_status=9 (영구 실패)
- 비즈니스 트랜잭션은 롤백하지 않음

### 3.9 인가(RBAC) 3계층 Defense in Depth

OWASP API5:2023 준수, 3중 방어:

```
요청 → [Layer 1: RoleFilter] → [Layer 2: Controller] → [Layer 3: Repository]
         라우트 레벨              ce_code 이중 검증        소유권 쿼리 조건
```

| Layer | 위치 | 방식 |
|-------|------|------|
| Layer 1 | `RoleFilter:callee` | 라우트 필터에서 역할 차단 (상담사 전용 EP) |
| Layer 2 | `checkNeedLogin(true)` | 컨트롤러에서 ce_code 이중 검증 |
| Layer 3 | Repository 쿼리 | WHERE 절에 소유권 조건 내장 |

**상담사 판별:** `tb_account.ce_code` 존재 여부로 `UserRole::Callee` / `UserRole::Caller` 구분

**상담사 전용 EP:** `callees/*`, `goods/callee-*`, `shop/callee-*` → `['filter' => 'role:callee']` 필수

### 3.10 필터 체인 (Request Pipeline)

```
Request → RateLimit → CsrfToken → Auth(JWT) → Role:callee(해당 시) → Controller
```

| 필터 | 역할 | 적용 범위 |
|------|------|----------|
| `ratelimit` | IP 기반 요청 제한 | 전체 API |
| `csrftoken` | Signed Double Submit Cookie (HMAC-SHA256) | POST/PUT/DELETE |
| `auth` | JWT HttpOnly 쿠키 검증 | 인증 필요 EP |
| `role:callee` | 상담사 역할 필터 | 상담사 전용 EP (57개) |

### 3.11 CSRF 방어 (Signed Double Submit Cookie)

CI4 내장 CSRF 필터는 사용하지 않는다 (stateless JWT 아키텍처와 불일치). 자체 구현:

1. 로그인 시 `hc_csrf` 쿠키 발급 (HttpOnly=false, 프론트엔드 읽기 가능)
2. 상태 변경 요청(POST/PUT/DELETE) 시 `X-CSRF-TOKEN` 헤더 필수
3. 서버에서 HMAC-SHA256 서명 검증
4. SameSite=Lax 병행 (Defense in Depth)

### 3.12 BaseApiController

모든 API 컨트롤러의 기반 클래스:

```php
class BaseApiController extends ResourceController
{
    protected $format = 'json';

    // 표준 응답 헬퍼
    protected function respondSuccess(array $data, int $code = 200);
    protected function respondError(string $code, string $message, int $httpCode = 400);

    // 입력 처리
    protected function getJsonInput(): array;      // JSON body 파싱
    protected function sanitizeOutput($data);       // XSS 방지 출력 정제

    // 인증
    protected function checkNeedLogin(bool $needLogin = false): ?array;
}
```

### 3.13 신규 API 개발 시 9개 필수 산출물

| # | 산출물 | 위치 |
|---|--------|------|
| 1 | Controller | `Modules/{BC}/Controllers/` |
| 2 | Service + Interface | `Modules/{BC}/Services/`, `Modules/{BC}/Interfaces/` |
| 3 | Repository + Interface | `Modules/{BC}/Repositories/`, `Modules/{BC}/Interfaces/` |
| 4 | Model | `Modules/{BC}/Models/` |
| 5 | Entity/VO | `Modules/{BC}/Entities/`, `Modules/{BC}/ValueObjects/` (도메인 규칙 시) |
| 6 | DI 등록 | `app/Config/Services.php` |
| 7 | Unit + Feature 테스트 | `tests/Unit/Modules/{BC}/`, `tests/Feature/Modules/{BC}/` |
| 8 | 라우트 등록 | `Modules/{BC}/Config/Routes.php` |
| 9 | API 문서 | `api-docs/{module}/{apiname}.md` + OpenAPI YAML |

### 3.14 Entity / ValueObject 규칙

**Entity:**
- 순수 PHP 클래스 (Framework/DB import 금지)
- 비즈니스 규칙과 유효성 검증 포함
- 식별자(ID)로 동등성 비교

**ValueObject:**
- `readonly` 클래스 필수 (불변)
- 생성자에서 자기 유효성 검증
- 값으로 동등성 비교
- 예: `Money`, `PhoneNumber`, `CountryCode`

```php
readonly class Money
{
    public function __construct(
        public int $amount,
        public string $currency,
    ) {
        if ($amount < 0) {
            throw new \InvalidArgumentException('Amount must be non-negative');
        }
    }
}
```

### 3.15 서버 사이드 아키텍처 (Nginx Hybrid)

```
                    ┌──────────────────────┐
                    │       Nginx          │
                    │   prd.gl.hongcafe.com│
                    └──────┬───────┬───────┘
                           │       │
              /api/*       │       │  /*
                           │       │
                    ┌──────▼──┐ ┌──▼────────┐
                    │ PHP-FPM │ │  Next.js   │
                    │ :8080   │ │  :3000     │
                    │ (CI4)   │ │  (PM2)     │
                    └────┬────┘ └────────────┘
                         │
                    ┌────▼────────────┐
                    │  Aurora MySQL    │
                    │  (RDS Proxy)    │
                    └─────────────────┘
```

### 3.16 Abstraction 원칙

| 조건 | 추상화 여부 |
|------|------------|
| Public Service (외부 노출) | Interface 필수 |
| 2개 이상 구현체 존재 | Interface 필수 |
| 외부 시스템 연동 (Stripe, Sendbird 등) | Interface 필수 |
| 모든 Repository | Interface 필수 |
| 내부 헬퍼/유틸리티 | Concrete 허용 |

---

## 4. 인프라 구성

### 4.1 프로덕션 서버

| 항목 | 값 |
|------|-----|
| 인스턴스 | `prod_ec2_hongcafe_usa` (`i-0183f9ab360cc9d80`) |
| Public IP | `54.198.20.157` |
| OS | Amazon Linux 2023 (aarch64) |
| SSH Port | 20010 (비표준) |
| 접속 | SSM Session Manager (SSH 키 불일치로 SSM만 사용) |
| 리전 | us-east-1 |

### 4.2 3환경 포트 매핑 (단일 EC2)

| 환경 | 도메인 | PHP-FPM | Next.js | BE 경로 | FE 경로 |
|------|--------|---------|---------|---------|---------|
| PRD | prd.gl.hongcafe.com | 127.0.0.1:8080 | :3000 | `/works/hongcafe-global/prd/be/` | `/works/hongcafe-global/prd/fe/` |
| STG | stg.gl.hongcafe.com | 127.0.0.1:8081 | :3001 | `/works/hongcafe-global/stg/be/` | `/works/hongcafe-global/stg/fe/` |
| DEV | dev.gl.hongcafe.com | 127.0.0.1:8082 | :3002 | `/works/hongcafe-global/dev/be/` | `/works/hongcafe-global/dev/fe/` |

**설정 파일 경로:** `/works/hongcafe-global/{env}/config/.env` (심볼릭 링크)

### 4.3 Nginx 설정

**글로벌 (`nginx.conf`):**
```nginx
user nginx;
worker_processes auto;
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;
    include /etc/nginx/conf.d/*.conf;
}
```

**환경별 (`conf.d/hongcafe-{env}.conf`):**
```nginx
server {
    listen 80;
    server_name prd.gl.hongcafe.com;
    server_tokens off;

    # 보안 헤더
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header X-XSS-Protection "1; mode=block" always;

    client_max_body_size 20M;

    # Gzip
    gzip on;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript;

    # Backend API → PHP-FPM
    location /api/ {
        include fastcgi_params;
        fastcgi_pass 127.0.0.1:8080;  # STG: 8081, DEV: 8082
        fastcgi_param SCRIPT_FILENAME /works/hongcafe-global/prd/be/public/index.php;
        fastcgi_param PATH_INFO $uri;
        fastcgi_param HTTP_X_FORWARDED_FOR $proxy_add_x_forwarded_for;
        fastcgi_param HTTP_X_REAL_IP $remote_addr;
    }

    # Frontend → Next.js (PM2)
    location / {
        proxy_pass http://127.0.0.1:3000;  # STG: 3001, DEV: 3002
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 숨김 파일/내부 디렉토리 차단
    location ~ /\. { deny all; }
    location ~ ^/(app|system|writable|vendor)/ { deny all; }
}
```

### 4.4 PHP-FPM Pool 설정

| 항목 | PRD (`www-prd`) | STG (`www-stg`) | DEV (`www-dev`) |
|------|----------------|----------------|----------------|
| listen | 127.0.0.1:8080 | 127.0.0.1:8081 | 127.0.0.1:8082 |
| pm | dynamic | dynamic | dynamic |
| max_children | 50 | 20 | 10 |
| start_servers | 5 | 3 | 2 |
| min_spare | 5 | 3 | 2 |
| max_spare | 35 | 10 | 5 |
| max_requests | 500 | 500 | 500 |
| display_errors | Off | Off | On |
| CI_ENVIRONMENT | production | staging | development |

### 4.5 PHP 주요 설정 (`php.ini`)

```ini
max_execution_time = 120
max_input_time = 240
max_input_vars = 10000
memory_limit = -1
upload_max_filesize = 32M
post_max_size = 48M
max_file_uploads = 50
display_errors = Off
expose_php = Off
date.timezone = UTC
session.cookie_httponly = 1
```

### 4.6 PM2 설정 (`ecosystem.config.js`)

```javascript
module.exports = {
  apps: [
    { name: 'hongcafe-fe-prd', cwd: '/works/hongcafe-global/prd/fe', script: 'npm', args: 'start', env: { PORT: 3000, NODE_ENV: 'production' } },
    { name: 'hongcafe-fe-stg', cwd: '/works/hongcafe-global/stg/fe', script: 'npm', args: 'start', env: { PORT: 3001, NODE_ENV: 'production' } },
    { name: 'hongcafe-fe-dev', cwd: '/works/hongcafe-global/dev/fe', script: 'npm', args: 'start', env: { PORT: 3002, NODE_ENV: 'development' } },
  ],
};
```

### 4.7 배포 디렉토리 구조

```
/works/hongcafe-global/
├── prd/
│   ├── be -> releases/be_20260403120000    ← Symlink (Atomic Deploy)
│   ├── fe/
│   ├── config/.env                         ← 환경 설정
│   └── releases/
│       ├── be_20260403120000/
│       ├── be_20260402100000/
│       └── ...                             ← 최대 5개 유지
├── stg/
│   └── (동일 구조)
├── dev/
│   └── (동일 구조)
└── scripts/
    ├── deploy-be.sh
    └── deploy-fe.sh
```

---

## 5. DB 구성

### 5.1 Aurora MySQL (메인 DB)

| 항목 | 값 |
|------|-----|
| 엔진 | Aurora MySQL 3.12.0 (MySQL 8.0.44 호환) |
| 클러스터 | `prod-aurora-hongcafe-usa` |
| 엔드포인트 | `prod-aurora-hongcafe-usa.cluster-*.us-east-1.rds.amazonaws.com` |
| RDS Proxy | `prod-rdsproxy-hongcafe-usa.proxy-c47e2m0qmf7h.us-east-1.rds.amazonaws.com` |
| 데이터베이스 | `athena` |
| 사용자 | `athena` |
| 인증 | IAM Auth (비밀번호 없음) |
| 리전 | us-east-1 |

### 5.2 Hermes DB (외부 연동)

| 항목 | 값 |
|------|-----|
| 호스트 | `101.101.211.242` |
| 데이터베이스 | `hermes` |
| 용도 | 외부 시스템 연동 |

### 5.3 RDS Proxy

- Lambda와 PHP 모두 RDS Proxy를 경유하여 Aurora에 접속
- IAM Auth 사용 (비밀번호 저장 불필요)
- Max Connections = Aurora `max_connections` x 80%
- Lambda / RDS Proxy / Aurora는 동일 VPC private subnet

### 5.4 Data Sync 테이블

| 테이블 | 용도 |
|--------|------|
| `global_sync_pub_log` | Outbox — PHP에서 SNS로 발행한 이벤트 기록 |
| `global_sync_sub_log` | Inbox — Lambda에서 수신한 이벤트 처리 기록 |

### 5.5 Query Builder 규칙 (mysql8 스킬)

| 원칙 | 설명 |
|------|------|
| ANSI SQL 우선 | MySQL 전용 문법 사용 시 ANSI 대안 병기 |
| SELECT * 금지 | 필요 컬럼 명시 (11건 최적화 완료, 45건 잔여) |
| N+1 방지 | JOIN/subquery로 단일 라운드트립 |
| Full Scan 금지 | `EXPLAIN FORMAT=TREE`로 검증 |
| 함수 래핑 금지 | `WHERE YEAR(date) = 2026` → `WHERE date BETWEEN ...` |
| Query Builder 우선 | CTE/Window Function만 `$db->query()` + named binding |
| 인덱스 제안 | Checkpoint 형식으로 사용자 승인 후 적용 |
| 쿼리 힌트 금지 | `FORCE INDEX` 대신 인덱스 설계로 해결 |

---

## 6. CI/CD 파이프라인

### 6.1 파이프라인 구성

```
Bitbucket Pipelines (amazon/aws-cli 이미지)
         │
         ▼
SSM send-command → EC2
         │
         ▼
deploy-be.sh / deploy-fe.sh
         │
         ▼
Atomic Deploy (Symlink 교체)
```

### 6.2 Backend 배포 흐름 (`deploy-be.sh`)

```
1. git clone (fresh)
2. releases/ 디렉토리에 타임스탬프 폴더 생성
3. composer install --no-dev
4. .env 심볼릭 링크 연결
5. php spark migrate (마이그레이션)
6. phpunit (테스트)
7. be 심볼릭 링크를 새 릴리즈로 교체
8. php-fpm reload
9. 이전 릴리즈 정리 (5개 초과 삭제)
```

### 6.3 Frontend 배포 흐름 (`deploy-fe.sh`)

```
1. SSM으로 EC2에서 스크립트 실행
2. git pull + npm install + npm run build
3. pm2 restart hongcafe-fe-{env}
```

### 6.4 환경별 배포 정책

| 환경 | 트리거 | 승인 |
|------|--------|------|
| PRD (`production` 브랜치) | 머지 | 수동 승인 필수 |
| STG (`staging` 브랜치) | 머지 | 수동 승인 필수 |
| DEV (`develop` 브랜치) | 머지 | 자동 배포 |

### 6.5 Bitbucket Pipelines 설정

```yaml
image: amazon/aws-cli

definitions:
  steps:
    - step: &atomic-deploy
        name: Remote Test and Atomic Deploy
        script:
          - aws ssm send-command --instance-ids $INSTANCE_ID
              --document-name "AWS-RunShellScript"
              --parameters commands=["bash /works/hongcafe-global/scripts/deploy-be.sh $BITBUCKET_BRANCH"]
          - aws ssm wait command-executed
          - aws ssm get-command-invocation (결과 확인)

pipelines:
  branches:
    production:
      - step: Ready to Deploy (수동 승인)
      - step: *atomic-deploy
        deployment: US-Env
    staging:
      - step: Ready to Deploy (수동 승인)
      - step: *atomic-deploy
        deployment: US-Env
    develop:
      - step: *atomic-deploy
        deployment: US-Env
```

### 6.6 IAM 권한

- 배포 IAM User: `HC-bitbucket-deploy`
- 정책: `BitbucketDeploySSM` (SSM send-command, get-command-invocation)

### 6.7 롤백 절차

| 대상 | 절차 |
|------|------|
| Backend | `ln -sfn releases/be_{이전타임스탬프} be` + `systemctl reload php-fpm` |
| Frontend | `pm2 restart hongcafe-fe-{env}` |

---

## 7. Lambda & Data Sync

### 7.1 Lambda 함수 인벤토리

| 함수명 | 리전 | 상태 |
|--------|------|------|
| `prod_lambda_hongcafe_sqs_push_usa` | us-east-1 | Active |
| `prod_lambda_hongcafe_sqs_push_kor` | ap-northeast-2 | Planned (스켈레톤) |
| `prod_lambda_hongcafe_logpull_kor` | ap-northeast-2 | Planned |

### 7.2 Data Sync 아키텍처 (Hub-and-Spoke)

```
PHP (CI4) → GlobalSyncService → SnsPublisher
                                      │
                               ┌──────▼──────┐
                               │ SNS FIFO    │
                               │ (KOR 중심)   │
                               └──┬───┬───┬──┘
                                  │   │   │
                    ┌─────────────▼┐ ┌▼┐ ┌▼─────────────┐
                    │ SQS USA     │ │K│ │ SQS JPN      │
                    │ .fifo       │ │R│ │ .fifo (예정)  │
                    └──────┬──────┘ └┬┘ └───────────────┘
                           │         │
                    ┌──────▼──┐  ┌───▼────┐
                    │Lambda   │  │Lambda  │
                    │USA      │  │KOR     │
                    │(Active) │  │(Skel)  │
                    └─────────┘  └────────┘
```

### 7.3 SNS/SQS 설정

**SNS Topic:**
- `prod_sns_hongcafe_global.fifo` (ap-northeast-2)
- ContentBasedDedup: true
- KMS 암호화: `alias/aws/sns`

**SQS Queues:**
- `prod_sqs_hongcafe_usa.fifo` (us-east-1)
- `prod_sqs_hongcafe_kor.fifo` (ap-northeast-2)
- `prod_sqs_hongcafe_jpn.fifo` (ap-northeast-1, 예정)
- VisibilityTimeout: 30s
- MessageRetentionPeriod: 4일

### 7.4 Lambda Handler 구조 (USA)

```python
def handler(event, context):
    batch_item_failures = []
    for record in event.get("Records", []):
        try:
            body = json.loads(record.get("body", "{}"))
            msg = parse_message(body)
            process_sync(msg)
        except Exception:
            batch_item_failures.append({"itemIdentifier": record.get("messageId")})
    return {"batchItemFailures": batch_item_failures}

def process_sync(msg):
    # INSERT IGNORE → UPDATE status 1 → process → UPDATE status 3
    # 실패 시: UPDATE status 0 + retry_count + error logging

def route_event(cursor, conn, event_type, entity_id, payload):
    handlers = {
        "account_create": handle_account_create,
        "account_update": handle_account_update,
        "coin_transfer": handle_coin_transfer,
        "coin_adjust": handle_coin_adjust,
    }
```

### 7.5 DB 연결 (Lambda → Aurora)

```python
# shared/db_connection.py
def get_auth_token():
    client = boto3.client("rds")
    return client.generate_db_auth_token(DBHostname=DB_HOST, Port=3306, DBUsername=DB_USER)

def get_connection():
    global connection
    if connection is not None:
        connection.ping(reconnect=True)
        return connection
    connection = pymysql.connect(
        host=DB_HOST, user=DB_USER, password=get_auth_token(),
        database=DB_NAME, charset="utf8mb4", ssl={"ssl": True}
    )
    return connection
```

### 7.6 Lambda CI/CD (예정)

- 순차 배포: USA → KOR → JPN (검증 포함)
- 경로 필터: `lambda/**` 변경 시에만 트리거
- 패키징: 국가별 zip (`function_usa_sqs_push.zip` 등, shared/ 포함)
- Layer: `prod_functionlayer_hongcafe_usa:1` (pymysql)

---

## 8. 보안 정책

### 8.1 인증 (Authentication)

| 항목 | 정책 |
|------|------|
| 방식 | JWT + HttpOnly 쿠키 전용 |
| localStorage | **금지** (OWASP/IETF/Auth0 합의) |
| Access Token | 15분 만료, HttpOnly 쿠키 (`hc_access`) |
| Refresh Token | 별도 HttpOnly 쿠키, Rotation 적용 |
| Refresh Rotation | Family UUID, 단일 사용, Reuse Detection, Family Revoke |

### 8.2 쿠키 설정

| 속성 | 값 |
|------|-----|
| SameSite | Lax |
| HttpOnly | true (hc_csrf 제외) |
| Secure | true |
| Prefix | `hc_` |

### 8.3 CORS

Same-Origin 아키텍처 (Nginx 리버스 프록시)이므로 CORS 헤더 불필요. 와일드카드(`*`) 금지.

### 8.4 암호화

- AES-256-CBC, 연산마다 랜덤 IV 필수

### 8.5 비밀번호 정책

- 최소 8자, 최대 128자
- HaveIBeenPwned API 연동 (예정)

### 8.6 Auto Routing

`setAutoRoute(false)` — 모든 EP는 모듈별 Routes.php에 명시적 등록 필수.

### 8.7 계정 열거 차단 (CWE-204)

모든 인증 실패 시 동일한 401 응답 + 동일한 응답 본문. 타이밍 공격 방어 포함.

### 8.8 보안 감사 스킬 7개 도메인

| Part | 도메인 | 트리거 |
|------|--------|--------|
| A | PHP/CI4 | app/ PHP, composer.json 변경 |
| B | Common | 모든 코드 변경 |
| C | MySQL 8.x | 마이그레이션, 스키마, 쿼리 변경 |
| D | Lambda/Python | Lambda, IAM 정책 변경 |
| E | CI/CD + Docker | 파이프라인, Dockerfile 변경 |
| F | Process | 아키텍처 변경, 설계 리뷰 |
| G | API Security | API 엔드포인트, 인증/인가 변경 |

**자동 탐지 패턴 (Critical):**
- 하드코딩된 시크릿
- SQL Injection (`$db->query("..." . $var)`)
- 위험 함수 (`eval()`, `exec()`, `system()`, `shell_exec()`)
- `unserialize()`, `setAutoRoute(true)`
- Production에 `FakeLogin`, `var_dump()`

### 8.9 IAM Least Privilege

| 대상 | 허용 권한 |
|------|----------|
| SQS | `ReceiveMessage`, `DeleteMessage`, `GetQueueAttributes` (특정 큐 ARN) |
| SNS | Topic별 `Publish` (Resource: * 금지) |
| Lambda | 함수별 별도 역할 (공유 금지) |
| EC2 | Instance Profile (Access Key 금지) |

### 8.10 Security Group 규칙

| SG | Inbound | Outbound |
|----|---------|----------|
| Lambda SG | — | TCP 3306 (Aurora SG), TCP 443 (AWS API) |
| Aurora SG | TCP 3306 from sg-lambda + sg-ec2 | — |
| EC2 SG | SSH from 특정 IP (0.0.0.0/0 금지), HTTP/HTTPS | Aurora + 외부 API |

---

## 9. API 응답 표준

### 9.1 기본 원칙

**HTTP 상태코드가 성공/실패의 SSOT** (RFC 7231). `success` 플래그 불필요.

### 9.2 성공 응답

```json
{
  "data": { ... }
}
```
- HTTP 200 (조회/수정/삭제), 201 (생성)

### 9.3 에러 응답

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Resource not found"
  }
}
```

### 9.4 에러 코드 (현상 서술형, suffix 없음)

| 코드 | HTTP | 용도 |
|------|------|------|
| `INVALID_INPUT` | 400 | 입력 유효성 실패 |
| `UNAUTHORIZED` | 401 | 인증 실패 |
| `FORBIDDEN` | 403 | 권한 없음 |
| `NOT_FOUND` | 404 | 리소스 없음 |
| `CONFLICT` | 409 | 상태 충돌 |
| `INTERNAL` | 500 | 서버 내부 오류 |

### 9.5 페이지네이션

CI4 4.7.2 빌트인 Pager 사용. `Model::paginate()` 호출 후 `Model::pager`로 meta 구성.

```json
{
  "data": [ ... ],
  "meta": {
    "currentPage": 1,
    "perPage": 20,
    "total": 150,
    "lastPage": 8
  }
}
```

- camelCase 통일
- 커스텀 Pager 구현 금지

### 9.6 JSON 키 컨벤션

- **camelCase** 통일 (currentPage, perPage, lastPage, createdAt)
- DB snake_case → 응답 시 camelCase 변환

---

## 10. 라우트 정책

### 10.1 라우트 등록

- **명시적 등록 필수:** `app/Modules/{BC}/Config/Routes.php`
- **Auto Routing 비활성화:** `setAutoRoute(false)`
- 14개 모듈 라우트 파일 운영 중

### 10.2 URL 네이밍

- **kebab-case + 복수형:** `api/members/check-id`, `api/callees/get-chat-list`
- 완료: Board, Event, Notification, Member, Call, Chat, Commerce, Reservation, Service, Social, Content

### 10.3 HTTP 메서드

| 메서드 | 용도 | 비고 |
|--------|------|------|
| GET | 조회 | |
| POST | 생성/액션 | |
| PUT | 수정 | |
| DELETE | 삭제 | POST로 삭제 동작 금지 |

### 10.4 필터 체인

```
ratelimit → csrftoken → auth → role:callee(해당 시) → Controller
```

### 10.5 공개 EP

AuthFilter `EXCLUDED_PATHS`에 등록 (kebab-case URL 사용).

### 10.6 파일 업로드

MIME 타입 이중 검증 필수: 확장자 + `mime_content_type()`

### 10.7 i18n

에러 메시지는 `lang()` 키 사용. 하드코딩 문자열 금지.

---

## 11. 글로벌 컨텍스트

### 11.1 국가 코드

- ISO 3166-1 alpha-2 (대문자 2자): **US**, **KR**, **JP**
- 전송 우선순위: JWT `country` claim → `X-Country-Code` 헤더 → `.env defaultCountry` → Accept-Language

### 11.2 Country Resolver

- CI4 Filter로 모든 요청에 자동 적용
- `Services::country()` 또는 `service('country')`로 접근

### 11.3 Country Config

```
app/Config/Countries/
├── US.php    ← currency: USD, timezone: America/New_York, ...
├── KR.php    ← currency: KRW, timezone: Asia/Seoul, ...
└── JP.php    ← currency: JPY, timezone: Asia/Tokyo, ...
```

필드: `currency`, `timezone`, `locale`, `dateFormat`, `phonePrefix`, `taxRate`, `features`

### 11.4 Feature Flag

| 항목 | 설정 |
|------|------|
| SSOT | DB 테이블 `tb_feature_flags` |
| 캐시 | Redis TTL 5분, DB 변경 시 무효화 |
| 기본 동작 | Fail-closed (미등록 기능 = 비활성) |
| 조회 | `service('featureFlag')->isEnabled('feature_name', $countryCode)` |

### 11.5 타임존

| 레이어 | 타임존 |
|--------|--------|
| DB 저장 | **UTC 고정** (SSOT) |
| 서버 처리 | UTC (`date_default_timezone_set('UTC')`) |
| DB 연결 | `SET time_zone = '+00:00'` |
| API 응답 | ISO 8601 (Z suffix) |
| 클라이언트 | 프론트엔드에서 사용자 타임존으로 변환 |

### 11.6 DateTimeImmutable 강제

| 구분 | 대상 |
|------|------|
| **허용** | `\DateTimeImmutable`, `createFromFormat()`, `CarbonImmutable` |
| **금지** | `date()`, `time()`, `strtotime()`, `DateTime` (mutable) |

### 11.7 i18n 파일 구조

```
app/Language/
├── en/
│   ├── Messages.php
│   └── Error.php
└── ko/
    ├── Messages.php
    └── Error.php
```

호출: `lang('Messages.welcome')` — Country Config에서 locale 자동 설정

### 11.8 배포 격리

- 경로: `deploy/{country}/.env`, `deploy/{country}/deploy.sh`
- 국가별: DB 엔드포인트, API 키, 외부 서비스 URL, 인스턴스 ID
- CI/CD: `COUNTRY` 환경변수로 구분

---

## 12. 코딩 표준

### 12.1 PSR 준수

| 표준 | 적용 |
|------|------|
| PSR-1 | 기본 코딩 표준 |
| PSR-4 | Autoloading (`App\Modules\{BC}\{Layer}`) |
| PSR-12 | 확장 코딩 스타일 (4-space indent) |

### 12.2 필수 선언

```php
<?php

declare(strict_types=1);

namespace App\Modules\{BC}\{Layer};
```

### 12.3 네이밍 컨벤션

| 대상 | 규칙 | 예시 |
|------|------|------|
| 클래스 | PascalCase | `BoardService`, `PaymentRepository` |
| 메서드 | camelCase | `getList()`, `createUser()` |
| 변수 | camelCase | `$userId`, `$phoneNumber` |
| 상수 | UPPER_SNAKE | `MAX_RETRY_COUNT` |
| DB 컬럼 | snake_case | `created_at`, `ce_code` |
| URL | kebab-case + 복수형 | `/api/members/check-id` |
| 파일명 | PascalCase | `BoardController.php` |

### 12.4 PHP 8.4+ 활용 패턴

**Constructor Promotion:**
```php
public function __construct(
    private readonly BoardRepositoryInterface $boardRepository,
    private readonly CommentRepository $commentRepository,
) {}
```

**Enums (10개 구현 완료):**
```php
enum UserRole: string
{
    case Callee = 'callee';
    case Caller = 'caller';
}
```

**Named Arguments:**
```php
$db->query('SELECT * FROM tb WHERE id = :id:', ['id' => $id]);
```

**match 표현식:**
```php
$status = match($code) {
    200 => 'success',
    404 => 'not_found',
    default => 'error',
};
```

### 12.5 DI 규칙

```php
// 올바른 사용
$service = service('boardService');

// 금지
$service = new BoardService();
```

### 12.6 mixed 반환형 금지

모든 메서드에 명시적 반환 타입 선언 필수. `mixed` 사용 금지.

### 12.7 주석 규칙

- 모든 public 메서드: `@param`, `@return`, 목적 설명
- 주석 없이 읽히는 명시적 코드 우선
- 전체 단어 사용 (`fullName`, `index` — 약어 지양)

---

## 13. 테스트

### 13.1 원칙

**"No Test, No Merge"** — 모든 수정은 유닛 테스트 또는 실행 로그 증빙 동반.

### 13.2 디렉토리 구조

```
tests/
├── Unit/Modules/{BC}/       ← 타입별 1차, 모듈별 2차
├── Feature/Modules/{BC}/
└── _support/
```

### 13.3 현황

- 테스트 파일: 148개 (`*Test.php`)
- 마지막 확인 테스트 수: 2,279+

### 13.4 실행 명령

```bash
# 전체 테스트
php vendor/bin/phpunit

# 모듈별 Unit
php vendor/bin/phpunit tests/Unit/Modules/{BC}/

# 단일 메서드
php vendor/bin/phpunit --filter testMethodName
```

### 13.5 테스트 유형

| 유형 | 목적 | 특징 |
|------|------|------|
| Unit | Repository/Service 로직 | Repository Mock 사용 |
| Feature | API 통합 테스트 | `FeatureTestTrait`, 실제 HTTP 요청 |

---

## 14. 브랜치 전략 & 커밋 컨벤션

### 14.1 브랜치 구조

| 브랜치 | 용도 | 비고 |
|--------|------|------|
| `master` | 메인 브랜치 | |
| `production` | 배포 브랜치 | 머지 후 수동 승인 |
| `dev/migration` | 마이그레이션 작업 | 현재 활성 |

### 14.2 Conventional Commits v1.0.0

```
type(scope): subject (72자 이내)

body (선택)

footer (선택)
```

### 14.3 type 목록

| type | 용도 |
|------|------|
| `feat` | 새 기능 |
| `fix` | 버그 수정 |
| `refactor` | 리팩토링 (기능 변경 없음) |
| `perf` | 성능 개선 |
| `test` | 테스트 추가/수정 |
| `docs` | 문서 |
| `style` | 코드 스타일 (로직 변경 없음) |
| `build` | 빌드/의존성 |
| `ci` | CI/CD |
| `chore` | 기타 |

### 14.4 scope 규칙

| 대상 | 규칙 | 예시 |
|------|------|------|
| BE 모듈 | PascalCase | `Auth`, `Payment`, `Member` |
| FE 페이지 | kebab-case | `Login`, `MyPage` |
| 공유/인프라 | lowercase | `config`, `infra`, `deps` |
| 멀티 모듈 | scope 생략 | `refactor: URL kebab-case 전환` |

### 14.5 규칙

- 1 커밋 = 1 변경 (feat + refactor 혼합 금지)
- `--force` / `--force-with-lease`: 사용자 명시 요청 시만
- main/master force push: 경고 + 확인 필수

---

## 15. 환경 설정

### 15.1 .env 구조

```ini
# APP
CI_ENVIRONMENT = production|staging|development
app.baseURL = 'https://{env}.gl.hongcafe.com/'

# DATABASE (Aurora RDS Proxy)
database.default.hostname = prod-rdsproxy-hongcafe-usa.proxy-*.rds.amazonaws.com
database.default.database = athena
database.default.username = athena
database.default.password =                    # IAM Auth (비밀번호 없음)
database.default.DBDriver = MySQLi

# DATABASE (Hermes 외부)
database.hermes.hostname = 101.101.211.242
database.hermes.database = hermes

# STRIPE
stripe.secretKey = sk_...
stripe.publishableKey = pk_...
stripe.webhookSecret = whsec_...

# SENDBIRD
sendbird.apiToken = ...
sendbird.baseUrl = https://api-{app-id}.sendbird.com

# SECURITY
encryption.key = hex2bin:...
jwt.secretKey = ...
csrf.secretKey = ...

# API_KEYS
api.keys = key1,key2,...
```

### 15.2 환경별 차이

| 항목 | PRD | STG | DEV |
|------|-----|-----|-----|
| CI_ENVIRONMENT | production | production | development |
| baseURL | prd.gl.hongcafe.com | stg.gl.hongcafe.com | dev.gl.hongcafe.com |
| DB | RDS Proxy (IAM Auth) | RDS Proxy (IAM Auth) | RDS Proxy (IAM Auth) |
| display_errors | Off | Off | On |
| Stripe | 본계정 키 | 테스트 키 | 테스트 키 |
| PHP-FPM | max 50 children | max 20 children | max 10 children |

### 15.3 민감 정보 관리

- `.env` 파일은 Git에 포함하지 않음
- 서버의 `/works/hongcafe-global/{env}/config/.env`에 수동 배치
- 배포 시 심볼릭 링크로 연결
- IAM Auth로 DB 비밀번호 불필요

---

## 16. 마이그레이션 현황

### 16.1 브랜치

`dev/migration` — master 대비 50+ 커밋 진행

### 16.2 완료된 작업 (주요)

| 날짜 | 작업 |
|------|------|
| 2026-03-16~24 | 레거시 CI4 마이그레이션 시작, SQL injection 수정, 3-Layer 스키마 매핑 |
| 2026-04-01 | Docker 환경, Auth API, Modular Monolith Phase 1 |
| 2026-04-02 | 14 BC 모듈 생성, 네임스페이스 표준화, DI 컨테이너 설정 |
| 2026-04-06 | strict_types 471파일, Enum 4종 생성, 2,258 테스트 |
| 2026-04-07 | Enum Phase 2+3 (10종), 600+ 매직 문자열 교체 |
| 2026-04-08 | 교차검증 18건, 스킬 통합, Gap 분석 16건 |
| 2026-04-09 | Raw SQL → Query Builder Phase 1+2 (35/68건), SQL injection 해소 |
| 2026-04-10 | 전체 API 검증 (~268 EP), CSRF Signed Double Submit Cookie |
| 2026-04-13 | OpenAPI YAML 검증, API spec 리뷰 D-01~D-22, Refresh Token Rotation |
| 2026-04-14 | SELECT * → 명시 컬럼 (11건), RBAC 57 EP, wildcard 라우트 제거, autoRoute 비활성화 |

### 16.3 최근 커밋 (dev/migration)

```
746627a docs: API 체크리스트 전수 검증 + 세션 3 이력 기록
3898f08 fix(Member): D-12 CWE-204 회귀 수정 + D-02 loginUser JWT 발급
efb55b0 docs: CLAUDE.md 환경별 URL 추가 (prd/stg/dev)
2c24471 refactor(Auth): 중복 EP 삭제 + 필터 경로 정리 (D-10)
f5d6575 feat(Member): ResetPassword + 검증API 폐기 + OTP 204
13e40a7 refactor: bearerAuth→cookieAuth + refreshCookieAuth (D-02/D-07)
86d9462 refactor: URL kebab-case 전환 (Reservation/Service/Social/Content)
9c4037b refactor(Chat,Commerce): URL kebab-case+복수형 전환
7b0af07 refactor(Call): URL kebab-case+복수형 전환 (83→60 BC 제거)
ac83eef refactor(Member): URL kebab-case+복수형 전환 (48→24 BC 제거)
3974193 refactor: URL kebab-case+복수형 전환 (Board/Event/Notification)
0b2bbd5 perf: SELECT * → 필요 컬럼 명시 (Module Repos 11건)
3e58078 refactor: Auth/CSRF/RateLimit 필터 전면 적용
a4c813d perf(Chat): N+1 쿼리 해소
832a0a2 feat: Country Config 디렉토리 구현 (US/KR/JP)
194b48f refactor: 국가코드 ISO 3166-1 alpha-2 통일 (US/KR/JP)
9002f44 feat(Auth): D-08 Refresh Token Rotation 구현
0f8b803 refactor: 보안+인프라 개선 (Cookie/MIME/에러코드/UTC)
```

### 16.4 잔여 작업

| 항목 | 상태 |
|------|------|
| SELECT * → 명시 컬럼 | 45건 잔여 (분석 필요) |
| API 문서 갭 | ~99 EP 문서 미비 |
| D-13 SMS/Email DoS 방어 | CAPTCHA + rate-limit 미구현 |
| Lambda KOR/JPN | 스켈레톤 상태 |
| Raw SQL → Query Builder | 33/68건 잔여 |
| HTTP 메서드 부적합 | 29건 (POST→DELETE/GET 전환 필요) |

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-14 | 최초 작성 | jypark |
| 2026-04-15 | doc-template 양식 적용 | jypark |
