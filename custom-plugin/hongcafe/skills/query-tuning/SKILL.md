---
name: query-tuning
description: >
  이미 느린 MySQL 쿼리를 실서버에서 진단·재작성·폐기 판단하는 실전 튜닝 스킬.
  mysql8(올바르게 쓰는 규칙)과 구분 — 본 스킬은 "느린 쿼리를 어떻게 진단하고 다시 쓰는가"의 판단이 핵심.
  5축: (1) 측정 우선 진단 워크플로우 (2) 인덱스가 안 먹는 진짜 이유 (3) 복합 인덱스 ESR 설계 (4) 재작성 패턴 (5) 안티패턴 카탈로그.
  철칙: 추정 금지·실서버 실행 검증 필수, EXPLAIN/EXPLAIN ANALYZE 가 0.5초 안에 안 뜨면 폐기·재설계.
  5.7(ANSI SQL·파생테이블 우회) vs 8.0(CTE·재귀·윈도우·EXPLAIN ANALYZE·hash join) 버전 분기 대응.
triggers:
  - "느린 쿼리"
  - "슬로우 쿼리"
  - "slow query"
  - "쿼리 튜닝"
  - "쿼리 진단"
  - "쿼리 재작성"
  - "쿼리 폐기"
  - "쿼리가 느려"
  - "쿼리 느림"
  - "인덱스 안 탐"
  - "인덱스 미적용"
  - "인덱스를 안 타"
  - "풀스캔"
  - "Full Table Scan"
  - "filesort"
  - "Using temporary"
  - "EXPLAIN ANALYZE"
  - "실행시간 개선"
  - "응답 느림"
  - "N+1"
  - "/query-tuning"
version: 1.0.0
user-invocable: true
depends_on: [mysql8, prod-debug, task-docs]
conflicts_with: []
min_claude_md_version: "4.0"
---

# MySQL Query Tuning Skill

이미 존재하는 **느린 쿼리를 실서버에서 진단하고, 재작성하거나 폐기 판정**하는 실전 튜닝 스킬.

> **[용도 경계 — mysql8 과의 분리]**
> - `mysql8` = 쿼리를 **처음부터 올바르게 쓰는 규칙** (SELECT 컬럼 명시·N+1 방지·ANSI 병기·utf8mb4·암호화·타임존).
> - 본 스킬 = 이미 느린 쿼리를 **진단·재작성·폐기 판단** (왜 느린가, 인덱스가 왜 안 먹나, 어떻게 다시 쓰나).
> - 새 쿼리 작성이면 mysql8, 느린 쿼리 개선이면 본 스킬. 둘 다 필요하면 병행.
>
> **[실행 주체]** Claude 본체 단독. 본 스킬은 진단·판단 도구다. 실서버 접속 경로는 `prod-debug` (SSM), 쓰기 규칙 SSOT 는 `mysql8` 을 재사용한다 — 중복 정의하지 않는다.

---

## 0. 철칙 (non-negotiable)

이 3가지는 튜닝의 전제 조건이다. 위반하면 나머지 절차가 전부 무의미하다.

### 0.1. 추정 금지 — 실서버 실행 검증 필수

쿼리가 빠른지 느린지는 **반드시 실제 SQL 서버에서 돌려서** 판단한다. "인덱스 있으니 빠를 것", "JOIN 이니 느릴 것" 같은 추정으로 결론 내지 않는다.

**Why:** 옵티마이저의 실제 선택은 데이터 분포·통계·버전에 따라 갈린다. 종이 위 추론은 옵티마이저가 인덱스를 버리는 케이스(§2)를 절대 못 잡는다. 돌려봐야만 보인다.

- 측정 환경: **dev / stg 에서 실행** (실데이터 또는 프로덕션 유사 볼륨). prod 직접 실행은 §3 Checkpoint — `prod-debug` 절차 경유, 사용자 승인 필수.
- 접속 경로를 새로 만들지 않는다. `prod-debug` (SSM) 또는 기존 DB 커넥션을 재사용한다.

