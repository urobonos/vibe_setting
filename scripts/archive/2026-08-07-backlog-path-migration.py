#!/usr/bin/env python3
"""
2026-08-07-backlog-path-migration.py — backlog 본문 저장처 이관 스크립트 (기록용, 재실행 금지)

배경: 2026-08-06 설계 결정에 따라 backlog 본문 저장처를
  `~/.claude/projects/{project}/memory/backlog_{slug}.md`
  → `~/.claude/docs/working/backlog/{yyyy-mm-dd}-{slug}.md`
로 이관했다(298건, 2026-08-07 실행). 이 스크립트는 **그때 실제로 실행한 로직을 사후 재구성**한 것이다
(콜드리뷰 M5 — "298건 비가역 이관을 수행한 스크립트가 커밋에 없다. 재현·감사·역이관 수단이 없다").

**실행하지 마라 — 원본 파일은 이미 이동 완료됐고 소스 경로가 비어 있어 forward 모드는 0건 처리로
끝난다(안전하지만 무의미).** 이 파일의 목적은 (1) 감사(무엇을, 왜, 어떤 규칙으로 옮겼는지 코드로
고정) (2) 역이관(rollback, 마이그레이션 맵을 갖고 신 경로 → 구 경로로 되돌림) (3) 향후 유사 이관 시
재사용 가능한 뼈대 제공 — 3가지다.

## 이관 규칙 요약
- 날짜 소스 3단 fallback: frontmatter `created:` → `modified:` → 파일 mtime.
- 파일명 충돌(동일 date+slug, 서로 다른 project) 시 `--{product}` suffix. `product` 는
  frontmatter `product:` 필드가 **아니라** origin project 의 product-resolver.sh 관례값(cwd
  basename) — 실측 4쌍 전부 frontmatter `product:` 값이 쌍 안에서 동일해 그 필드로는 충돌이
  해소되지 않았다(task-docs/SKILL.md §파일 양식 §"파일명 충돌 규약" SSOT).
- 인덱스(MEMORY.md/BACKLOG.md) href 갱신은 slug 단위 전수 치환 — 링크 텍스트(`[slug]`)·요약 텍스트는
  불변, `(href)` 부분만 `../../../docs/working/backlog/{target}.md` 로 치환한다. 충돌 slug(동일 slug,
  다른 project)는 **그 index 파일 자신의 origin project 와 일치하는 target** 을 선택한다(cross-project
  참조가 실측 0건이라 이 방식으로 전건 해소됐다 — ambiguous 케이스가 나오면 치환하지 않고 보고한다).

## 산출물(감사 스냅샷)
전체 298건 매핑 표 = `~/.claude/docs/claude-harness/output/verification/2026-08-06-backlog-path-code-review/2026-08-07-migration-map.md`
(project/원파일명/date_src/target파일명/충돌비고 6열, 이 스크립트의 `load_migration_map()` 이 그 표를 파싱한다)

## 사용법 (참고용 — §3 승인 없이 rollback 실행 금지)
    python 2026-08-07-backlog-path-migration.py --mode audit     # 매핑 재검증만(읽기 전용)
    python 2026-08-07-backlog-path-migration.py --mode forward   # (이미 실행됨, no-op 이 정상)
    python 2026-08-07-backlog-path-migration.py --mode rollback  # 신 경로 → 구 경로 역이관(§3, 미실행)
"""
import argparse
import glob
import os
import re

HOME = os.path.expanduser("~/.claude")
MIGRATION_MAP_PATH = os.path.join(
    HOME, "docs", "claude-harness", "output", "verification",
    "2026-08-06-backlog-path-code-review", "2026-08-07-migration-map.md",
)
NEW_DIR = os.path.join(HOME, "docs", "working", "backlog")
PROJECTS_ROOT = os.path.join(HOME, "projects")

ROW_RE = re.compile(
    r'^\|\s*\d+\s*\|\s*([^|]+?)\s*\|\s*`([^`]+)`\s*\|\s*(\w+)\s*\|\s*`([^`]+)`\s*\|\s*(.*?)\s*\|\s*$'
)


def load_migration_map(path=MIGRATION_MAP_PATH):
    """migration-map.md 의 '전체 매핑(298건)' 표를 파싱한다.
    반환: [{"project":..., "orig_name":..., "date_src":..., "target_name":..., "note":...}, ...]

    M11(2026-08-07 콜드리뷰 R2) — 파싱 결과 0건이면 예외를 던진다. 이전엔 표 헤더 문구
    ("## 전체 매핑")가 바뀌거나 파일 경로가 틀려도 조용히 빈 리스트를 반환해 rollback 이
    "대상 0건" 으로 아무 일도 안 하고 성공한 것처럼 끝났다 — 실패와 무대상을 구분 못 했다.
    """
    records = []
    with open(path, encoding="utf-8") as f:
        in_full_table = False
        for line in f:
            if line.startswith("## 전체 매핑"):
                in_full_table = True
                continue
            if not in_full_table:
                continue
            m = ROW_RE.match(line.rstrip("\n"))
            if m:
                project, orig_name, date_src, target_name, note = m.groups()
                records.append({
                    "project": project,
                    "orig_name": orig_name,
                    "date_src": date_src,
                    "target_name": target_name,
                    "note": note,
                })
    if not records:
        raise RuntimeError(
            f"매핑 파싱 결과 0건 — {path} 의 '## 전체 매핑' 표 형식이 바뀌었거나 파일을 못 찾았을 가능성. "
            "빈 리스트로 계속 진행하면 forward/rollback 이 '대상 0건'을 성공으로 오인한다."
        )
    return records


