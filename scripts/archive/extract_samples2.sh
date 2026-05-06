#!/bin/bash
set -e
AURORA_HOST="prod-aurora-hongcafe-usa.cluster-ro-c47e2m0qmf7h.us-east-1.rds.amazonaws.com"
P=$(grep "database.default.password" /works/hongcafe-global/dev/config/.env | head -1 | cut -d= -f2 | tr -d " ")
printf "[client]\nuser=athena\npassword=%s\nssl-mode=REQUIRED\n" "$P" > /tmp/.my.cnf
chmod 600 /tmp/.my.cnf
MYCMD="mysql --defaults-file=/tmp/.my.cnf -h $AURORA_HOST athena -N -B"

OUT="/tmp/sample_rows.tsv"
> $OUT

for T in tb_account tb_account_history global_sync_sub_log; do
  COLS=$($MYCMD -e "SELECT GROUP_CONCAT(CONCAT('''', COLUMN_NAME, ''', IFNULL(CAST(\`', COLUMN_NAME, '\` AS CHAR), ''NULL'')') ORDER BY ORDINAL_POSITION) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='athena' AND TABLE_NAME='$T'")
  ROWS=$($MYCMD -e "SELECT JSON_OBJECT($COLS) FROM \`$T\` LIMIT 3" 2>/dev/null || echo "")
  IDX=0
  while IFS= read -r row; do
    if [ -n "$row" ]; then
      row=$(echo "$row" | sed -E 's/("(ac_password|password|token|secret|api_key|api_token)"\s*:\s*)"[^"]*"/\1"***"/g')
      printf "%s\t%s\t%s\n" "$T" "$IDX" "$row" >> $OUT
      IDX=$((IDX+1))
    fi
  done <<< "$ROWS"
  echo "$T: $IDX rows"
done

rm -f /tmp/.my.cnf
cat $OUT
