---
name: mysql8
description: >
  MySQL 8.x 환경에서 쿼리 작성, 최적화, 스키마 설계를 수행하는 스킬.
  표준 ANSI SQL을 우선하며, N+1 문제 방지, Full Scan 지양, 실행계획(EXPLAIN FORMAT=TREE) 검증을 필수로 수행한다.
  인덱스 추가/수정은 반드시 사용자 승인 후 적용. 쿼리 힌트 사용 금지.
  타 DB 이관 가능성을 항상 고려하여 MySQL 전용 구문 사용 시 ANSI 대안을 병기한다.
triggers:
  - "쿼리 작성"
  - "쿼리 최적화"
  - "SQL 작성"
  - "스키마 설계"
  - "테이블 설계"
  - "마이그레이션 작성"
  - "인덱스 추가"
  - "인덱스 설계"
  - "실행계획 분석"
  - "EXPLAIN"
  - "app/Database/Migrations"
  - "/mysql8"
version: 1.0.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# MySQL 8.x Query & Schema Skill

MySQL 8.x 환경에서 **표준 ANSI SQL 기반**으로 쿼리 작성, 최적화, 스키마 설계를 수행하는 스킬.

---

## 핵심 원칙

### 1. 표준 ANSI SQL 우선

- MySQL 전용 구문(`IFNULL`, `LIMIT ... OFFSET`, `GROUP_CONCAT` 등) 사용 시 **ANSI 대안 쿼리를 반드시 병기**한다.
**Why:** 타 DB 이관 시 MySQL 전용 함수는 문법 에러로 즉시 실패하며, ANSI 대안 병기 없으면 마이그레이션 시 모든 쿼리를 재작성해야 한다.
- 타 DB(PostgreSQL, Oracle, SQL Server 등)로 이관 가능성을 항상 고려한다.

```sql
-- MySQL 전용
SELECT IFNULL(column_name, 'default') FROM table_name;

-- ANSI 표준 (병기 필수)
SELECT COALESCE(column_name, 'default') FROM table_name;
```

### 2. 필요한 컬럼만 SELECT

- **필요 컬럼만 명시**한다.
- 쿼리빌더 사용 시에도 사용하는 컬럼만 명시적으로 지정한다.

```php
// 금지
$builder->select('*')->get();

// 올바른 사용
$builder->select('id, name, email, created_at')->get();
```

### 3. N+1 문제 방지

- **JOIN/서브쿼리로 일괄 조회**한다.
**Why:** N건 부모 + 자식 N회 쿼리는 RTT 가 N+1 배 누적되어, 100건 리스트만으로 수십~수백 ms 지연·DB 커넥션 풀 고갈을 유발한다.
- 관련 데이터는 **JOIN** 또는 **서브쿼리**로 한 번에 조회한다.

```php
// 금지: N+1
$orders = $orderModel->findAll();
foreach ($orders as &$order) {
    $order['items'] = $itemModel->where('order_id', $order['id'])->findAll();
}

// 올바른 사용: JOIN
$builder = $db->table('orders');
$builder->select('orders.id, orders.total, order_items.product_name, order_items.quantity');
$builder->join('order_items', 'order_items.order_id = orders.id', 'left');
$result = $builder->get()->getResultArray();
```

### 4. Full Scan 지양

- 모든 주요 쿼리는 **실행계획을 검증**하여 Full Table Scan이 발생하지 않는지 확인한다.
- WHERE 절에 사용되는 컬럼은 인덱스 존재 여부를 확인한다.
- 함수로 감싼 컬럼 조건(`WHERE YEAR(created_at) = 2026`)은 인덱스를 무효화하므로 **범위 조건으로 변환**한다.
**Why:** 컬럼에 함수 적용 시 옵티마이저는 인덱스의 정렬 순서를 활용할 수 없어 풀스캔으로 폴백, 1000만 행 테이블에서 ms → 분 단위 응답 지연이 발생한다.

```sql
-- 금지: 인덱스 무효화
WHERE YEAR(created_at) = 2026

-- 올바른 사용: 범위 조건
WHERE created_at >= '2026-01-01' AND created_at < '2027-01-01'
```

### 5. 실행계획 확인

- MySQL 8.x에서는 **`EXPLAIN FORMAT=TREE`** 를 사용하여 실행계획을 확인한다.
- 실행계획에서 아래 항목이 발견되면 반드시 보고한다:
**Why:** Full scan·temporary·filesort 는 데이터 증가 시 선형 또는 초선형으로 응답시간이 악화되어, 출시 직후엔 멀쩡하다가 6개월 뒤 장애로 터지는 전형적 시한폭탄이다.
  - `Table scan` — Full Table Scan 발생
  - `Nested loop` 에서 inner table이 인덱스 없이 스캔되는 경우
  - `Using temporary`, `Using filesort` — 대량 데이터에서 성능 이슈 가능

