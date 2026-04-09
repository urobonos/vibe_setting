# OWASP CSRF Prevention

> 출처: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html
> 최종 갱신: 2026-04-08

## CSRF 방어 방법 비교

| 방법 | 상태관리 | 복잡도 | 적합 대상 |
|------|---------|--------|----------|
| Synchronizer Token | Stateful | 높음 | 전통적 웹앱 |
| Signed Double-Submit | Stateless | 중상 | 마이크로서비스, API |
| SameSite Cookie | N/A | 매우 낮음 | 모든 앱 (보조 수단) |
| Custom Request Header | N/A | 낮음 | AJAX/API |
| Fetch Metadata | N/A | 매우 낮음 | 모던 앱 |

## 핵심 원칙

1. **프레임워크 내장 CSRF 보호 우선 사용**
2. **다층 방어**: 최소 1가지 방법 + SameSite 병행
3. **GET으로 상태 변경 금지**: POST/PUT/PATCH/DELETE만
4. **XSS 먼저 방지**: XSS가 있으면 CSRF 방어 무력화
5. **토큰 생성**: CSPRNG(암호학적 보안 난수 생성기) 사용 필수

## SameSite Cookie 속성

| 값 | 동작 | 용도 |
|----|------|------|
| `Strict` | 크로스 사이트 요청 시 쿠키 미전송 | 고보안 앱 |
| `Lax` | 안전한 메서드(GET) + 최상위 네비게이션만 | 대부분 사이트 기본값 |
| `None` | 모든 요청에 전송 (Secure 필수) | 크로스 오리진 |

**주의: SameSite만으로는 CSRF 완전 방어 불가** — 보조 수단 (OWASP)

## CI4 프로젝트 적용

- **방식**: CI4 CSRF 필터 (Session-Based) — Synchronizer Token Pattern
- **SameSite=Strict**: 병행 적용
- **Cookie-Based CSRF 금지**: Same-site 공격 방어 불가 (CI4 공식 문서 경고)
- **설정**: `Config/Security.php` → `$csrfProtection = 'session'`
- **글로벌 필터**: `Config/Filters.php` → `$globals['before']`에 `'csrf'` 등록
- **이 프로젝트**: JWT를 HttpOnly 쿠키에 저장하므로 CSRF 필터 필수
