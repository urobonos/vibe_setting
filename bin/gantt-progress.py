#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gantt-progress.py — 간트 진행률 문서 폐기·완료 마킹(T1) + 미완 출력(T2).

SSOT 문서: ~/.claude/docs/참조문서/간트/jypark-gant-progress-verification.md
설계 원칙: '## 현재 진행률 상세' 표를 진실源(SSOT)으로 삼아 레이어1(모듈별 추세
마지막 열)·작성정보 전체%를 재집계한다. 폐기·완료는 진행률 100%로 동일하나 상태
라벨이 다르다(⛔ vs ✅) — 카운트는 '완료+폐기'로 합산(문서 기존 규약).

사용:
  gantt-progress.py retire MOD-11-011[,MOD-10-009] "사유"   # 폐기 마킹 (100% + ⛔)
  gantt-progress.py done   MOD-15-007 "사유"                # 완료 마킹 (100% + ✅)
  gantt-progress.py show                                    # 미완(🟡·❌)만 모듈별 출력
공통 옵션:
  --doc PATH     대상 문서 (기본 = SSOT)
  --date Y-M-D   레이어2 주차 계산 기준일 (기본 = 오늘)
  --dry-run      파일 미수정, 변경 요약만 stdout 출력 (검증용)
"""
import sys, re, argparse, datetime, os

DEFAULT_DOC = os.path.expanduser("~/.claude/docs/참조문서/간트/jypark-gant-progress-verification.md")
RETIRE_LABEL = "⛔ 폐기·N/A"
DONE_LABEL = "✅ 완료"
MODULES = ["MOD-01", "MOD-02", "MOD-03", "MOD-04", "MOD-06", "MOD-07",
           "MOD-10", "MOD-11", "MOD-15", "MOD-18", "MOD-19", "MOD-20"]


def split_cells(line):
    """마크다운 표 행을 셀로 분리 (이스케이프 \\| 는 분리 안 함)."""
    return re.split(r'(?<!\\)\|', line.rstrip('\n'))


def join_cells(parts):
    return '|'.join(parts)


def progress_of(cells):
    m = re.search(r'(\d+)\s*%', cells[3])
    return int(m.group(1)) if m else 0


def module_of(wbs):
    return '-'.join(wbs.split('-')[:2])  # MOD-01-005 -> MOD-01


def iso_week_tag(d):
    """W{nn}({MM-DD}) — 문서 레이어2 주차 열 규약."""
    iso = d.isocalendar()
    return f"W{iso[1]:02d}({d.strftime('%m-%d')})"


def parse_detail_rows(lines):
    """'## 현재 진행률 상세' 표의 {wbs_id: (line_idx, cells)} 반환."""
    rows = {}
    in_detail = False
    for i, line in enumerate(lines):
        if line.startswith('## 현재 진행률 상세'):
            in_detail = True
            continue
        if in_detail and line.startswith('## '):
            break
        if in_detail:
            m = re.match(r'^\|\s*(MOD-\d+-\d+)\s*\|', line)
            if m:
                rows[m.group(1)] = (i, split_cells(line))
    return rows


def recompute(detail_rows):
    """상세표 기반 모듈별% · 전체% · 카운트 재집계."""
    mod_items = {m: [] for m in MODULES}
    done_retire = partial = incomplete = 0
    total_pct_sum = 0
    for wbs, (idx, cells) in detail_rows.items():
        p = progress_of(cells)
        total_pct_sum += p
        mod = module_of(wbs)
        if mod in mod_items:
            mod_items[mod].append(p)
        if p >= 100:
            done_retire += 1
        elif p >= 50:
            partial += 1
        else:
            incomplete += 1
    mod_pct = {m: (round(sum(ps) / len(ps), 1) if ps else 0.0) for m, ps in mod_items.items()}
    total = len(detail_rows)
    total_pct = round(total_pct_sum / total, 1) if total else 0.0
    return mod_pct, total_pct, done_retire, partial, incomplete, total


def mark_detail(cells, kind, reason, date_str):
    """상세표 행 셀 갱신: 진행률 100% + 상태 라벨 + 작업명 끝 주석."""
    label = RETIRE_LABEL if kind == 'retire' else DONE_LABEL
    tag = '폐기' if kind == 'retire' else '✅완료'
    cells[3] = ' 100% '
    cells[4] = f' {label} '
    cells[2] = cells[2].rstrip() + f' **[{tag} {date_str} · {reason}]** '
    return cells


def update_layer1(lines, mod_pct, total_pct):
    """레이어1 표의 마지막 데이터 열을 상세표 재집계값으로 갱신."""
    for i, line in enumerate(lines):
        m = re.match(r'^\|\s*(MOD-\d+)\s*\|', line)
        if m and m.group(1) in mod_pct:
            cells = split_cells(line)
            cells[-2] = f" {mod_pct[m.group(1)]:.1f}% "
            lines[i] = join_cells(cells)
        elif re.match(r'^\|\s*\*\*전체\*\*\s*\|', line):
            cells = split_cells(line)
            cells[-2] = f" **{total_pct:.1f}%** "
            lines[i] = join_cells(cells)
    return lines


def update_meta(lines, total_pct, done_retire, partial, incomplete, total):
    """작성정보 '전체 진행률' 행의 % + 카운트 갱신."""
    for i, line in enumerate(lines):
        if re.match(r'^\|\s*전체 진행률\s*\|', line):
            new = re.sub(r'약 [\d.]+%', f'약 {total_pct:.1f}%', line, count=1)
            new = re.sub(r'완료\+폐기 \d+ · 부분 \d+ · 미완 \d+ / \d+항목',
                         f'완료+폐기 {done_retire} · 부분 {partial} · 미완 {incomplete} / {total}항목',
                         new, count=1)
            lines[i] = new
            break
    return lines


def append_layer2(lines, week_tag, wbs, reason, prev_pct, kind):
    """레이어2 변경 로그 표 끝에 마킹 이력 행 삽입."""
    label = '폐기' if kind == 'retire' else '✅완료'
    header_idx = None
    for i, line in enumerate(lines):
        if re.match(r'^\|\s*주차\s*\|\s*WBS ID\s*\|', line):
            header_idx = i
            break
    if header_idx is None:
        return lines
    last = header_idx + 1  # 구분선
    j = header_idx + 2
    while j < len(lines) and lines[j].lstrip().startswith('|'):
        last = j
        j += 1
    newrow = (f"| {week_tag} | {wbs} | (스크립트 마킹) "
              f"**[{label} · {reason}]** | {prev_pct}→100% | (스크립트 마킹) |")
    lines.insert(last + 1, newrow)
    return lines


def cmd_show(lines):
    detail = parse_detail_rows(lines)
    pending = []
    for wbs in sorted(detail.keys()):
        idx, cells = detail[wbs]
        p = progress_of(cells)
        if p < 100:
            status = cells[4].strip()
            name = re.sub(r'\*\*\[.*?\]\*\*', '', cells[2]).strip()
            pending.append((wbs, status, p, name[:60]))
    mod_pct, total_pct, dr, pa, inc, total = recompute(detail)
    print(f"## 잔여 (🟡{pa}·❌{inc}) — 전체 {total_pct:.1f}%")
    if not pending:
        print("\n(미완 항목 없음 — 전 항목 100%)")
        return
    cur_mod = None
    for wbs, status, p, name in pending:
        mod = module_of(wbs)
        if mod != cur_mod:
            cur_mod = mod
            print(f"\n### {mod} ({mod_pct.get(mod, 0):.1f}%)")
        print(f"{wbs} {status} {p}% · {name}")


def cmd_mark(lines, kind, wbs_ids, reason, date):
    detail = parse_detail_rows(lines)
    week_tag = iso_week_tag(date)
    date_str = date.strftime('%Y-%m-%d')
    changed = []
    for wbs in wbs_ids:
        if wbs not in detail:
            print(f"ERROR: WBS ID '{wbs}' 상세표에 없음 — 중단", file=sys.stderr)
            return None, None
        idx, cells = detail[wbs]
        prev = progress_of(cells)
        cells = mark_detail(cells, kind, reason, date_str)
        lines[idx] = join_cells(cells)
        detail[wbs] = (idx, cells)
        changed.append((wbs, prev))
    # 재집계 (상세표 SSOT)
    mod_pct, total_pct, dr, pa, inc, total = recompute(detail)
    lines = update_layer1(lines, mod_pct, total_pct)
    lines = update_meta(lines, total_pct, dr, pa, inc, total)
    for wbs, prev in changed:
        lines = append_layer2(lines, week_tag, wbs, reason, prev, kind)
    # 무결성 검증
    integrity_ok = (dr + pa + inc == total == 183)
    report = {
        'changed': changed, 'mod_pct': mod_pct, 'total_pct': total_pct,
        'done_retire': dr, 'partial': pa, 'incomplete': inc, 'total': total,
        'integrity_ok': integrity_ok, 'week_tag': week_tag,
        'affected_mods': sorted({module_of(w) for w, _ in changed}),
    }
    return lines, report


def main():
    ap = argparse.ArgumentParser(description="간트 진행률 폐기·완료 마킹 + 미완 출력")
    ap.add_argument('cmd', choices=['retire', 'done', 'show'])
    ap.add_argument('wbs', nargs='?', help='MOD-NN-NNN[,MOD-NN-NNN...]')
    ap.add_argument('reason', nargs='?', default='', help='사유 (retire/done 필수)')
    ap.add_argument('--doc', default=DEFAULT_DOC)
    ap.add_argument('--date', default=None, help='YYYY-MM-DD (레이어2 주차 기준일)')
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()

    with open(args.doc, encoding='utf-8') as f:
        lines = f.read().split('\n')

    if args.cmd == 'show':
        cmd_show(lines)
        return

    # retire / done
    if not args.wbs or not args.reason:
        print("ERROR: retire/done 은 WBS ID 와 사유가 필수", file=sys.stderr)
        sys.exit(2)
    wbs_ids = [w.strip().upper() for w in args.wbs.split(',') if w.strip()]
    date = (datetime.datetime.strptime(args.date, '%Y-%m-%d').date()
            if args.date else datetime.date.today())

    new_lines, report = cmd_mark(lines, args.cmd, wbs_ids, args.reason, date)
    if report is None:
        sys.exit(1)

    kind_ko = '폐기' if args.cmd == 'retire' else '완료'
    print(f"[{kind_ko} 마킹] {', '.join(w for w, _ in report['changed'])}  주차={report['week_tag']}")
    for wbs, prev in report['changed']:
        print(f"  ✓ 상세표 {wbs} → 100% · 상태 '{RETIRE_LABEL if args.cmd=='retire' else DONE_LABEL}' (이전 {prev}%)")
    print("  ✓ 레이어1 재계산: " + ', '.join(f"{m}={report['mod_pct'][m]:.1f}%" for m in report['affected_mods']))
    print(f"  ✓ 전체 진행률: {report['total_pct']:.1f}%")
    print(f"  ✓ 레이어2 {len(report['changed'])}행 append")
    ok = report['integrity_ok']
    print(f"  {'✓' if ok else '✗'} 무결성: 완료+폐기{report['done_retire']}·🟡{report['partial']}·❌{report['incomplete']} = {report['total']} "
          f"{'OK' if ok else '**불일치! 183 아님 — 적용 중단 권장**'}")

    if not ok:
        print("무결성 실패 — 파일 미수정", file=sys.stderr)
        sys.exit(1)
    if args.dry_run:
        print("\n[dry-run] 파일 미수정 — 위 변경이 실제 적용될 내용입니다.")
        return
    with open(args.doc, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))
    print(f"\n적용 완료: {args.doc}")


if __name__ == '__main__':
    main()