### 0.2. 0.5초 폐기 게이트

**EXPLAIN 자체가 0.5초 안에 안 뜨면, 그 쿼리는 폐기하고 재설계한다.**

**Why:** plain `EXPLAIN` 은 실행 없이 플랜만 뽑으므로 보통 즉시 반환된다. 그런데도 0.5초를 넘긴다면 옵티마이저가 **플랜 생성 자체에 허덕이는 것** — 조인 순서 후보가 폭발했거나 파생테이블·서브쿼리가 과도하게 중첩된 것이다. 이건 복잡도 red flag 이지 튜닝 대상이 아니다. 쿼리 구조를 갈아엎어야 한다.

두 층 모두에 0.5초 게이트를 건다:

| 층 | 도구 | 0.5초 초과 시 의미 |
|----|------|-------------------|
| 플랜 생성 | `EXPLAIN` / `EXPLAIN FORMAT=TREE` | 쿼리 구조가 옵티마이저 한계 초과 → **폐기·재설계** |
| 실측 런타임 | `EXPLAIN ANALYZE` (8.0.18+) / 실제 실행 타이밍 (5.7) | 실행이 느림 → 인덱스·재작성으로 튜닝 시도, 안 되면 폐기 |

- **측정 함정 (필수 인지):** 0.5초 게이트는 **실서버 실데이터 볼륨** 기준이다. 빈 dev 테이블에서 잰 0.01초는 거짓 통과다.
- **cold cache 보정:** 첫 실행은 buffer pool 이 비어 느릴 수 있다. **2~3회 반복 실행 후 정상 상태(steady-state)** 수치로 판정한다.

### 0.3. 힌트로 덮지 않는다

`FORCE INDEX` / `USE INDEX` / `STRAIGHT_JOIN` 으로 증상을 덮지 않는다 (mysql8 §8 SSOT). 인덱스 설계와 쿼리 구조로 옵티마이저가 스스로 옳은 계획을 고르게 만든다. 힌트가 불가피하면 Checkpoint.

**Why:** 힌트는 작성 시점의 데이터 분포에 계획을 못 박는다. 통계가 바뀌면 옵티마이저가 고를 더 나은 계획을 힌트가 막아, 성능 악화의 근본 원인을 코드에 박제한다 — 6개월 뒤 데이터가 10배가 되면 그 힌트가 장애 원인이 된다.

---

## 1. 호출 방식

### 1.1. 자동 트리거

frontmatter `triggers` 매칭 시 호출. "이 쿼리 왜 느려", "인덱스를 안 타는데", "슬로우 쿼리 잡아줘", "풀스캔 뜬다" 등.

**트리거 안 됨 (mysql8 로):** "이 조회 쿼리 새로 짜줘", "테이블 설계", "마이그레이션 작성" — 신규 작성은 mysql8.

### 1.2. 슬래시 커맨드

```
/query-tuning {느린 쿼리 또는 파일 경로}
```

인자로 쿼리(또는 위치)를 받아 §4 진단 워크플로우를 실행한다.

---

## 2. 인덱스가 안 먹는 진짜 이유 (첫 질문)

느린 쿼리를 보면 "인덱스를 추가하자"가 아니라 **"왜 기존 인덱스를 옵티마이저가 버렸나"** 를 먼저 묻는다. 대부분 인덱스는 이미 있고, 쿼리가 그걸 못 쓰게 짜여 있다.

**Why:** 인덱스가 없어서가 아니라 **쿼리가 인덱스를 무효화**해서 느린 경우가 압도적이다. 원인을 안 짚고 인덱스만 추가하면, 쓰기 비용만 늘고 여전히 풀스캔인 중복 인덱스가 쌓인다.

