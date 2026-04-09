# MySQL Database Security Guide

> Source: OWASP Database Security Cheat Sheet + CIS MySQL 8.0 Benchmark

---

## 1. 네트워크 격리 (Network Isolation)

데이터베이스는 외부 네트워크에서 직접 접근할 수 없어야 한다.

### 1.1 localhost 바인딩

```ini
# my.cnf
[mysqld]
bind-address = 127.0.0.1
skip-networking = OFF
```

- `bind-address = 127.0.0.1`: 로컬 머신에서만 접속 허용
- 원격 접속이 필요한 경우 내부 IP만 바인딩 (`bind-address = 10.0.1.50`)
- `skip-networking = ON`으로 설정하면 TCP/IP 연결 자체를 비활성화 (소켓만 사용)

### 1.2 방화벽 규칙

```bash
# iptables: 애플리케이션 서버에서만 3306 허용
iptables -A INPUT -p tcp --dport 3306 -s 10.0.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 3306 -j DROP

# UFW
ufw allow from 10.0.1.0/24 to any port 3306
ufw deny 3306
```

### 1.3 DMZ 분리

```
Internet → [DMZ: Web/App Server] → [Internal: DB Server]
                                         ↑
                                    방화벽으로 분리
```

- 데이터베이스는 반드시 내부 네트워크(Private Subnet)에 배치
- 애플리케이션 서버만 DB 포트에 접근 가능하도록 방화벽 규칙 설정
- 관리 접근은 SSH 터널 또는 VPN을 통해서만 허용

---

## 2. 전송 계층 보안 (Transport Layer Security)

데이터베이스 연결 시 평문 전송을 차단하고 TLS 암호화를 강제한다.

### 2.1 TLS 설정

```ini
# my.cnf
[mysqld]
require_secure_transport = ON
tls_version = TLSv1.2,TLSv1.3

ssl_ca = /etc/mysql/ssl/ca-cert.pem
ssl_cert = /etc/mysql/ssl/server-cert.pem
ssl_key = /etc/mysql/ssl/server-key.pem
```

### 2.2 권장 Cipher Suite

```ini
# TLSv1.2
ssl_cipher = ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305

# TLSv1.3 (MySQL 8.0.16+)
tls_ciphersuites = TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256
```

| Cipher | 특성 |
|--------|------|
| AES-256-GCM | AEAD, 하드웨어 가속(AES-NI) 지원 |
| ChaCha20-Poly1305 | AEAD, AES-NI 미지원 환경에서 우수한 성능 |
| ECDHE | Forward Secrecy 보장 |

### 2.3 클라이언트 측 TLS 강제

```sql
-- 특정 사용자에게 TLS 필수화
ALTER USER 'app_user'@'10.0.1.%' REQUIRE SSL;

-- 클라이언트 인증서까지 요구 (mTLS)
ALTER USER 'admin_user'@'10.0.1.%'
  REQUIRE X509;
```

---

## 3. 인증 설정 (Authentication)

### 3.1 강력한 비밀번호 정책

```ini
# my.cnf
[mysqld]
# validate_password 컴포넌트 (MySQL 8.0+)
validate_password.policy = STRONG
validate_password.length = 14
validate_password.mixed_case_count = 1
validate_password.number_count = 1
validate_password.special_char_count = 1
```

```sql
-- validate_password 컴포넌트 설치
INSTALL COMPONENT 'file://component_validate_password';
```

### 3.2 인증 플러그인

```sql
-- caching_sha2_password (MySQL 8.0 기본값, 권장)
CREATE USER 'app_user'@'10.0.1.%'
  IDENTIFIED WITH caching_sha2_password
  BY 'StrongP@ssw0rd!2024';

-- 비밀번호 만료 정책
ALTER USER 'app_user'@'10.0.1.%'
  PASSWORD EXPIRE INTERVAL 90 DAY;

-- 로그인 실패 잠금
ALTER USER 'app_user'@'10.0.1.%'
  FAILED_LOGIN_ATTEMPTS 5
  PASSWORD_LOCK_TIME 2;
```

### 3.3 서비스별 단일 계정

| 서비스 | 계정 | 용도 |
|--------|------|------|
| Web Application | `app_readonly` | SELECT만 |
| API Backend | `app_writer` | SELECT, INSERT, UPDATE, DELETE |
| Batch/Cron | `batch_user` | 특정 테이블에 한정 |
| Migration | `migrate_user` | DDL 전용, 배포 시에만 활성화 |
| Monitoring | `monitor_user` | `PROCESS`, `REPLICATION CLIENT` |

### 3.4 정기 검토

