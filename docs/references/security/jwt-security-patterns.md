# JWT 보안 패턴 (JSON Web Token Security Patterns)

> 출처: https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html
> 최종 갱신: 2026-04-09

---

## 1. 알고리즘 선택 (Algorithm Selection)

### None Algorithm 공격

JWT 헤더의 `alg` 값을 `"none"`으로 변조하면 서명 검증을 완전히 우회할 수 있다.

```json
// 공격 페이로드 예시
{
  "alg": "none",
  "typ": "JWT"
}
```

서버가 `alg` 필드를 신뢰하고 서명 검증을 생략하면, 공격자는 임의의 claims를 주입할 수 있다.

### 방지 대책

- **라이브러리 레벨에서 허용 알고리즘을 명시적으로 지정**한다. JWT 파싱 시 토큰 헤더의 `alg` 값을 그대로 사용하지 않는다.
- `none` 알고리즘을 허용 목록에서 완전히 제외한다.

```php
// PHP 예시 (firebase/php-jwt)
$decoded = JWT::decode($token, new Key($secret, 'HS256')); // 알고리즘 명시
```

```javascript
// Node.js 예시 (jsonwebtoken)
jwt.verify(token, secret, { algorithms: ['HS256'] }); // 허용 알고리즘 제한
```

### Algorithm Confusion 공격 (Key Confusion)

RSA 공개키를 HMAC 시크릿으로 사용하는 공격. 서버가 RSA로 서명 검증을 기대하지만, 공격자가 `alg`을 `HS256`으로 변경하고 공개키(public key)를 HMAC 시크릿으로 사용하여 서명하면 검증을 통과할 수 있다.

**방지**: 서버 측에서 알고리즘을 하드코딩하고, 토큰 헤더의 `alg` 값을 무시한다.

### HMAC vs RSA 선택 기준

| 기준 | HMAC (HS256/384/512) | RSA (RS256/384/512) |
|------|---------------------|---------------------|
| 키 유형 | 대칭키 (동일 키로 서명/검증) | 비대칭키 (개인키 서명, 공개키 검증) |
| 적합 환경 | 단일 서버, 내부 서비스 간 통신 | 분산 시스템, 외부 클라이언트 검증 필요 |
| 키 분배 | 모든 서비스가 동일 시크릿 공유 필요 (위험) | 공개키만 배포 (안전) |
| 성능 | 빠름 | 서명 생성 느림, 검증은 빠름 |
| 권장 사례 | 모놀리식, 단일 API 서버 | MSA, OAuth2/OIDC, 제3자 검증 |

**원칙**: 토큰을 생성하는 서비스와 검증하는 서비스가 다르면 RSA(비대칭키)를 사용한다.

---

## 2. 시크릿 관리 (Secret Management)

### 키 강도 요구사항

- **최소 64자(512비트) 이상**의 시크릿 사용 (HMAC 기준)
- **암호학적 보안 난수 생성기(CSPRNG)** 로 생성 — `Math.random()`, `rand()` 등은 사용 금지

```php
// PHP — CSPRNG로 시크릿 생성
$secret = bin2hex(random_bytes(64)); // 128자 hex string (512비트)
```

```bash
# CLI — OpenSSL로 생성
openssl rand -base64 64
```

### 메모리 내 시크릿 보호

- Java/Kotlin: `String` 대신 `byte[]` 또는 `char[]` 사용 — `String`은 불변(immutable)이라 GC 전까지 메모리에 잔류
- 사용 후 `Arrays.fill(secretBytes, (byte) 0)` 으로 즉시 제로화
- PHP: `sodium_memzero()` 함수로 민감 변수 제로화

### 크래킹 위험

약한 시크릿은 오프라인 무차별 대입으로 크래킹 가능하다.

- **Hashcat**: `hashcat -m 16500 jwt.txt wordlist.txt` — GPU 기반 고속 크래킹
- **John the Ripper**: `john --format=HMAC-SHA256 jwt.txt`
- 짧거나 예측 가능한 시크릿(`secret`, `password123`, 회사명 등)은 수초 내 크래킹됨

**대책**: 64자 이상 CSPRNG 시크릿 + 정기 로테이션 (90일 권장)

---

## 3. 토큰 만료 (Expiration & Rotation)

### 만료 시간 권장값

| 토큰 유형 | 만료 시간 | 근거 |
|-----------|----------|------|
| Access Token | **15~30분** | 탈취 시 피해 윈도우 최소화 |
| Refresh Token | **7~30일** | 사용자 경험 vs 보안 균형 |
| Absolute Timeout | **최대 8시간** | 세션 고정 공격 방지 (OWASP) |

### 필수 Claims 설정

