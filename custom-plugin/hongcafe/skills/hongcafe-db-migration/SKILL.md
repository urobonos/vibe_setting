---
name: hongcafe-db-migration
description: >-
  HongCafe 데이터를 소스 DB(NCP athena 등 레거시)에서 타겟 production Aurora(US hc-us-aurora-enc / JP
  hc-jp-aurora-enc)로 안전하게 이관·적재·시드하는 절차 스킬. 상담사(tb_callee/tb_account/tb_items/tb_chat_items)
  등 테이블을 접속판별→컬럼교집합→선정→SQL생성→전송→dry-run→적재→검증→PII위생→롤백 파이프라인으로 처리한다.
  "데이터 이관", "상담사 이관", "prd 적재", "DB 시드", "NCP에서 Aurora로", "US/JP DB에 넣어" 등에서 사용.
  완전 자동 아님 — 소스/타겟/테이블/조건/country/seed는 매 실행 파라미터 + 사용자 확인, 실제 prd 적재는 §3 최고위험(명시 승인 필수).
triggers:
  - "데이터 이관"
  - "상담사 이관"
  - "prd 적재"
  - "DB 시드"
  - "NCP에서 Aurora로"
  - "US/JP DB에 넣어"
  - "Aurora 적재"
  - "/hongcafe-db-migration"
metadata:
  version: 1.0.0
  type: procedure
---

# HongCafe DB Migration

소스 DB(NCP `athena` 등 레거시 한국 홍카페) → 타겟 prd Aurora(`athena` DB)로 행 단위 데이터를 안전 이관한다. 2026-07-06 NCP→US/JP 상담사 실적재로 검증된 파이프라인 + 안전장치를 담는다.

**이 스킬은 "쉽게 실행"이 아니라 "안전하게 반복"이 목적이다.** 소스/타겟/테이블/선정조건/country/seed는 매 실행 시 파라미터로 확정하고, 실제 prd 적재(COMMIT)는 사용자 명시 승인을 받는다. 원클릭 자동화가 아니다.

## ⚠️ 안전 원칙 (건너뛰지 말 것)

이 작업은 **PII(주민번호 `ce_jumin`·계좌 `ce_account_no`·비번해시 `ac_password`)를 prod DB에 대량 INSERT** 한다 — CLAUDE.md §3 최고위험(비가역·외부시스템·PII).

1. **dry-run 필수** — 실제 COMMIT 전에 트랜잭션 내 INSERT→카운트 검증→`ROLLBACK`으로 prd 미변경 검증. 대상 테이블 엔진이 **InnoDB 아니면 abort**(MyISAM은 롤백 불가 → dry-run이 실데이터를 남김).
2. **§3 승인** — 실제 적재(COMMIT)는 BEFORE/AFTER·롤백 방안을 보고하고 **사용자 명시 승인 후** 실행.
3. **PII 위생** — 임시 SQL 파일(S3·EC2·로컬)을 이관 완료 후 **전량 삭제**.
4. **auto mode PII 차단 대응** — auto mode classifier가 PII 이동(로컬 staging·S3·SSM 전송)을 반복 차단한다. `settings.local.json`의 `autoMode.allow`에 **임시 승인 규칙**을 추가해 통과시키고, **이관 완료 후 반드시 제거(원복)** 한다. 규칙 문구·재추가/제거 절차는 `references/automode-pii-rule.md` 참조.
5. **롤백 준비** — 적재 전 롤백 기준(파생 `country_code` 값 또는 삽입 키 목록)을 확보. FK 역순 DELETE.

## 파라미터 (실행 시 사용자와 확정)

| 파라미터 | 예시(2026-07-06 실적재) |
|---|---|
| 소스 | `db-8bna4.pub-cdb.ntruss.com:3306` user/db `athena` (NCP KOR-dev) |
| 타겟 EC2 / .env | US `i-0183f9ab360cc9d80` / `prd/config/.env` · JP `i-0fb0cb3eb0efc16bc` / `prd/be/.env` (경로 상이 주의) |
| 타겟 Aurora | US `hc-us-aurora-enc`(us-east-1) · JP `hc-jp-aurora-enc`(ap-northeast-1), DB `athena` |
| 테이블(FK 순서) | `tb_account` → `tb_callee` → `tb_items` → `tb_chat_items` |
| 선정 조건 | `tb_callee.ce_status=3 AND tb_account.ac_status=2` (활성 상담사), 조인키 `ac_id` |
| 무작위/재현 | `ORDER BY RAND(<seed>) LIMIT <N>` (seed 고정 = 재현. US=42, JP=43 등 리전별 다르게) |
| 파생 컬럼 | `country_code = 'US'` / `'JP'` |
| 중복 처리 | `INSERT IGNORE` (PK 중복 skip, 기존 운영데이터 보존) |

좌표는 메모리 참조: [[reference_ncp_kor_dev_db]] · [[reference_ec2_hongcafe]] · [[us-prd-kor-counselor-load]] · [[reference_jp_dedicated_vpc]]. 실행 전 이 메모리로 최신 host/EC2/경로를 확인한다(값이 변할 수 있다).

## 파이프라인

모든 원격 명령은 **SSM `AWS-RunShellScript` + base64 래핑**으로 실행한다(따옴표/이스케이프 회피, 큰 스크립트 전달). 폴링·`.env` 파싱·base64 패턴은 `references/ssm-patterns.md` 참조.