def _completed_lifecycle_path(target_name):
    """target_name 이 이미 hook(move_backlog_to_tasks)을 거쳐 tasks/{product}/tasks/{date}/backlog/
    로 정상 이동했는지 확인한다(M10, 2026-08-07 콜드리뷰 R2). docs/working/backlog/ 에도 구 경로에도
    없다고 해서 유실이 아니다 — status:done 파일은 이 hook 이 완료 시 지운다. 실측 사례:
    force-mapping-patch 가 docs/working/backlog/ 도 구 경로도 아닌
    qa-scanner-v2_3_1/tasks/20260807/backlog/2026-05-26-force-mapping-patch.md 에 있었다.
    반환: 찾은 절대경로 또는 None.
    """
    pattern = os.path.join(HOME, "docs", "*", "tasks", "*", "backlog", target_name)
    hits = glob.glob(pattern)
    return hits[0] if hits else None


def audit(records):
    print(f"매핑 레코드: {len(records)}건")
    by_date_src = {}
    for r in records:
        by_date_src[r["date_src"]] = by_date_src.get(r["date_src"], 0) + 1
    print("date_src 분포:", by_date_src)

    suffixed = [r for r in records if r["note"]]
    print(f"suffix 적용(충돌 해소): {len(suffixed)}건")

    not_in_new_dir = [r for r in records if not os.path.isfile(os.path.join(NEW_DIR, r["target_name"]))]
    # M10 — "신 경로에 없음" 을 "완료돼 tasks/ 로 이동함"(정상) 과 "진짜 유실"(비정상)로 분리한다.
    completed, truly_missing = [], []
    for r in not_in_new_dir:
        hit = _completed_lifecycle_path(r["target_name"])
        if hit:
            completed.append((r, hit))
        else:
            truly_missing.append(r)
    print(f"신 경로에 없음: {len(not_in_new_dir)}건 — 그중 완료(tasks/ 로 정상 이동) {len(completed)}건 / 진짜 유실 {len(truly_missing)}건")
    for r, hit in completed[:20]:
        print(f"  COMPLETED: {r['target_name']} -> {hit}")
    for r in truly_missing[:20]:
        print("  MISSING:", r["target_name"])
    return records


def forward(records, execute=False):
    """구 경로 -> 신 경로. 이미 실행 완료 상태라 정상적으로는 대상 0건(소스 부재)이어야 한다.
    M9(2026-08-07 콜드리뷰 R2) — rollback 과 동일하게 목적지 존재 검사를 추가한다. 검사 없이
    os.rename 을 그대로 쓰면 Windows 는 FileExistsError 로 중단되고 POSIX 는 무경고 덮어쓴다 —
    둘 다 위험하다(전자는 부분 실행 후 알 수 없는 상태로 죽고, 후자는 조용한 데이터 손실).
    """
    src_tmpl = os.path.join(PROJECTS_ROOT, "{project}", "memory", "{orig_name}")
    planned, skipped = [], []
    for r in records:
        s = src_tmpl.format(project=r["project"], orig_name=r["orig_name"])
        d = os.path.join(NEW_DIR, r["target_name"])
        if not os.path.isfile(s):
            continue
        if os.path.exists(d):
            skipped.append((s, d))
            continue
        planned.append((s, d))
    print(f"forward 대상(구 경로에 아직 남아있는 것): {len(planned)}건 / 목적지 이미 존재라 SKIP: {len(skipped)}건")
    for s, d in planned[:20]:
        print(f"  {s} -> {d}")
    for s, d in skipped[:20]:
        print(f"  SKIP(대상 이미 존재, 덮어쓰지 않음): {d}")
    if execute:
        moved = 0
        for s, d in planned:
            os.rename(s, d)
            moved += 1
        print(f"이동 {moved}건 / SKIP {len(skipped)}건")
        if len(skipped) > 0:
            raise SystemExit(1)
    else:
        print("--execute 없이는 실제 이동하지 않는다(dry-run).")


