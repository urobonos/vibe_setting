#!/usr/bin/env python3
"""
docset-compact.py - Dash docset HTML to compact SQLite

Usage:
    python docset-compact.py                          # convert all
    python docset-compact.py PHP MySQL                # specific docsets
    python docset-compact.py --list                   # show status
    python docset-compact.py --cleanup PHP            # remove HTML after convert
    python docset-compact.py --read PHP password_hash # test query
"""

import os, sys, re, zlib, sqlite3, argparse, datetime, shutil
from html.parser import HTMLParser
from pathlib import Path

REFS_DIR = Path.home() / ".claude" / "docs" / "references"


class TextExtractor(HTMLParser):
    SKIP_TAGS = frozenset({
        "script", "style", "nav", "header", "footer",
        "noscript", "svg", "iframe", "object", "embed",
    })
    BLOCK_TAGS = frozenset({
        "p", "br", "div", "section", "article", "aside",
        "h1", "h2", "h3", "h4", "h5", "h6",
        "li", "tr", "td", "th", "dt", "dd",
        "pre", "blockquote", "figcaption",
    })

    def __init__(self):
        super().__init__()
        self.parts = []
        self.skip_depth = 0

    def handle_starttag(self, tag, attrs):
        if tag in self.SKIP_TAGS:
            self.skip_depth += 1
        if tag in self.BLOCK_TAGS:
            self.parts.append("\n")

    def handle_endtag(self, tag):
        if tag in self.SKIP_TAGS and self.skip_depth > 0:
            self.skip_depth -= 1

    def handle_data(self, data):
        if self.skip_depth == 0:
            self.parts.append(data)

    def get_text(self):
        raw = "".join(self.parts)
        lines = []
        for line in raw.split("\n"):
            cleaned = re.sub(r"[ \t]+", " ", line).strip()
            if cleaned:
                lines.append(cleaned)
        return "\n".join(lines)


def extract_text(html_path):
    try:
        with open(html_path, "r", encoding="utf-8", errors="replace") as f:
            html = f.read()
        ext = TextExtractor()
        ext.feed(html)
        return ext.get_text()
    except Exception:
        return None


def get_docsets():
    return sorted(
        [d for d in REFS_DIR.iterdir() if d.suffix == ".docset" and d.is_dir()],
        key=lambda d: d.stem,
    )


def get_docset_info(docset_path):
    total_size = html_size = html_count = 0
    for root, _, files in os.walk(docset_path):
        for f in files:
            fp = os.path.join(root, f)
            try:
                sz = os.path.getsize(fp)
            except OSError:
                continue
            total_size += sz
            if f.endswith((".html", ".htm")):
                html_size += sz
                html_count += 1
    idx_path = docset_path / "Contents" / "Resources" / "docSet.dsidx"
    idx_size = idx_entries = 0
    if idx_path.exists():
        idx_size = idx_path.stat().st_size
        try:
            conn = sqlite3.connect(str(idx_path))
            idx_entries = conn.execute("SELECT COUNT(*) FROM searchIndex").fetchone()[0]
            conn.close()
        except sqlite3.Error:
            pass
    return {"total": total_size, "html": html_size, "html_count": html_count,
            "idx": idx_size, "idx_entries": idx_entries}


