# PHP Configuration Security Cheat Sheet

> Source: OWASP PHP Configuration Cheat Sheet

---

## 1. 에러 처리 (Error Handling)

프로덕션 환경에서 에러 정보가 외부에 노출되면 공격 표면이 확대된다.

```ini
; PHP 버전 헤더 노출 차단
expose_php = Off

; 브라우저에 에러 출력 금지 (프로덕션 필수)
display_errors = Off
display_startup_errors = Off

; 서버 측 에러 로그 활성화
log_errors = On
error_log = /var/log/php/error.log

; 모든 에러 수준 기록
error_reporting = E_ALL
```

**핵심:** `display_errors=On`은 개발 환경에서만 허용. 프로덕션에서는 반드시 `Off`로 설정하고 `log_errors`로 서버 내부에만 기록한다.

---

## 2. 일반 설정 (General Settings)

원격 파일 접근과 디렉토리 탐색을 제한하여 SSRF 및 LFI 공격을 방지한다.

```ini
; 원격 URL을 파일처럼 열기 차단 (SSRF 방지)
allow_url_fopen = Off

; 원격 파일 include 차단 (RFI 방지)
allow_url_include = Off

; PHP가 접근 가능한 디렉토리를 제한 (LFI 완화)
open_basedir = /var/www/html:/tmp

; 심볼릭 링크를 통한 basedir 우회 방지
; Apache: Options -FollowSymLinks
```

**핵심:** `open_basedir`은 PHP 프로세스가 접근할 수 있는 파일 시스템 경계를 강제한다. 애플리케이션 루트와 임시 디렉토리만 허용한다.

---

## 3. 파일 업로드 (File Uploads)

업로드 기능은 웹쉘 삽입의 주요 경로이다. 크기와 수량을 최소한으로 제한한다.

```ini
; 파일 업로드 허용 여부 (불필요 시 Off)
file_uploads = On

; 단일 파일 최대 크기
upload_max_filesize = 2M

; 한 요청당 최대 업로드 파일 수
max_file_uploads = 2

; 업로드 임시 디렉토리 (전용 파티션 권장)
upload_tmp_dir = /var/lib/php/upload_tmp
```

**추가 방어:**
- 업로드된 파일의 MIME 타입을 서버 측에서 검증 (`finfo_file()`)
- 실행 가능한 확장자(`.php`, `.phtml`, `.phar`) 차단
- 업로드 디렉토리에 실행 권한 제거 (`chmod 0640`)
- 웹 루트 외부에 저장

---

## 4. 위험 함수 비활성화 (Disable Dangerous Functions)

OS 명령 실행이 가능한 함수를 비활성화하여 RCE(Remote Code Execution) 공격을 차단한다.

```ini
disable_functions = system, exec, shell_exec, passthru, phpinfo, show_source,
  highlight_file, popen, proc_open, fopen_with_path, dbmopen, dbase_open,
  putenv, filepro, filepro_rowcount, filepro_retrieve, posix_mkfifo,
  dl, mail, symlink, link, escapeshellcmd, escapeshellarg,
  pcntl_exec, pcntl_fork, pcntl_signal, pcntl_waitpid, pcntl_wexitstatus,
  pcntl_setpriority, pcntl_getpriority
```

| 함수 | 위험도 | 설명 |
|------|--------|------|
| `system()` | Critical | OS 명령 실행 + 출력 반환 |
| `exec()` | Critical | OS 명령 실행 + 마지막 줄 반환 |
| `shell_exec()` | Critical | 쉘을 통한 명령 실행 |
| `passthru()` | Critical | 바이너리 출력 직접 전달 |
| `popen()` | High | 프로세스 파이프 열기 |
| `proc_open()` | High | 양방향 프로세스 파이프 |
| `phpinfo()` | Medium | 서버 환경 전체 노출 |
| `putenv()` | Medium | 환경변수 조작 (LD_PRELOAD 공격) |
| `dl()` | High | 런타임 확장 로드 |

**핵심:** 애플리케이션에서 실제로 사용하는 함수가 있다면 해당 함수만 제외. 기본 정책은 전부 비활성화이다.

---

## 5. 세션 보안 (Session Security)

세션 하이재킹과 세션 고정 공격을 방지하기 위한 설정이다.

### 5.1 세션 모드 및 쿠키 설정

```ini
; 초기화되지 않은 Session ID 거부 (세션 고정 방지)
session.use_strict_mode = 1

; 쿠키로만 Session ID 전달 (URL 파라미터 차단)
session.use_cookies = 1
session.use_only_cookies = 1

; HTTPS에서만 세션 쿠키 전송
session.cookie_secure = 1

; JavaScript에서 세션 쿠키 접근 차단 (XSS 완화)
session.cookie_httponly = 1

; Cross-site 요청 시 쿠키 미전송 (CSRF 완화)
session.cookie_samesite = Strict
```

### 5.2 Session ID 강도

