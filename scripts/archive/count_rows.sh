#!/bin/bash
set -e
AURORA_HOST="prod-aurora-hongcafe-usa.cluster-ro-c47e2m0qmf7h.us-east-1.rds.amazonaws.com"
P=$(grep "database.default.password" /works/hongcafe-global/dev/config/.env | head -1 | cut -d= -f2 | tr -d " ")
printf "[client]\nuser=athena\npassword=%s\nssl-mode=REQUIRED\n" "$P" > /tmp/.my.cnf
chmod 600 /tmp/.my.cnf
MYCMD="mysql --defaults-file=/tmp/.my.cnf -h $AURORA_HOST athena -N -B"
$MYCMD -e "SELECT TABLE_NAME, TABLE_ROWS FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='athena' AND TABLE_ROWS > 0 ORDER BY TABLE_ROWS DESC"
rm -f /tmp/.my.cnf