| 증상 (EXPLAIN 신호) | 원인 | 처방 |
|---------------------|------|------|
| 인덱스 있는데 `type: ALL` | **컬럼에 함수 래핑** — `WHERE DATE(created_at)=...`, `WHERE SUBSTRING(code,1,3)=...` | 함수 제거·범위 조건 변환. `created_at >= :d: AND < :d+1:` |
| `key: NULL`, 조건은 인덱스 컬럼 | **암묵 타입 변환** — `WHERE phone = 01012345678` (phone=varchar, 값=int) | 값을 컬럼 타입에 맞춘다 (`'01012345678'`). 조인 컬럼은 **양쪽 타입·collation 일치** |
| `LIKE '%kw%'` 풀스캔 | **leading wildcard** — B-tree 는 앞부분부터만 탐색 | 접두 검색(`'kw%'`)으로 바꾸거나 FULLTEXT 인덱스 검토 |
| `OR` 조건에서 풀스캔 | 옵티마이저가 index_merge 를 포기 | 각 조건이 개별 인덱스면 **`UNION` 으로 분해** (각 브랜치가 인덱스 탐) |
| 복합 인덱스 일부만 사용 | **leftmost prefix 위반** — `INDEX(a,b,c)` 에 `WHERE b=..` 만 | 인덱스 컬럼 순서 재설계 (§3) 또는 선행 컬럼 조건 추가 |
| 인덱스 있는데 풀스캔 선택 | **낮은 선택도** — 조건이 테이블 대부분을 반환 (예: `status='active'` 가 90%) | 옵티마이저 판단이 맞음. 인덱스가 아니라 쿼리·요구사항을 재검토 |
| 범위 조건 뒤 컬럼 미사용 | `INDEX(a,b)` 에 `WHERE a > 10 AND b = 5` — **범위 뒤는 인덱스 탐색 중단** | 범위 컬럼을 인덱스 마지막에 (§3 ESR) |

**진단 순서:** `EXPLAIN` 의 `key` / `type` / `rows` 를 먼저 본다. `key: NULL` 또는 `type: ALL` 이면 위 표에서 원인을 짚는다. 인덱스 추가는 이 표를 다 훑고도 답이 없을 때의 마지막 수단이다.

---

## 3. 복합 인덱스 설계 — ESR 순서

인덱스를 새로 만들어야 한다면 컬럼 순서가 성능을 좌우한다. **ESR: Equality → Sort → Range.**

```
INDEX (등치조건 컬럼들, ORDER BY 컬럼, 범위조건 컬럼)
```

**Why 이 순서:**
- **Equality(등치, `=` `IN`) 먼저** — B-tree 에서 정확히 한 지점으로 좁힌다. 선행 컬럼일수록 탐색 범위가 준다.
- **Sort(`ORDER BY`) 다음** — 등치로 좁힌 뒤 인덱스 정렬 순서를 그대로 쓰면 **filesort 가 사라진다**.
- **Range(범위, `>` `<` `BETWEEN`) 마지막** — 범위 조건을 만나는 순간 그 뒤 인덱스 컬럼은 탐색에 못 쓴다. 그래서 맨 뒤에 둔다.

```sql
-- 쿼리
SELECT id, title FROM tb_post
WHERE board_id = 10           -- equality
  AND status = 'open'         -- equality
  AND created_at >= '2026-01-01'  -- range
ORDER BY created_at DESC
LIMIT 20;

-- ESR 인덱스: equality(board_id,status) → sort/range 겸용(created_at)
-- created_at 은 ORDER BY 이자 range 라 마지막에 두면 정렬+범위 동시 충족
CREATE INDEX idx_post_board_status_created
  ON tb_post (board_id, status, created_at);
```

**커버링 인덱스:** `SELECT` 하는 컬럼까지 인덱스에 포함되면 테이블 조회(random I/O)가 사라진다 — EXPLAIN 에 `Using index`. 자주 도는 좁은 쿼리에 강력하다.