```sql
-- 비밀번호 없는 계정 탐지
SELECT User, Host FROM mysql.user
WHERE authentication_string = '' OR authentication_string IS NULL;

-- 90일 이상 미사용 계정 확인 (Performance Schema)
SELECT user, host, last_seen
FROM performance_schema.host_cache
WHERE last_seen < NOW() - INTERVAL 90 DAY;

-- 불필요한 계정 잠금
ALTER USER 'old_user'@'%' ACCOUNT LOCK;
```

---

## 4. 자격증명 보안 (Credential Security)

데이터베이스 자격증명이 소스 코드나 저장소에 노출되면 전체 시스템이 위험해진다.

### 4.1 소스 코드 외부 관리

```bash
# 환경변수 방식
export DB_HOST=127.0.0.1
export DB_USER=app_writer
export DB_PASS=StrongP@ssw0rd!2024

# 또는 별도 설정 파일 (소스 코드 외부)
# /etc/app/db-credentials.ini (권한 0600)
```

### 4.2 파일 권한 제한

```bash
# 설정 파일 소유권 및 권한
chown root:www-data /etc/app/db-credentials.ini
chmod 0640 /etc/app/db-credentials.ini

# my.cnf 권한
chmod 0600 /etc/mysql/my.cnf
chown mysql:mysql /etc/mysql/my.cnf
```

### 4.3 저장소 미포함

```gitignore
# .gitignore
*.env
.env.*
db-credentials.*
**/secrets/
```

```bash
# 이미 커밋된 경우 히스토리에서 제거
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch .env' \
  --prune-empty --tag-name-filter cat -- --all
```

### 4.4 시크릿 관리 도구

| 도구 | 설명 |
|------|------|
| AWS Secrets Manager | 자동 로테이션, RDS 통합 |
| HashiCorp Vault | 동적 DB 자격증명 발급 |
| AWS Parameter Store | SecureString 타입으로 암호화 저장 |

---

## 5. 최소 권한 원칙 (Principle of Least Privilege)

### 5.1 기본 권한 설정

```sql
-- 애플리케이션 계정: DML만 허용
GRANT SELECT, INSERT, UPDATE, DELETE
  ON myapp.* TO 'app_writer'@'10.0.1.%';

-- 읽기 전용 계정
GRANT SELECT ON myapp.* TO 'app_readonly'@'10.0.1.%';

-- 불필요한 전역 권한 절대 금지
-- GRANT ALL PRIVILEGES ON *.* (사용 금지)
```

### 5.2 root 계정 미사용

```sql
-- root 원격 접속 차단
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
FLUSH PRIVILEGES;

-- 또는 root 계정명 변경
RENAME USER 'root'@'localhost' TO 'dba_admin'@'localhost';
```

### 5.3 세분화된 권한 제어

```sql
-- 테이블 수준 권한
GRANT SELECT ON myapp.orders TO 'report_user'@'10.0.1.%';

-- 컬럼 수준 권한 (민감 데이터 보호)
GRANT SELECT (id, name, email) ON myapp.users TO 'cs_user'@'10.0.1.%';
-- phone_number, ssn 등 민감 컬럼 제외

-- 행 수준 접근 제어 (MySQL 8.0 Views 활용)
CREATE VIEW myapp.my_orders AS
  SELECT * FROM myapp.orders
  WHERE tenant_id = SUBSTRING_INDEX(USER(), '@', 1);

GRANT SELECT ON myapp.my_orders TO 'tenant_user'@'10.0.1.%';
```

### 5.4 권한 감사

```sql
-- 모든 사용자 권한 조회
SELECT * FROM information_schema.USER_PRIVILEGES;
SELECT * FROM information_schema.SCHEMA_PRIVILEGES;
SELECT * FROM information_schema.TABLE_PRIVILEGES;
SELECT * FROM information_schema.COLUMN_PRIVILEGES;

-- 특정 사용자 권한 확인
SHOW GRANTS FOR 'app_writer'@'10.0.1.%';
```

---

## 6. 서버 강화 (Server Hardening)

### 6.1 mysql_secure_installation

설치 직후 반드시 실행하여 기본 보안 설정을 적용한다.

```bash
mysql_secure_installation
```

수행 항목:
- root 비밀번호 설정/변경
- 익명(anonymous) 사용자 제거
- root 원격 접속 차단
- `test` 데이터베이스 삭제
- 권한 테이블 리로드

### 6.2 FILE 권한 비활성화

```sql
-- FILE 권한은 서버 파일 시스템 읽기/쓰기가 가능하므로 반드시 회수
REVOKE FILE ON *.* FROM 'app_writer'@'10.0.1.%';

-- LOAD DATA LOCAL INFILE 비활성화
-- my.cnf
[mysqld]
local_infile = OFF
```

### 6.3 CIS Benchmarks 주요 항목

