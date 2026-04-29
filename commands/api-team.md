API 추가/오류 시 FE+BE+인프라 3-멤버 병렬 영향 분석을 수행한다.

## 사용법

```
/api-team add {METHOD} {PATH} [요지]
/api-team debug {METHOD} {PATH} [에러 메시지]
```

**예시:**
- `/api-team add POST /v1/orders 주문 생성 API 추가`
- `/api-team debug GET /v1/orders/{id} 500 internal error`

## 인자 처리

1. **첫 번째 인자 = 모드**
   - `add` → 3-레포 반영 체크리스트 산출
   - `debug` → 3-레포 가설 우선순위 산출
   - 누락·오타 시 사용자에게 한 줄 확인 후 진행

2. **두 번째 인자 = HTTP METHOD**
   - GET / POST / PUT / DELETE / PATCH 등
   - 누락 시 사용자에게 확인

3. **세 번째 인자 = PATH**
   - `/v1/orders` 같은 엔드포인트
   - `{id}` 같은 path parameter 포함 가능

4. **나머지 인자 = 모드별 컨텍스트**
   - `add` 모드: 추가 요지 (페이로드/응답 한 줄 설명)
   - `debug` 모드: 에러 메시지/HTTP 상태/스택 발췌

## 수행 절차

`api-team` 스킬의 §4 작동 흐름을 그대로 따른다:

1. 입력 정규화 (METHOD, PATH, 모드별 컨텍스트)
2. PATH 슬러그 생성 → 산출물 파일명 사전 결정
3. 3명 병렬 Agent spawn (`run_in_background=true`, `model=opus`):
   - **FE 멤버** → `C:\Works\hongcafe_global_frontend`
   - **BE 멤버** → `C:\Works\hongcafe_global_backend`
   - **INF 멤버** → `C:\Works\infra` (폴더) + AWS CLI 실시간 조회
4. 모든 멤버 완료 대기 (자동 알림 — 사용자에게 폴링 노출 X)
5. 결과 종합 — 충돌·누락 탐지 후 가설 우선순위 재조정
6. 산출물 작성:
   ```
   ~/.claude/docs/claude-harness/output/api-impact/
     └─ {YYYY-MM-DD}-{slug}-{add|debug}.md
   ```
7. 사용자 보고 — 요약 3~5 줄 + 산출물 경로

## 멤버 spawn prompt

`api-team` 스킬 §6 의 FE/BE/INF 템플릿을 그대로 사용한다.

## 가드

- 산출물 경로는 `output/` (Gate-0 직행, gate-enforce.sh 면제)
- INF 멤버 AWS CLI: 조회계 즉시 실행, 변경계는 Lead 가 사용자 승인 후 직접
- BE 멤버 phpunit 실행 권고 시: phpunit-prd-guard 자동 적용 (prd DB 직결 차단)
- 인자 부족·모호 시 즉시 spawn 하지 않고 사용자 확인 우선
