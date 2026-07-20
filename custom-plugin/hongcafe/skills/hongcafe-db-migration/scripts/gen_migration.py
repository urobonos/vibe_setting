#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
HongCafe DB migration SQL generator (로컬 pymysql).
사용:  python gen_migration.py <out.sql> <source_password>
- 아래 CONFIG를 매 이관마다 수정한다 (소스/선정/테이블/DROP/country/seed/limit).
- DROP = 소스에만 있어 타겟에 넣을 수 없는 컬럼 (소스∩타겟 comm 결과) + auto_increment PK.
- INSERT IGNORE = PK 중복 skip (기존 타겟 운영데이터 보존). FK 순서대로 생성.
- 출력은 SET FOREIGN_KEY_CHECKS=0; START TRANSACTION; 로 감싸므로 로더가 ROLLBACK(dry-run)/COMMIT(실적재) 선택.
"""
import pymysql, sys

# ===================== CONFIG (매 이관 수정) =====================
SRC = dict(host='db-8bna4.pub-cdb.ntruss.com', port=3306, user='athena', database='athena')  # password는 argv[2]
SEED = 42
LIMIT = 1000
# 선정: (ce_code, ac_id) 두 키를 뽑는다. 조건/조인은 이관 대상에 맞게 수정.
SELECT_KEYS = ("SELECT c.ce_code, c.ac_id FROM tb_callee c "
               "JOIN tb_account a ON c.ac_id=a.ac_id "
               "WHERE c.ce_status=3 AND a.ac_status=2 "
               "ORDER BY RAND({seed}) LIMIT {limit}")
# 테이블 FK 순서: (테이블, 선정키 컬럼, 키종류 'ac'|'ce')
PLAN = [('tb_account', 'ac_id', 'ac'), ('tb_callee', 'ce_code', 'ce'),
        ('tb_items', 'ce_code', 'ce'), ('tb_chat_items', 'ce_code', 'ce')]
# 타겟에 없어 버릴 컬럼 (소스∩타겟 교집합 밖). ac_no = auto_inc PK 회피.
DROP = {
    'tb_account': set("ac_no ai_call_useyn ai_chat_useyn ai_priv_policy_cf ai_priv_policy_date "
                      "is_momcafe latest_access_date mom_code rt_code rt_group_code "
                      "rt_total_coin_amount rt_update_date".split()),
    'tb_callee': set("cafeshop_call_use ce_bank_code_tmp ce_business_category ce_business_code "
                     "ce_business_email ce_business_license_copy_img ce_business_name ce_business_no "
                     "ce_business_owner ce_business_phone ce_business_type ce_caller_popup_yn "
                     "ce_finance_info_re_input_status ce_finance_info_regist_date ce_foreigner "
                     "ce_gender ce_item_cafeclass ce_item_cafeshop ce_manage_hong ce_manage_naver "
                     "ce_mentee_eligible ce_recommender ce_status0_first_login_date ce_summai_useyn "
                     "ce_tax_jumin ce_tax_name it_banner_img start_green_ce_level start_purple_ce_level "
                     "update_recommender_date".split()),
    'tb_items': set(),
    'tb_chat_items': set(),
}
# 파생 컬럼: 소스에 없고 타겟에 넣을 값. 리전별로 'US'/'JP' 등 변경.
ADD_COUNTRY = {'tb_callee': "'US'"}
# ================================================================

if len(sys.argv) < 3:
    sys.exit("usage: python gen_migration.py <out.sql> <source_password>")
OUT, SRC['password'] = sys.argv[1], sys.argv[2]

conn = pymysql.connect(connect_timeout=15, charset='utf8mb4', **SRC)
cur = conn.cursor()
cur.execute(SELECT_KEYS.format(seed=SEED, limit=LIMIT))
picks = cur.fetchall()
ce_codes = [p[0] for p in picks]
ac_ids = sorted(set(p[1] for p in picks if p[1]))
keys_by_kind = {'ce': ce_codes, 'ac': ac_ids}

def esc(v):
    if v is None: return "NULL"
    if isinstance(v, (int, float)): return str(v)
    if isinstance(v, (bytes, bytearray)): v = v.decode('utf8', 'replace')
    return "'" + str(v).replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "\\r") + "'"

def inlist(keys):
    return ",".join("'" + str(k).replace("\\", "\\\\").replace("'", "\\'") + "'" for k in keys)

def gen(table, key_col, keys):
    cur.execute("SHOW COLUMNS FROM `%s`" % table)
    cols = [r[0] for r in cur.fetchall() if r[0] not in DROP.get(table, set())]
    cur.execute("SELECT %s FROM `%s` WHERE `%s` IN (%s)"
                % (",".join('`'+c+'`' for c in cols), table, key_col, inlist(keys)))
    rows = cur.fetchall()
    add = ADD_COUNTRY.get(table)
    outcols = cols + (['country_code'] if (add and 'country_code' not in cols) else [])
    collist = ",".join('`'+c+'`' for c in outcols)
    lines = []
    for row in rows:
        vals = [esc(v) for v in row]
        if add and 'country_code' not in cols:
            vals.append(add)
        lines.append("INSERT IGNORE INTO `%s` (%s) VALUES (%s);" % (table, collist, ",".join(vals)))
    return lines

with open(OUT, 'w', encoding='utf8') as out:
    out.write("SET NAMES utf8mb4;\nSET FOREIGN_KEY_CHECKS=0;\nSTART TRANSACTION;\n")
    summary = {}
    for table, key_col, kind in PLAN:
        lines = gen(table, key_col, keys_by_kind[kind])
        summary[table] = len(lines)
        out.write("\n-- %s : %d rows\n" % (table, len(lines)))
        out.write("\n".join(lines) + "\n")
    out.write("\n-- ROLLBACK; (dry-run)\n-- COMMIT;   (실적재 — §3 승인 후)\n")

print("selected: callee=%d ac_id=%d" % (len(ce_codes), len(ac_ids)))
for t, _, _ in PLAN:
    print("  %-16s %d rows" % (t, summary[t]))
