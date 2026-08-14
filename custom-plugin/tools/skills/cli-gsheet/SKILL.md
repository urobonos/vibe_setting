---
name: cli-gsheet
description: 구글 시트 읽기·쓰기 스킬 (gspread + 서비스 계정). 시트 조회, 행 append, 셀 update, 정렬, 서식 복사를 다룬다. "구글 시트", "스프레드시트", "시트에 넣어", "시트 갱신" 등에서 사용. 쓰기는 append·update 만 — 행 삭제·시트 clear 는 스킬 범위 밖(사용자 직접).
---

# cli-gsheet — 구글 시트 CLI

서비스 계정으로 인증해 시트를 읽고 쓴다. 익명 CSV export(읽기 전용)와 달리 쓰기가 된다.

## 자격증명

| 항목 | 값 |
|---|---|
| 방식 | GCP 서비스 계정 (브라우저 동의 불필요 — 무인 루프 가능) |
| 키 파일 | `~/.claude/custom-plugin/tools/.token/gsheet.token` (JSON, `.token` 확장자로 gitignore) |
| 계정 | `claude-googlesheet@gen-lang-client-0636559980.iam.gserviceaccount.com` |
| GCP 프로젝트 | `gen-lang-client-0636559980` |
| 스코프 | `https://www.googleapis.com/auth/spreadsheets` |
| 의존 | `pip install gspread google-auth` |

**확장자가 `.token` 이어야 한다.** gitignore 규칙이 `custom-plugin/**/*.token` 이라 `.json` 으로 두면 커밋된다.

### 권한 부여

키만으로는 아무 시트도 못 연다. **대상 시트마다** 공유에서 위 계정 이메일을 **편집자**로 추가해야 한다.

### 키 갱신·폐기

1. GCP 콘솔 → `IAM 및 관리자` → `서비스 계정` → 해당 계정 → `키` 탭
2. 기존 키 삭제 → `키 추가 → JSON`
3. 받은 파일을 위 경로에 같은 이름으로 저장 (코드 변경 불요)

시트 공유는 계정 단위라 키를 갈아도 유지된다. 계정 자체를 회수하려면 시트 공유에서 빼면 된다.

> **키 내용을 대화·이슈·커밋에 붙여넣지 마라.** 세션 transcript(`~/.claude/projects/*.jsonl`)에 평문으로 남아 폐기·재발급해야 한다. 실제로 2026-08-14 에 한 번 발생했다 — 경로만 주고받는다.

## 등록된 시트

| 용도 | 문서 ID | 탭 |
|---|---|---|
| 로컬 관리자 WBS | `1ef2TzudeRfXzdAyKH7AmYwACFSjVgmafYHPMGwKurHQ` | `개발WBS`(정본 547행) · `요약`(보고용) |

`개발WBS` 는 `/tools:wbs-sync` 의 상태·담당자 SSOT 다. 열 구성·동기화 규약은 `custom-plugin/tools/commands/wbs-sync.md` SSOT.

## 접속

```python
import gspread
from google.oauth2.service_account import Credentials

KEY = r'C:\Users\PV\.claude\custom-plugin\tools\.token\gsheet.token'
cred = Credentials.from_service_account_file(KEY, scopes=['https://www.googleapis.com/auth/spreadsheets'])
sh = gspread.authorize(cred).open_by_key('{문서 ID}')
ws = sh.worksheet('{탭명}')
```

## 쓰기 규약 (필수)

| 허용 | 금지 |
|---|---|
| `append_rows` — 행 추가 | `delete_rows` — 행 삭제 |
| `update_cell` / `batch_update` — 지정 셀 | `clear()` — 시트 전체 비우기 |
| `sortRange` — 정렬 (스냅샷 후) | 범위 미지정 대량 덮어쓰기 |

**쓰기 전 스냅샷을 뜬다.** `ws.get_all_values()` 를 TSV 로 저장해두면 되돌릴 수 있다. 시트는 되돌리기가 로컬 파일보다 어렵다.

**삭제는 스킬 범위 밖이다.** 폐기 처리는 삭제가 아니라 상태값(`DROPPED`)으로 표기한다 — 이력이 남고 되돌릴 수 있다.

## 자주 쓰는 조작

### append 후 서식 맞추기

`append_rows` 는 값만 넣는다. 서식(배경색·폰트·테두리)이 안 따라와 기존 행과 달라 보인다. 같은 그룹의 기존 행에서 `copyPaste` 로 서식만 복사한다.

```python
sh.batch_update({'requests': [{'copyPaste': {
    'source':      {'sheetId': ws.id, 'startRowIndex': src-1, 'endRowIndex': src,
                    'startColumnIndex': 0, 'endColumnIndex': ncol},
    'destination': {'sheetId': ws.id, 'startRowIndex': a-1,   'endRowIndex': b,
                    'startColumnIndex': 0, 'endColumnIndex': ncol},
    'pasteType': 'PASTE_FORMAT'}}]})
```

> **소스 행 번호를 셀 때 오프셋을 조심해라.** `enumerate(values[1:], start=2)` 로 "그룹 첫 등장 행" 을 잡으면 직전 그룹의 마지막 행을 집는다 (2026-08-14 실측 — JPA-02 에 JPA-01 색이 칠해졌다). 뽑은 행의 그룹 값을 반드시 재확인한다.

### ID 정렬

문자열 정렬은 `JPA-02-9 > JPA-02-10` 이 된다. 숫자 키 열을 임시로 만들어 정렬하고 지운다.

```python
ws.update([[phase*10000 + num] for ...], 'M2:M548', value_input_option='RAW')
sh.batch_update({'requests': [{'sortRange': {
    'range': {'sheetId': ws.id, 'startRowIndex': 1, 'endRowIndex': last,
              'startColumnIndex': 0, 'endColumnIndex': keycol+1},
    'sortSpecs': [{'dimensionIndex': keycol, 'sortOrder': 'ASCENDING'}]}}]})
ws.batch_clear(['M2:M548'])
```

`sortRange` 는 서식도 함께 옮긴다.

### 범위 표기 함정

`ws.batch_update` / `ws.update` / `ws.batch_clear` 는 **이미 워크시트 스코프**다. `'탭명!A1'` 처럼 접두를 붙이면 `Unable to parse range: '탭'!탭!A1` 로 400 이 난다. 탭명 접두는 `sh.values_batch_*`(스프레드시트 스코프)에서만 쓴다.

## §3 Checkpoint 우선 적용

- 읽기 = 비대상
- **행 추가·셀 갱신 = 외부 시스템 변경.** 대상·건수를 보고하고 승인 후 실행
- **정렬·대량 갱신 = 사용자 명시 승인 필수.** 스냅샷 먼저
- 행 삭제·시트 clear = Claude 자동 실행 금지 (사용자 직접)

## SSOT

| SSOT | 역할 |
|---|---|
| `~/.claude/custom-plugin/tools/.token/gsheet.token` | 자격증명 (gitignore) |
| `custom-plugin/tools/commands/wbs-sync.md` | WBS 시트 동기화 규약 |
| 본 파일 | 접속 방식·쓰기 규약·조작 패턴 |
