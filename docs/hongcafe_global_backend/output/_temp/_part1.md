# HTTP Status Code 현황 감사 보고서

- **작성일:** 2026.04.14
- **검증일:** 2026.04.14 (코드 전수 대조 검증 완료)
- **대상:** hongcafe_global_backend API 전체
- **브랜치:** dev/migration
- **기준:** RFC 9110 (HTTP Semantics), RFC 6585 (Additional HTTP Status Codes), CLAUDE.md API 응답 표준

---

## 1. 프로젝트 API 응답 표준 (CLAUDE.md 기준)

```
성공: { "data": {...} }                                        → HTTP 200/201
에러: { "error": { "code": "...", "message": "..." } }         → HTTP 4xx/5xx
```

- HTTP 상태코드가 성공/실패의 SSOT (Single Source of Truth)
- 에러 코드: 현상 서술형, suffix 없음 (INVALID_INPUT, NOT_FOUND, UNAUTHORIZED, FORBIDDEN, CONFLICT, INTERNAL)
