#!/usr/bin/env python3
"""Parse schema_raw.tsv and build SQLite knowledge base."""
import sqlite3
import os

RAW_FILE = os.path.join(os.path.dirname(__file__), "schema_raw.tsv")
DB_FILE = os.path.expanduser("~/.claude/docs/references/hongcafe-schema.db")

os.makedirs(os.path.dirname(DB_FILE), exist_ok=True)

conn = sqlite3.connect(DB_FILE)
c = conn.cursor()

# Create tables
c.executescript("""
DROP TABLE IF EXISTS columns;
DROP TABLE IF EXISTS indexes;
DROP TABLE IF EXISTS relations;
DROP TABLE IF EXISTS business_rules;
DROP TABLE IF EXISTS query_patterns;
DROP TABLE IF EXISTS sample_rows;

CREATE TABLE columns (
    table_name     TEXT NOT NULL,
    table_desc     TEXT,
    column_name    TEXT NOT NULL,
    column_desc    TEXT,
    type           TEXT,
    nullable       INTEGER DEFAULT 1,
    default_value  TEXT,
    column_key     TEXT,
    extra          TEXT,
    is_pk          INTEGER DEFAULT 0,
    is_unique      INTEGER DEFAULT 0,
    is_indexed     INTEGER DEFAULT 0,
    enum_values    TEXT,
    sample_data    TEXT,
    PRIMARY KEY (table_name, column_name)
);

CREATE TABLE indexes (
    table_name     TEXT NOT NULL,
    index_name     TEXT NOT NULL,
    columns        TEXT NOT NULL,
    index_type     TEXT
);

CREATE TABLE relations (
    from_table     TEXT NOT NULL,
    from_column    TEXT NOT NULL,
    to_table       TEXT NOT NULL,
    to_column      TEXT NOT NULL,
    relation_type  TEXT DEFAULT 'FK',
    on_delete      TEXT,
    description    TEXT
);

CREATE TABLE business_rules (
    table_name     TEXT,
    column_name    TEXT,
    rule_type      TEXT,
    rule_desc      TEXT,
    module         TEXT
);

CREATE TABLE query_patterns (
    pattern_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    name           TEXT,
    description    TEXT,
    tables         TEXT,
    join_condition TEXT,
    where_example  TEXT,
    module         TEXT
);

CREATE TABLE sample_rows (
    table_name  TEXT NOT NULL,
    row_index   INTEGER NOT NULL,
    row_data    TEXT NOT NULL,
    PRIMARY KEY (table_name, row_index)
);
""")

# Parse raw file
with open(RAW_FILE, "r", encoding="utf-8", errors="replace") as f:
    lines = f.readlines()

section = None
table_descs = {}

for line in lines:
    line = line.rstrip("\n")
    if line.startswith("=== TABLES ==="):
        section = "tables"
        continue
    elif line.startswith("=== COLUMNS ==="):
        section = "columns"
        continue
    elif line.startswith("=== INDEXES ==="):
        section = "indexes"
        continue
    elif line.startswith("=== RELATIONS ==="):
        section = "relations"
        continue
    elif line.startswith("=== DONE ==="):
        break
    elif not line.strip():
        continue

    parts = line.split("\t")

    if section == "tables" and len(parts) >= 1:
        tname = parts[0]
        tdesc = parts[1] if len(parts) > 1 else ""
        table_descs[tname] = tdesc

    elif section == "columns" and len(parts) >= 4:
        tname = parts[0]
        cname = parts[1] if len(parts) > 1 else ""
        cdesc = parts[2] if len(parts) > 2 else ""
        ctype = parts[3] if len(parts) > 3 else ""
        nullable = 1 if (len(parts) > 4 and parts[4] == "YES") else 0
        default_val = parts[5] if len(parts) > 5 else "NULL"
        col_key = parts[6] if len(parts) > 6 else ""
        extra = parts[7] if len(parts) > 7 else ""

        is_pk = 1 if col_key == "PRI" else 0
        is_unique = 1 if col_key == "UNI" else 0
        is_indexed = 1 if col_key in ("MUL", "UNI", "PRI") else 0

        tdesc = table_descs.get(tname, "")

        c.execute("""INSERT OR REPLACE INTO columns
            (table_name, table_desc, column_name, column_desc, type, nullable, default_value, column_key, extra, is_pk, is_unique, is_indexed)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (tname, tdesc, cname, cdesc, ctype, nullable, default_val, col_key, extra, is_pk, is_unique, is_indexed))

    elif section == "indexes" and len(parts) >= 3:
        tname = parts[0]
        iname = parts[1]
        icols = parts[2]
        itype = parts[3] if len(parts) > 3 else "INDEX"
        c.execute("INSERT INTO indexes VALUES (?, ?, ?, ?)", (tname, iname, icols, itype))

    elif section == "relations" and len(parts) >= 4:
        c.execute("INSERT INTO relations (from_table, from_column, to_table, to_column) VALUES (?, ?, ?, ?)",
            (parts[0], parts[1], parts[2], parts[3]))

conn.commit()

# Stats
tables = c.execute("SELECT COUNT(DISTINCT table_name) FROM columns").fetchone()[0]
cols = c.execute("SELECT COUNT(*) FROM columns").fetchone()[0]
idxs = c.execute("SELECT COUNT(*) FROM indexes").fetchone()[0]
rels = c.execute("SELECT COUNT(*) FROM relations").fetchone()[0]

print(f"SQLite DB created: {DB_FILE}")
print(f"  Tables:    {tables}")
print(f"  Columns:   {cols}")
print(f"  Indexes:   {idxs}")
print(f"  Relations: {rels}")
print(f"  + Empty tables: business_rules, query_patterns, sample_rows")

conn.close()
