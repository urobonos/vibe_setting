# Part C: MySQL 8.x 보안 체크리스트

**적용 시점:** 마이그레이션 파일 생성/수정, DB 스키마 변경, 쿼리 최적화 작업 시

| 기반 표준 | URL |
|----------|-----|
| CIS MySQL 8.0 Benchmark | https://www.cisecurity.org/benchmark/mysql |
| OWASP DB Security Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/Database_Security_Cheat_Sheet.html |
| OWASP SQL Injection Prevention | https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html |
| MySQL Security Guide | https://dev.mysql.com/doc/refman/8.0/en/security.html |

---

## C1. 계정 및 인증

- [ ] root 계정의 원격 접속이 비활성화되어 있는가
- [ ] 미사용 DB 계정이 즉시 삭제(DROP)되어 있는가 (MySQL Ref Manual)
- [ ] 애플리케이션별로 별도 DB 계정을 사용하고 있는가 (OWASP DB Security)
- [ ] DB 계정 비밀번호 만료 정책(password expiration)이 설정되어 있는가 (MySQL Ref Manual)
- [ ] `validate_password` 컴포넌트가 활성화되어 있는가 (MySQL Ref Manual)
- [ ] `caching_sha2_password` 인증 플러그인을 사용하는가 (mysql_native_password 미사용) (MySQL Ref Manual)
- [ ] 계정 잠금 정책(로그인 실패 시 잠금)이 설정되어 있는가 (MySQL Ref Manual)
- [ ] DB 계정 및 권한을 정기적으로 감사하고 있는가 (OWASP DB Security)

## C2. 권한 관리

- [ ] 앱 전용 DB 계정에 `GRANT ALL`이 아닌 최소 권한만 부여되어 있는가
- [ ] `FILE` 권한이 모든 사용자에게 비활성화되어 있는가 (OWASP DB Security)
- [ ] `GRANT OPTION`이 앱 계정에 부여되지 않았는가
- [ ] VIEW를 통해 테이블 직접 접근을 제한하고 있는가 (OWASP DB Security)
- [ ] ROLE 기반 권한 관리를 사용하고 있는가 (MySQL Ref Manual)
- [ ] 계정별 리소스 제한(max_queries_per_hour, max_connections_per_hour)이 설정되어 있는가 (MySQL Ref Manual)
- [ ] 애플리케이션 계정이 DBA/admin 권한 없이 운영되고 있는가 (OWASP SQLi Prevention)

## C3. 네트워크 및 연결

- [ ] SSL/TLS 연결이 강제되어 있는가 (require_secure_transport=ON)
- [ ] TLS 프로토콜 버전이 1.2 이상으로 제한되어 있는가 (MySQL Ref Manual)
- [ ] mysqld가 bind-address로 필요한 IP에만 바인딩되어 있는가 (OWASP DB Security)
- [ ] 방화벽 규칙으로 DB 포트(3306) 접근이 특정 호스트로 제한되어 있는가 (OWASP DB Security)
- [ ] DB 서버가 애플리케이션 서버와 별도 네트워크 세그먼트에 분리되어 있는가 (OWASP DB Security)
- [ ] Connection Control 플러그인(brute-force 방지)이 설치되어 있는가 (MySQL Ref Manual)
- [ ] SSL 인증서가 유효하고 만료되지 않았는가 (OWASP DB Security)

## C4. 서버 설정

- [ ] `local_infile`이 비활성화되어 있는가
- [ ] 프로덕션에서 `general_log`가 비활성화되어 있는가
- [ ] mysqld 프로세스가 전용 저권한 OS 사용자로 실행되고 있는가 (MySQL Ref Manual)
- [ ] 데이터/로그/설정 파일의 OS 파일 권한이 적절히 제한되어 있는가 (MySQL Ref Manual)
- [ ] 에러 로그에 비밀번호가 노출되지 않도록 설정되어 있는가 (MySQL Ref Manual)
- [ ] `mysql_secure_installation`이 실행되어 기본 보안 설정이 적용되었는가 (OWASP DB Security)
- [ ] 기본 test 데이터베이스가 삭제되어 있는가 (OWASP DB Security)

## C5. 마이그레이션 및 스키마

- [ ] 마이그레이션에 평문 비밀번호 저장 컬럼이 없는가
- [ ] 외래키 참조 컬럼에 인덱스가 존재하는가
- [ ] `TEXT`/`BLOB` 과다 사용(3개+)이 없는가
- [ ] 테이블/컬럼명 식별자가 사용자 입력으로 결정될 때 allowlist 검증을 수행하는가 (OWASP SQLi Prevention)

## C6. SQL 인젝션 방어 (애플리케이션 레벨)

- [ ] 모든 SQL 쿼리에서 Prepared Statement(바인드 변수)를 사용하는가 (OWASP SQLi Prevention)
- [ ] 동적 SQL 생성(문자열 연결) 패턴이 코드베이스에 존재하지 않는가 (OWASP SQLi Prevention)
- [ ] 사용자 입력을 쿼리 전달 전 타입 변환/검증을 수행하는가 (OWASP SQLi Prevention)

## C7. 백업 및 복구

- [ ] 백업 파일이 암호화되고 접근 권한이 제한되어 있는가 (MySQL Ref Manual)
- [ ] 트랜잭션 로그가 DB 데이터 파일과 별도 디스크에 저장되어 있는가 (OWASP DB Security)
- [ ] 백업 복구 절차가 검증(테스트)되어 있는가 (MySQL Ref Manual)

## C8. 감사 및 모니터링

- [ ] Enterprise Audit 또는 동등한 감사 로그가 활성화되어 있는가 (MySQL Ref Manual)
- [ ] SQL 기반 계정 활동 감사가 구현되어 있는가 (MySQL Ref Manual)

## C9. 암호화 및 키 관리

- [ ] Keyring 컴포넌트를 통한 키 관리가 구성되어 있는가 (저장 데이터 암호화) (MySQL Ref Manual)
- [ ] DB 자격증명이 소스코드에 커밋되지 않고 웹루트 밖에 저장되어 있는가 (OWASP DB Security)

## C10. 기타 하드닝

- [ ] 보안 패치 및 마이너 업데이트가 적시에 적용되고 있는가 (OWASP DB Security)
- [ ] 개발/UAT/운영 환경별로 분리된 DB 계정이 사용되는가 (OWASP DB Security)
- [ ] SELinux/AppArmor 정책이 mysqld에 적용되어 있는가 (Linux 환경) (MySQL Ref Manual)