```json
{
  "iat": 1712600000,   // Issued At — 발급 시각
  "exp": 1712601800,   // Expiration — 만료 시각 (iat + 30분)
  "nbf": 1712600000    // Not Before — 이 시각 이전 사용 불가
}
```

### Cookie와의 동기화

- **Cookie의 `Max-Age` 또는 `Expires`는 반드시 JWT `exp` 이하**로 설정
- Cookie가 JWT보다 오래 살면, 만료된 JWT가 전송되어 불필요한 요청 발생
- 이상적: `Cookie Max-Age = JWT exp - 현재 시각`

### Refresh Token Rotation

- Refresh Token 사용 시마다 새 Refresh Token 발급 (1회용)
- 이전 Refresh Token은 즉시 무효화
- **Reuse Detection**: 이미 사용된 Refresh Token이 다시 제출되면, 해당 사용자의 모든 Refresh Token 무효화 (탈취 징후)

---

## 4. 토큰 저장소 (Token Storage)

### 저장 방식별 위험도

| 저장소 | 위험 | 설명 |
|--------|------|------|
| Cookie (`HttpOnly` 없음) | **매우 높음** | XSS로 `document.cookie` 탈취 + CSRF 자동 전송 |
| Cookie (`HttpOnly`) | **높음** | XSS 직접 탈취 불가, 그러나 CSRF 자동 전송 |
| `localStorage` | **높음** | XSS로 `localStorage.getItem()` 탈취, 영구 저장 |
| `sessionStorage` | **중간** | XSS 탈취 가능하나, 탭 종료 시 삭제 |
| JavaScript 클로저 | **낮음** | XSS로 직접 접근 어려움, 새로고침 시 삭제 |

### 권장 저장 순서

1. **`sessionStorage`** — 탭 단위 격리, 탭 종료 시 자동 삭제
2. **JavaScript 클로저** — 전역 접근 불가, 가장 안전하나 새로고침 시 재인증 필요
3. **`localStorage`** — 마지막 수단, 반드시 짧은 만료 시간과 병행

### 클로저 패턴으로 Token 캡슐화

```javascript
// 토큰을 클로저 내부에 캡슐화 — 외부에서 직접 접근 불가
const createTokenManager = () => {
  let _accessToken = null;

  return {
    setToken: (token) => { _accessToken = token; },
    getAuthHeader: () => _accessToken
      ? { Authorization: `Bearer ${_accessToken}` }
      : {},
    clearToken: () => { _accessToken = null; },
  };
};

const tokenManager = createTokenManager();

// 사용
tokenManager.setToken(response.accessToken);
fetch('/api/resource', { headers: tokenManager.getAuthHeader() });

// XSS 공격자가 tokenManager._accessToken 접근 시도 → undefined
```

**주의**: 클로저 패턴도 XSS가 `tokenManager.getAuthHeader()`를 호출할 수 있으면 토큰 노출 가능. **CSP(Content Security Policy)** 와 반드시 병행한다.

---

## 5. Token Sidejacking 방지

### 문제

Access Token이 네트워크 전송 중 탈취되거나, XSS로 추출되면 공격자가 다른 컨텍스트에서 재사용할 수 있다. 이를 **Token Sidejacking** 이라 한다.

### Fingerprint 기법 (OWASP 권장)

토큰을 특정 클라이언트에 바인딩하여, 탈취된 토큰의 재사용을 방지한다.

**동작 흐름:**

1. **로그인 시**: 서버가 50바이트 이상의 암호학적 난수(fingerprint) 생성
2. **Cookie 설정**: fingerprint 원본을 hardened cookie로 전송
   ```
   Set-Cookie: __Secure-Fgp=<fingerprint_raw>;
     SameSite=Strict; HttpOnly; Secure; Path=/
   ```
3. **JWT에 해시 저장**: fingerprint의 SHA-256 해시를 JWT claim에 포함
   ```json
   {
     "sub": "user123",
     "exp": 1712601800,
     "userFingerprint": "a4f2b8c1d3e5...sha256_hash"
   }
   ```
4. **요청 검증**: 서버는 Cookie의 fingerprint를 SHA-256 해시 → JWT의 `userFingerprint` claim과 비교

### Cookie 보안 속성 (필수)

| 속성 | 값 | 목적 |
|------|-----|------|
| `SameSite` | `Strict` | 크로스 사이트 요청 시 쿠키 미전송 |
| `HttpOnly` | `true` | JavaScript에서 쿠키 접근 차단 |
| `Secure` | `true` | HTTPS에서만 전송 |
| `__Secure-` 접두사 | 필수 | Secure 속성 강제 (브라우저 검증) |

### IP 기반 컨텍스트를 피할 것

