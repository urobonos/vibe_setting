# RDS Proxy

## 역할

Lambda → Aurora MySQL 연결 시 **커넥션 풀 고갈(connection exhaustion)을 방지**하는 프록시 레이어.
Lambda 의 동시 실행 수가 급증해도 RDS Proxy 가 커넥션 풀을 관리하여 Aurora 에 대한 연결 수를 제한한다.

> **Why:** Lambda 는 동시 실행 수가 트래픽 따라 수백~수천으로 증가 — 각 컨테이너가 직접 Aurora 에 connect 하면 Aurora `max_connections` 한도를 초과해 신규 연결 거부 발생. RDS Proxy 가 중간에서 풀링하면 Aurora 연결 수는 제한된 채 Lambda 동시성은 그대로 유지.

## 설정 규칙

```
RDS Proxy 설정:
- Engine: MySQL
- IAM Authentication: 활성화 (Secrets Manager 연동)
- Idle Client Timeout: 1800초 (기본)
- Max Connections: Aurora 인스턴스 max_connections 의 80%
- Connection Borrow Timeout: 120초
```

> **Why (Max Connections 80%):** Aurora 가 자체 사용하는 연결(모니터링, 복제 등) 여유분 확보 — 100% 설정 시 Aurora 내부 작업이 연결 부족으로 실패 가능.

## Lambda 연결 패턴

```python
import pymysql
import os

# RDS Proxy 엔드포인트 사용 (Aurora 직접 엔드포인트 아님)
PROXY_ENDPOINT = os.environ['RDS_PROXY_ENDPOINT']
DB_NAME = os.environ['DB_NAME']

# IAM 인증 사용 시
import boto3
def get_auth_token():
    client = boto3.client('rds')
    return client.generate_db_auth_token(
        DBHostname=PROXY_ENDPOINT,
        Port=3306,
        DBUsername=os.environ['DB_USER'],
        Region=os.environ['AWS_REGION']
    )

connection = None

def get_connection():
    global connection
    if connection is None or not connection.open:
        connection = pymysql.connect(
            host=PROXY_ENDPOINT,
            user=os.environ['DB_USER'],
            password=get_auth_token(),  # IAM 인증 토큰
            database=DB_NAME,
            connect_timeout=5,
            ssl={'ssl': True}
        )
    return connection
```

## 핵심 규칙

- Lambda 에서 Aurora 는 RDS Proxy 를 경유한다. **Why:** 위 "역할" 참조 — 커넥션 풀 고갈 방지
- Aurora Writer/Reader 엔드포인트 대신 **Proxy 엔드포인트** 사용
- IAM 인증 활성화 시 **Secrets Manager 에 DB 자격 증명 저장** 필수. **Why:** IAM 토큰은 단기 유효 — 자격 증명 회전 시 코드 변경 없이 자동 반영
- 페일오버 시 RDS Proxy 가 자동으로 새 인스턴스로 라우팅 — 애플리케이션 레벨 재연결 로직 불필요. **Why:** 프록시가 DNS 갱신을 추상화 — Lambda 는 Proxy 엔드포인트만 알면 됨
- VPC 내 Lambda + RDS Proxy + Aurora 모두 **동일 VPC, 프라이빗 서브넷** 배치. **Why:** Aurora/Proxy 를 퍼블릭 서브넷에 두면 인터넷 노출 위험

## 자가 검증 체크리스트

- [ ] Lambda 가 Aurora 직접 엔드포인트 대신 Proxy 엔드포인트를 사용하는가
- [ ] IAM 인증이 활성화되어 있는가
- [ ] Secrets Manager 에 DB 자격 증명이 저장되어 있는가
- [ ] Max Connections 가 Aurora max_connections 의 80% 이하인가
- [ ] Lambda, RDS Proxy, Aurora 가 동일 VPC 프라이빗 서브넷에 있는가
