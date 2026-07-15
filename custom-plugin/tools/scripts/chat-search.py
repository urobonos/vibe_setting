#!/usr/bin/env python3
"""chat-search — Claude Code 대화 기록(JSONL 세션 트랜스크립트) 정규식 검색.

~/.claude/projects/ 아래 세션 트랜스크립트를 정규식으로 검색한다.
표준 라이브러리만 사용한다. `search` 플러그인의 검색 엔진.
"""

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude" / "projects"


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        prog="chat-search",
        description="Claude Code 대화 기록에서 정규식으로 검색합니다.",
    )
    parser.add_argument("pattern", help="검색할 정규식 패턴 (여러 단어는 따옴표로 묶으세요)")
    parser.add_argument("--all", action="store_true",
                        help="서브에이전트·워크플로우 트랜스크립트까지 포함 (기본: top-level 세션만)")
    parser.add_argument("--case", action="store_true",
                        help="대소문자 구분 (기본: 무시)")
    parser.add_argument("--thinking", action="store_true",
                        help="assistant 의 thinking 블록도 검색")
    parser.add_argument("--project", metavar="SUBSTR",
                        help="프로젝트 슬러그 부분일치 필터 (예: hongcafe)")
    parser.add_argument("--role", choices=["user", "assistant"],
                        help="해당 role 메시지만 검색")
    parser.add_argument("--since", metavar="YYYY-MM-DD",
                        help="이 날짜 이후 수정된 세션만 (파일 mtime 기준)")
    parser.add_argument("--until", metavar="YYYY-MM-DD",
                        help="이 날짜 이전 수정된 세션만 (파일 mtime 기준)")
    parser.add_argument("--context", type=int, default=60, metavar="N",
                        help="매치 전후 표시 글자 수 (기본: 60)")
    parser.add_argument("--limit", type=int, default=200, metavar="N",
                        help="최대 매치 출력 수 (기본: 200)")
    parser.add_argument("--json", action="store_true", dest="as_json",
                        help="결과를 JSON 으로 출력")
    parser.add_argument("--count", action="store_true",
                        help="매치 건수만 출력")
    return parser.parse_args(argv)


def parse_date(value):
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError:
        raise SystemExit(f"날짜 형식 오류: {value!r} (YYYY-MM-DD 필요)")


def iter_transcripts(include_all, project_filter):
    """검색 대상 JSONL 경로를 최신 수정순으로 반환한다."""
    if not PROJECTS_DIR.is_dir():
        raise SystemExit(f"프로젝트 디렉토리 없음: {PROJECTS_DIR}")
    files = []
    for path in PROJECTS_DIR.rglob("*.jsonl"):
        relative = path.relative_to(PROJECTS_DIR)
        if project_filter and project_filter.lower() not in relative.parts[0].lower():
            continue
        # top-level 세션 = projects/{슬러그}/{uuid}.jsonl (2 파트). 서브에이전트·워크플로우는 더 깊다.
        if not include_all and len(relative.parts) != 2:
            continue
        files.append(path)
    files.sort(key=lambda item: item.stat().st_mtime, reverse=True)
    return files


def stringify(value):
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    try:
        return json.dumps(value, ensure_ascii=False)
    except (TypeError, ValueError):
        return str(value)


def extract_segments(record, include_thinking):
    """한 JSONL 레코드에서 (role, text) 세그먼트를 뽑는다."""
    segments = []
    record_type = record.get("type")
    message = record.get("message") or {}
    if record_type == "user":
        content = message.get("content")
        if isinstance(content, str):
            segments.append(("user", content))
        elif isinstance(content, list):
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "text":
                    segments.append(("user", block.get("text", "")))
                elif block.get("type") == "tool_result":
                    segments.append(("user", stringify(block.get("content"))))
    elif record_type == "assistant":
        content = message.get("content")
        if isinstance(content, list):
            for block in content:
                if not isinstance(block, dict):
                    continue
                block_type = block.get("type")
                if block_type == "text":
                    segments.append(("assistant", block.get("text", "")))
                elif block_type == "tool_use":
                    name = block.get("name", "tool")
                    segments.append(("assistant", f"[tool_use:{name}] " + stringify(block.get("input"))))
                elif block_type == "thinking" and include_thinking:
                    segments.append(("assistant", block.get("thinking", "")))
    return segments


def make_snippet(text, match, context):
    start = max(0, match.start() - context)
    end = min(len(text), match.end() + context)
    prefix = "…" if start > 0 else ""
    suffix = "…" if end < len(text) else ""
    body = re.sub(r"\s+", " ", text[start:end]).strip()
    return f"{prefix}{body}{suffix}"


def run():
    args = parse_args()
    flags = 0 if args.case else re.IGNORECASE
    try:
        regex = re.compile(args.pattern, flags)
    except re.error as error:
        raise SystemExit(f"정규식 오류: {error}")

    since = parse_date(args.since) if args.since else None
    until = parse_date(args.until) if args.until else None

    results = []
    for path in iter_transcripts(args.all, args.project):
        modified = datetime.fromtimestamp(path.stat().st_mtime)
        day = modified.date()
        if since and day < since:
            continue
        if until and day > until:
            continue
        project = path.relative_to(PROJECTS_DIR).parts[0]
        try:
            with path.open(encoding="utf-8") as handle:
                for line in handle:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        record = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    for role, text in extract_segments(record, args.thinking):
                        if args.role and role != args.role:
                            continue
                        if not text:
                            continue
                        match = regex.search(text)
                        if not match:
                            continue
                        results.append({
                            "file": str(path),
                            "project": project,
                            "date": modified.strftime("%Y-%m-%d %H:%M"),
                            "role": role,
                            "snippet": make_snippet(text, match, args.context),
                        })
                        if len(results) >= args.limit:
                            break
                    if len(results) >= args.limit:
                        break
        except OSError:
            continue
        if len(results) >= args.limit:
            break

    if args.count:
        print(len(results))
        return
    if args.as_json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return
    if not results:
        print("매치 없음")
        return
    for item in results:
        print(f"[{item['date']}] {item['project']} · {item['role']}")
        print(f"  {item['snippet']}")
        print(f"  → {item['file']}")
        print()
    note = " (limit 도달 — --limit 로 확대)" if len(results) >= args.limit else ""
    print(f"총 {len(results)}건{note}")


if __name__ == "__main__":
    try:
        run()
    except KeyboardInterrupt:
        sys.exit(130)