- **GDPR 위반 위험**: IP 주소는 개인정보에 해당 (EU GDPR)
- **네트워크 전환**: 모바일 사용자는 Wi-Fi ↔ LTE 전환 시 IP 변경 → 세션 끊김
- **VPN/프록시**: 정상 사용자도 IP 변경 빈번

---

## 6. Claims 검증

### 필수 검증 Claims

| Claim | 이름 | 검증 내용 |
|-------|------|----------|
| `iss` | Issuer (발급자) | 신뢰할 수 있는 발급자 목록과 일치 여부 |
| `exp` | Expiration (만료) | 현재 시각 기준 만료 여부 (clock skew 허용: 최대 30초) |
| `nbf` | Not Before (시작) | 현재 시각이 `nbf` 이후인지 확인 |
| `sub` | Subject (사용자 ID) | 유효한 사용자 식별자인지 검증 |
| `aud` | Audience (대상) | 토큰이 현재 서비스를 대상으로 발급되었는지 |

### 검증 코드 예시

```php
// PHP (firebase/php-jwt) — 엄격한 검증
$decoded = JWT::decode($token, new Key($secret, 'HS256'));

// 필수 claims 존재 여부
if (!isset($decoded->iss, $decoded->exp, $decoded->sub, $decoded->aud)) {
    throw new InvalidTokenException('Missing required claims');
}

// 발급자 검증
if ($decoded->iss !== 'https://auth.example.com') {
    throw new InvalidTokenException('Invalid issuer');
}

// 대상 검증
if ($decoded->aud !== 'https://api.example.com') {
    throw new InvalidTokenException('Invalid audience');
}
```

### Custom Claims 검증

- 비즈니스 로직에 사용하는 custom claims(`role`, `permissions`, `tenant_id` 등)도 **서버 측에서 반드시 검증**
- 클라이언트가 보낸 JWT의 claims를 그대로 신뢰하지 않는다
- Custom claim 값의 허용 범위를 화이트리스트로 관리

```php
$allowedRoles = ['user', 'admin', 'moderator'];
if (!in_array($decoded->role, $allowedRoles, true)) {
    throw new InvalidTokenException('Invalid role claim');
}
```

---

## 7. 정보 공개 방지 (Information Disclosure Prevention)

### 문제

JWT payload는 **Base64URL 인코딩**일 뿐, **암호화가 아니다**. 누구나 디코딩하여 내용을 읽을 수 있다.

```bash
# JWT payload 디코딩 (누구나 가능)
echo "eyJzdWIiOiIxMjM0NTY3ODkwIn0" | base64 -d
# 결과: {"sub":"1234567890"}
```

### 민감 정보 포함 금지

JWT payload에 절대 포함하지 말 것:

- 비밀번호, 비밀번호 해시
- 세션 키, API 키
- 주민등록번호, 신용카드 번호
- 내부 데이터베이스 ID (auto-increment)
- 상세 권한 목록 (공격 표면 노출)

### JWE (JSON Web Encryption) 적용

민감 claims가 불가피한 경우, **JWE**로 payload를 암호화한다.

- **권장 알고리즘**: `A256GCM` (AES-256-GCM, AEAD)
- **키 래핑**: `RSA-OAEP-256` 또는 `A256KW`
- JWE 구조: `Header.EncryptedKey.IV.Ciphertext.Tag` (5파트)

```
// JWE Compact Serialization 예시
eyJhbGciOiJSU0EtT0FFUC0yNTYiLCJlbmMiOiJBMjU2R0NNIn0.
OKOawDo13gRp2ojaHV7LFpZcgV7T6DVZKTyKOMTYUmKoTCVJRgckCL9kiMT03JGe
ipsEdY3mx_etLbbWSrFr05kLzcSr4qKAq7YN7e9jwQRb23nfa6c9d-StnImGyFDbS
...
```

**원칙**: 서명(JWS)은 무결성, 암호화(JWE)는 기밀성. 둘 다 필요하면 Nested JWT (JWS → JWE 래핑) 사용.

---

## 8. 토큰 무효화 (Token Revocation)

### JWT 고유 문제

JWT는 **stateless**하므로, 발급 후 만료 시간(`exp`) 전까지 서버가 일방적으로 무효화할 수 없다. 이는 JWT의 구조적 한계이다.

### 무효화가 필요한 상황

- 사용자 로그아웃
- 비밀번호 변경
- 권한 변경 (관리자 → 일반 사용자)
- 계정 탈취 감지
- 관리자에 의한 강제 세션 종료

### Denylist 방식

1. JWT의 고유 식별자(`jti` claim)를 **SHA-256 해시**하여 DB(또는 Redis)에 저장
2. 모든 요청 시 토큰의 `jti` 해시가 denylist에 있는지 확인
3. denylist 엔트리는 해당 JWT의 `exp` 시각에 자동 만료 (TTL 설정)

