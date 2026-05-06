#!/usr/bin/env python3
"""Insert sample rows from SSM output into SQLite schema DB."""
import sqlite3
import re
import os

DB_FILE = os.path.expanduser("~/.claude/docs/references/hongcafe-schema.db")
conn = sqlite3.connect(DB_FILE)
c = conn.cursor()

# Clear existing
c.execute("DELETE FROM sample_rows")

# Sample data extracted from EC2 (hardcoded since SSM output is already captured)
samples = [
    ("tb_account_history", 0, '{"h_no":"1","ac_id":"testbot2026c@test.com","ac_no":"23","cr_code":"CR-20260410075021-231","st_code":"hongcafe","ac_status":"2","regist_type":"caller","change_reason":"신규 회원 등록","target_column":"join","regist_date":"2026-04-10 07:50:21"}'),
    ("tb_account_history", 1, '{"h_no":"2","ac_id":"testbot2026final@test.com","ac_no":"24","cr_code":"CR-20260410081231-241","st_code":"hongcafe","ac_status":"2","regist_type":"caller","change_reason":"신규 회원 등록","target_column":"join","regist_date":"2026-04-10 08:12:31"}'),
    ("tb_account_history", 2, '{"h_no":"3","ac_id":"woohyun@peoplev.co","ac_no":"25","cr_code":"CR-20260416002654-140","st_code":"hongcafe","ac_status":"2","regist_type":"caller","change_reason":"신규 회원 등록","target_column":"join","regist_date":"2026-04-16 00:26:54"}'),
    ("global_sync_sub_log", 0, '{"sub_log_seq":"1","msg_id":"dedup-1773119910442674038-11","pub_country":"JP","msg_group_id":"JP:ACCOUNT:COIN:2","sub_status":"3","retry_count":"0","reg_date":"2026-03-10 05:14:51","updated_at":"2026-04-07 00:35:48"}'),
    ("global_sync_sub_log", 1, '{"sub_log_seq":"2","msg_id":"dedup-1773119910442674038-12","pub_country":"JP","msg_group_id":"JP:ACCOUNT:COIN:5","sub_status":"3","retry_count":"0","reg_date":"2026-03-10 05:14:55","updated_at":"2026-04-07 00:35:48"}'),
    ("global_sync_sub_log", 2, '{"sub_log_seq":"3","msg_id":"dedup-1773119910442674038-13","pub_country":"KR","msg_group_id":"KR:ACCOUNT:COIN:7","sub_status":"3","retry_count":"0","reg_date":"2026-03-10 05:14:58","updated_at":"2026-04-07 00:35:48"}'),
]

c.executemany("INSERT INTO sample_rows (table_name, row_index, row_data) VALUES (?, ?, ?)", samples)
conn.commit()

count = c.execute("SELECT COUNT(*) FROM sample_rows").fetchone()[0]
tables = c.execute("SELECT COUNT(DISTINCT table_name) FROM sample_rows").fetchone()[0]
print(f"Inserted {count} sample rows from {tables} tables")

# Verify
for row in c.execute("SELECT table_name, row_index, substr(row_data, 1, 80) FROM sample_rows"):
    print(f"  {row[0]}[{row[1]}]: {row[2]}...")

conn.close()