```sql
EXPLAIN FORMAT=TREE
SELECT id, name, email
FROM users
WHERE status = 'active' AND created_at >= '2026-01-01';
```

### 6. CTE 사용 및 ANSI 대안 병기

- 임시테이블이 필요한 경우 **CTE(Common Table Expression)** 를 사용한다.
- CTE는 ANSI SQL:1999 표준이므로 대부분의 DB에서 호환되나, 호환되지 않는 DB를 위해 **서브쿼리 기반 ANSI 대안을 병기**한다.

```sql
-- CTE 버전 (MySQL 8.x, PostgreSQL, SQL Server 호환)
WITH active_users AS (
    SELECT id, name, email
    FROM users
    WHERE status = 'active'
)
SELECT active_users.name, COUNT(orders.id) AS order_count
FROM active_users
JOIN orders ON orders.user_id = active_users.id
GROUP BY active_users.name;

-- ANSI 서브쿼리 대안 (CTE 미지원 DB 대응)
SELECT sub.name, COUNT(orders.id) AS order_count
FROM (
    SELECT id, name, email
    FROM users
    WHERE status = 'active'
) AS sub
JOIN orders ON orders.user_id = sub.id
GROUP BY sub.name;
```

### 7. 인덱스 추가/수정 — 사용자 승인 필수 **[High]**

- 인덱스 추가, 수정, 삭제가 필요하다고 판단되면 **제안만 하고 사용자 승인 후 적용한다**.
**Why:** 인덱스는 읽기 성능을 높이는 대신 INSERT/UPDATE/DELETE 마다 B-tree 재정렬 비용을 누적시키며, 대용량 테이블에서 무단 추가는 쓰기 응답시간을 수배로 늘리고 디스크를 폭증시킨다.
- 반드시 아래 형식으로 보고 후 사용자 승인을 받는다:

```
[Checkpoint: 인덱스 변경 제안]
- 대상 테이블: {table_name}
- 제안 내용: {CREATE INDEX / DROP INDEX / ALTER 등}
- 사유: {Full Scan 방지, 쿼리 성능 개선 등}
- 예상 영향: {쓰기 성능 저하 가능성, 디스크 사용량 등}

사용자 승인을 기다립니다.
```

### 8. 쿼리 힌트 금지

- `FORCE INDEX`, `USE INDEX`, `STRAIGHT_JOIN` 등 쿼리 힌트는 **사용하지 않는다**.
**Why:** 힌트는 작성 시점의 데이터 분포에 고정되어, 통계가 바뀌면 옵티마이저의 더 나은 계획 선택을 막아 성능 악화의 근본 원인을 코드에 박제한다.
- 옵티마이저가 최적 실행계획을 선택하도록 인덱스 설계와 쿼리 구조로 해결한다.
- 힌트가 불가피하다고 판단되면 Checkpoint를 발동하여 사용자에게 보고한다.

### 9. 문자셋 — utf8mb4 통일

- 모든 테이블/컬럼의 문자셋은 **`utf8mb4`**, collation은 **`utf8mb4_unicode_ci`** 를 기본으로 한다.
**Why:** 레거시 `utf8`(=utf8mb3) 은 3바이트 한정이라 이모지·일부 한자·보조 평면 문자 입력 시 `Incorrect string value` 에러로 INSERT 실패, 데이터 유실이 발생한다.
- 레거시 `utf8`(=`utf8mb3`)은 상위 호환이므로 기존 데이터 문제는 없으나, **신규 테이블 생성 시 반드시 `utf8mb4`를 명시**한다.
- 기존 `utf8` 테이블은 마이그레이션 시 `ALTER TABLE ... CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`로 변환한다.

```sql
-- 신규 테이블 생성 시 필수
CREATE TABLE tb_example (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 기존 테이블 변환
ALTER TABLE tb_legacy CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 10. 암호화 함수 사용 시 세션 설정 **[Critical]**

MySQL `AES_ENCRYPT()` / `AES_DECRYPT()` 함수를 사용할 때는 세션 변수 `block_encryption_mode`를 **프로젝트 보안 정책에 맞춰 명시적으로 설정**한다. 기본값(MySQL 8.x: `aes-128-ecb`)에 의존하지 않는다 — ECB 모드는 동일 평문에 동일 암호문을 생성하여 패턴 노출 위험.

```sql
-- 프로젝트 보안 정책이 AES-256-CBC 인 경우
SET SESSION block_encryption_mode = 'aes-256-cbc';

