# Aurora MySQL

## Lambda 에서 Aurora 연결

```python
import pymysql
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# 모듈 레벨에서 연결 객체 생성 (Lambda 컨테이너 재사용 시 연결 재활용)
connection = None

def get_connection():
    """
    Aurora MySQL 연결을 반환한다.
    Lambda 컨테이너 재사용 시 기존 연결을 재활용한다.
    연결이 끊어진 경우 재생성한다.

    @return: pymysql 연결 객체
    """
    global connection

    if connection is not None:
        try:
            connection.ping(reconnect=True)
            return connection
        except Exception:
            logger.warning("DB connection lost, reconnecting...")
            connection = None

    connection = pymysql.connect(
        host=os.environ.get("DB_HOST"),          # Writer 또는 Reader 엔드포인트
        user=os.environ.get("DB_USER"),
        password=os.environ.get("DB_PASSWORD"),
        database=os.environ.get("DB_NAME"),
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=5,
        read_timeout=10,
        write_timeout=10,
        autocommit=False
    )

    return connection
```

> **Why (모듈 레벨 connection):** Lambda 는 컨테이너를 재사용 — 핸들러 함수 외부(모듈 레벨)에 둔 변수는 동일 컨테이너 호출 간 유지됨. 매 호출마다 connect() 하면 cold/warm 무관하게 연결 비용 발생.

## Aurora 엔드포인트 규칙

| 엔드포인트 | 용도 | Lambda 환경변수 |
|-----------|------|----------------|
| **Writer (클러스터 엔드포인트)** | INSERT, UPDATE, DELETE | `DB_HOST_WRITER` |
| **Reader (리더 엔드포인트)** | SELECT (읽기 전용) | `DB_HOST_READER` |

- 읽기 전용 Lambda 는 **Reader 엔드포인트** 사용. **Why:** Writer 인스턴스 부하 분리 — 읽기 트래픽이 Writer 로 몰리면 쓰기 지연 유발
- 쓰기 작업이 포함된 Lambda 는 **Writer 엔드포인트** 사용. **Why:** Reader 는 읽기 전용 복제본 — 쓰기 시도 시 read-only error
- Reader/Writer 엔드포인트를 하나의 환경변수로 통합하지 않는다. **Why:** 통합하면 함수별 트래픽 특성(읽기/쓰기) 가 환경변수만 봐서는 식별 불가 — 운영 시 Writer 부하 추적 어려움

## 페일오버 대응

```python
import pymysql

MAX_RETRY = 3

def execute_with_failover(query, params=None, is_write=False):
    """
    Aurora 페일오버 시 재연결 후 재시도한다.

    @param query: 실행할 SQL 쿼리
    @param params: 바인딩 파라미터
    @param is_write: 쓰기 작업 여부 (True 이면 Writer 엔드포인트)
    @return: 쿼리 결과
    """
    for attempt in range(MAX_RETRY):
        try:
            conn = get_connection()
            with conn.cursor() as cursor:
                cursor.execute(query, params)
                if is_write:
                    conn.commit()
                return cursor.fetchall()
        except pymysql.err.OperationalError as error:
            logger.warning(f"DB OperationalError (attempt {attempt + 1}/{MAX_RETRY}): {error}")
            global connection
            connection = None  # 연결 초기화하여 다음 시도 시 재연결
            if attempt == MAX_RETRY - 1:
                raise
```

> **Why (페일오버 재시도):** Aurora 페일오버 시 기존 연결은 끊어지지만 DNS 갱신까지 수십 초 소요 — 재시도 없이 단발 연결 시 페일오버 직후 모든 호출이 실패. RDS Proxy 사용 시 본 로직은 불필요(프록시가 라우팅 처리).

## hongcafe:mysql8 연동

Lambda 에서 Aurora 쿼리 작성 시에도 `hongcafe:mysql8` 의 규칙을 동일하게 적용한다:
- 표준 ANSI SQL 우선
- `SELECT *` 금지, 필요 컬럼만 명시
- N+1 방지
- 쿼리 힌트 지양
