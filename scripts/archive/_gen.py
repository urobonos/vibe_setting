
import pathlib
Q = chr(34)
NL = chr(10)
BS = chr(92)

lines = [
    f"#!/usr/bin/env python3",
    f"{Q}{Q}{Q}",
    f"docset-compact.py - Dash docset HTML to compact SQLite",
    f"",
    f"HTML text extraction -> zlib compression -> single SQLite file.",
    f"~4GB HTML -> ~200-400MB compact SQLite (90%+ reduction).",
    f"",
    f"Usage:",
    f"    python docset-compact.py                          # convert all",
    f"    python docset-compact.py PHP MySQL                # specific docsets",
    f"    python docset-compact.py --list                   # show status",
    f"    python docset-compact.py --cleanup PHP            # remove HTML after convert",
    f"    python docset-compact.py --read PHP password_hash # test query",
    f"{Q}{Q}{Q}",
]
print(NL.join(lines))