**설계 시 트레이드오프 (mysql8 §7 Checkpoint 재사용):** 인덱스는 읽기를 살리고 쓰기(INSERT/UPDATE/DELETE)마다 B-tree 재정렬 비용을 더한다. 대용량 테이블 인덱스 추가는 **반드시 사용자 승인 후 적용** — 쓰기 영향·디스크 증가를 함께 보고한다. 카디널리티 낮은 컬럼(성별·플래그) 단독 인덱스는 효과 없으니 만들지 않는다.

---

## 4. 진단 워크플로우 (측정 없이 최적화 없음)

```
1. 느린 쿼리 확보    — slow query log / 사용자 제공 쿼리
2. EXPLAIN           — 플랜 확인 (0.5초 게이트 §0.2). key/type/rows/Extra 판독
3. EXPLAIN ANALYZE   — 실측 (8.0.18+). estimated vs actual rows 괴리 확인
   또는 실제 실행 타이밍 (5.7, 2~3회 steady-state)
4. driving table 특정 — 조인에서 가장 먼저 스캔되는 테이블, rows 가 폭발하는 지점
5. 병목 판정          — §2(인덱스 미적용) / filesort / temporary / 잘못된 조인 순서
6. 재작성 또는 인덱스 — §2·§3·§6 적용
7. 재측정             — before/after 실측 비교. 0.5초 게이트 재통과 확인
```

**EXPLAIN ANALYZE 판독 핵심:**
- `rows=100 (actual rows=50000)` 처럼 **추정과 실측이 크게 벌어지면** 옵티마이저가 오판한 것 — 통계(`ANALYZE TABLE`)가 낡았거나 상관관계를 못 읽은 것이다.
- `actual time` 이 큰 노드가 병목. `loops` × per-loop time 으로 실제 비용을 읽는다.
- `Using temporary` + `Using filesort` 동반이면 GROUP BY / ORDER BY 가 인덱스를 못 쓴 것 — §3 으로 정렬을 인덱스에 태운다.

**FORMAT=TREE (8.0):** 중첩 구조로 조인 순서·비용을 위에서 아래로 읽는다. 5.7 은 `EXPLAIN FORMAT=JSON` 으로 `cost_info` 를 본다 (TREE·ANALYZE 미지원).

---

## 5. 버전 분기 — 5.7 vs 8.0

**튜닝 전 대상 버전을 먼저 확정한다.** 쓸 수 있는 무기가 다르다.

| 축 | MySQL 5.7 | MySQL 8.0 |
|----|-----------|-----------|
| **재작성 중심** | 일반 ANSI SQL — 파생테이블·자기조인·UNION 우회 | CTE·재귀 CTE·윈도우 함수 정식 사용 |
| **CTE / 재귀** | 없음 → 파생 서브쿼리 / UNION 반복 | `WITH` / `WITH RECURSIVE` |
| **윈도우 함수** | 없음 → 상관 서브쿼리·변수(`@rn`) 우회 | `ROW_NUMBER() / RANK() OVER (...)` |
| **진단 도구** | `EXPLAIN FORMAT=JSON` + 실행 타이밍 | `EXPLAIN ANALYZE` (실측) + `FORMAT=TREE` |
| **조인 전략** | Nested Loop 만 | **Hash Join** (8.0.18+) — 인덱스 없는 등치 조인에 유리 |
| **파생테이블 최적화** | derived merge | derived merge + **condition pushdown** (8.0.22+) |
| **LATERAL** | 없음 | `JOIN LATERAL` 지원 |

**실전 함의:**
- 5.7 에서 "윈도우 함수로 순위 뽑자"는 불가 — 상관 서브쿼리나 사용자 변수로 우회하되, 사용자 변수는 평가 순서 미보장이라 8.0 이전에도 신중히.
- 8.0 은 인덱스 없는 대용량 등치 조인에서 **Hash Join 이 Nested Loop 보다 빠를 수 있다** — 억지로 인덱스 만들기 전에 EXPLAIN ANALYZE 로 확인.
- CTE(`WITH`)는 CI4 QB 미지원 — raw + named binding (mysql8 §"Raw 쿼리" SSOT).