| CIS 항목 | 설정 | 설명 |
|-----------|------|------|
| 2.6 | `--skip-symbolic-links` | 심볼릭 링크 공격 방지 |
| 3.1 | `datadir` 전용 파티션 | 데이터 디렉토리 분리 |
| 3.4 | `log_bin` 전용 파티션 | 바이너리 로그 분리 |
| 4.2 | `sql_mode = STRICT_ALL_TABLES` | 엄격한 SQL 모드 |
| 4.3 | `log_error_verbosity = 2` | 충분한 에러 로깅 |
| 6.1 | `audit_log` 플러그인 | 감사 로그 활성화 |
| 6.2 | `general_log = OFF` | 일반 쿼리 로그 비활성화 (성능) |
| 7.1 | `default_password_lifetime = 90` | 비밀번호 만료 정책 |

### 6.4 불필요한 기능 비활성화

```ini
[mysqld]
# 심볼릭 링크 차단
symbolic-links = 0

# LOAD DATA LOCAL 차단
local_infile = OFF

# SHOW DATABASES 제한
skip-show-database

# 대화형 연결 타임아웃
interactive_timeout = 3600
wait_timeout = 600
```

---

## 7. 데이터 보호 (Data Protection)

### 7.1 정기 백업 + 암호화

```bash
# mysqldump 백업 + 암호화
mysqldump --single-transaction --routines --triggers \
  --all-databases | gzip | \
  openssl enc -aes-256-cbc -salt -pbkdf2 \
  -out /backup/mysql-$(date +%Y%m%d).sql.gz.enc

# XtraBackup (물리 백업, 대규모 DB 권장)
xtrabackup --backup --encrypt=AES256 \
  --encrypt-key-file=/etc/mysql/backup.key \
  --target-dir=/backup/full/
```

### 7.2 백업 검증

```bash
# 백업 복원 테스트 (정기적으로 수행)
openssl enc -d -aes-256-cbc -pbkdf2 \
  -in /backup/mysql-20240101.sql.gz.enc | \
  gunzip | mysql --defaults-file=/etc/mysql/restore.cnf

# 체크섬 검증
sha256sum /backup/mysql-*.sql.gz.enc > /backup/checksums.sha256
```

### 7.3 트랜잭션 로그 분리 디스크

```ini
[mysqld]
# 바이너리 로그를 데이터와 다른 디스크에 저장
log_bin = /var/log/mysql-binlog/mysql-bin
relay_log = /var/log/mysql-binlog/relay-bin

# Redo 로그 분리 (MySQL 8.0.30+)
innodb_log_group_home_dir = /var/log/mysql-redo/
```

**분리 이유:**
- 데이터 디스크 장애 시 트랜잭션 로그로 복구 가능
- I/O 경합 감소로 성능 향상
- 디스크 풀 방지 (로그가 데이터 디스크를 채우는 사고 예방)

### 7.4 저장 시 암호화 (Encryption at Rest)

```ini
[mysqld]
# InnoDB 테이블스페이스 암호화
early-plugin-load = keyring_file.so
keyring_file_data = /var/lib/mysql-keyring/keyring

innodb_undo_log_encrypt = ON
innodb_redo_log_encrypt = ON

# 개별 테이블 암호화
# CREATE TABLE sensitive_data (...) ENCRYPTION='Y';

# 기본 테이블 암호화 활성화
default_table_encryption = ON
```

---

## 8. RDS 특화 항목 (AWS 환경)

AWS RDS는 관리형 서비스로, 일부 OS 레벨 설정이 불가능한 대신 AWS 네이티브 보안 기능을 활용한다.

### 8.1 RDS Proxy 활용

```yaml
# RDS Proxy 이점
- 커넥션 풀링: Lambda 동시 실행 시 DB 연결 폭증 방지
- 장애 조치: 멀티 AZ 페일오버 시 연결 자동 전환
- IAM 인증 통합: 자격증명 직접 관리 불필요
- Secrets Manager 통합: 자격증명 자동 로테이션
```

```bash
# RDS Proxy 생성
aws rds create-db-proxy \
  --db-proxy-name myapp-proxy \
  --engine-family MYSQL \
  --auth '[{
    "AuthScheme": "SECRETS",
    "SecretArn": "arn:aws:secretsmanager:ap-northeast-2:123456789:secret:myapp/db",
    "IAMAuth": "REQUIRED"
  }]' \
  --role-arn arn:aws:iam::123456789:role/rds-proxy-role \
  --vpc-subnet-ids subnet-abc123 subnet-def456
```

### 8.2 IAM 인증 (IAM Database Authentication)

```sql
-- RDS에서 IAM 인증 사용자 생성
CREATE USER 'iam_user'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.* TO 'iam_user'@'%';
```