```php
// Denylist 확인 예시
$jtiHash = hash('sha256', $decoded->jti);

if ($redis->exists("jwt:denylist:{$jtiHash}")) {
    throw new TokenRevokedException('Token has been revoked');
}

// 토큰 무효화 (로그아웃 시)
$ttl = $decoded->exp - time(); // 남은 만료 시간
if ($ttl > 0) {
    $redis->setex("jwt:denylist:{$jtiHash}", $ttl, '1');
}
```

### Fingerprint 기법과의 관계

- **Fingerprint가 제대로 구현**되면 (Section 5 참조), 탈취된 토큰은 fingerprint cookie 없이 사용 불가
- 따라서 **denylist의 필요성이 크게 감소**함
- 그러나 내부 위협(insider threat), 서버 측 로그아웃 강제 등의 시나리오에서는 denylist가 여전히 필요

### 성능 고려사항

| 저장소 | 조회 성능 | 적합 환경 |
|--------|----------|----------|
| Redis (SET + TTL) | O(1) | 대규모 트래픽, MSA |
| RDBMS (인덱스) | O(log n) | 소규모, 이미 DB 사용 중 |
| In-memory Map | O(1) | 단일 인스턴스, 개발 환경 |

---

## 9. XSS & CSRF 완화 (Mitigation)

### XSS 완화

JWT를 탈취하는 가장 흔한 경로는 **XSS(Cross-Site Scripting)** 이다.

| 대책 | 설명 |
|------|------|
| `sessionStorage` 사용 | `localStorage`보다 노출 범위 제한 (탭 단위) |
| **CSP 헤더** | `script-src 'self'` — 인라인 스크립트/외부 스크립트 차단 |
| 입력 검증 + 출력 인코딩 | 서버/클라이언트 양측에서 실행 |
| DOMPurify | 사용자 입력 HTML 삭제 |
| Subresource Integrity | CDN 스크립트 변조 감지 |

```
# CSP 헤더 예시
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'
```

### CSRF 완화

JWT를 Cookie에 저장하는 경우 CSRF 공격에 노출된다.

| 대책 | 설명 |
|------|------|
| `SameSite=Strict` | 크로스 사이트 요청 시 쿠키 미전송 |
| `Authorization` 헤더 사용 | Cookie 대신 `Bearer` 토큰으로 전송 — CSRF 면역 |
| CSRF 토큰 병행 | Cookie 저장 시 추가 방어 계층 |

**최선의 조합**: `sessionStorage` 저장 + `Authorization: Bearer` 헤더 전송 + CSP

이 조합은:
- **XSS**: sessionStorage(탭 격리) + CSP(스크립트 차단)로 방어
- **CSRF**: Cookie를 사용하지 않으므로 원천 면역

---

## 보안 체크리스트

| # | 항목 | 확인 |
|---|------|------|
| 1 | 알고리즘을 서버 측에서 **명시적으로 지정**하고 `none`을 허용하지 않는가? | [ ] |
| 2 | HMAC 시크릿이 **64자 이상 + CSPRNG**으로 생성되었는가? | [ ] |
| 3 | Access Token 만료가 **30분 이하**, Absolute Timeout이 **8시간 이하**인가? | [ ] |
| 4 | 토큰을 **`sessionStorage`** 또는 **클로저**에 저장하고, `localStorage` 장기 저장을 피하는가? | [ ] |
| 5 | **Fingerprint 기법**(hardened cookie + JWT SHA-256 해시)이 구현되었는가? | [ ] |
| 6 | 필수 claims(`iss`, `exp`, `nbf`, `sub`, `aud`)를 **모두 검증**하는가? | [ ] |
| 7 | JWT payload에 **민감 정보**(비밀번호, API 키, 개인정보)가 포함되지 않는가? | [ ] |
| 8 | 로그아웃/비밀번호 변경 시 **토큰 무효화**(denylist 또는 fingerprint 쿠키 삭제)가 동작하는가? | [ ] |
| 9 | **CSP 헤더**가 설정되고 인라인 스크립트가 차단되는가? | [ ] |
| 10 | Cookie 사용 시 **SameSite=Strict, HttpOnly, Secure** 속성이 모두 설정되는가? | [ ] |

---

## 참고 자료

- [OWASP JSON Web Token Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)
- [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)
- [RFC 7519 — JSON Web Token (JWT)](https://datatracker.ietf.org/doc/html/rfc7519)
- [RFC 7516 — JSON Web Encryption (JWE)](https://datatracker.ietf.org/doc/html/rfc7516)
