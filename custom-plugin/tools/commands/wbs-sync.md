---
description: 구글 시트 → WBS 간트(xlsx) 상태·담당자 동기화 한 방 실행 — 시트 캐시 → tsv/csv → xlsx 재생성 + 결과 요약
---

# /tools:wbs-sync

구글 시트의 태스크 상태·담당자를 WBS 간트 xlsx 에 반영한다. 3 단계를 한 번에 돌리고 결과를 요약한다.

## 실행

Claude 가 **직접** 아래 한 줄을 Bash 로 호출한다 (§4.2 실행 책임 — 사용자에게 떠넘기지 않는다).

```bash
bash ~/.claude/custom-plugin/tools/scripts/wbs-sheet-sync.sh
```

레포 밖에서 호출하거나 다른 레포를 대상으로 할 때만 인자를 준다.

```bash
bash ~/.claude/custom-plugin/tools/scripts/wbs-sheet-sync.sh /c/Works/hongcafe_local_athena
```

## 무엇이 도는가

| 단계 | 스크립트 (레포 `docs/wbs/tools/`) | 입력 → 출력 |
|---|---|---|
| 1 | `sheet-sync.py` | 구글 시트 CSV export → `2026-08-12-sheet-owner-status.csv` 캐시 |
| 2 | `build-tracker.py` | `phases/*.md` + 캐시 → `…-wbs-gantt.tsv` · `.csv` |
| 3 | `build-xlsx.py` | tsv → `…-wbs-gantt.xlsx` (서식·드롭다운·요약 시트) |
| 4 | `build-menu-summary.py` | 간트 xlsx → `2026-08-12-wbs-menu-summary.xlsx` (비개발자 보고용 3시트) |

**로직은 레포 쪽 4 스크립트가 SSOT 다.** 본 커맨드와 러너는 순서·실패 분기·요약만 담당한다.

4단계는 간트 xlsx 를 소스로 읽으므로 반드시 3단계 뒤에 온다. 스크립트가 없는 레포에서는 건너뛴다.

## SSOT 경계 — 무엇이 어디서 오는가

| 열 | SSOT | 비고 |
|---|---|---|
| 상태 · 담당자 | **구글 시트** | 시트값이 `Pending` 이 아닐 때만 상태를 덮는다 (`phases/*.md` 의 `Blocked` 보존) |
| 그 외 전 열 | `phases/*.md` | 태스크 정의. 시트가 건드리지 않는다 |

간트 xlsx 는 파생물이다. **직접 편집하면 다음 실행에 소멸한다** — 상태·담당자는 시트에서, 나머지는 `phases/*.md` 에서 고친다.

## 실패했을 때

| 메시지 | 원인 | 조치 |
|---|---|---|
| `[중단] … 잠겨 있다` | Excel 이 xlsx 를 열고 있음 | 파일 닫고 재실행. tsv/csv 는 이미 갱신됨 |
| `시트 HTTP 401` / `로그인 HTML` | 시트가 비공개로 되돌아감 | 공유 → "링크가 있는 모든 사용자 · 뷰어" |
| `알 수 없는 상태값 "X"` | 시트에 매핑 밖 어휘 등장 | `build-tracker.py` 의 `STATUS_MAP` 에 추가 (드롭다운·요약 버킷도 같이) |
| `시트에만 있는 ID` | 시트와 `phases/*.md` 가 어긋남 | 어느 쪽이 맞는지 확인 후 정렬 |
| `시트 헤더 누락` | 시트 열 이름 변경 | 실제 헤더가 함께 찍힌다. 시트를 되돌리거나 `NEED` 수정 |

전 경로가 비영 exit 로 크게 실패한다 — 조용히 틀린 숫자를 남기지 않는다.

## 무변경 회차

데이터가 안 바뀐 회차에는 xlsx 만 재생성 타임스탬프로 바이너리 diff 가 난다. 러너가 3중 조건(데이터 3종 무변경 + `docs/wbs` 변경분이 xlsx 단 하나 + git 레포)을 확인하고 되돌린다. 사람이 손댄 xlsx 는 삼키지 않는다.

## 반복 실행

`/loop 5m` 으로 무인 반복할 때 이 커맨드를 그대로 쓴다.

```
/loop 5m /tools:wbs-sync
```

## 보고

실행 후 결론 1~2줄 + 상태·담당자 카운트만 보고한다 (CLAUDE.md §4.4 응답 간결). 변경 0건이면 "무변경" 한 줄로 끝낸다 — 같은 표를 매 5분 다시 그리지 않는다.