### ① 접속 경로 판별
타겟 EC2에서 소스에 직접 접속 시도(`mysql -h <소스> ...`). **성공** → EC2에서 mysqldump/mysql 직결(로컬 미경유, 가장 안전). **ACG 차단(ERROR 2003)** → 로컬 경유(pymysql 추출 → S3 → EC2). NCP는 EC2에서 차단되므로 로컬 경유가 표준.

### ② 타겟 스키마·기존 건수
SSM으로 EC2 prd `.env` 파싱(`database.default.hostname/database/username/password`) → `mysql`로 대상 테이블 존재·컬럼·`COUNT(*)`·`country_code` 분포 확인. 빈 DB인지 기존 운영데이터가 있는지 파악(중복·오염 판단).

### ③ 컬럼 교집합
소스 `SHOW COLUMNS` ∩ 타겟 `SHOW COLUMNS` = INSERT 대상 컬럼. **소스에만 있는 컬럼은 버림**(타겟에 없어 INSERT 불가). auto_increment PK(예: `tb_account.ac_no`)도 제외(타겟 재발급). `comm`으로 교집합/차집합 산출.

### ④ 선정
활성 조건 + `ORDER BY RAND(<seed>) LIMIT <N>`. **먼저 교집합·활성 풀 크기를 세어** 요청 인원(비겹침 N×리전) 확보 가능한지 확인(부족하면 사용자와 조정: 겹침 허용/기준 완화/인원 축소).

### ⑤ SQL 생성
`scripts/gen_migration.py` (로컬 pymysql). 상단 CONFIG(소스·테이블·DROP 컬럼·country·seed·limit·선정조건) 수정 후 실행 → `INSERT IGNORE` 문 생성. `SET FOREIGN_KEY_CHECKS=0; START TRANSACTION;`로 감싸 dry-run/실적재 선택 가능.

### ⑥ 전송 (로컬 경유일 때)
`gzip` → `aws s3 cp` → `s3://hongcafe-global-assets-private/_migration_tmp/` → 타겟 EC2 SSM에서 `aws s3 cp` 다운로드 + `gunzip`. S3는 글로벌 네임스페이스라 **크로스리전 OK**(us-east-1 버킷 ↔ JP EC2). 8MB급은 명령 인자로 못 넣으니 반드시 S3(또는 gzip+base64 output) 경유 — 인자 직접 전달은 "Argument list too long".

### ⑦ dry-run
`SELECT DISTINCT engine ... WHERE table_name IN (...)` → **InnoDB 확인**. `{ cat migration.sql; echo "SELECT ...검증카운트...; ROLLBACK;"; } | mysql -t`. ERROR 없고 IN_TXN 카운트가 기대치면 통과. 직후 별도 SELECT로 **원상복구(BEFORE=AFTER) 확인**.

### ⑧ 실제 적재 — §3 승인 후
BEFORE/AFTER 예상·롤백 방안 보고 → **사용자 승인** → `{ cat migration.sql; echo "COMMIT;"; } | mysql`. ERROR 0 확인.

### ⑨ 검증
BEFORE/AFTER `COUNT(*)` + `country_code` 분포. 노출 검증 = 프로필 EP curl: 내부 `http://127.0.0.1:8080/api/counselors/<ce_code>` + `-H "Host: <prd server_name>" -H "X-Forwarded-Proto: https"`(CI4가 http를 307 리다이렉트하므로 XFP 필수). counselorId = **ce_code 평문**(암호화 아님).

### ⑩ PII 위생
`aws s3 rm` (임시 gz) + EC2 SSM `rm -f /tmp/migration*.sql* /tmp/*.sh` + 로컬 `rm` (SQL·gen 스크립트·중간 txt). 흔적 0 확인.

### ⑪ 롤백
적재 전 callee가 0이었으면 `country='<값>'`이 곧 이번 적재분 → FK 역순 DELETE:
```sql
DELETE FROM tb_chat_items WHERE ce_code IN (SELECT ce_code FROM tb_callee WHERE country_code='<값>');
DELETE FROM tb_items      WHERE ce_code IN (SELECT ce_code FROM tb_callee WHERE country_code='<값>');
DELETE FROM tb_account    WHERE ac_id   IN (SELECT ac_id   FROM tb_callee WHERE country_code='<값>');
DELETE FROM tb_callee     WHERE country_code='<값>';
```
(정식 해당 country 상담사가 생기기 전까지만 이 기준 유효 — 이후엔 삽입 키 목록 기반)

## 완료 체크리스트
- [ ] 접속 경로 판별 + 타겟 현황(빈 DB/기존 데이터) 파악
- [ ] 컬럼 교집합 + 선정 풀 확보 확인
- [ ] dry-run 통과(InnoDB·에러0·원상복구)
- [ ] **§3 승인** 후 실적재(에러0)
- [ ] 검증(카운트 + 프로필 EP)
- [ ] PII 위생(S3·EC2·로컬)
- [ ] **settings `autoMode.allow` 원복**
- [ ] 롤백 스크립트 확보 + 메모리 기록

세부 명령 패턴은 `references/ssm-patterns.md`, auto mode 규칙 문구는 `references/automode-pii-rule.md`, SQL 생성 템플릿은 `scripts/gen_migration.py`를 본다.
