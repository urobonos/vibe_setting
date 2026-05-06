#!/usr/bin/env python3
"""Extract sample rows from local MySQL, insert into SQLite schema DB."""
import subprocess
import sqlite3
import json
import os
import re

MYSQL = "C:/laragon/bin/mysql/mysql-5.7.44-winx64/bin/mysql.exe"
DB_FILE = os.path.expanduser("~/.claude/docs/references/hongcafe-schema.db")

# Get table list from SQLite
conn = sqlite3.connect(DB_FILE)
c = conn.cursor()
tables = [r[0] for r in c.execute("SELECT DISTINCT table_name FROM columns ORDER BY table_name")]
print(f"Tables in SQLite: {len(tables)}")

# Sensitive columns to mask
SENSITIVE = re.compile(r'(ac_password|password|token|secret|api_key|api_token|encryption_key)', re.I)

c.execute("DELETE FROM sample_rows")

inserted = 0
skipped = 0

for tname in tables:
    # Get columns for JSON_OBJECT
    cols_result = subprocess.run(
        [MYSQL, "-h", "localhost", "-u", "athena", "-pVlvmf8383!!", "athena",
         "-N", "-B", "-e",
         f"SELECT GROUP_CONCAT(CONCAT('\\'', COLUMN_NAME, '\\'', ', IFNULL(CAST(`', COLUMN_NAME, '` AS CHAR), \\'NULL\\')') ORDER BY ORDINAL_POSITION) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='athena' AND TABLE_NAME='{tname}'"],
        capture_output=True, text=True, encoding='utf-8', errors='replace'
    )
    cols_expr = cols_result.stdout.strip()
    if not cols_expr:
        skipped += 1
        continue

    # Get 3 rows as JSON
    query = f"SELECT JSON_OBJECT({cols_expr}) FROM `{tname}` LIMIT 3"
    rows_result = subprocess.run(
        [MYSQL, "-h", "localhost", "-u", "athena", "-pVlvmf8383!!", "athena",
         "-N", "-B", "-e", query],
        capture_output=True, text=True, encoding='utf-8', errors='replace'
    )

    if rows_result.returncode != 0:
        # MySQL 5.7 may not support JSON_OBJECT, fallback to tab-separated
        skipped += 1
        continue

    rows = [r for r in rows_result.stdout.strip().split('\n') if r]
    for idx, row in enumerate(rows):
        # Mask sensitive fields
        try:
            data = json.loads(row)
            for key in list(data.keys()):
                if SENSITIVE.search(key):
                    data[key] = "***"
            row = json.dumps(data, ensure_ascii=False)
        except json.JSONDecodeError:
            pass

        c.execute("INSERT OR REPLACE INTO sample_rows (table_name, row_index, row_data) VALUES (?, ?, ?)",
                  (tname, idx, row))
        inserted += 1

    if rows:
        print(f"  {tname}: {len(rows)} rows")

conn.commit()

total = c.execute("SELECT COUNT(*) FROM sample_rows").fetchone()[0]
table_count = c.execute("SELECT COUNT(DISTINCT table_name) FROM sample_rows").fetchone()[0]
print(f"\nDone: {total} sample rows from {table_count} tables (skipped {skipped})")
conn.close()
