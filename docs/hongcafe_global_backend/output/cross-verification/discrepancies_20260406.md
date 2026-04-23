# 불일치 항목 추출본 (18건)

> **출처**: `docs/output/cross-verification-report_20260406.md`

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-15 |
| 유형 | report |
| 상태 | 승인됨 |

> 성민 vs 재영 백엔드 바이브 코딩 문서 교차검증에서 **불일치** 판정된 항목만 추출
> **상태**: 초안 — 제안 항목 순차 업데이트 예정

---

## 요약 테이블

| # | 도메인 | 항목 | 성민 | 재영 | 제안 | 결정 |
|---|--------|------|------|------|------|------|
| 1-3 | 기술 스택 | MySQL 버전 | 8.0 (Aurora MySQL 8.x) | 8.0.4 | Aurora MySQL 3.12.0 (Compatible with MySQL 8.0.44) 통일 | 제안 |
| 1-11 | 기술 스택 | PHP 8.x 활용 기능 | Property Hooks, Typed Constants | Constructor Promotion, Enums, readonly | 항목명 "활용 권장 PHP 8.x 기능"으로 변경 + 합집합 버전별 정리 | 제안 |
| 2-1 | 아키텍처 | 아키텍처 모드 | Modular Monolith (3-Layer) | Dual Mode (Legacy + Modular Monolith) | Modular Monolith 통일 (Dual Mode는 레거시 변환용) | 성민 |
| 2-2 | 아키텍처 | 레이어 구조 | Controller→Service→Repository | Controller→Service→Repository→Model + Entity/VO | 합의 필요 — 성민 아키텍처 문서에도 Entity/VO 언급 있음 | 재영 |
| 2-6 | 아키텍처 | 공유 모듈명 | Common/ | Shared/ | 합의 필요 — Shared/ 권장 (CI4 Common.php 혼동 방지) | 재영 |
| 2-7 | 아키텍처 | BC 매핑 수 | 21개 MOD 확정 | 14개 BC | 패스 — 개발 진행에 따라 유동적 | 성민 |
| 2-9 | 아키텍처 | New 모드 산출물 | 7개 필수 | 9개 필수 (+ API 명세서 md+yaml) | API 명세서(Swagger/OpenAPI yaml) 추가 필수 제안 | 제안 |
| 4-2 | CI4 패턴 | Controller 베이스 | BaseController | ResourceController | ResourceController 제안 (ResponseTrait 내장, JSON 기본값) | 제안 |
| 4-3 | CI4 패턴 | Repository 구현 | Repository extends Model | 별도 클래스 + Model 주입 | 별도 클래스 제안 (DIP 준수, Mock 테스트 용이) | 재영 |
| 4-5 | CI4 패턴 | Model 레이어 | Repository가 Model 겸임 | 별도 Model 클래스 | Model 분리 제안 (SRP 준수, Fat Model 방지) | 재영 |
| 5-4 | API 설계 | 성공 응답 키 | `"success": true` (boolean) | `"status": "success"` (string) | 합의 필요 — 업계 주류는 HTTP 상태코드만 사용 (Google, Stripe, GitHub) | 제안 |
| 5-5 | API 설계 | 에러 코드명 | VALIDATION_ERROR | VALIDATION_FAILED | 합의 필요 — 업계 주류는 suffix 없는 현상 서술형 (INVALID_ARGUMENT 등) | 제안 |
| 5-6 | API 설계 | 페이지네이션 키 | `meta.page` | `meta.currentPage` | 합의 필요 — offset 키에 외부 표준 없음, 프로젝트 camelCase 일관성 기준 | 제안 |
| 5-9 | API 설계 | 라우트 정의 | 모듈별 Config/Routes.php | Legacy+New 이중 구조 | 이중 구조는 과도기 허용, 완료 후 단일 통일 제안 (Strangler Fig) | 성민 |
| 7-1 | 보안 | 인증 토큰 저장 | HttpOnly 쿠키 전용 | cookie 또는 localStorage | HttpOnly 쿠키 전용 제안 (OWASP·IETF·Auth0 전원 일치) | 성민 |
| 7-4 | 보안 | CSRF 방어 | SameSite + Custom Header | CSRF 토큰 | 합의 필요 — 업계 표준은 CSRF Token, SameSite는 보조 수단 | 제안 + JWT 추가 |
| 9-1 | 테스트 | 디렉토리 구조 | tests/Unit/Modules/{BC}/ | tests/Modules/{BC}/Unit/ | 합의 필요 — PHP 관례는 타입별, Modular Monolith는 모듈별 | 성민 |
| 10-1 | 커밋 | 커밋 메시지 형식 | `[ModuleName] type: 설명` + CC 혼재 | 미기재 | 패스 — 스킬에 이미 반영, 동일 | 성민 |

