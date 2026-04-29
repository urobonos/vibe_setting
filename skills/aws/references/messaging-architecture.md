# 메시징 아키텍처 (SNS + SQS + Lambda)

| 구성 요소 | 역할 | 비고 |
|-----------|------|------|
| **SNS** | 이벤트 발행 (Pub) | 토픽별 도메인 이벤트 분류 |
| **SQS (FIFO)** | 이벤트 구독 (Sub) | 순서 보장, 중복 제거(deduplication) |
| **Lambda** | 이벤트 처리 | SQS 트리거, 배치 부분 실패 처리 |

- SNS → SQS → Lambda 파이프라인이 기본 패턴. **Why:** SNS 직접 Lambda 트리거는 재시도 정책이 제한적 — SQS 가 중간 버퍼 역할로 Visibility/maxReceiveCount/DLQ 정밀 제어 가능
- FIFO 큐 사용 시 `MessageGroupId` 로 순서 보장 범위 지정. **Why:** 단일 그룹 내에서만 순서 보장 — 그룹 키 설계로 처리량/순서 트레이드오프 조정
- DLQ(Dead Letter Queue) 필수 설정 — 3회 재시도 후 DLQ 이동. **Why:** 영구 실패 메시지가 큐를 점유하면 정상 메시지 처리 지연

## Outbox Pattern (Pub 단계 신뢰성 보장)

크로스 도메인 이벤트 발행 시 **DB 트랜잭션과 메시지 발행을 원자적으로 묶기 위해** Outbox 테이블을 경유한다.

> **Why:** 직접 `sns.publish()` 호출은 네트워크 실패/재시도 시 중복 발행 또는 유실 위험 — DB 트랜잭션은 커밋됐는데 publish 실패 시 이벤트 유실, publish 성공 후 트랜잭션 롤백 시 이벤트 누설(phantom event). Outbox 는 두 작업을 하나의 트랜잭션으로 묶어 원자성 보장.

| 단계 | 동작 |
|------|------|
| 1. Write | 비즈니스 트랜잭션 내에서 Outbox 테이블(`*_pub_log` 등)에 이벤트 row INSERT + 비즈니스 데이터 COMMIT |
| 2. Poll | Lambda/Cron 이 주기적으로 Outbox 에서 `status='pending'` row 조회 |
| 3. Publish | SNS/SQS 에 publish. 성공 시 `status='published'` UPDATE |
| 4. Retry | 실패 시 `retry_count++` 후 재시도. 최대 재시도 초과 시 `status='failed'` + DLQ 알림 |

Outbox 테이블 최소 스키마:

```sql
CREATE TABLE {project}_pub_log (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    topic VARCHAR(100) NOT NULL,
    payload JSON NOT NULL,
    status ENUM('pending','published','failed') NOT NULL DEFAULT 'pending',
    retry_count INT UNSIGNED NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    published_at DATETIME NULL,
    INDEX idx_status_created (status, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**규칙**:
- 비즈니스 데이터 INSERT/UPDATE 와 Outbox INSERT 는 **같은 DB 트랜잭션**. **Why:** 원자성 — 두 작업이 하나의 commit/rollback 단위
- 폴러 Lambda 는 단일 인스턴스 보장 (`ReservedConcurrentExecutions=1`) 또는 낙관적 잠금(`UPDATE ... WHERE status='pending' AND id=?`)으로 중복 publish 방지. **Why:** 다중 폴러가 동일 row 를 동시에 publish 하면 다운스트림에 중복 이벤트 전달
- SQS 메시지 ID 또는 `topic + payload_hash` 로 **소비자 측 멱등성** 병행 보장. **Why:** Pub 단계 신뢰성에도 SQS at-least-once 특성으로 소비자 측 중복 가능 — 양방향 방어 필요
- 구체 테이블명·토픽명 규약은 프로젝트 `CLAUDE.md` 참조
