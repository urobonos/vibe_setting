# References Cache

공식 문서 발췌 캐시. 타당성 검토 시 WebFetch 대신 이 파일들을 Read하여 근거로 사용한다.

## 파일 목록

| 파일 | 출처 | 용도 |
|------|------|------|
| `aws-well-architected.md` | AWS Well-Architected Security Pillar | 5대 보안 원칙 |
| `ci4-filters.md` | CI4 공식 Filters 문서 | 필터 생성/등록/실행 순서 |
| `rfc-http.md` | RFC 9110 HTTP Semantics | 상태 코드/메서드 속성 |
| `rfc-cookies.md` | RFC 6265 HTTP Cookies | 쿠키 보안 속성 |

## security/ — 보안 지식베이스

| 파일 | 출처 | 용도 |
|------|------|------|
| `security/owasp-top10.md` | OWASP Top 10 2021 | A01~A10 위협 분류 |
| `security/owasp-api-security-top10.md` | OWASP API Security Top 10 2023 | API 보안 10대 위협 상세 |
| `security/owasp-asvs.md` | OWASP ASVS 5.0.0 | 애플리케이션 보안 검증 표준 (L1/L2/L3) |
| `security/owasp-csrf.md` | OWASP CSRF Prevention | CSRF 방어 방법 비교 |
| `security/owasp-headers.md` | OWASP HTTP Headers | 보안 헤더 권장값 |
| `security/cwe-top25.md` | CWE Top 25 2024 | 위험도 순위 + PHP/웹 관련성 태그 |
| `security/jwt-security-patterns.md` | OWASP JWT Cheat Sheet | JWT 보안 모범 사례 10개 영역 |
| `security/php-security.md` | PHP 공식 Security | 위험 함수/입력 처리/에러 설정 |
| `security/php-security-config.md` | OWASP PHP Config Cheat Sheet | php.ini 보안 설정 전체 |
| `security/ci4-security.md` | CI4 공식 Security | CSRF 설정/토큰 처리 |
| `security/mysql-hardening.md` | OWASP DB Security + CIS MySQL 8.0 | MySQL 보안 강화 가이드 |
| `security/aws-security-best-practices.md` | AWS Well-Architected Security Pillar | AWS 서비스별 보안 체크리스트 |

## 갱신 규칙

- 공식 문서 메이저 버전 변경 시 재 fetch
- 각 파일 상단의 `최종 갱신` 날짜 확인
- 미수록 근거가 필요하면 WebFetch 후 이 디렉토리에 추가