-- 이후 암호화/복호화 호출 (named binding 필수)
INSERT INTO tb_sensitive (payload_enc)
VALUES (AES_ENCRYPT(:plaintext:, :key:, :iv:));
```

- **IV (Initialization Vector)** 필수. NULL IV 허용 금지
**Why:** ECB 모드 또는 NULL IV 는 동일 평문이 동일 암호문으로 매핑되어 패턴 분석으로 평문 추정이 가능, 사실상 암호화하지 않은 것과 같다.
- 키/IV는 `.env` 또는 Secrets Manager 에서 주입. 하드코딩 금지
**Why:** 키 하드코딩은 git 히스토리·바이너리 디컴파일·로그 유출 경로로 즉시 노출되어, 침해 시 키 회전이 불가능해 전체 데이터 재암호화로만 복구된다.
- 알고리즘 선택(CBC/GCM/ECB 등)은 프로젝트 `security-audit` 정책을 따른다
- 연결 풀링 환경(RDS Proxy 등)에서는 `SET SESSION` 이 다음 세션에 이어지지 않을 수 있으므로 암호화 쿼리마다 세션 변수를 재설정하거나 `init_connect` 에 등록

### 11. 연결 시 타임존 강제 (UTC 고정)

다국가 서비스에서는 DB 연결 세션에서 타임존을 UTC로 강제하여 서버 로컬 타임존에 의한 `NOW()`, `CURRENT_TIMESTAMP`, DATETIME 컬럼 해석 불일치를 방지한다.

```sql
-- 연결 직후 강제 (모든 애플리케이션 연결에 적용)
SET time_zone = '+00:00';
```

**설정 위치**:
- CI4: `app/Config/Database.php` 의 각 커넥션 설정에 초기 쿼리로 등록
- MySQL 서버: `my.cnf` → `default_time_zone = '+00:00'`
- RDS Parameter Group: `time_zone = UTC`
- Aurora MySQL: Parameter Group 에서 클러스터 레벨 설정 (가장 안전)

**검증**:

```sql
SELECT @@session.time_zone, @@global.time_zone, NOW(), UTC_TIMESTAMP();
-- @@session.time_zone 이 '+00:00' 또는 'UTC' 이고, NOW() === UTC_TIMESTAMP() 여야 한다
```

**주의**:
- 서버 `system_time_zone` 과 세션 `time_zone` 은 별개. 반드시 세션 레벨까지 UTC 고정 확인
**Why:** 서버·세션 타임존 불일치 시 `NOW()` 와 DATETIME 컬럼 해석이 어긋나 결제 시각·로그 타임스탬프가 9시간 비틀려, 다국가 정산·감사 추적이 무너진다.
- 상세는 `global-context` §6 "DB 타임존" 참조

---

## CI4 쿼리빌더 사용 시 적용 규칙

CI4 쿼리빌더를 사용할 때도 위 원칙을 동일하게 적용한다.

### CI4 QB 미지원 — Raw 쿼리 필수 기능

아래 MySQL 8.0 기능은 CI4 Query Builder로 빌드할 수 없으므로 `$db->query()`로 직접 작성한다.

| 기능 | 예시 |
|------|------|
| `WITH` (CTE) | `WITH cte AS (SELECT ...)` |
| Window Functions | `RANK() OVER (...)`, `ROW_NUMBER() OVER (...)` |
| `JSON_TABLE()` | `JSON_TABLE(col, '$.path' COLUMNS(...))` |
| `LATERAL JOIN` | `JOIN LATERAL (SELECT ...)` |

#### Raw 쿼리 사용 시 named binding 필수

QB 미지원 구문을 `$db->query()` 로 작성할 때는 **반드시 named binding (`:name:`)** 을 사용한다. 문자열 결합/보간은 SQL Injection 위험으로 금지.
**Why:** 문자열 보간은 사용자 입력의 따옴표·세미콜론을 그대로 SQL 에 합성해 인증 우회·데이터 덤프·테이블 드롭으로 이어지는 가장 대표적인 침해 경로다.

```php
// 금지: 문자열 결합/보간
$sql = "WITH ranked AS (SELECT * FROM tb_settlement WHERE status = '{$status}')";
$this->db->query($sql);

$sql = "SELECT * FROM tb_settlement WHERE id = " . $id;
$this->db->query($sql);

// 허용: named binding
$sql = 'WITH ranked AS (
            SELECT *, RANK() OVER (PARTITION BY counselor_id ORDER BY created_at DESC) AS rn
            FROM tb_settlement
            WHERE status = :status:
        )
        SELECT * FROM ranked WHERE rn = 1';