# H2(2026-08-07 콜드리뷰 R2) — 인덱스 href 미복구 경고를 dry-run 전용에서 공통 위치로 승격한다.
# 이전엔 else(dry-run) 분기에만 있어 --execute 를 쓴 사람은 이 문장을 한 번도 못 봤다. rollback 직후
# 인덱스 href(170개)가 전부 존재하지 않는 경로를 가리키게 되고, 신 경로만 지원하는 현재 hook 은
# status:done 파일을 찾지 못해 done 처리가 전건 무동작이 된다 — 그런데 이 반쪽 상태를 알리는 신호가
# 없었다. execute 모드는 추가로 명시 토큰(--i-acknowledge-index-not-reverted)을 요구한다 — 화면에
# 경고를 찍는 것만으론 안 읽고 지나칠 수 있어서, 실행 자체를 토큰 없이는 거부한다.
_INDEX_WARNING = (
    "[경고] 이 스크립트는 인덱스(MEMORY.md/BACKLOG.md) href 를 되돌리지 않는다 — 파일만 구 경로로 "
    "이동한다. rollback 후 인덱스 href(약 170개)는 전부 존재하지 않는 경로를 가리키게 되고, 신 경로만 "
    "지원하는 hooks/backlog-lifecycle.sh 는 그 status:done 파일을 찾지 못해 완료 처리가 무동작된다. "
    "인덱스 처리 방침(수동 복원 / 백업에서 인덱스도 함께 복원 / 방치)을 실행 전에 결정하라."
)


def rollback(records, execute=False, ack_index=False):
    """신 경로 -> 구 경로. 비가역 §3 — 사용자 명시 승인 없이 --execute 사용 금지."""
    print(_INDEX_WARNING)
    planned, skipped = [], []
    for r in records:
        s = os.path.join(NEW_DIR, r["target_name"])
        d = os.path.join(PROJECTS_ROOT, r["project"], "memory", r["orig_name"])
        if not os.path.isfile(s):
            continue
        if os.path.exists(d):
            skipped.append((s, d))
            continue
        planned.append((s, d))
    print(f"rollback 대상: {len(planned)}건 / 목적지 이미 존재라 SKIP: {len(skipped)}건")
    for s, d in planned[:20]:
        print(f"  {s} -> {d}")
    for s, d in skipped[:20]:
        print(f"  SKIP(대상 이미 존재, 덮어쓰지 않음): {d}")
    if execute:
        # H1(2026-08-07 콜드리뷰 R2) — "백업을 projects/*/memory/ 로 먼저 복원 후 rollback" 같은
        # 자연스러운 복구 순서에서는 대상 전부가 SKIP 으로 빠지는데, 이전 코드는 moved 건수를 세지
        # 않고 무조건 "rollback 실행 완료: {len(planned)}건"(=SKIP 포함 전체 계획 건수)을 찍어 0건
        # 이동을 성공으로 보고했다. moved 와 skipped 를 분리해서 찍고, SKIP>0 이면 non-zero exit.
        if not ack_index:
            print("[BLOCKED] --i-acknowledge-index-not-reverted 없이는 --execute 를 거부한다 (위 경고 참조).")
            raise SystemExit(2)
        moved = 0
        for s, d in planned:
            os.rename(s, d)
            moved += 1
        print(f"이동 {moved}건 / SKIP {len(skipped)}건")
        if len(skipped) > 0:
            raise SystemExit(1)
    else:
        print("--execute 없이는 실제 되돌리지 않는다(dry-run).")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["audit", "forward", "rollback"], default="audit")
    ap.add_argument("--execute", action="store_true", help="실제 파일 이동을 수행한다(기본은 dry-run)")
    # M12(2026-08-07 콜드리뷰 R2) — 297건 비가역 rename 의 안전장치가 --execute 플래그 하나뿐이었다.
    # dry-run 결과는 이 스크립트 구조상 항상 먼저 출력되지만(planned 리스트는 execute 분기 이전에
    # 항상 찍힌다), 그것과 별개로 "본인이 무엇을 승인하는지" 문자열로 재확인시킨다 — §3 대상이라
    # 후속 자동화가 이 스크립트를 그대로 재사용해 --execute 만 붙여 돌리는 사고를 막는다.
    ap.add_argument("--confirm", metavar="TOKEN", default="",
                     help="rollback --execute 에는 정확히 'ROLLBACK-297-IRREVERSIBLE' 을 요구한다")
    ap.add_argument("--i-acknowledge-index-not-reverted", action="store_true", dest="ack_index",
                     help="rollback --execute 필수 — 인덱스 href 미복구를 인지했다는 명시 토큰")
    args = ap.parse_args()

    records = load_migration_map()
    if args.mode == "audit":
        audit(records)
    elif args.mode == "forward":
        forward(records, execute=args.execute)
    elif args.mode == "rollback":
        if args.execute and args.confirm != "ROLLBACK-297-IRREVERSIBLE":
            print("[BLOCKED] rollback --execute 에는 --confirm ROLLBACK-297-IRREVERSIBLE 이 정확히 필요하다 (§3).")
            raise SystemExit(2)
        rollback(records, execute=args.execute, ack_index=args.ack_index)


if __name__ == "__main__":
    main()
