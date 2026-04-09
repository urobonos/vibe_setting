# CWE Top 25 Most Dangerous Software Weaknesses (2024)

> **출처:** [cwe.mitre.org](https://cwe.mitre.org/top25/archive/2024/2024_top25_list.html)
> **기준 연도:** 2024
> **작성일:** 2026-04-09
> **용도:** PHP 백엔드 프로젝트 보안 점검 레퍼런스

---

## 목차

1. [전체 순위표](#전체-순위표)
2. [카테고리별 상세](#카테고리별-상세)
   - [입력 검증 (Input Validation)](#1-입력-검증-input-validation)
   - [인증/인가 (Auth)](#2-인증인가-auth)
   - [메모리 안전 (Memory Safety)](#3-메모리-안전-memory-safety)
   - [기타](#4-기타)
3. [PHP/웹 프로젝트 우선순위 요약](#php웹-프로젝트-우선순위-요약)

---

## 전체 순위표

| Rank | CWE ID | Name | Score |
|------|--------|------|-------|
| 1 | CWE-79 | Improper Neutralization of Input During Web Page Generation ('Cross-site Scripting') | 56.92 |
| 2 | CWE-787 | Out-of-bounds Write | 45.20 |
| 3 | CWE-89 | Improper Neutralization of Special Elements used in an SQL Command ('SQL Injection') | 35.88 |
| 4 | CWE-352 | Cross-Site Request Forgery (CSRF) | 19.57 |
| 5 | CWE-22 | Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal') | 12.74 |
| 6 | CWE-125 | Out-of-bounds Read | 11.42 |
| 7 | CWE-78 | Improper Neutralization of Special Elements used in an OS Command ('OS Command Injection') | 11.30 |
| 8 | CWE-416 | Use After Free | 10.19 |
| 9 | CWE-862 | Missing Authorization | 10.11 |
| 10 | CWE-434 | Unrestricted Upload of File with Dangerous Type | 10.03 |
| 11 | CWE-94 | Improper Control of Generation of Code ('Code Injection') | 7.13 |
| 12 | CWE-20 | Improper Input Validation | 6.78 |
| 13 | CWE-77 | Improper Neutralization of Special Elements used in a Command ('Command Injection') | 6.74 |
| 14 | CWE-287 | Improper Authentication | 5.94 |
| 15 | CWE-269 | Improper Privilege Management | 5.22 |
| 16 | CWE-502 | Deserialization of Untrusted Data | 5.07 |
| 17 | CWE-200 | Exposure of Sensitive Information to an Unauthorized Actor | 5.07 |
| 18 | CWE-863 | Incorrect Authorization | 4.05 |
| 19 | CWE-918 | Server-Side Request Forgery (SSRF) | 4.05 |
| 20 | CWE-119 | Improper Restriction of Operations within the Bounds of a Memory Buffer | 3.69 |
| 21 | CWE-476 | NULL Pointer Dereference | 3.58 |
| 22 | CWE-798 | Use of Hard-coded Credentials | 3.46 |
| 23 | CWE-190 | Integer Overflow or Wraparound | 3.37 |
| 24 | CWE-400 | Uncontrolled Resource Consumption | 3.23 |
| 25 | CWE-306 | Missing Authentication for Critical Function | 2.73 |

---

## 카테고리별 상세

### 1. 입력 검증 (Input Validation)

사용자 입력을 적절히 검증하거나 이스케이프하지 않아 발생하는 취약점 그룹. PHP/웹 프로젝트에서 가장 빈번하게 노출되는 영역이다.

---

#### Rank 1 -- CWE-79: Cross-site Scripting (XSS)

- **Score:** 56.92
- **PHP/웹 관련성:** **높음**

웹 페이지 생성 시 사용자 입력을 적절히 무력화(neutralize)하지 않아, 공격자가 피해자 브라우저에서 임의 스크립트를 실행할 수 있다.
PHP에서는 `htmlspecialchars()` 미적용 출력, Blade/Twig 템플릿의 raw 출력이 대표적 원인이다.

---

#### Rank 3 -- CWE-89: SQL Injection

- **Score:** 35.88
- **PHP/웹 관련성:** **높음**

SQL 쿼리 구성 시 사용자 입력을 직접 연결(concatenation)하여 공격자가 임의 SQL을 실행할 수 있다.
CI4 Query Builder나 Prepared Statement를 사용하지 않고 raw query에 변수를 직접 삽입하면 발생한다.

---

#### Rank 5 -- CWE-22: Path Traversal

- **Score:** 12.74
- **PHP/웹 관련성:** **높음**

파일 경로를 제한된 디렉토리 내로 한정하지 않아, `../` 등의 시퀀스로 의도하지 않은 파일에 접근할 수 있다.
파일 다운로드/업로드 엔드포인트에서 사용자 입력을 basename 검증 없이 경로에 사용하면 발생한다.

---

#### Rank 7 -- CWE-78: OS Command Injection

- **Score:** 11.30
- **PHP/웹 관련성:** **높음**

OS 명령어 구성 시 사용자 입력을 적절히 이스케이프하지 않아 공격자가 임의 시스템 명령을 실행할 수 있다.
PHP의 `exec()`, `shell_exec()`, `system()`, `passthru()` 등에 사용자 입력을 직접 전달하면 발생한다.

---

#### Rank 11 -- CWE-94: Code Injection

- **Score:** 7.13
- **PHP/웹 관련성:** **높음**

애플리케이션이 코드 생성 과정을 적절히 제어하지 못해 공격자가 임의 코드를 주입, 실행할 수 있다.
PHP에서 `eval()`, `preg_replace()`의 `/e` modifier(과거 버전), 동적 `include`/`require` 등이 대표적 벡터이다.

---

#### Rank 12 -- CWE-20: Improper Input Validation

- **Score:** 6.78
- **PHP/웹 관련성:** **높음**

입력 데이터를 적절히 검증하지 않아 예상치 못한 값이 시스템 내부로 유입되는 포괄적 취약점이다.
타입 검증, 범위 검증, 길이 제한, 허용 문자 필터링 등 다층 검증이 누락될 때 다른 구체적 취약점(XSS, SQLi 등)의 근본 원인이 된다.

---

#### Rank 13 -- CWE-77: Command Injection

- **Score:** 6.74
- **PHP/웹 관련성:** **중간**

명령어 문자열에 특수 요소를 적절히 무력화하지 않아 공격자가 의도하지 않은 명령을 실행할 수 있다.
CWE-78(OS Command Injection)과 유사하나, OS 명령에 한정되지 않고 메일 헤더 인젝션, LDAP 쿼리 인젝션 등 더 넓은 범위를 포함한다.

---

### 2. 인증/인가 (Auth)

인증(Authentication)과 인가(Authorization) 메커니즘의 부재 또는 결함으로 발생하는 취약점 그룹. API 기반 백엔드에서 특히 중요하다.

---

#### Rank 4 -- CWE-352: Cross-Site Request Forgery (CSRF)

- **Score:** 19.57
- **PHP/웹 관련성:** **높음**

인증된 사용자의 브라우저를 이용해 의도하지 않은 요청을 서버에 전송하도록 유도하는 공격이다.
CI4의 CSRF 필터를 활성화하지 않거나, SPA에서 CSRF 토큰 검증을 생략하면 발생한다. API 전용 프로젝트에서도 cookie 기반 인증 사용 시 해당된다.

---

#### Rank 9 -- CWE-862: Missing Authorization

- **Score:** 10.11
- **PHP/웹 관련성:** **높음**

보호 대상 리소스에 대한 인가 검사가 누락되어 인증된 사용자가 권한 밖의 자원에 접근할 수 있다.
컨트롤러에서 `hasPermission()` 또는 policy 검사를 빠뜨린 엔드포인트가 대표적 사례이다. IDOR(Insecure Direct Object Reference)의 근본 원인이기도 하다.

---

#### Rank 14 -- CWE-287: Improper Authentication

- **Score:** 5.94
- **PHP/웹 관련성:** **높음**

사용자 신원을 적절히 검증하지 않아 공격자가 타인의 ID로 시스템에 접근할 수 있다.
JWT 서명 미검증, 세션 고정(session fixation), 비밀번호 재설정 토큰의 약한 엔트로피 등이 해당된다.

---

#### Rank 15 -- CWE-269: Improper Privilege Management

- **Score:** 5.22
- **PHP/웹 관련성:** **중간**

권한 부여, 변경, 추적 메커니즘이 부적절하여 사용자가 의도보다 높은 권한을 획득할 수 있다.
관리자 역할 할당 로직의 결함, 권한 에스컬레이션 경로 미차단 등이 해당된다.

---

#### Rank 18 -- CWE-863: Incorrect Authorization

- **Score:** 4.05
- **PHP/웹 관련성:** **높음**

인가 검사가 존재하지만 로직이 잘못되어, 허용되지 않아야 할 접근을 허용하는 취약점이다.
CWE-862(Missing Authorization)가 검사 자체의 부재라면, CWE-863은 검사는 있으나 조건식 오류, 역할 매핑 오류 등으로 우회가 가능한 경우이다.

---

#### Rank 22 -- CWE-798: Use of Hard-coded Credentials

- **Score:** 3.46
- **PHP/웹 관련성:** **높음**

소스 코드에 비밀번호, API 키, 토큰 등의 인증 정보를 하드코딩하여 노출 위험이 발생한다.
`.env` 파일이나 Vault 등 외부 비밀 저장소를 사용하지 않고 코드에 직접 기재하면 Git 이력을 통해 영구 노출된다.

---

#### Rank 25 -- CWE-306: Missing Authentication for Critical Function

- **Score:** 2.73
- **PHP/웹 관련성:** **높음**

핵심 기능(관리자 설정, 데이터 삭제 등)에 인증 절차가 누락되어 비인증 사용자가 직접 접근할 수 있다.
라우트에 auth 미들웨어/필터를 적용하지 않은 관리 엔드포인트가 대표적이다.

---

### 3. 메모리 안전 (Memory Safety)

메모리 관리 결함으로 발생하는 취약점 그룹. PHP 자체보다는 PHP가 의존하는 C 확장, 서버 바이너리, 시스템 라이브러리에서 주로 발생한다.

---

#### Rank 2 -- CWE-787: Out-of-bounds Write

- **Score:** 45.20
- **PHP/웹 관련성:** **낮음**

할당된 메모리 버퍼 범위를 벗어나 데이터를 쓰는 취약점으로, 코드 실행 또는 시스템 크래시를 유발한다.
PHP 코드에서 직접 발생하지는 않으나, PHP 인터프리터나 C 확장(ImageMagick, libxml 등)의 취약점으로 간접 영향을 받을 수 있다.

---

#### Rank 6 -- CWE-125: Out-of-bounds Read

- **Score:** 11.42
- **PHP/웹 관련성:** **낮음**

할당된 메모리 버퍼 범위를 벗어나 데이터를 읽는 취약점으로, 민감 정보 노출이나 크래시를 유발한다.
Heartbleed(OpenSSL)가 대표적 사례이며, PHP 확장이나 의존 라이브러리 업데이트로 대응한다.

---

#### Rank 8 -- CWE-416: Use After Free

- **Score:** 10.19
- **PHP/웹 관련성:** **낮음**

해제된 메모리를 참조하여 임의 코드 실행 또는 크래시를 유발하는 취약점이다.
PHP 엔진 또는 C 확장 레벨에서 발생하며, PHP 버전 업데이트로 대응한다.

---

#### Rank 20 -- CWE-119: Buffer Overflow (Memory Buffer Bounds)

- **Score:** 3.69
- **PHP/웹 관련성:** **낮음**

메모리 버퍼 경계를 벗어나는 연산을 수행하는 포괄적 취약점으로, CWE-787과 CWE-125의 상위 카테고리이다.
PHP 애플리케이션 코드에서 직접 발생하지 않으나, 서버 인프라(Nginx, Apache) 및 PHP 런타임 업데이트 시 점검 대상이다.

---

#### Rank 21 -- CWE-476: NULL Pointer Dereference

- **Score:** 3.58
- **PHP/웹 관련성:** **낮음**

NULL 포인터를 역참조하여 프로그램이 크래시되는 취약점이다.
C/C++ 기반 시스템에서 발생하며, PHP에서는 런타임이 자동으로 처리하므로 직접적 위험은 낮다. 다만 PHP 확장의 segfault로 나타날 수 있다.

---

#### Rank 23 -- CWE-190: Integer Overflow or Wraparound

- **Score:** 3.37
- **PHP/웹 관련성:** **낮음**

정수 연산이 최대/최소 범위를 초과하여 예기치 않은 값으로 래핑되는 취약점이다.
PHP는 자동으로 float 변환을 수행하나, 32비트 환경이나 C 확장에서 문제가 될 수 있다. 금액 계산 등 정밀도가 중요한 로직에서는 `bcmath` 등을 사용한다.

---

### 4. 기타

위 세 카테고리에 속하지 않는 취약점으로, 파일 업로드, 직렬화, 정보 노출, SSRF, 자원 소모 등을 포함한다.

---

#### Rank 10 -- CWE-434: Unrestricted Upload of File with Dangerous Type

- **Score:** 10.03
- **PHP/웹 관련성:** **높음**

위험한 타입의 파일(예: `.php`, `.phtml`)을 제한 없이 업로드할 수 있어, 서버에서 임의 코드가 실행될 수 있다.
MIME 타입 검증만으로는 불충분하며, 확장자 화이트리스트, 업로드 디렉토리의 실행 권한 제거, 저장 경로 난수화가 필요하다.

---

#### Rank 16 -- CWE-502: Deserialization of Untrusted Data

- **Score:** 5.07
- **PHP/웹 관련성:** **높음**

신뢰할 수 없는 데이터를 역직렬화(unserialize)하여 임의 객체 생성 및 코드 실행이 가능해지는 취약점이다.
PHP의 `unserialize()` 함수는 매직 메서드(`__wakeup`, `__destruct`)를 통한 POP chain 공격에 취약하다. `json_decode()`로 대체하거나 `allowed_classes` 옵션을 반드시 지정한다.

---

#### Rank 17 -- CWE-200: Exposure of Sensitive Information

- **Score:** 5.07
- **PHP/웹 관련성:** **높음**

에러 메시지, 스택 트레이스, 디버그 정보 등을 통해 민감 정보가 비인가 사용자에게 노출되는 취약점이다.
프로덕션 환경에서 `display_errors = On`, CI4의 `CI_ENVIRONMENT = development` 설정이 남아있으면 DB 접속 정보, 파일 경로 등이 노출된다.

---

#### Rank 19 -- CWE-918: Server-Side Request Forgery (SSRF)

- **Score:** 4.05
- **PHP/웹 관련성:** **높음**

서버가 사용자 입력으로 제공된 URL에 요청을 보내어, 내부 네트워크 자원에 접근하거나 클라우드 메타데이터를 탈취하는 공격이다.
`file_get_contents()`, `curl`로 외부 URL을 요청할 때 내부 IP(127.0.0.1, 169.254.169.254 등)를 차단하는 검증이 필요하다.

---

#### Rank 24 -- CWE-400: Uncontrolled Resource Consumption

- **Score:** 3.23
- **PHP/웹 관련성:** **중간**

CPU, 메모리, 디스크, 네트워크 등의 자원을 제한 없이 소모하게 하여 서비스 거부(DoS)를 유발하는 취약점이다.
대용량 파일 업로드 제한, 요청 빈도 제한(rate limiting), 쿼리 타임아웃 설정 등으로 대응한다.

---

## PHP/웹 프로젝트 우선순위 요약

PHP 백엔드 프로젝트 관점에서 관련성 수준별로 정리한 대응 우선순위이다.

### 높음 (즉시 점검 필요) -- 16개

| Rank | CWE ID | 핵심 키워드 |
|------|--------|------------|
| 1 | CWE-79 | XSS -- 출력 이스케이프 |
| 3 | CWE-89 | SQL Injection -- Prepared Statement |
| 4 | CWE-352 | CSRF -- 토큰 검증 |
| 5 | CWE-22 | Path Traversal -- basename 검증 |
| 7 | CWE-78 | OS Command Injection -- escapeshellarg |
| 9 | CWE-862 | Missing Authorization -- 인가 필터 |
| 10 | CWE-434 | File Upload -- 확장자 화이트리스트 |
| 11 | CWE-94 | Code Injection -- eval 금지 |
| 12 | CWE-20 | Input Validation -- 다층 검증 |
| 14 | CWE-287 | Authentication -- JWT/세션 검증 |
| 16 | CWE-502 | Deserialization -- unserialize 금지 |
| 17 | CWE-200 | Info Exposure -- 에러 출력 차단 |
| 18 | CWE-863 | Incorrect Authorization -- 인가 로직 검증 |
| 19 | CWE-918 | SSRF -- 내부 IP 차단 |
| 22 | CWE-798 | Hard-coded Credentials -- .env 분리 |
| 25 | CWE-306 | Missing Auth -- auth 미들웨어 |

### 중간 -- 3개

| Rank | CWE ID | 핵심 키워드 |
|------|--------|------------|
| 13 | CWE-77 | Command Injection -- 넓은 범위 명령 주입 |
| 15 | CWE-269 | Privilege Management -- 권한 에스컬레이션 |
| 24 | CWE-400 | Resource Consumption -- Rate Limiting |

### 낮음 (인프라/런타임 업데이트로 대응) -- 6개

| Rank | CWE ID | 핵심 키워드 |
|------|--------|------------|
| 2 | CWE-787 | Out-of-bounds Write -- C 확장 업데이트 |
| 6 | CWE-125 | Out-of-bounds Read -- 라이브러리 패치 |
| 8 | CWE-416 | Use After Free -- PHP 버전 업데이트 |
| 20 | CWE-119 | Buffer Overflow -- 서버 바이너리 업데이트 |
| 21 | CWE-476 | NULL Pointer Deref -- 확장 점검 |
| 23 | CWE-190 | Integer Overflow -- bcmath 사용 |