$this->db->query($sql, ['status' => $status]);
```

- named binding 은 Repository 레이어에서만 허용
- 바인딩 키는 `camelCase` 권장 (`:counselorId:`, `:startDate:`)
- 배열 바인딩 (`IN (...)`) 도 named binding 으로 처리 — 문자열 join 금지

```php
// 올바른 CI4 쿼리빌더 패턴
$builder = $db->table('users');
$builder->select('users.id, users.name, users.email, profiles.avatar_url');
$builder->join('profiles', 'profiles.user_id = users.id', 'left');
$builder->where('users.status', 'active');
$builder->where('users.created_at >=', '2026-01-01');
$builder->orderBy('users.created_at', 'DESC');
$builder->limit(20, 0);
$result = $builder->get()->getResultArray();
```

---

## 출력 형식

쿼리 관련 작업 시 아래 순서로 응답한다:

1. **요구사항 분석** — 어떤 데이터를 어떤 조건으로 조회/변경하는지
2. **쿼리 작성** — MySQL 8.x 쿼리 + ANSI 대안 (해당 시)
3. **실행계획 검증** — `EXPLAIN FORMAT=TREE` 결과 분석
4. **인덱스 제안** — 필요 시 Checkpoint 형식으로 보고
5. **CI4 코드** — 쿼리빌더 또는 raw 쿼리를 사용하는 PHP 코드 (해당 시)

---

## Mental Dry-Run (코드 사전 검증, 필수)

쿼리·스키마 코드 생성·수정 시, **실제 파일에 기록하기 전에** 다음 절차를 반드시 수행한다.
**Why:** 스키마 변경은 한번 운영 DB 에 반영되면 롤백 비용이 데이터 마이그레이션 수준으로 폭증하므로, 메모리 단계에서 사전 검증으로 잡는 비용이 실제 반영 후 잡는 비용보다 수십 배 저렴하다.

1. **1차 작성** — 응답(메모리) 상에서만 코드를 작성한다. 실제 파일에는 기록하지 않는다.
2. **1차 재검토** — 작성한 코드를 스킬 규칙·자가 검증 체크리스트 기준으로 검토한다.
3. **2차 재검토** — 엣지 케이스, 사이드 이펙트, 기존 코드와의 정합성을 추가 검토한다.
4. **파일 반영** — 2회 검토 후 문제가 없다고 판단될 경우에만 실제 파일에 기록한다.

> 검토 중 문제가 발견되면 메모리 상에서 수정 후 다시 1차 재검토부터 반복한다.

---

## 스키마 마이그레이션 SQL 관리

### 파일 경로 및 네이밍

- **경로**: `database/schema/`
- **네이밍**: `{항목코드}_{테이블명}_{변경유형}.sql`
  - 항목코드: 작업 식별자 (예: `D-04`, `D-06`, `D-08`)
  - 변경유형: `create` (신규 테이블), `alter` (컬럼/인덱스 추가·변경), `drop` (삭제)
- **예시**: `D-04_tb_account_agree_fields.sql`, `D-08_tb_refresh_token_create.sql`

### 분리 원칙

- **테이블 단위 1파일** — 하나의 SQL 파일에 여러 테이블 변경을 혼합하지 않는다.
- 동일 테이블의 ALTER + 데이터 마이그레이션(UPDATE)은 같은 파일에 포함 가능.

### 헤더 주석 표준

모든 스키마 SQL 파일 상단에 아래 형식의 헤더를 필수 포함한다:

```sql
-- =============================================================================
-- {항목코드}: {변경 요약} ({대상 테이블})
-- 근거: {법적 근거, RFC, CWE, 보안 요건 등}
-- 대상 DB: {DB명} ({엔진 버전})
-- 주의: 프로덕션 반영 전 반드시 스테이징에서 검증
-- =============================================================================
```

**Why:** 헤더 주석은 6개월 후 스키마 변경 이력 추적 시 항목코드·근거·대상 DB 를 즉시 식별 가능하게 해, 동일 컬럼 재추가·근거 없는 롤백 같은 사고를 방지한다.

### 반영 절차

1. `database/schema/`에 SQL 파일 작성
2. 스테이징 환경에서 실행 및 검증
3. 검증 완료 후 프로덕션 반영 (사용자 승인 필수)

---

## 자가 검증 체크리스트

쿼리 응답 작성 전 반드시 확인:
- [ ] SELECT * 사용하지 않았는가
- [ ] N+1 패턴이 존재하지 않는가
- [ ] WHERE 절 컬럼에 함수를 적용하지 않았는가
- [ ] MySQL 전용 구문 사용 시 ANSI 대안을 병기했는가
- [ ] 실행계획 확인 쿼리(`EXPLAIN FORMAT=TREE`)를 제공했는가
- [ ] Full Scan이 발생하지 않는 쿼리인가
- [ ] 인덱스 변경이 필요한 경우 Checkpoint로 보고했는가
- [ ] 쿼리 힌트를 사용하지 않았는가
- [ ] CTE 사용 시 서브쿼리 대안을 병기했는가
- [ ] 신규 테이블/컬럼에 `utf8mb4` charset을 명시했는가
