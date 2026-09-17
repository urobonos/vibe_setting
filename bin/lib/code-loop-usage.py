#!/usr/bin/env python
"""code-loop run 목록 + 토큰·비용 실측.

토큰은 러너가 세는 것이 아니라 스텝이 남긴 세션 jsonl 에서 읽는다 — 러너는
`claude -p` 를 띄우고 끝나므로 자기가 쓴 양을 모른다. 그래서 매핑이 이 도구의
전부다: jsonl 첫머리에 산출 경로(`state/code-loop/{run}/...`)가 들어가는 것을
키로 쓴다.

매핑 누락을 숨기지 않으려고 `스텝` 열에 `jsonl/run.log` 두 수를 같이 낸다.
한쪽만 내면 "적게 나온 것"과 "적게 센 것"을 구분할 수 없다.
"""
import json, os, re, sys, unicodedata
from pathlib import Path

HOME  = Path(os.environ.get("CLAUDE_HOME") or os.path.expanduser("~/.claude"))
STATE = HOME / "state" / "code-loop"
PROJ  = HOME / "projects"

# per-1M USD (base_input, output). cache_read = base*0.1, cache_write(1h TTL) = base*2
PRICE = {
    "claude-opus-5":              (5.0, 25.0),
    "claude-sonnet-5":            (2.0, 10.0),
    "claude-haiku-4-5-20251001":  (1.0,  5.0),
}
DEFAULT_PRICE = (2.0, 10.0)

STEP_RE = re.compile(r"^--- (\d\d:\d\d:\d\d) \[([^\]]+)\]")


def usd(model, u):
    base, out = PRICE.get(model, DEFAULT_PRICE)
    return (u["in"] * base + u["cr"] * base * 0.1
            + u["cw"] * base * 2.0 + u["out"] * out) / 1e6


def dwidth(s):
    """터미널 표시 폭. 한글은 2칸이라 문자 수로 정렬하면 열이 어긋난다."""
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)


def pad(s, w, right=False):
    fill = " " * max(0, w - dwidth(s))
    return fill + s if right else s + fill


def human(n):
    for unit, div in (("M", 1e6), ("K", 1e3)):
        if n >= div:
            return "%.1f%s" % (n / div, unit)
    return str(n)


def scan_runs():
    """run.log 에서 상태와 스텝 수를 읽는다. 여기가 '무엇이 돌았나'의 SSOT."""
    runs = {}
    if not STATE.is_dir():
        return runs
    for d in sorted(STATE.iterdir()):
        log = d / "run.log"
        if not log.is_file():
            continue
        steps, last_label, aborted = 0, "", False
        try:
            for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
                m = STEP_RE.match(line)
                if m:
                    steps += 1
                    last_label = m.group(2)
                    aborted = False   # 새 스텝이 떴으면 앞의 중단은 이어받은 것이다
                elif line.startswith("!!!"):
                    aborted = True
        except OSError:
            pass
        if (d / "RESULT.md").is_file():
            state = "완료"
        elif aborted:
            state = "중단"
        else:
            state = ("%s 진행" % last_label) if last_label else "시작"
        runs[d.name] = {"state": state, "steps": steps, "sess": 0,
                        "in": 0, "cr": 0, "cw": 0, "out": 0, "usd": 0.0}
    return runs


def scan_sessions(runs):
    """세션 jsonl 을 run 으로 귀속시키고 usage 를 합산한다.

    키는 run 디렉토리 이름 그 자체다. 이름의 *형식*(타임스탬프 패턴)을 정규식으로
    가정하면 러너가 명명 규칙을 바꾸는 순간 조용히 0 이 된다 — 집계 도구가 0 을
    내면 "안 썼다"로 읽히므로 그 실패는 눈에 안 띈다.
    """
    if not PROJ.is_dir():
        return
    # 긴 이름부터 본다. 짧은 run 이 긴 run 의 접두이면(…-hello-world 와
    # …-hello-world2) 짧은 쪽이 먼저 걸려 남의 비용을 가져간다.
    names = sorted(runs, key=len, reverse=True)
    for f in PROJ.glob("*/*.jsonl"):
        run, agg = None, {}
        try:
            with open(f, encoding="utf-8", errors="replace") as fh:
                for i, line in enumerate(fh):
                    if run is None:
                        if i >= 30:
                            break          # 첫머리에 없으면 code-loop 스텝이 아니다
                        for n in names:
                            if n in line:
                                run = n
                                break
                        if run is None:
                            continue
                    if '"usage"' not in line:
                        continue
                    try:
                        msg = (json.loads(line).get("message") or {})
                    except (ValueError, AttributeError):
                        continue
                    u = msg.get("usage") or {}
                    if not u:
                        continue
                    a = agg.setdefault(msg.get("model", "?"),
                                       {"in": 0, "cr": 0, "cw": 0, "out": 0})
                    a["in"]  += u.get("input_tokens", 0) or 0
                    a["cr"]  += u.get("cache_read_input_tokens", 0) or 0
                    a["cw"]  += u.get("cache_creation_input_tokens", 0) or 0
                    a["out"] += u.get("output_tokens", 0) or 0
        except OSError:
            continue
        if run is None:
            continue
        r = runs[run]
        r["sess"] += 1
        for model, a in agg.items():
            for k in ("in", "cr", "cw", "out"):
                r[k] += a[k]
            r["usd"] += usd(model, a)


def main():
    runs = scan_runs()
    if not runs:
        print("run 없음")
        return 0
    scan_sessions(runs)

    w = 44
    head = (pad("항목", w) + " " + pad("상태", 18) + " "
            + pad("스텝", 8, True) + " " + pad("토큰", 9, True) + " "
            + pad("비용", 9, True))
    print(head)
    print("-" * dwidth(head))
    tt = tc = 0
    for name, r in runs.items():
        tok = r["in"] + r["cr"] + r["cw"] + r["out"]
        tt += tok
        tc += r["usd"]
        label = name if len(name) <= w else name[:w - 1] + "~"
        print(pad(label, w) + " " + pad(r["state"], 18) + " "
              + pad("%s/%s" % (r["sess"], r["steps"]), 8, True) + " "
              + pad(human(tok), 9, True) + " "
              + pad("$%.2f" % r["usd"], 9, True))
    print("-" * dwidth(head))
    print(pad("합계 (%d run)" % len(runs), w) + " " + pad("", 18) + " "
          + pad("", 8) + " " + pad(human(tt), 9, True) + " "
          + pad("$%.2f" % tc, 9, True))
    print()
    print("스텝 = jsonl 로 귀속된 수 / run.log 가 띄운 수. 어긋나면 그만큼 덜 센 것이다.")
    print("진행 상황: tail -f %s/{run}/run.log" % STATE.as_posix())
    return 0


if __name__ == "__main__":
    sys.exit(main())
