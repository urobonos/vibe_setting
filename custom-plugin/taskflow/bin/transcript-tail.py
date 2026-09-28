#!/usr/bin/env python3
"""transcript-tail.py — 세션 transcript jsonl 의 '지금 상태' 신호 추출 (read-only).

용도: /taskflow:watch 의 파서. REGISTRY(선언된 의도)가 아니라 transcript(실제 진행)를 본다.

설계 제약:
  - transcript 는 100MB+ / 10만 줄까지 커진다 → **전체 파싱 금지**. 파일 끝 N바이트만 seek 해서 읽는다
    (비용이 파일 크기와 무관한 상수). 앞쪽 잘린 불완전 라인 1개는 버린다.
  - jq 가 이 환경에 없어 python 파서로 대체 (2026-07-27 실측).
  - **관측 전용** — 프로세스·loop 를 건드리지 않는다. 정지 판단은 사용자 몫
    (CLAUDE.md 메모리 feedback_no-autonomous-loop-kill).

사용:
  python3 transcript-tail.py [sid_prefix ...]   # 생략 시 mtime 최신 --top 개
  python3 transcript-tail.py --json 77af0d0f
"""
import glob
import json
import os
import sys
import time

PROJECTS = os.path.expanduser("~/.claude/projects")
TAIL_BYTES = 256 * 1024   # 끝 256KB — 최근 수십 턴을 담기 충분
KEEP_RECORDS = 80         # 파싱 후 유지할 최근 레코드 수
NOOP_WINDOW = 10          # 반복 판정에 볼 최근 assistant 텍스트 수


def find_transcripts(prefixes, top):
    files = glob.glob(os.path.join(PROJECTS, "*", "*.jsonl"))
    if prefixes:
        picked = []
        for p in prefixes:
            hit = [f for f in files if os.path.basename(f).startswith(p)]
            if not hit:
                picked.append((p, None))
            else:
                picked.extend((os.path.basename(h)[:8], h) for h in hit)
        return picked
    # sidechain(subagent) 선별은 하지 않는다 — 864개 transcript 전수 실측 결과 첫 레코드
    # isSidechain 이 전부 false 라 판정 근거가 없고, 파일 864개 open 비용만 +1.1초 든다 (2026-07-27).
    files.sort(key=os.path.getmtime, reverse=True)
    return [(os.path.basename(f)[:8], f) for f in files[:top]]


def tail_records(path):
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        if size > TAIL_BYTES:
            f.seek(-TAIL_BYTES, os.SEEK_END)
        blob = f.read()
    lines = blob.split(b"\n")
    if size > TAIL_BYTES:
        lines = lines[1:]           # 잘린 첫 라인 폐기
    out = []
    for ln in lines:
        ln = ln.strip()
        if not ln:
            continue
        try:
            out.append(json.loads(ln))
        except (ValueError, UnicodeDecodeError):
            continue
    return out[-KEEP_RECORDS:]


# 도구 인자는 통째 json 이 아니라 대표 키 1개만 — watch 는 사람이 훑는 대시보드다
ARG_KEYS = ("command", "file_path", "pattern", "prompt", "query", "description", "skill")


def tool_arg(inp):
    if not isinstance(inp, dict):
        return ""
    for key in ARG_KEYS:
        if inp.get(key):
            return " ".join(str(inp[key]).split())[:110]
    return json.dumps(inp, ensure_ascii=False)[:110]


def blocks(rec, role):
    msg = rec.get("message") or {}
    if msg.get("role") != role:
        return []
    content = msg.get("content")
    return content if isinstance(content, list) else []


def summarize(sid, path):
    st = os.stat(path)
    recs = tail_records(path)

    current = None          # 마지막 tool_use
    sentinel = None         # 마지막 sentinel + 몇 턴 전인지
    texts = []              # 최근 assistant 텍스트 (반복 판정용)
    assistant_turns = 0

    for idx, rec in enumerate(reversed(recs)):
        for b in blocks(rec, "assistant"):
            btype = b.get("type")
            if btype == "tool_use":
                if current is None:
                    current = {"tool": b.get("name", "?"), "input": tool_arg(b.get("input"))}
            elif btype == "text":
                txt = (b.get("text") or "").strip()
                if not txt:
                    continue
                assistant_turns += 1
                texts.append(" ".join(txt.split())[:160])
                if sentinel is None:
                    for mark in ("[AUTO-ITERATE-USER-DECISION]", "[AUTO-ITERATE-DONE]"):
                        if mark in txt:
                            sentinel = {"mark": mark.strip("[]"), "turns_ago": idx}
                            break

    window = texts[:NOOP_WINDOW]
    repeat = 0
    if window:
        repeat = max(window.count(t) for t in window)

    return {
        "sid": sid,
        "path": path,
        "cwd_slug": os.path.basename(os.path.dirname(path)),
        "idle_sec": int(time.time() - st.st_mtime),
        "size_mb": round(st.st_size / 1048576, 1),
        "current": current,
        "sentinel": sentinel,
        "assistant_turns_in_tail": assistant_turns,
        "repeat_max": repeat,
        "repeat_window": len(window),
    }


def human(idle):
    if idle < 90:
        return f"{idle}초 전"
    if idle < 5400:
        return f"{idle // 60}분 전"
    return f"{idle // 3600}시간 전"


def render(s):
    live = "●" if s["idle_sec"] < 180 else "○"
    state = "활성" if s["idle_sec"] < 180 else "정지(추정)"
    lines = [f"{s['sid']}  {live} {state} ({human(s['idle_sec'])})  {s['cwd_slug']}  {s['size_mb']}MB"]

    if s["current"]:
        lines.append(f"    지금: {s['current']['tool']} — {s['current']['input']}")
    else:
        lines.append("    지금: (최근 tail 에 tool_use 없음)")

    if s["sentinel"]:
        mark = s["sentinel"]["mark"]
        icon = "판단 대기" if "USER-DECISION" in mark else "iteration 완료"
        lines.append(f"    신호: {icon} — {mark} ({s['sentinel']['turns_ago']}레코드 전)")

    if s["repeat_max"] >= 2:
        lines.append(
            f"    반복: 최근 {s['repeat_window']}개 응답 중 동일 응답 {s['repeat_max']}회 "
            f"(관측치일 뿐 — 정지 판단 금지)"
        )
    return "\n".join(lines)


def main():
    argv = [a for a in sys.argv[1:] if a != "--json"]
    as_json = "--json" in sys.argv[1:]
    top = 5
    if argv and argv[0].startswith("--top="):
        top = int(argv.pop(0).split("=", 1)[1])

    targets = find_transcripts(argv, top)
    if not targets:
        print("관측 대상 transcript 없음")
        return

    results, missing = [], []
    for sid, path in targets:
        if path is None:
            missing.append(sid)
            continue
        results.append(summarize(sid, path))

    if as_json:
        print(json.dumps({"sessions": results, "missing": missing}, ensure_ascii=False, indent=2))
        return

    for s in results:
        print(render(s))
        print()
    for m in missing:
        print(f"{m}  ✗ transcript 없음 (sid 오타 또는 다른 머신 세션)")


if __name__ == "__main__":
    main()
