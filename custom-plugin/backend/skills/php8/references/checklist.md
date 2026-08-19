# Mental Dry-Run + 자가 검증 체크리스트

## Mental Dry-Run (코드 사전 검증, 필수)

코드 생성·수정 시, **실제 파일에 기록하기 전에** 다음 절차를 반드시 수행한다.

1. **1차 작성** — 응답(메모리) 상에서만 코드를 작성한다. 실제 파일에는 기록하지 않는다.
2. **1차 재검토** — 작성한 코드를 스킬 규칙·자가 검증 체크리스트 기준으로 검토한다.
3. **2차 재검토** — 엣지 케이스, 사이드 이펙트, 기존 코드와의 정합성을 추가 검토한다.
4. **파일 반영** — 2회 검토 후 문제가 없다고 판단될 경우에만 실제 파일에 기록한다.

> 검토 중 문제가 발견되면 메모리 상에서 수정 후 다시 1차 재검토부터 반복한다.

## 자가 검증 체크리스트

### 0. 모드 판별 (최우선)
- [ ] Legacy 수정인가, New 모듈 생성인가 판별했는가
- [ ] 판별 결과에 따라 아래 해당 체크리스트를 적용

### New 모드 체크리스트

#### 아키텍처
- [ ] 모듈 구조(`app/Modules/{BC}/`)로 파일이 배치되었는가
- [ ] Controller → Service → Repository 레이어 모두 존재
- [ ] Controller에 비즈니스 로직 없음
- [ ] Service에 HTTP/응답 로직 없음, DB 직접 접근 없음
- [ ] Repository에서만 DB 접근
- [ ] Model은 Repository에서만 사용

#### Entity/VO
- [ ] 도메인 규칙이 있는 경우 Entity/VO가 생성되었는가
- [ ] Entity/VO에 외부 의존성(DB, HTTP, Framework)이 없는가
- [ ] VO는 불변(`readonly`)이고 자체 유효성 검증이 있는가
- [ ] 공유 VO는 `Modules/Shared/ValueObjects/`에 배치했는가

#### 모듈 경계
- [ ] 모듈 간 직접 클래스 참조 없음 (Interface만 사용)
- [ ] 공개 Interface가 `Interfaces/`에 정의되었는가
- [ ] 공통 리소스(2+ 모듈 참조)는 `Modules/Shared/`에 배치했는가

#### DI
- [ ] `service()` 함수로 의존성을 주입받는가
- [ ] `new Service()`, `new Repository()`, `new Model()` 직접 호출이 없는가
- [ ] 모듈별 `Config/Services.php`에 바인딩이 등록되었는가

#### 데이터 접근
- [ ] Query Builder를 우선 사용했는가
- [ ] raw query 사용 시: Repository에서만 + named binding + 사유 주석이 있는가

#### 기타
- [ ] Controller의 catch에서 안전한 메시지만 반환하는가
- [ ] Unit 테스트 + Feature 테스트 모두 포함
- [ ] 모듈 Routes.php 제공
- [ ] API 명세서(`api-docs/{module}/{apiname}.md`)가 생성되었는가
- [ ] Swagger YAML(`api-docs/{module}/{apiname}.yaml`)이 생성/갱신되었는가
- [ ] `api-docs/README.md` 인덱스에 항목이 추가되었는가
- [ ] PSR-12 코딩 스타일 준수
- [ ] 모든 PHP 파일에 `declare(strict_types=1)` 선언
- [ ] 보안 검증 통과
- [ ] 에러 응답이 표준 에러 코드 체계를 따르는가
- [ ] `date()`, `time()` 사용 없이 `DateTimeImmutable`만 사용했는가

### Legacy 모드 체크리스트
- [ ] 기존 파일의 네이밍/DI/디렉토리 패턴을 유지했는가
- [ ] 변경으로 인한 사이드 이펙트를 확인했는가
- [ ] PSR-12 코딩 스타일 준수
- [ ] 신규/수정 PHP 파일에 `declare(strict_types=1)` 선언
- [ ] 보안 검증 통과
- [ ] 테스트 코드 갱신 (있는 경우)
