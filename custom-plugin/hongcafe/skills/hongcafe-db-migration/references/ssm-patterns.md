# SSM 실행 패턴 (검증됨, 2026-07-06)

원격 EC2 명령은 SSM `AWS-RunShellScript`로 실행한다. `<R>`=리전, `<IID>`=인스턴스 ID.

## base64 래핑 (이스케이프·큰 스크립트)
```bash
SC=/tmp/x.sh
cat > $SC <<'SCRIPT'
#!/bin/bash
# EC2에서 실행할 내용 (로컬 확장 없이 그대로 전달됨)
SCRIPT
B64SC=$(base64 -w0 $SC)
CID=$(aws ssm send-command --region <R> --instance-ids <IID> --document-name AWS-RunShellScript \
  --parameters "commands=[\"echo $B64SC | base64 -d | bash\"]" --query Command.CommandId --output text)
```
- 소스 데이터(수천 ce_code 등)를 **명령 인자로 직접 넣지 말 것** → "Argument list too long". 큰 페이로드는 S3 또는 gzip+base64 stdout.

## 폴링
```bash
sleep 3
for i in $(seq 1 40); do
  ST=$(aws ssm get-command-invocation --region <R> --command-id "$CID" --instance-id <IID> --query Status --output text 2>/dev/null)
  case "$ST" in Success|Failed|Cancelled|TimedOut) break;; esac; sleep 2
done
aws ssm get-command-invocation --region <R> --command-id "$CID" --instance-id <IID> --query StandardOutputContent --output text
```

## CI4 .env 파싱
```bash
ENVF=/works/hongcafe-global/prd/config/.env   # US. JP는 prd/be/.env (경로 상이!)
clean(){ grep -iE "^ *$1 *=" "$ENVF" | head -1 | sed -E 's/^[^=]*= *//; s/[[:space:]]*$//'; }
DBHOST=$(clean 'database\.default\.hostname'); DBNAME=$(clean 'database\.default\.database')
DBUSER=$(clean 'database\.default\.username'); DBPASS=$(clean 'database\.default\.password')
run(){ mysql -N -h "$DBHOST" -u "$DBUSER" -p"$DBPASS" "$DBNAME" "$@" 2>/dev/null; }
```

## 큰 파일 전송 (로컬 → EC2)
```bash
gzip -kf migration.sql
aws s3 cp migration.sql.gz s3://hongcafe-global-assets-private/_migration_tmp/migration.sql.gz
# EC2 SSM 내부:
aws s3 cp s3://hongcafe-global-assets-private/_migration_tmp/migration.sql.gz /tmp/ && gunzip -kf /tmp/migration.sql.gz
```
- S3는 글로벌 네임스페이스 → **크로스리전 OK**(us-east-1 버킷 ↔ JP EC2). EC2 IAM `EC2-SSM-Profile`이 이 버킷 접근 가능(검증).
- 소량 결과 회수: `... | gzip -c | base64 -w0` → StandardOutputContent (약 24KB 제한 — 초과분은 잘림).

## dry-run / 실적재
```bash
# InnoDB 확인 (아니면 abort — 롤백 불가)
run -e "SELECT DISTINCT engine FROM information_schema.tables WHERE table_schema='$DBNAME' AND table_name IN ('tb_account','tb_callee','tb_items','tb_chat_items')"
# dry-run
{ cat /tmp/migration.sql; echo "SELECT (SELECT COUNT(*) FROM tb_callee) c; ROLLBACK;"; } | mysql -t -h "$DBHOST" -u "$DBUSER" -p"$DBPASS" "$DBNAME" 2>&1 | grep -iE "ERROR|[0-9]"
# 실적재 (§3 승인 후)
{ cat /tmp/migration.sql; echo "COMMIT;"; } | mysql -h "$DBHOST" -u "$DBUSER" -p"$DBPASS" "$DBNAME" 2>&1 | grep -i ERROR
```

## 프로필 EP 검증
```bash
curl -s -m10 -H "Host: <prd server_name>" -H "X-Forwarded-Proto: https" \
  "http://127.0.0.1:8080/api/counselors/<ce_code>"
```
- CI4가 http를 **307 리다이렉트**하므로 `X-Forwarded-Proto: https` 필수.
- counselorId = **ce_code 평문**(암호화 아님, `getDetail`이 trim 후 직접 조회).
- loopback 포트: prd 8080 / stg 8081 / dev 8082. server_name은 nginx conf(`server_name` 지시)에서 확인 — `_`(default) 말고 실제 도메인 사용.
