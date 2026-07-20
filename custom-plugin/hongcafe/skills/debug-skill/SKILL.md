---
name: debug-skill
description: >
  단일 레포 디버깅 표준 흐름 스킬. 증상 분류 → 로그 확보 → 가설 우선순위 → 재현 → 검증 → 수정 → 회귀 테스트 7단계.
  영역별 P0~P2 의심 매트릭스 (PHP/CI4 / Lambda / MySQL / SQS·SNS / 다국가) 와 표준 진단 도구를 제공한다.
  api-team 은 풀스택 영향분석 전용 — 단일 레포 디버깅에는 본 스킬을 호출한다.
  사용자가 "디버깅", "원인 분석", "왜 안 됨", HTTP 에러 코드, deadlock/timeout 등 구체 증상을 언급하면 즉시 호출한다.
triggers:
  - "디버깅 도와줘"
  - "디버깅 해줘"
  - "원인 분석"
  - "원인 찾아줘"
  - "왜 안 됨"
  - "왜 실패함"
  - "왜 안돼"
  - "원인 모르겠음"
  - "에러 원인"
  - "에러 분석"
  - "500 떠"
  - "401 떠"
  - "403 떠"
  - "404 떠"
  - "timeout 발생"
  - "deadlock 발생"
  - "lock timeout"
  - "Lambda 안 돌아감"
  - "메시지 안 옴"
  - "DLQ 쌓임"
  - "DLQ 폭증"
  - "slow query"
  - "쿼리 느림"
  - "특정 국가만 실패"
  - "특정 환경만 실패"
  - "/debug-skill"
version: 1.0.0
user-invocable: true
depends_on: [php8, aws, mysql8, security-audit]
conflicts_with: []
min_claude_md_version: "4.0"
---

# Debug Skill

단일 레포 디버깅 표준 흐름. **증상 → 가설 → 재현 → 검증 → 수정 → 회귀** 의 7단계로 진행한다.

> **[api-team 과 분담]** api-team 은 **풀스택 영향분석**(FE+BE+인프라 3-멤버 spawn) 전용. **단일 레포 디버깅**(이 스킬) 과 분담 명확. 분담 표는 §7 참조.

> **[전제]** 본 스킬은 사용자 환경(PHP 8.4 / CI 4.7 / Modular Monolith / AWS Lambda Python / Aurora MySQL 8 / SQS+SNS / 다국가) 특화. 다른 환경은 본 가이드 적용 전 검토 필요.

---

## 1. 표준 디버깅 흐름 (7단계)

| 단계 | 핵심 질문 | 도구 / 산출물 |
|------|-----------|--------------|
| **1. 증상 분류** | HTTP code? 영역? 재현 가능? | 영역 매핑 (§2 표) |
| **2. 로그 확보** | 가장 빠른 1차 진단 도구는? | 영역별 로그 (§3) |
| **3. 가설 우선순위** | P0/P1/P2 어디부터? | 의심 매트릭스 (§3) |
| **4. 재현 시나리오** | 최소 PoC 는? | curl / 단위 테스트 / SQL 단독 실행 |
| **5. 가설 검증** | 변수 1개씩 격리해 검증 | 단일 변경 + 입증/반증 |
| **6. 수정** | Mental Dry-Run 적용했나? | php8/aws/mysql8 의 사전 검증 절차 |
| **7. 회귀 테스트** | 같은 증상 재발 방지? | 단위/통합 테스트 추가 |

> **Why (7단계 고정):** 디버깅 시 가설을 자유롭게 수립하면 가설 폭발(여러 영역 동시 의심) → 검증 시간 분산. 7단계 고정은 가설 공간을 단계별로 좁혀 검증 비용 ↓.

---

## 2. 영역별 분기 가이드

증상에 따라 어느 영역의 P0~P2 매트릭스로 갈지 1차 분기:

