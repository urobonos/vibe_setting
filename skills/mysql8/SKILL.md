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
depends_on: []
conflicts_with: []
min_claude_md_version: "3.2"
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

- `SELECT *` 는 **절대 금지**한다.
- 쿼리빌더 사용 시에도 사용하는 컬럼만 명시적으로 지정한다.

```php
// 금지
$builder->select('*')->get();

// 올바른 사용
$builder->select('id, name, email, created_at')->get();
```

### 3. N+1 문제 방지

- 루프 안에서 쿼리를 실행하지 않는다.
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

- 인덱스 추가, 수정, 삭제가 필요하다고 판단되면 **제안만 하고 실행하지 않는다**.
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

---

## CI4 쿼리빌더 사용 시 적용 규칙

CI4 쿼리빌더를 사용할 때도 위 원칙을 동일하게 적용한다.

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