```ini
; Session ID 길이 (기본 32 → 256으로 증가)
session.sid_length = 256

; Session ID 문자당 비트 수 (6 = a-z, A-Z, 0-9, -, ,)
session.sid_bits_per_character = 6
```

**엔트로피 계산:** 256 x 6 = 1,536 bits. 무차별 대입이 사실상 불가능한 수준이다.

### 5.3 세션 이름 변경

```ini
; 기본 세션 이름 'PHPSESSID' 변경 (핑거프린팅 방지)
session.name = __Host-sess
```

**`__Host-` 접두사 효과:**
- `Secure` 속성 필수
- `Path=/` 필수
- `Domain` 속성 불허
- 브라우저가 자동으로 쿠키 무결성 강제

### 5.4 세션 수명 제어

```ini
; 세션 수명 (초 단위, 1800 = 30분)
session.gc_maxlifetime = 1800

; 쿠키 수명 (0 = 브라우저 종료 시 삭제)
session.cookie_lifetime = 0
```

---

## 6. 추가 보안 설정 (Additional Hardening)

### 6.1 리소스 제한

```ini
; 메모리 제한 (DoS 완화)
memory_limit = 50M

; 최대 실행 시간 (초 단위)
max_execution_time = 60

; 최대 입력 처리 시간
max_input_time = 60

; POST 데이터 최대 크기
post_max_size = 8M

; 입력 변수 최대 수 (HashDoS 방지)
max_input_vars = 1000
```

### 6.2 예외 정보 보호

```ini
; Stack trace에서 함수 인자 숨김 (PHP 7.4+)
zend.exception_ignore_args = On

; Stack trace에서 반환값 숨김 (PHP 8.2+)
zend.exception_string_param_max_len = 0
```

**핵심:** 예외가 로그에 기록될 때 민감한 데이터(비밀번호, 토큰 등)가 함수 인자로 노출되는 것을 차단한다.

### 6.3 기타

```ini
; 쿠키에 httponly 기본 적용
session.cookie_httponly = 1

; realpath 캐시 크기 제한
realpath_cache_size = 4096k

; CGI 보안 (Apache mod_php 사용 시)
cgi.force_redirect = 1
```

---

## 7. Snuffleupagus 보안 확장

[Snuffleupagus](https://snuffleupagus.readthedocs.io/)는 PHP 7+ / 8+용 보안 모듈로, Suhosin의 후속 프로젝트이다.

### 주요 기능

| 기능 | 설명 |
|------|------|
| Virtual-patching | 코드 수정 없이 알려진 취약점 차단 |
| `disable_function` 강화 | 조건부 함수 비활성화 (특정 인자 패턴 매칭) |
| Cookie 암호화 | 쿠키 값을 자동 암호화 |
| `eval` 화이트리스트 | 허용된 컨텍스트에서만 `eval()` 실행 |
| Read-only 실행 | 업로드 디렉토리 내 파일 실행 차단 |
| 자동 세션 쿠키 보호 | `SameSite`, `HttpOnly`, `Secure` 플래그 자동 강제 |
| XXE 차단 | XML External Entity 공격 기본 차단 |

### 설치 및 적용

```bash
# PECL 설치
pecl install snuffleupagus

# php.ini 추가
extension=snuffleupagus.so
sp.configuration_file=/etc/php/snuffleupagus.rules
```

### 기본 규칙 예시

```ini
# 업로드 디렉토리 실행 차단
sp.readonly_exec.enable();
sp.readonly_exec.list("/var/www/html/uploads/");

# eval 전면 차단
sp.eval.blacklist.regex(".*");

# 쿠키 암호화
sp.cookie.name("session").encrypt();

# 특정 함수를 특정 조건에서만 차단
sp.disable_function.function("mail").param("to").value_r("@evil\\.com").drop();
```

### Snuffleupagus vs disable_functions

| 비교 항목 | `disable_functions` | Snuffleupagus |
|-----------|---------------------|---------------|
| 조건부 차단 | 불가 | 가능 (인자/호출 위치 기반) |
| Virtual-patching | 불가 | 가능 |
| 쿠키 보호 | 불가 | 자동 암호화/플래그 강제 |
| 성능 영향 | 없음 | 경미 (< 2%) |
| 유지보수 | INI 수정 | 규칙 파일 관리 필요 |

---

## 프로덕션 체크리스트

```text
[x] expose_php = Off
[x] display_errors = Off
[x] log_errors = On
[x] allow_url_fopen = Off
[x] allow_url_include = Off
[x] open_basedir 설정
[x] disable_functions 설정
[x] session.use_strict_mode = 1
[x] session.cookie_secure = 1
[x] session.cookie_httponly = 1
[x] session.cookie_samesite = Strict
[x] session.sid_length >= 128
[x] session.name 기본값 변경
[x] memory_limit 제한
[x] max_execution_time 제한
[x] zend.exception_ignore_args = On
[x] Snuffleupagus 설치 (권장)
```
