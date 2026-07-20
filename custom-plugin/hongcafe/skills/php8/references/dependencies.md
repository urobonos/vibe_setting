# 의존성 관리 + 미적용 DDD

## 의존성 관리

- **Composer 버전**: 2.x
- **버전 고정 정책**: exact 또는 caret(`^`) 사용. `composer.lock` 파일 반드시 커밋
  **Why:** lock 미커밋 시 배포 환경마다 의존성 마이너 버전이 달라져 "내 로컬에선 되는데" 류 재현 불가 버그가 양산된다.
- **PSR-4 Autoload**: `App\` 단일 루트 매핑으로 `app/` 하위 전체 자동 해석

## 미적용 DDD 요소

아래 DDD 요소는 현재 프로젝트에서 **의도적으로 미적용**:

| 요소 | 미적용 사유 |
|------|-----------|
| Aggregate Root | CI4 Model/Entity 구조에서 Aggregate 경계 강제가 과도한 복잡성 유발 |
| CQRS | 단일 DB(Aurora MySQL) 사용, 읽기/쓰기 분리 불필요 |
| Event Sourcing | 이벤트 저장소 인프라 미구축, 현 규모에서 오버엔지니어링 |
| Domain Event Bus | 모듈 간 통신은 Interface 기반 동기 호출로 충분. 비동기 필요 시 SNS/SQS 사용 |