---

## 6. 재작성 패턴

| 패턴 | Before (느림) | After (빠름) |
|------|---------------|--------------|
| **상관 서브쿼리 → JOIN** | `SELECT ..., (SELECT COUNT(*) FROM b WHERE b.a_id=a.id) FROM a` (행마다 재실행) | `LEFT JOIN (SELECT a_id, COUNT(*) c FROM b GROUP BY a_id) t ON ...` |
| **IN(서브쿼리) → EXISTS/JOIN** | `WHERE id IN (SELECT a_id FROM b WHERE ...)` (대용량 시 materialize) | `WHERE EXISTS (SELECT 1 FROM b WHERE b.a_id=a.id AND ...)` 또는 JOIN |
| **deep OFFSET → keyset(seek)** | `ORDER BY id LIMIT 20 OFFSET 100000` (앞 10만 행 스캔·폐기) | `WHERE id > :last_id: ORDER BY id LIMIT 20` (커서 위치부터) |
| **filesort 제거** | `ORDER BY created_at` 가 인덱스 밖 | 정렬 컬럼을 인덱스에 태운다 (§3 ESR) |
| **temp table 제거** | `GROUP BY` 가 인덱스 정렬을 못 씀 | GROUP BY 컬럼 선행 인덱스 |
| **`SELECT *` → 커버링** | 넓은 행 랜덤 I/O | 필요 컬럼만 + 커버링 인덱스 (`Using index`) |

**keyset 페이지네이션 (deep paging 의 정석):**
```sql
-- OFFSET 은 페이지가 깊어질수록 앞 행을 전부 읽고 버려 선형으로 느려진다.
-- 마지막으로 본 (정렬키, PK) 를 커서로 넘겨 그 지점부터 읽는다.
SELECT id, title, created_at FROM tb_post
WHERE (created_at, id) < (:last_created:, :last_id:)   -- 복합 커서
ORDER BY created_at DESC, id DESC
LIMIT 20;
-- 인덱스 (created_at, id) 위를 순차 탐색 → 페이지 깊이와 무관하게 일정
```

---

## 7. 안티패턴 카탈로그

| 안티패턴 | 왜 느린가 | 처방 |
|----------|-----------|------|
| **N+1** | 부모 N건 + 자식 N회 = RTT N배 누적 (mysql8 §3) | JOIN / IN 일괄 조회 |
| **거대 `IN (…)`** | 수천 개 리터럴 IN 은 파싱·플랜 비용 폭증 | 임시테이블 조인 또는 배치 분할 |
| **과인덱싱** | 인덱스마다 쓰기 재정렬 비용 — 5개 넘어가면 INSERT 가 배로 | 실제 쓰이는 인덱스만. `sys.schema_unused_indexes` 로 미사용 제거 |
| **`ORDER BY` + `LIMIT` 인덱스 불일치** | 정렬 못 태우면 전체 정렬 후 LIMIT — filesort | 정렬 컬럼을 인덱스에 (§3) |
| **`SELECT COUNT(*)` 대용량** | 전체 스캔 카운트 | 근사치 허용 시 `information_schema` 통계, 정확 필요 시 카운터 테이블 |
| **`DISTINCT` 남용** | 중복 제거 위해 temp table | JOIN 조건·GROUP BY 재설계로 중복 자체를 없앰 |
| **함수 기반 WHERE** | 인덱스 무효 (§2) | 범위 조건 변환 (8.0 은 함수형 인덱스도 검토) |
| **암묵 타입 변환** | 인덱스 무효 + 행마다 캐스팅 (§2) | 값·컬럼 타입 일치, 조인 컬럼 collation 통일 |