| 증상 패턴 | 영역 | 1차 진단 도구 |
|-----------|------|---------------|
| API 500 / 401 / 403 / 404 | §3.1 PHP/CI4 | `error.log` + CloudWatch (도커 stdout) |
| Lambda Timeout / Memory / 503 | §3.2 Lambda | CloudWatch Logs Insights |
| Slow query / Deadlock / Lock timeout | §3.3 MySQL | `EXPLAIN` / `SHOW ENGINE INNODB STATUS` |
| SQS 메시지 미수신 / DLQ 폭증 | §3.4 SQS·SNS | DLQ 메시지 + Lambda 호출 로그 |
| 특정 국가만 실패 | §3.5 다국가 | 국가별 `.env` diff + `COUNTRY` 변수 |
| 풀스택 영향 (FE+BE+인프라) | **api-team 호출** | 본 스킬 적용 외 |

---

## 3. 영역별 P0~P2 의심 매트릭스

### 3.1. PHP/CI4 API

| 우선순위 | 의심 영역 | 검증 명령 / 확인 |
|---------|-----------|-----------------|
| **P0** | Filter 차단 (rate-limit / csrf / auth / role) | `error.log` 의 Filter 진입/응답 라인 grep — 어느 Filter 에서 응답 발생? |
| **P0** | 입력 검증 실패 (Validation) | Controller `validate()` 결과 / 422 응답 시 `errors` 필드 |
| **P1** | Service 예외 (비즈니스 로직) | Service 내 try-catch 미적용 → 예외 stack trace |
| **P1** | Repository 쿼리 실패 | `error.log` 의 SQL 실패 라인 + named binding 검토 |
| **P2** | 외부 의존성 (SMS / 결제 게이트웨이) | 외부 API 응답 logging |
| **P2** | 트랜잭션 롤백 | `$this->db->trans_status()` 결과 / Service 의 commit/rollback 위치 |

> **Why (Filter 가 P0):** php8 §Filter 패턴 — Filter 체인이 모든 요청 진입점. 401/403 의 80%+ 가 Filter 단계. Service/Repository 까지 안 갔는데 의심하면 시간 낭비.

**구체 명령:**
```bash
# error.log 최근 200줄 + 에러 키워드 grep
tail -200 writable/logs/log-$(date +%Y-%m-%d).php | grep -E 'ERROR|Exception|Fatal'

# Filter 진입 흔적
grep -E 'Filter|filter' writable/logs/log-*.php | tail -50
```

### 3.2. Lambda (Python)

| 우선순위 | 의심 영역 | 검증 명령 / 확인 |
|---------|-----------|-----------------|
| **P0** | 외부 호출 hang (DB / API) | CloudWatch Logs Insights — `duration` 필드 + handler 진입/응답 시각 |
| **P0** | IAM 권한 부재 | CloudWatch 의 `AccessDenied` / `not authorized` 메시지 |
| **P0** | 환경변수 누락 | handler 첫 줄 `os.environ.get(...)` 결과 None 검증 |
| **P1** | 콜드스타트 | duration > 임계값 + INIT_REPORT 로그 |
| **P1** | DB 연결 재사용 누락 | 모듈 레벨 connection 객체 vs 매 호출 재연결 |
| **P2** | 메모리 한계 | CloudWatch `Max Memory Used` 필드 |
| **P2** | DLQ 미설정 | Lambda dead letter queue 설정 확인 |

> **Why (P0 3개 동급):** Lambda 실패의 가장 흔한 3원인 — 외부 호출 / IAM / 환경변수. 어느 하나가 P0 인지는 증상에 따라 달라지므로 동급으로 둠.

**구체 명령 (CloudWatch Logs Insights):**
```
fields @timestamp, @message
| filter @message like /ERROR|Exception|AccessDenied|not authorized/
| sort @timestamp desc
| limit 50
```

### 3.3. MySQL 8 (Aurora)

| 우선순위 | 의심 영역 | 검증 명령 / 확인 |
|---------|-----------|-----------------|
| **P0** | index 미사용 (Slow query) | `EXPLAIN` 의 `key=NULL` / `Using filesort` / `Using temporary` |
| **P0** | N+1 쿼리 | 동일 패턴 반복 횟수 (응답 시간이 데이터 건수에 비례) |
| **P0** | Lock 대기 | `SHOW ENGINE INNODB STATUS` 의 `LATEST DETECTED DEADLOCK` |
| **P1** | Reader/Writer 잘못 라우팅 | 쓰기 작업이 Reader 엔드포인트 호출 → read-only 에러 |
| **P1** | 트랜잭션 범위 과다 | Service 의 `transStart()` ~ `transComplete()` 사이 외부 호출 포함 여부 |
| **P2** | 통계 outdated | `ANALYZE TABLE` 미실행 → optimizer 가 잘못된 plan 선택 |

