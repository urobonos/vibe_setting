---
name: mysql8
description: >
  MySQL 8.x 환경에서 쿼리 작성, 최적화, 스키마 설계를 수행하는 스킬.
  표준 ANSI SQL을 우선하며, N+1 문제 방지, Full Scan 지양, 실행계획(EXPLAIN FORMAT=TREE) 검증을 필수로 수행한다.
  인덱스 추가/수정은 반드시 사용자 승인 후 적용. 쿼리 힌트 사용 금지.
  타 DB 이관 가능성을 항상 고려하여 MySQL 전용 구문 사용 시 ANSI 대안을 병기한다.
triggers:
  - "쿼리 작성", "쿼리 최적화", "SQL 작성"
  - "스키마 설계", "테이블 설계", "마이그레이션 작성"
  - "인덱스 추가", "인덱스 설계", "실행계획 분석"
  - MySQL/DB 관련 코드 작성/수정, 마이그레이션 파일(app/Database/Migrations/) 작업 시
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

```sql
-- 금지: 인덱스 무효화
WHERE YEAR(created_at) = 2026

-- 올바른 사용: 범위 조건
WHERE created_at >= '2026-01-01' AND created_at < '2027-01-01'
```

### 5. 실행계획 확인

- MySQL 8.x에서는 **`EXPLAIN FORMAT=TREE`** 를 사용하여 실행계획을 확인한다.
- 실행계획에서 아래 항목이 발견되면 반드시 보고한다:
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

### 7. 인덱스 추가/수정 — 사용자 승인 필수

- 인덱스 추가, 수정, 삭제가 필요하다고 판단되면 **제안만 하고 사용자 승인 후 적용한다**.
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
- 옵티마이저가 최적 실행계획을 선택하도록 인덱스 설계와 쿼리 구조로 해결한다.
- 힌트가 불가피하다고 판단되면 Checkpoint를 발동하여 사용자에게 보고한다.

### 9. 문자셋 — utf8mb4 통일

- 모든 테이블/컬럼의 문자셋은 **`utf8mb4`**, collation은 **`utf8mb4_unicode_ci`** 를 기본으로 한다.
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