---

## 상세 분석

### 1. MySQL 버전 (1-3)

- **성민**: 8.0 (Aurora MySQL 8.x)
- **재영**: 8.0.4
- **근거**: Aurora MySQL은 자체 버전 체계(3.x)를 사용하며, MySQL 호환 버전은 별도 표기됨. 양쪽 모두 정확한 버전이 아님.
- **제안**: `Amazon Aurora MySQL 3.12.0 (Compatible with MySQL 8.0.44)` 형식으로 양쪽 통일. Aurora 자체 버전(3.x)과 MySQL 호환 버전(8.0.x)을 모두 명시.
- **추가 제안 (CI4)**: `collation`을 `utf8mb4_unicode_ci` 또는 `utf8mb4_0900_ai_ci`(MySQL 8.0 기본)로 통일 합의 필요(CI4 기본값은 `utf8mb4_general_ci`). `strictOn = true` 명시 권장. (SSL 인증은 RDS Proxy IAM Auth 사용 중이므로 별도 설정 불필요) ([CI4 Database Configuration](https://codeigniter4.github.io/userguide/database/configuration.html))

---

### 2. PHP 8.x 활용 기능 (1-11)

- **성민**: Property Hooks, Typed Constants, new without parentheses
- **재영**: Constructor Promotion, Named Arguments, Enums, readonly, Union Types
- **근거**: 성민은 8.3~8.4 신규 기능 강조, 재영은 8.0~8.2 기능 강조. 양쪽 모두 유효. 항목명 "PHP 8.4 전용 기능"은 부정확(Typed Constants=8.3, Constructor Promotion=8.0 등).
- **제안**: 항목명을 "활용 권장 PHP 8.x 기능"으로 변경하고, 합집합으로 통일. 버전별 정리:
  - **8.0**: Constructor Promotion, Named Arguments, Union Types, match 표현식
  - **8.1**: Enums, readonly property, Fibers, Intersection Types
  - **8.2**: readonly class, DNF Types
  - **8.3**: Typed Constants, json_validate(), #[\Override]
  - **8.4**: Property Hooks, new without parentheses, Asymmetric Visibility, array_find()/array_any()/array_all(), #[\Deprecated] 어트리뷰트
- **추가 제안 (CI4+PHP 8.4 호환)**: CI4 Entity는 내부 `$attributes[]` 배열 + `__get`/`__set` 매직 메서드로 동작하므로, Property Hooks를 Entity 클래스에 직접 사용 시 `$attributes` 우회 문제 발생 가능(CI4 Issue #8573). Property Hooks는 순수 PHP 객체(VO/DTO)에서만 활용 권장. CI4 4.6+부터 PHP 8.4 공식 지원. ([PHP 8.4 New Features](https://www.php.net/releases/8.4/en.php), [CI4 PHP 8.4 Support #9116](https://github.com/codeigniter4/CodeIgniter4/issues/9116))

---

### 3. 아키텍처 모드 (2-1)

- **성민**: Modular Monolith (3-Layer)
- **재영**: Dual Mode (Legacy + Modular Monolith)
- **근거**: 재영 측 Dual Mode는 기존 USA 레거시 코드를 Modular Monolith로 변환하는 과정에서 추가된 운영 모드. 글로벌 신규 개발의 목표 아키텍처는 동일.
- **제안**: Modular Monolith (3-Layer)로 통일. 재영 문서의 Dual Mode/Legacy 모드 기술은 마이그레이션 가이드로 분리 또는 삭제.

---

### 4. 레이어 구조 (2-2)

- **성민**: Controller → Service → Repository (문서상 3-Layer 표기)
- **재영**: Controller → Service → Repository → Model + Entity/VO
- **근거**: [프론트/백엔드 공통 표준](https://www.notion.so/32c793554a5c818b83e5cc441d24602f)에도 Entity/VO가 언급되어 있어 실질적으로 양쪽 동일. 성민 문서의 "3-Layer" 표기가 Entity/VO를 누락한 것으로 보임.
- **제안**: 합의 필요. Controller → Service → Repository → Model + Entity/VO 구조로 통일 방향이나, 성민 측과 "3-Layer" 표기 보정 합의 필요.

---

### 5. 공유 모듈명 (2-6)

- **성민**: `Modules/Common/` (인증, 국가, 다국어)
- **재영**: `Modules/Shared/` (Models, Entities, ValueObjects, Interfaces)
- **근거**: DDD Shared Kernel 개념 참조. 두 모듈의 책임이 다름.
- **제안**: 합의 필요. 이름과 책임 범위 정의 후 결정.
- **추가 제안 (CI4)**: CI4 프레임워크 내부에 `system/Common.php`(공통 함수 파일)가 존재하므로, 팀 공유 모듈명은 `Shared/`를 사용해 프레임워크 내부와 혼동 방지 권장. ([CI4 Code Modules](https://codeigniter4.github.io/userguide/general/modules.html))

---

### 6. BC 매핑 수 (2-7)

- **성민**: 21개 MOD 확정 (WBS 기반)
- **재영**: 14개 BC (Auth, Board, Call 등)
- **제안**: 패스. BC 수는 개발 진행에 따라 유동적으로 늘어나는 부분이므로 불일치로 볼 필요 없음.

---

### 7. New 모드 산출물 (2-9)

- **성민**: 7개 필수 (Controller~Interface)
- **재영**: 9개 필수 (7개 + API 명세서 md+yaml)
- **근거**: Swagger/OpenAPI yaml 형식의 API 명세서는 프론트엔드 연동·테스트 자동화·문서 공유에 필수적.
- **제안**: API 명세서(Swagger/OpenAPI yaml) 추가를 성민 측에 제안. 최소 yaml(OpenAPI 3.1) 필수, md는 선택.
- **추가 제안 (CI4 4.7)**: CI4 4.7.0에 **API Transformer** 신기능 추가(`make:transformer` CLI 명령). Transformer로 응답 구조 표준화 시 Swagger 스키마와 1:1 대응 가능하므로 동시 설계 권장. ([CI4 4.7.0 Changelog](https://codeigniter4.github.io/userguide/changelogs/v4.7.0.html))

---

### 8. Controller 베이스 (4-2)

- **성민**: `extends BaseController`
- **재영**: `extends ResourceController` (API용)
- **근거**: ResourceController는 `BaseResource → Controller` 상속 구조로 ResponseTrait이 내장되어 있어 `respond()`, `failNotFound()` 등 API 헬퍼를 별도 use 없이 사용 가능. `$format = 'json'` 기본값 설정으로 JSON-only API에 최적. ([CI4 RESTful Resource Handling](https://codeigniter4.github.io/userguide/incoming/restful.html))
- **제안**: ResourceController 제안. 단, `$modelName` 자동 모델 주입은 Repository 패턴 사용 시 비활성화하고, DI로 Repository를 주입.
- **추가 제안 (CI4 4.7)**: CI4 4.7.0 API Transformer와 조합 시 ResourceController + Transformer 패턴이 공식 권장 방향으로 수렴. BaseController 공통 처리(인증/권한)는 PHP 단일 상속 제약상 Traits 또는 Filters로 대체. ([CI4 RESTful Resource Handling](https://codeigniter4.github.io/userguide/incoming/restful.html))

---

### 9. Repository 구현 방식 (4-3)

- **성민**: Repository extends CI4 Model
- **재영**: Repository 별도 클래스 + model() 헬퍼로 Model 주입
- **근거**: `extends Model`은 CI4 DB 연결을 필수로 요구하여 단위 테스트 시 Mock 대체 어려움. DIP(의존성 역전 원칙) 위반. CI4 공식 Entity 문서도 Repository를 Model과 분리하는 구조 권장. 커뮤니티 패키지(`tattersoftware/codeigniter4-repositories` 등)도 별도 클래스 방식 제안. ([CI4 Entity Classes](https://codeigniter4.github.io/userguide/models/entities.html))
- **제안**: 별도 클래스 + Model 주입 방식 제안. `model()` 헬퍼보다 생성자 주입이 테스트 시 Mock 교체에 명확.

---

### 10. Model 레이어 (4-5)

- **성민**: Repository가 Model 겸임 (extends Model이므로 별도 Model 없음)
- **재영**: 별도 Model 클래스 (테이블 매핑, 필드 정의, 모델 검증)
- **근거**: Repository=Model 겸임 시 한 클래스에 스키마 메타데이터(`$table`, `$allowedFields`, `$validationRules`) + 비즈니스 쿼리가 공존하여 SRP 위반 및 Fat Model 안티패턴. CI4 공식 구조도 Models/Repositories/Entities 디렉토리 분리를 권장. ([CI4 Application Structure](https://codeigniter4.github.io/userguide/concepts/structure.html))
- **제안**: Model 분리 제안. Model은 테이블 매핑/필드/검증 전용, Repository는 비즈니스 쿼리 전용.

---

### 11. API 성공 응답 키 (5-4)

- **성민**: `{ "success": true, "data": {...} }` — boolean
- **재영**: `{ "status": "success", "data": {...} }` — string
- **근거**: 업계 주류(Stripe, GitHub, Google, Discord, Twilio)는 HTTP 상태코드만으로 성공/실패를 표현하고 body에 성공 플래그를 두지 않음. Slack의 `ok: true`는 역사적 설계 오류로 분류됨. ([Google API Design Guide](https://cloud.google.com/apis/design), [RFC 7231](https://datatracker.ietf.org/doc/html/rfc7231))
- **제안**: 합의 필요. 업계 표준은 body 내 성공 플래그 자체가 불필요(HTTP 상태코드 중복). 다만 프론트엔드 편의를 위해 유지한다면 양측 형식 통일 합의.
- **추가 제안 (CI4 4.7)**: CI4 4.7.0 API Transformer를 활용해 응답 구조를 Transformer 클래스로 표준화하는 것이 현재 CI4 권장 방향. CI4 ResponseTrait은 고정 키 구조를 강제하지 않음. ([CI4 API Responses](https://codeigniter4.github.io/userguide/outgoing/api_responses.html))

---

### 12. 에러 코드명 (5-5)

- **성민**: `VALIDATION_ERROR`
- **재영**: `VALIDATION_FAILED`
- **근거**: 업계 주요 API는 `_ERROR`/`_FAILED` suffix를 에러 코드에 붙이지 않고, 현상 서술형을 사용. Google Cloud: `INVALID_ARGUMENT`, `NOT_FOUND`, `PERMISSION_DENIED`. Stripe: `card_declined`, `invalid_cvc`. GitHub: `missing_field`, `already_exists`. Microsoft Graph: `invalidRequest`, `accessDenied`. ([Google API Error Model](https://cloud.google.com/apis/design/errors), [Stripe Error Codes](https://stripe.com/docs/error-codes))
- **제안**: 합의 필요. 업계 주류는 suffix 없는 현상 서술형. 양측 모두 업계 표준과 차이가 있으므로 에러 코드 체계 재설계를 포함한 합의 권고.
- **추가 제안 (CI4)**: CI4 기본 에러 응답 키는 `status`(HTTP 코드) + `code`(커스텀 에러 코드) + `messages`(에러 메시지 배열). `code` 값 형식(숫자 vs 문자열 코드명)은 팀 결정 사항. ([CI4 API Responses](https://codeigniter4.github.io/userguide/outgoing/api_responses.html))

---

### 13. 페이지네이션 키명 (5-6)

- **성민**: `meta.page`
- **재영**: `meta.currentPage`
- **근거**: 업계 주류(GitHub, Stripe, Shopify, Slack)는 cursor 기반 페이지네이션으로 전환 완료. offset 기반에서는 통일된 외부 표준이 없음 — Laravel: `current_page`(snake_case), Spring: `pageNumber`(camelCase). ([GitHub Pagination](https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api), [Stripe Pagination](https://stripe.com/docs/api/pagination), [Laravel Pagination](https://laravel.com/docs/pagination))
- **제안**: 합의 필요. offset 페이지네이션 키에 외부 표준은 없으므로 프로젝트 내 camelCase 일관성 기준으로 결정.
- **추가 제안 (CI4 4.7)**: CI4 Pager 라이브러리는 JSON 키명을 정의하지 않음(뷰 렌더링 중심). API Transformer의 `paginate()` 응답에서 `data/meta/links` 구조가 사용되므로 이를 표준으로 제안. ([CI4 Pagination](https://codeigniter4.github.io/userguide/libraries/pagination.html))

---

### 14. 라우트 정의 패턴 (5-9)

- **성민**: 모듈별 Config/Routes.php
- **재영**: Legacy(group api) + New(모듈별) 이중 구조
- **근거**: Strangler Fig 패턴([Martin Fowler](https://martinfowler.com/bliki/StranglerFigApplication.html), [Azure Architecture Guide](https://learn.microsoft.com/en-us/azure/architecture/patterns/strangler-fig))에서 이중 구조는 과도기 필수 단계로 인정되나, 영구화는 기술 부채. Netflix, Shopify 등도 마이그레이션 중 이중 구조 운영 후 완료 시 레거시 제거.
- **제안**: 현재 이중 구조는 정당한 과도기 전략. 마이그레이션 완료 후 단일 모듈별 구조 통일 제안. 레거시 라우트에 sunset date 설정 권고.
- **추가 제안 (CI4)**: 프로덕션에서 `spark routes:cache`로 라우트 캐싱 시 auto-discovery 오버헤드 제거 가능 — 배포 스크립트에 포함 권장. ([CI4 Code Modules](https://codeigniter4.github.io/userguide/general/modules.html))

---

### 15. 인증 토큰 저장 (7-1)

- **성민**: HttpOnly 쿠키 전용. localStorage/응답 body 노출 금지
- **재영**: cookie 또는 localStorage 허용
- **근거**: OWASP Session Management Cheat Sheet — "Do not store session identifiers in local storage as the data is always accessible by JavaScript." IETF draft-ietf-oauth-browser-based-apps Section 6.3 — "Tokens MUST NOT be stored in localStorage or sessionStorage." Auth0·Okta 모두 localStorage 토큰 저장을 명시적 discourage. XSS 1회로 localStorage는 즉시 탈취되나 HttpOnly 쿠키는 JS 접근 불가. Same-Origin BFF 구조는 HttpOnly 쿠키 전용의 최적 환경. ([OWASP Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html), [IETF OAuth Browser Apps](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-browser-based-apps), [Auth0 Token Storage](https://auth0.com/docs/secure/security-guidance/data-security/token-storage))
- **제안**: HttpOnly 쿠키 전용 제안. OWASP·IETF·Auth0·Okta 전원 일치하는 명백한 업계 표준.

---

### 16. CSRF 방어 (7-4)

- **성민**: SameSite=Strict(1차) + X-Requested-With(2차)
- **재영**: 전통적 CSRF 토큰 보호
- **근거**: OWASP CSRF Prevention Cheat Sheet — SameSite 쿠키를 "defense-in-depth layer(보조 수단)"로 분류하며 단독 primary defense로 권장하지 않음. Synchronizer Token Pattern을 "가장 대중적이고 권장되는 방법"으로 명시. Django·Rails·Laravel·Spring·CI4 5개 주요 프레임워크 모두 CSRF Token이 기본값. SameSite=Strict의 한계: top-level navigation 시 쿠키 미전송으로 로그인 세션 깨짐 가능. ([OWASP CSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html), [Django CSRF](https://docs.djangoproject.com/en/5.1/ref/csrf/), [Laravel CSRF](https://laravel.com/docs/11.x/csrf))
- **제안**: 합의 필요. 업계 표준은 CSRF Token(모든 주요 프레임워크 기본값). 단, Same-Origin SPA + BFF 환경에서 SameSite + Custom Header도 실용적 대안으로 사용 증가 추세.
- **추가 제안 (CI4)**: CI4 CSRF 필터는 Cookie-Based(기본) / Session-Based 두 방식 제공. 공식 문서: "세션 사용 시 Session-Based CSRF로 전환 필수 — Cookie-Based는 Same-site 공격 방어 불가." SPA + JWT Bearer 토큰 방식(Authorization 헤더)이면 API 경로를 CSRF 필터 `$except`에 제외 가능. ([CI4 Security/CSRF](https://codeigniter4.github.io/userguide/libraries/security.html))

---

### 17. 테스트 디렉토리 구조 (9-1)

- **성민**: `tests/Unit/Modules/{BC}/` — 타입별(Unit/Feature) 1차 분류
- **재영**: `tests/Modules/{BC}/Unit/` — 모듈별 1차 분류
- **근거**: PHP 프레임워크 생태계(Laravel·Symfony·CI4)는 타입별 1차 분류(`tests/Unit/`, `tests/Feature/`)가 압도적 표준. PHPUnit 공식 예제도 타입별 구조 제시. 반면 Modular Monolith 원칙(Sam Newman, Shopify Engineering)에서는 모듈 자급자족성을 위해 모듈별 1차 분류 권장 — 모듈 삭제/이동 시 1곳만 수정. ([PHPUnit Organizing Tests](https://docs.phpunit.de/en/11.0/organizing-tests.html), [Laravel Testing](https://laravel.com/docs/11.x/testing), [Shopify Monolith](https://shopify.engineering/deconstructing-monolith-designing-software-maximizes-developer-productivity))
- **제안**: 합의 필요. PHP 관례 우선이면 타입별(성민), 모듈 독립성 우선이면 모듈별(재영). 아키텍처 방향성 선택의 문제.

---

### 18. 커밋 메시지 형식 (10-1)

- **성민 BE 11**: `[ModuleName] type: 설명` (대괄호)
- **성민 common-standards S14**: `type(scope): 제목` (Conventional Commits)
- **재영**: 미기재
- **근거**: 성민 측 내부 불일치 존재. common-standards S14가 최신(2026-04-03 개정).
- **제안**: 패스. 재영 측은 스킬에 커밋 컨벤션이 이미 반영되어 있어 실질적으로 동일.

---

## 협의 체크리스트

- [x] 1-3 MySQL 버전 → 제안 수용: Aurora MySQL 3.12.0 (Compatible with MySQL 8.0.44) 통일
- [x] 1-11 PHP 8.x 활용 기능 → 제안 수용: 합집합 통일 + 버전별 정리
- [x] 2-1 아키텍처 모드 → **성민**: Modular Monolith 통일
- [x] 2-2 레이어 구조 → **재영**: Controller→Service→Repository→Model + Entity/VO
- [x] 2-6 공유 모듈 → **재영**: Shared/
- [x] 2-7 BC 매핑 → **성민**: 21개 MOD 기준 (개발 진행에 따라 유동적)
- [x] 2-9 New 모드 산출물 → 제안 수용: Swagger/OpenAPI yaml 추가
- [x] 4-2 Controller 베이스 → 제안 수용: ResourceController
- [x] 4-3 Repository 구현 → **재영**: 별도 클래스 + Model 주입
- [x] 4-5 Model 레이어 → **재영**: Model 분리
- [x] 5-4 API 성공 응답 키 → 제안 수용
- [x] 5-5 에러 코드 네이밍 → 제안 수용
- [x] 5-6 페이지네이션 키 → 제안 수용
- [x] 5-9 라우트 정의 → **성민**: 완료 후 단일 모듈별 통일
- [x] 7-1 인증 토큰 저장 → **성민**: HttpOnly 쿠키 전용
- [x] 7-4 CSRF 방어 → 제안 수용 + JWT 추가
- [x] 9-1 테스트 디렉토리 → **성민**: 타입별 1차 분류
- [x] 10-1 커밋 형식 → **성민**: CC 형식 통일

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-15 | 최초 작성 | jypark |
| 2026-04-15 | doc-template 양식 적용 | jypark |