---

## 8. 출력 형식

진단 요청 시 아래 순서로 응답한다.

1. **원 쿼리 + 대상 버전** — 5.7 / 8.0 확정
2. **EXPLAIN 판독** — `key` / `type` / `rows` / `Extra`, 0.5초 게이트 통과 여부
3. **병목 특정** — §2·§7 중 어느 원인인지, driving table 어디인지
4. **재작성안** — §6 패턴 적용, 5.7/8.0 버전에 맞게
5. **인덱스 제안** — 필요 시 §3 ESR + Checkpoint (사용자 승인)
6. **before/after 실측** — EXPLAIN ANALYZE(또는 실행 타이밍) 수치 대조. 폐기면 폐기 사유

**산출물 문서 (다건·공유 대상일 때만):** `~/.claude/docs/{product}/output/analysis/{YYYY-MM-DD}-query-tuning-{slug}.md`. 단발 인라인 진단은 문서 불요 (Simplicity First). `{product}` 변환 = `hooks/lib/product-resolver.sh`.

---

## 9. 가드레일

- **prod 실행 = §3 Checkpoint:** 프로덕션 DB 직접 쿼리 실행은 비가역·외부 시스템 — `prod-debug` 절차 경유, 사용자 명시 승인. dev/stg 우선.
  **Why:** 튜닝 대상 쿼리는 정의상 무겁다. prod 에서 무심코 돌린 EXPLAIN ANALYZE(실제 실행)나 대용량 정렬이 buffer pool 을 밀어내고 락·복제 지연을 유발해, 진단하려던 성능 문제를 오히려 장애로 키운다.
- **인덱스 변경 = 사용자 승인:** `CREATE/DROP/ALTER INDEX` 는 제안만, 쓰기 영향·디스크 보고 후 승인 (mysql8 §7 SSOT).
- **DDL 은 온라인 여부 확인:** 대용량 테이블 인덱스 추가는 락·복제 지연을 유발할 수 있다 — `ALGORITHM=INPLACE` 가능 여부, `pt-online-schema-change` / `gh-ost` 필요 여부를 함께 판단. 실제 적용은 §3.
- **측정 없는 결론 금지 (§0.1):** "빠를 것"으로 끝내지 않는다. 실측 수치를 붙인다.
- **힌트 금지 (§0.3):** 구조·인덱스로 해결.

---

## 10. 자가 검증 체크리스트

진단 응답 작성 전 확인:
- [ ] 대상 MySQL 버전(5.7/8.0)을 확정했는가
- [ ] 실서버(dev/stg) 실데이터 볼륨에서 실측했는가 (추정 아님, §0.1)
- [ ] EXPLAIN 이 0.5초 안에 떴는가 — 아니면 폐기 판정했는가 (§0.2)
- [ ] cold cache 보정 위해 2~3회 steady-state 로 쟀는가
- [ ] `key: NULL` / `type: ALL` 원인을 §2 표에서 짚었는가 (인덱스 추가는 마지막 수단)
- [ ] 인덱스 제안 시 ESR 순서를 지켰는가 (§3)
- [ ] EXPLAIN ANALYZE 의 estimated vs actual rows 괴리를 확인했는가
- [ ] before/after 실측 수치를 대조했는가
- [ ] 인덱스 변경을 Checkpoint 로 보고했는가
- [ ] 힌트(`FORCE INDEX` 등)로 덮지 않았는가

---

## 11. 변경 기록

| 버전 | 날짜 | 변경 |
|------|------|------|
| 1.0.0 | 2026-07-23 | 최초 작성 — 진단 워크플로우 / 인덱스 미적용 원인 표 / ESR 인덱스 설계 / 재작성 패턴 / 안티패턴 카탈로그 / 5.7·8.0 버전 분기 / 실서버 실측·0.5초 폐기 게이트 |
