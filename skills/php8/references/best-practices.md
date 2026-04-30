# CI4 베스트 프랙티스 + e2e 검증

## CI4 베스트 프랙티스

- JSON 요청 바디: `$this->request->getJSON(true)` 사용
- 폼 데이터: `$this->request->getVar()` 사용
- API 컨트롤러에 `protected string $format = 'json';` 항상 설정
- **DI**: `service('{name}')` 함수로 Service/Repository 인스턴스를 가져온다
- **Model 생성**: Repository에서 `model(ClassName::class)` 헬퍼 사용
- **테스트 DI 오버라이드**: Mock을 생성자에 직접 주입하여 단위 테스트
- **활용 권장 PHP 8.x 기능**:
  - 8.0: Constructor Promotion, Named Arguments, Union Types, match 표현식
  - 8.1: Enums, readonly property, Fibers, Intersection Types
  - 8.2: readonly class, DNF Types
  - 8.3: Typed Constants, json_validate(), #[\Override]
  - 8.4: Property Hooks, new without parentheses, Asymmetric Visibility
- 소프트 딜리트: `$useSoftDeletes = true` + 스키마에 `deleted_at` 포함

## e2e 검증 (필수)

코드 수정 후 유닛 테스트 통과만으로 완료 판단 금지. 5점 체크 통과 전 머지/배포 금지. 글로벌 CLAUDE.md §4 "e2e 검증" 룰의 SSOT.

1. **env 의존성** — 새 env 변수 참조 시 `.env.example` 추가 + 서버 `.env` 존재 확인. **Why:** 누락 env 는 로컬 mock 으로 숨겨졌다 배포 후 500 으로 드러남.
2. **함수/클래스 호출 3점 체크** — 정의 존재 / `Config/Services.php` · autoload 등록 / 헬퍼 로딩 (`helper('name')`). **Why:** 호출 코드만으로 정의 보장 안 됨, 런타임 에러로만 드러남.
3. **DB INSERT 전 스키마 대조** — `NOT NULL` + `DEFAULT` 없는 컬럼 전수 확인. **Why:** 누락 컬럼은 INSERT 실패 → 500 직행.
4. **프로덕션 API 호출** — 배포 후 curl 로 실제 엔드포인트 200 확인. **Why:** 로컬 통과 ≠ 배포 환경 통과 (env / DI / autoload 차이).
5. **테스트 mock 경고** — mock 으로 대체한 함수/서비스가 실제 정의 존재하는지 grep 확인. **Why:** mock 통과는 의존성 부재를 숨겨 false negative 를 만든다.