> **Why (index P0):** mysql8 §쿼리 표준 — index 미사용 슬로우는 데이터 증가 시 즉각 악화. EXPLAIN 한 번이면 즉시 확인 가능.

**구체 명령:**
```sql
-- 의심 쿼리 EXPLAIN
EXPLAIN SELECT ... ;

-- 데드락 최근 1건
SHOW ENGINE INNODB STATUS \G  -- 'LATEST DETECTED DEADLOCK' 섹션

-- 슬로우 쿼리 (slow log 활성화 시)
SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 20;

-- Lock 대기 현황
SELECT * FROM performance_schema.data_locks_waits;
```

### 3.4. SQS / SNS / 메시징

| 우선순위 | 의심 영역 | 검증 명령 / 확인 |
|---------|-----------|-----------------|
| **P0** | DLQ 도달 (maxReceiveCount 초과) | DLQ 큐의 메시지 본문 + `ApproximateReceiveCount` |
| **P0** | `batchItemFailures` 미적용 | Lambda 응답에 `batchItemFailures` 필드 누락 → 전체 배치 재처리 |
| **P0** | Outbox 폴러 lock timeout | Outbox 테이블의 `status='pending'` row 가 처리 안 되고 쌓임 |
| **P1** | SNS 직접 호출 (재시도 제어 어려움) | Subject 미사용 + DLQ 미설정 시 재시도 정책 빈약 |
| **P1** | 멱등성 미보장 | 처리 완료 message_id 중복 처리 (INSERT 중복 / 중복 결제 등) |
| **P2** | Visibility Timeout 부족 | 처리 시간 > Timeout → 다른 소비자에게 재전달 → 중복 처리 |

> **Why (DLQ P0):** SQS 메시지 미수신/처리 실패의 가장 직접 증거 = DLQ. DLQ 메시지 본문이 원본 = 재현 시나리오 즉시 확보.

**구체 명령:**
```bash
# DLQ 메시지 1건 미리보기 (peek)
aws sqs receive-message --queue-url <DLQ_URL> --max-number-of-messages 1 --visibility-timeout 0

# Outbox 폴러 lock 상태
SELECT id, topic, status, retry_count, created_at FROM {project}_pub_log
 WHERE status='pending' AND created_at < NOW() - INTERVAL 5 MINUTE
 ORDER BY created_at LIMIT 20;
```

### 3.5. 다국가 환경

| 우선순위 | 의심 영역 | 검증 명령 / 확인 |
|---------|-----------|-----------------|
| **P0** | 국가별 `.env` 차이 | `diff deploy/us/.env deploy/kr/.env` |
| **P0** | `COUNTRY` 변수 누락 / 잘못 주입 | Lambda 환경변수 / EC2 .env 의 `COUNTRY` 값 |
| **P1** | 리전별 리소스 차이 | RDS Proxy / S3 / CloudFront 리전별 ID 일치 여부 |
| **P1** | 국가별 feature flag | `tb_feature_flags` 또는 `Services::country()` 분기 |
| **P2** | CloudFront 캐시 차이 | 국가별 distribution 의 cache invalidation 시점 |
| **P2** | 시간대 차이 | UTC 통일 원칙 위반 — 국가별 timezone 변환 누락 |

> **Why (.env diff P0):** 다국가 운영의 90%+ 환경 차이 = `.env`. 국가별 분기 코드는 동일하므로 환경 변수 차이만 잡으면 끝나는 경우 다수.

---

## 4. 가설 검증 패턴 — 변수 1개씩 격리

가설을 검증할 때는 **변수 1개씩만 변경**하여 입증/반증한다.

> **Why:** 동시에 여러 변수 변경 → 무엇이 원인인지 모름. 단일 변경은 결과 해석 명확.