```python
# Python 연결 예시
import boto3

client = boto3.client('rds')
token = client.generate_db_auth_token(
    DBHostname='mydb.cluster-xxx.ap-northeast-2.rds.amazonaws.com',
    Port=3306,
    DBUsername='iam_user',
    Region='ap-northeast-2'
)
# token을 비밀번호로 사용하여 연결 (15분 유효)
```

**IAM 인증 이점:**
- 비밀번호를 코드/설정에 저장할 필요 없음
- IAM 정책으로 중앙 접근 제어
- CloudTrail에서 DB 접근 감사 가능
- 토큰 자동 만료 (15분)

### 8.3 자동 백업 + 스냅샷

```bash
# 자동 백업 활성화 (보존 기간 설정)
aws rds modify-db-instance \
  --db-instance-identifier mydb \
  --backup-retention-period 35 \
  --preferred-backup-window "03:00-04:00" \
  --apply-immediately

# 수동 스냅샷 생성 (주요 변경 전)
aws rds create-db-snapshot \
  --db-instance-identifier mydb \
  --db-snapshot-identifier mydb-pre-migration-20240101

# 스냅샷 다른 리전으로 복사 (재해 복구)
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier arn:aws:rds:ap-northeast-2:123456789:snapshot:mydb-snap \
  --target-db-snapshot-identifier mydb-snap-dr \
  --region ap-northeast-1
```

### 8.4 암호화 at rest (KMS)

```bash
# KMS 키로 암호화된 RDS 인스턴스 생성
aws rds create-db-instance \
  --db-instance-identifier mydb-encrypted \
  --storage-encrypted \
  --kms-key-id arn:aws:kms:ap-northeast-2:123456789:key/mrk-xxx \
  --engine mysql \
  --engine-version 8.0.36 \
  --db-instance-class db.r6g.large
```

**암호화 범위:**
- DB 인스턴스 스토리지
- 자동 백업
- Read Replica
- 스냅샷
- 로그 (Audit log, General log, Slow query log)

**주의:** 기존 비암호화 인스턴스는 직접 암호화 불가. 스냅샷 → 암호화된 스냅샷 복사 → 복원 절차 필요.

### 8.5 Security Group으로 접근 제어

```bash
# DB 전용 Security Group 생성
aws ec2 create-security-group \
  --group-name mydb-sg \
  --description "MySQL RDS access control" \
  --vpc-id vpc-xxx

# 애플리케이션 서버 SG에서만 3306 허용
aws ec2 authorize-security-group-ingress \
  --group-id sg-dbxxx \
  --protocol tcp \
  --port 3306 \
  --source-group sg-appxxx

# 퍼블릭 접근 차단
aws rds modify-db-instance \
  --db-instance-identifier mydb \
  --no-publicly-accessible \
  --apply-immediately
```

### 8.6 RDS 보안 체크리스트

```text
[x] 퍼블릭 접근 차단 (--no-publicly-accessible)
[x] Security Group: 앱 서버 SG에서만 3306 허용
[x] 스토리지 암호화 (KMS)
[x] 전송 암호화 (SSL/TLS 강제)
[x] IAM 인증 활성화
[x] Secrets Manager로 자격증명 관리
[x] 자동 백업 활성화 (보존 기간 >= 7일)
[x] 멀티 AZ 배포 (프로덕션)
[x] Enhanced Monitoring 활성화
[x] Performance Insights 활성화
[x] RDS Proxy 사용 (Lambda 환경)
[x] 파라미터 그룹: local_infile=OFF, require_secure_transport=ON
```

---

## 종합 보안 체크리스트

| 영역 | 항목 | 우선순위 |
|------|------|----------|
| 네트워크 | localhost 바인딩 또는 Private Subnet 배치 | Critical |
| 네트워크 | 방화벽/SG로 접근 IP 제한 | Critical |
| 전송 | TLSv1.2+ 강제 | Critical |
| 인증 | 강력한 비밀번호 정책 | Critical |
| 인증 | 서비스별 분리 계정 | High |
| 자격증명 | 소스 코드 외부 관리 | Critical |
| 자격증명 | Secrets Manager 또는 Vault 사용 | High |
| 권한 | 최소 권한 원칙 (DML Only) | Critical |
| 권한 | root 원격 접속 차단 | Critical |
| 서버 | mysql_secure_installation 실행 | Critical |
| 서버 | FILE 권한 / LOCAL INFILE 비활성화 | High |
| 데이터 | 정기 백업 + 암호화 | Critical |
| 데이터 | 트랜잭션 로그 분리 디스크 | High |
| 데이터 | Encryption at Rest | High |
| RDS | Security Group + 퍼블릭 차단 | Critical |
| RDS | IAM 인증 + Secrets Manager | High |
