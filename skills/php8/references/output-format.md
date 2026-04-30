# 출력 형식

## New 모드 출력 순서

1. **API 설계 요약** — 모듈명(BC), 구현 내용 간략 설명
2. **Controller** — 전체 코드 + 파일 경로
3. **Service + Interface** — 전체 코드 + 파일 경로
4. **Repository + Interface** — 전체 코드 + 파일 경로
5. **Model** — 전체 코드 + 파일 경로
6. **Entity/VO** — 도메인 규칙이 있는 경우 (단순 CRUD는 생략 가능)
7. **모듈 DI 등록** (`Modules/{BC}/Config/Services.php`)
8. **테스트 코드** — Unit + Feature + 파일 경로
9. **모듈 Routes** — 라우트 파일 + 메인 로드 확인
10. **API 명세서** — `api-docs/{module}/{apiname}.md` 생성
11. **Swagger YAML** — `api-docs/{module}/{apiname}.yaml` 생성 (OpenAPI 3.0.3)
12. **추가 참고사항** — 마이그레이션 SQL, 모듈 간 의존 관계, 후속 권고

## Legacy 모드 출력 순서

1. **수정 요약** — 변경 대상 파일, 변경 내용
2. **변경 코드** — diff 또는 전체 코드 + 파일 경로
3. **사이드 이펙트 확인** — 영향받는 파일 목록
4. **테스트** — 갱신 필요한 테스트 (있는 경우)

## 에러 응답 표준

```json
{
  "status": "error",
  "error": {
    "code": "NOT_FOUND",
    "message": "요청하신 항목을 찾을 수 없습니다."
  }
}
```

```json
{
  "status": "error",
  "error": {
    "code": "INVALID_INPUT",
    "message": "입력값이 유효하지 않습니다.",
    "details": {
      "email": ["이메일 형식이 올바르지 않습니다."],
      "name": ["이름은 필수 항목입니다."]
    }
  }
}
```

**표준 에러 코드:** `references/api-response.md` 의 에러 코드 표(현상 서술형, suffix 없음) 참조. 모든 응답 본문에 동일 코드 사용.