**예시 (잘못된 검증):**
```
"timeout 의심 → connect_timeout 늘리고 + retry 횟수 늘리고 + 외부 API 캐시 추가"
→ 효과 있어도 어느 변경이 효과인지 불명
```

**올바른 검증:**
```
1. connect_timeout 만 늘리기 → 효과 없으면 timeout 가설 반증
2. 다음 가설로 이동 (retry 횟수 / 외부 API 캐시 등)
```

---

## 5. 재현 시나리오 작성 가이드

**최소 PoC** 원칙:
- 단일 호출/쿼리/메시지로 증상 재현
- 외부 의존성 최소화 (mock / 더미 데이터)
- 입증/반증 가능한 명확한 출력

**영역별 재현 형태:**
| 영역 | 최소 PoC 예시 |
|------|--------------|
| PHP/CI4 API | `curl -X POST <endpoint> -H ... -d ...` 단일 호출 |
| Lambda | 테스트 이벤트 JSON + Lambda console "Test" 또는 `aws lambda invoke` |
| MySQL | 문제 쿼리 단독 실행 + `EXPLAIN` |
| SQS/SNS | DLQ 메시지를 다시 큐에 enqueue → Lambda 재호출 |
| 다국가 | 국가별 .env 단일 변수 변경 + 동일 시나리오 |

---

## 6. 회귀 테스트 가이드

수정 후 같은 증상 재발 방지 — 단위/통합 테스트 추가.

| 영역 | 테스트 추가 위치 | 참조 |
|------|----------------|------|
| PHP/CI4 | `tests/Unit/Modules/{BC}/` 또는 `tests/Feature/` | php8 §테스트 |
| Lambda | `lambda/tests/unit/` 또는 통합 테스트 | aws 스킬 (lambda.md) |
| MySQL | Repository 단위 테스트 (실 DB 또는 fixture) | mysql8 §테스트 |
| SQS/SNS | Lambda 핸들러 단위 테스트 (event mock) | aws 스킬 (sqs.md, sns.md) |
| 다국가 | 국가별 시나리오 행렬 (parameterized test) | global-context §테스트 |

> **Why:** 수정만 하고 테스트 미추가 시 동일 증상 재발 가능 — 유닛 테스트는 회귀 방지의 표준 안전장치.

---

## 7. api-team 과의 분담

| 시나리오 | 호출 스킬 |
|---------|-----------|
| 단일 레포 (BE only / FE only / Lambda only) 디버깅 | **debug-skill** (이 스킬) |
| API 신규 추가 시 FE+BE+인프라 3-레포 영향 매핑 | **api-team add 모드** |
| 엔드포인트 오류 — FE/BE/인프라 어느 레포 원인인지 모름 | **api-team debug 모드** |
| 단일 레포 안에서 영역(Filter/Service/Repository) 어디 원인인지 모름 | **debug-skill** (이 스킬) |

> **판별 기준:** "어느 레포의 문제인가?" 가 명확하면 **debug-skill**. "어느 레포의 문제인지 모름" 또는 "여러 레포 영향" 이면 **api-team**.

---

## 8. 자가 검증 체크리스트

디버깅 작업 종료 전 반드시 확인:
- [ ] 가설을 단일 변경으로 입증/반증했는가
- [ ] 재현 시나리오는 최소 PoC 인가
- [ ] 수정 후 회귀 테스트 추가했는가
- [ ] Mental Dry-Run 적용 (php8/aws/mysql8 의 사전 검증 절차) 했는가
- [ ] 수정 영향 범위(같은 모듈/다른 모듈/외부 의존)를 검토했는가
- [ ] 다국가 영향 시 국가별 영향 검토했는가

---

## 9. 다른 스킬 참조

| 영역 | 위임 스킬 |
|------|----------|
| PHP/CI4 코드 작성 / Filter / DI | `php8` |
| Lambda 핸들러 / SQS/SNS / Aurora 연결 | `aws` 스킬 (lambda.md, sqs.md, sns.md, aurora.md) |
| SQL / 인덱스 / 트랜잭션 | `mysql8` |
| 다국가 환경 / Country Resolver | `global-context` |
| 보안 정책 / CSRF / JWT | `security-audit` (§7-x) |
| 풀스택 영향분석 | `api-team` |
