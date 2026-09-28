#!/usr/bin/env python3
"""dream Phase 2 (GATHER SIGNAL) — 세션 트랜스크립트에서 메모리 후보 신호만 추출.

전체 읽기 금지(2.6GB). 사용자 발화만 골라 패턴 매칭한 뒤 원문 발췌로 남긴다.
판단(무엇을 메모리로 승격할지)은 하지 않는다 — 그건 Phase 3 에서 Claude 가 한다.

SSOT: custom-plugin/taskflow/commands/dream.md
"""
import argparse
import json
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

PATTERNS = {
    "correction": r"아닌데|아니야|아냐|아님|그게 아니|틀렸|틀린|하지\s*마|왜 안|다시 해|말했잖|잘못|안 되잖|이상한데|누락",
    "preference": r"항상|앞으로|매번|기본으로|대신|무조건|절대|하지 말고|규칙으로",
    "decision": r"진행|승인|확정|채택|보류|중단|넣음|빼|우선은",
}

# 사용자 발화가 아닌 것 (훅 주입·도구 결과·슬래시 본문)
NOISE = re.compile(
    r"Stop hook feedback|system-reminder|tool_result|<command-name>|"
    r"\[AUTO-ITERATE|Caveat: The messages below|Base directory for this skill|"
    r"<system-reminder>|Skill: |allowed-tools:|<task-notification>|<output-file>|"
    r"<local-command|<command-message>|tool-use-id"
)


def iter_user_texts(path):
    try:
        fh = path.open(encoding="utf-8", errors="replace")
    except OSError:
        return
    with fh:
        for line in fh:
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if rec.get("type") != "user":
                continue
            content = rec.get("message", {}).get("content")
            if isinstance(content, list):
                content = " ".join(
                    part.get("text", "")
                    for part in content
                    if isinstance(part, dict)
                )
            if not isinstance(content, str):
                continue
            text = content.strip()
            if not text or NOISE.search(text):
                continue
            # 슬래시 커맨드·스킬 본문 주입 = 사용자 발화 아님 (긴 마크다운 문서형)
            if len(text) > 300 and (
                text.startswith("#")
                or text.startswith('"')
                or "```" in text
                or "└" in text  # 붙여넣은 보고서 트리 문자
            ):
                continue
            yield rec.get("timestamp", ""), text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, help="projects/ 하위 슬러그")
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--max-chars", type=int, default=300)
    parser.add_argument("--limit", type=int, default=60, help="카테고리별 상한")
    args = parser.parse_args()

    root = Path.home() / ".claude" / "projects" / args.project
    if not root.is_dir():
        sys.exit(f"프로젝트 디렉토리 없음: {root}")

    cutoff = (datetime.now(timezone.utc) - timedelta(days=args.days)).timestamp()
    sessions = [p for p in root.glob("*.jsonl") if p.stat().st_mtime >= cutoff]

    hits = {name: [] for name in PATTERNS}
    seen = set()
    for path in sorted(sessions, key=lambda p: p.stat().st_mtime, reverse=True):
        for stamp, text in iter_user_texts(path):
            for name, pattern in PATTERNS.items():
                if len(hits[name]) >= args.limit:
                    continue
                if not re.search(pattern, text):
                    continue
                excerpt = " ".join(text.split())[: args.max_chars]
                key = (name, excerpt[:60])
                if key in seen:
                    continue
                seen.add(key)
                hits[name].append((stamp[:10], path.stem[:8], excerpt))

    print(f"# dream Phase 2 — 신호 추출 ({args.project})\n")
    print(f"- 스캔 세션: {len(sessions)}개 (최근 {args.days}일)")
    print(f"- 추출: " + " / ".join(f"{k} {len(v)}건" for k, v in hits.items()))
    print()
    for name, rows in hits.items():
        print(f"## {name} ({len(rows)})\n")
        if not rows:
            print("_해당 없음_\n")
            continue
        print("| 날짜 | 세션 | 발췌 |")
        print("|---|---|---|")
        for stamp, sid, excerpt in rows:
            safe = excerpt.replace("|", r"\|")
            print(f"| {stamp} | `{sid}` | {safe} |")
        print()


if __name__ == "__main__":
    main()