def compact_docset(docset_path, verbose=True):
    name = docset_path.stem
    docs_dir = docset_path / "Contents" / "Resources" / "Documents"
    idx_path = docset_path / "Contents" / "Resources" / "docSet.dsidx"
    out_path = REFS_DIR / f"{name}.compact.sqlite"

    if not idx_path.exists():
        if verbose: print(f"  [SKIP] {name}: no dsidx")
        return None
    if not docs_dir.exists():
        if verbose: print(f"  [SKIP] {name}: no Documents/")
        return None

    if verbose:
        print(f"\n{"="*60}")
        print(f"  {name}.docset -> {name}.compact.sqlite")
        print(f"{"="*60}")

    src = sqlite3.connect(str(idx_path))
    src_cols = [r[1] for r in src.execute("PRAGMA table_info(searchIndex)").fetchall()]
    src_select = ", ".join(src_cols)
    entries = src.execute(f"SELECT {src_select} FROM searchIndex").fetchall()
    src.close()
    if verbose: print(f"  searchIndex: {len(entries)} entries")

    all_html = {}
    for root, _, files in os.walk(docs_dir):
        for f in files:
            if f.endswith((".html", ".htm")):
                abs_p = os.path.join(root, f)
                rel_p = os.path.relpath(abs_p, docs_dir).replace("\\", "/")
                all_html[rel_p] = abs_p
    if verbose: print(f"  HTML files: {len(all_html)}")

    if out_path.exists(): out_path.unlink()
    out = sqlite3.connect(str(out_path))
    out.execute("PRAGMA journal_mode=WAL")
    out.execute("PRAGMA synchronous=NORMAL")
    out.execute("PRAGMA page_size=4096")
    col_defs = []
    for col in src_cols:
        if col == "id":
            col_defs.append("id INTEGER PRIMARY KEY")
        else:
            col_defs.append(f"{col} TEXT")
    out.execute(f"CREATE TABLE searchIndex ({', '.join(col_defs)})")
    placeholders = ",".join(["?"] * len(src_cols))
    out.executemany(f"INSERT INTO searchIndex VALUES ({placeholders})", entries)
    out.execute("CREATE TABLE documents (path TEXT PRIMARY KEY, content_compressed BLOB, size_original INTEGER, size_text INTEGER)")
    out.execute("CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT)")

    processed = total_html_bytes = total_text_bytes = total_comp_bytes = errors = 0
    for rel_path in sorted(all_html.keys()):
        abs_path = all_html[rel_path]
        try:
            html_size = os.path.getsize(abs_path)
        except OSError:
            errors += 1; continue
        text = extract_text(abs_path)
        if text is None:
            errors += 1; continue
        text_bytes = text.encode("utf-8")
        compressed = zlib.compress(text_bytes, 9)
        out.execute("INSERT OR REPLACE INTO documents VALUES (?,?,?,?)",
                    (rel_path, compressed, html_size, len(text_bytes)))
        total_html_bytes += html_size
        total_text_bytes += len(text_bytes)
        total_comp_bytes += len(compressed)
        processed += 1
        if verbose and processed % 500 == 0:
            print(f"  ... {processed}/{len(all_html)}")

    out.execute("CREATE INDEX idx_search_name ON searchIndex(name)")
    out.execute("CREATE INDEX idx_search_type ON searchIndex(type)")
    meta = {
        "source_docset": name,
        "created": datetime.datetime.now().isoformat(),
        "html_files": str(processed),
        "search_entries": str(len(entries)),
        "total_html_bytes": str(total_html_bytes),
        "total_text_bytes": str(total_text_bytes),
        "total_compressed_bytes": str(total_comp_bytes),
    }
    out.executemany("INSERT INTO metadata VALUES (?,?)", meta.items())
    out.commit(); out.execute("VACUUM"); out.close()

    compact_size = out_path.stat().st_size
    if verbose:
        saving = (1 - compact_size / total_html_bytes) * 100 if total_html_bytes > 0 else 0
        print(f"\n  HTML:    {total_html_bytes/1048576:>8.1f} MB ({processed} files)")
        print(f"  Text:    {total_text_bytes/1048576:>8.1f} MB")
        print(f"  zlib:    {total_comp_bytes/1048576:>8.1f} MB")
        print(f"  SQLite:  {compact_size/1048576:>8.1f} MB")
        print(f"  Saved:   {saving:.0f}%")
        if errors: print(f"  Errors:  {errors}")
    return {"name": name, "html_size": total_html_bytes, "text_size": total_text_bytes,
            "compact_size": compact_size, "files": processed, "entries": len(entries), "errors": errors}


def cleanup_html(docset_path, verbose=True):
    name = docset_path.stem
    docs_dir = docset_path / "Contents" / "Resources" / "Documents"
    compact = REFS_DIR / f"{name}.compact.sqlite"
    if not compact.exists():
        print(f"  [SKIP] {name}: no compact sqlite"); return False
    if not docs_dir.exists():
        print(f"  [SKIP] {name}: Documents/ already gone"); return False
    size = sum(os.path.getsize(os.path.join(r, f)) for r, _, files in os.walk(docs_dir) for f in files)
    if verbose: print(f"  {name}: deleting Documents/ ({size/1048576:.1f} MB)")
    shutil.rmtree(docs_dir)
    if verbose: print(f"  done")
    return True


