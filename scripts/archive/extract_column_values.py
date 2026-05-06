#!/usr/bin/env python3
"""Extract top 10 distinct values per column from local MySQL, store in SQLite columns.sample_data."""
import subprocess
import sqlite3
import json
import os

MYSQL = "C:/laragon/bin/mysql/mysql-5.7.44-winx64/bin/mysql.exe"
DB_FILE = os.path.expanduser("~/.claude/docs/references/hongcafe-schema.db")
SENSITIVE_COLS = {
    'ac_password', 'password', 'token', 'secret', 'api_key', 'api_token',
    'encryption_key', 'fcm_app_token', 'fcm_web_token', 'passwd_lost_cert',
    'sendbird_api_token', 'stripe_secret', 'jwt_secret', 'csrf_secret'
}

def run_query(query):
    r = subprocess.run(
        [MYSQL, "-h", "localhost", "-u", "athena", "-pVlvmf8383!!", "athena",
         "-N", "-B", "-e", query],
        capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=30
    )
    if r.returncode != 0:
        return None
    return r.stdout.strip()

conn = sqlite3.connect(DB_FILE)
c = conn.cursor()

# Get all table+column pairs
rows = c.execute("""
    SELECT table_name, column_name
    FROM columns
    ORDER BY table_name, column_name
""").fetchall()

print(f"Total columns: {len(rows)}")

# Get tables that have data (from INFORMATION_SCHEMA)
tables_with_data_raw = run_query(
    "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='athena' AND TABLE_ROWS > 0"
)
tables_with_data = set(tables_with_data_raw.split('\n')) if tables_with_data_raw else set()
print(f"Tables with data: {len(tables_with_data)}")

updated = 0
skipped = 0
errors = 0
current_table = None

for table_name, column_name in rows:
    # Skip tables without data
    if table_name not in tables_with_data:
        skipped += 1
        continue

    # Skip sensitive columns
    if column_name.lower() in SENSITIVE_COLS:
        c.execute("UPDATE columns SET sample_data = ? WHERE table_name = ? AND column_name = ?",
                  ('["***MASKED***"]', table_name, column_name))
        updated += 1
        continue

    # Print progress per table
    if table_name != current_table:
        current_table = table_name
        print(f"  {table_name}...", end="", flush=True)

    try:
        query = (
            f"SELECT CONCAT(IFNULL(CAST(`{column_name}` AS CHAR), 'NULL'), ' (', cnt, ')') "
            f"FROM (SELECT `{column_name}`, COUNT(*) as cnt FROM `{table_name}` "
            f"GROUP BY `{column_name}` ORDER BY cnt DESC LIMIT 10) sub"
        )
        result = run_query(query)
        if result:
            values = result.split('\n')
            # Truncate long values
            values = [v[:100] for v in values if v]
            sample_json = json.dumps(values, ensure_ascii=False)
            c.execute("UPDATE columns SET sample_data = ? WHERE table_name = ? AND column_name = ?",
                      (sample_json, table_name, column_name))
            updated += 1
        else:
            skipped += 1
    except Exception as e:
        errors += 1

    # Print newline after table changes
    if rows and table_name != current_table:
        print()

conn.commit()

filled = c.execute("SELECT COUNT(*) FROM columns WHERE sample_data IS NOT NULL").fetchone()[0]
total = c.execute("SELECT COUNT(*) FROM columns").fetchone()[0]
print(f"\n\nDone: {updated} updated, {skipped} skipped, {errors} errors")
print(f"Columns with sample_data: {filled}/{total}")
conn.close()