def read_compact(docset_name, keyword):
    compact_path = REFS_DIR / f"{docset_name}.compact.sqlite"
    if not compact_path.exists():
        print(f"ERROR: {compact_path} not found"); return
    conn = sqlite3.connect(str(compact_path))
    rows = conn.execute("SELECT name, type, path FROM searchIndex WHERE name LIKE ? ORDER BY name LIMIT 10",
                        (f"%{keyword}%",)).fetchall()
    if not rows:
        print(f"  No results for {keyword!r} in {docset_name}"); conn.close(); return
    print(f"\n  Search: {keyword!r} in {docset_name}.compact.sqlite")
    print(f"  {'-'*50}")
    for name, type_, path in rows:
        clean = re.sub(r"^<[^>]+>", "", path)
        clean = re.sub(r"#.*$", "", clean)
        row = conn.execute("SELECT content_compressed, size_text FROM documents WHERE path = ?", (clean,)).fetchone()
        if row:
            text = zlib.decompress(row[0]).decode("utf-8")
            preview = text[:200].replace("\n", " ")
            print(f"  [{type_}] {name}")
            print(f"    size: {row[1]} bytes")
            print(f"    preview: {preview}...")
            print()
    conn.close()


def cmd_list():
    print(f"\n  {'Name':<45} {'Total':>8} {'HTML':>8} {'Idx':>6} {'Entries':>8} {'Compact':>8}")
    print(f"  {'-'*87}")
    gt = gh = gc = 0
    for ds in get_docsets():
        info = get_docset_info(ds)
        cp = REFS_DIR / f"{ds.stem}.compact.sqlite"
        cs = cp.stat().st_size if cp.exists() else 0
        gt += info["total"]; gh += info["html"]; gc += cs
        cs_s = f"{cs/1048576:>7.1f}M" if cs else f"{'--':>8}"
        print(f"  {ds.stem:<45} {info['total']/1048576:>7.1f}M {info['html']/1048576:>7.1f}M {info['idx']/1048576:>5.1f}M {info['idx_entries']:>8} {cs_s}")
    print(f"  {'-'*87}")
    cs_s = f"{gc/1048576:>7.1f}M" if gc else f"{'--':>8}"
    print(f"  {'TOTAL':<45} {gt/1048576:>7.1f}M {gh/1048576:>7.1f}M {'':>6} {'':>8} {cs_s}")
    if gh > 0 and gc > 0:
        print(f"\n  Savings: {(gh-gc)/1048576:.0f} MB ({(1-gc/gh)*100:.0f}%)")


def main():
    p = argparse.ArgumentParser(description="Dash docset -> compact SQLite",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("targets", nargs="*", help="docset names to convert")
    p.add_argument("--list", action="store_true", help="show docset status")
    p.add_argument("--cleanup", nargs="*", metavar="NAME", help="remove HTML after conversion")
    p.add_argument("--read", nargs=2, metavar=("DOCSET", "KEYWORD"), help="test compact DB query")
    p.add_argument("--quiet", "-q", action="store_true", help="minimal output")
    args = p.parse_args()

    if args.list: cmd_list(); return
    if args.read: read_compact(args.read[0], args.read[1]); return
    if args.cleanup is not None:
        names = args.cleanup if args.cleanup else [ds.stem for ds in get_docsets()]
        for ds in get_docsets():
            if ds.stem in names: cleanup_html(ds, verbose=not args.quiet)
        return

    names = args.targets if args.targets else [ds.stem for ds in get_docsets()]
    docsets = [ds for ds in get_docsets() if ds.stem in names]
    if not docsets:
        print(f"No targets: {names}"); print(f"Available: {[d.stem for d in get_docsets()]}"); sys.exit(1)

    print(f"\n=== Docset Compact: {len(docsets)} docsets ===")
    results = []
    for ds in docsets:
        r = compact_docset(ds, verbose=not args.quiet)
        if r: results.append(r)

    if results:
        print(f"\n{'='*60}")
        print(f"  Done")
        print(f"{'='*60}")
        print(f"  {'Name':<30} {'HTML':>8} {'Compact':>8} {'Saved':>6}")
        print(f"  {'-'*54}")
        th = tc = 0
        for r in results:
            th += r["html_size"]; tc += r["compact_size"]
            sv = (1-r["compact_size"]/r["html_size"])*100 if r["html_size"]>0 else 0
            print(f"  {r['name']:<30} {r['html_size']/1048576:>7.1f}M {r['compact_size']/1048576:>7.1f}M {sv:>5.0f}%")
        print(f"  {'-'*54}")
        tsv = (1-tc/th)*100 if th>0 else 0
        print(f"  {'TOTAL':<30} {th/1048576:>7.1f}M {tc/1048576:>7.1f}M {tsv:>5.0f}%")
        print(f"\n  Cleanup HTML: python docset-compact.py --cleanup")


if __name__ == "__main__":
    main()
