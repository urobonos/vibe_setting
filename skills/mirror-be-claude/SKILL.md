---
name: mirror-be-claude
description: >
  be 프로젝트(`hongcafe_global_backend`) 미러링 검증·강제 스킬. 2 영역
  통합 — (1) CLAUDE.md ↔ 글로벌 미러본 양방향 동기화, (2) api-docs 3-way
  (글로벌 ↔ be ↔ hongcafe_global_docs) 정합 검증. PostToolUse hook
  (`mirror-claude-md.sh`) 의 수동 진입점 + mirror-docs.sh 폐기 (2026-05-18)
  후 api-docs 3-way 의 단일 검증 진입점.
  3개 모드 — `verify` (양 영역 diff + 3-way 정합 비교), `sync-from-be`
  (be → 글로벌 + docs 강제), `sync-from-global` (글로벌 → be 강제, §3 매칭).
  자동 트리거 (be 지침·api-docs 미러·동기화 키워드) + `/mirror-be-claude`
  슬래시 커맨드. 호출 주체 = Claude 본체. 산출물 없음 (보고만).
triggers:
  - "be CLAUDE 미러"
  - "be CLAUDE.md 미러"
  - "be 지침 미러"
  - "be 지침 동기화"
  - "be claude 동기화"
  - "be 미러 검증"
  - "api-docs 미러"
  - "api-docs 3-way"
  - "api-docs 정합"
  - "be 미러링 검증"
  - "/mirror-be-claude"
version: 1.1.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Mirror BE Skill (CLAUDE.md + api-docs)

be 프로젝트 (`hongcafe_global_backend`) 의 2 영역 미러링 상태를 검증·강제한다.

| 영역 | 대상 |
|------|------|
| **(1) CLAUDE.md** | `C:/Works/hongcafe_global_backend/CLAUDE.md` ↔ `~/.claude/mirrors/hongcafe_global_backend/CLAUDE.md` (양방향) |
| **(2) api-docs 3-way** | `~/.claude/docs/hongcafe_global_backend/api-docs/` ↔ `C:/Works/hongcafe_global_backend/api-docs/` ↔ `C:/Works/hongcafe_global_docs/be/api-docs/` |

> **[용도 한정]** 본 스킬은 **수동 진입점** 이다. CLAUDE.md 자동 동기화는 PostToolUse hook (`mirror-claude-md.sh`) 가 담당. api-docs 자동 미러링은 2026-05-18 폐기 (mirror-docs.sh 단방향 hook 의 정책 ↔ 실 사용 어긋남 결정 — 산출물 `output/analysis/2026-05-18-mirror-policy-redesign/`) — 본 스킬이 api-docs 3-way 의 **단일 검증 진입점**.
>
> **Why:** PostToolUse hook 은 Edit/Write 도구 호출 시점에만 trigger 된다. git checkout / 외부 IDE 편집 / 파일 직접 cp 등 도구 외 변경은 hook 이 잡지 못한다. api-docs 는 be cwd 세션 + IDE 편집 빈도가 글로벌 cwd 편집보다 높아 자동 hook 으로는 보장 불가 — 본 스킬이 명시 진입점.

> **[실행 주체]** Claude 본체 단독. 외부 Agent spawn 불필요. cp / diff / sha256 단순 작업.

---

## 1. 호출 방식

### 1.1. 자동 트리거

frontmatter `triggers` 매칭 시 즉시 호출. 모호한 경우 한 줄 확인 후 진행.

**트리거 예시 (호출됨):**
- "be CLAUDE.md 미러 상태 확인"
- "be 지침 동기화 깨졌나 확인"
- "글로벌 미러본 be 로 동기화"

**트리거 안 됨 (의도된 차단):**
- "be CLAUDE.md 수정해줘" → 직접 Edit (hook 이 자동 미러링)
- "다른 프로젝트 CLAUDE.md 미러링 추가" → skill-creator (스킬 확장 작업)

### 1.2. 슬래시 커맨드

```
/mirror-be-claude [mode]
```

`mode` 생략 시 default = `verify`.

| mode | 동작 | Checkpoint |
|------|------|------------|
| `verify` | 양 영역 (CLAUDE.md + api-docs 3-way) 정합 비교 + 상태 보고 (read-only) | 없음 |
| `sync-from-be` | be → 글로벌 + docs 강제 cp (양 영역 모두 글로벌 측 덮어씀) | 없음 (글로벌·docs 영향만) |
| `sync-from-global` | 글로벌 → be 강제 cp (be 프로젝트 파일 덮어씀) | **§3 Checkpoint 발동** — be 프로젝트 변경, 사용자 명시 승인 필수 |

---

## 2. 절차

### 2.1. `verify` (default) — 2 영역 통합 검증

#### 2.1.1. 영역 1 — CLAUDE.md 양방향

```bash
BE_MD="C:/Works/hongcafe_global_backend/CLAUDE.md"
MIRROR_MD="$HOME/.claude/mirrors/hongcafe_global_backend/CLAUDE.md"

# 1. 두 파일 존재 확인
[ -f "$BE_MD" ]     || echo "[VERIFY] FAIL: be CLAUDE.md 없음 ($BE_MD)"
[ -f "$MIRROR_MD" ] || echo "[VERIFY] FAIL: 글로벌 미러본 없음 ($MIRROR_MD)"

# 2. diff 실행
diff -q "$BE_MD" "$MIRROR_MD"
#   동일: "Files ... and ... identical" → PASS
#   상이: "Files ... and ... differ"    → FAIL + 상세 diff 표시

# 3. 상이 시 라인 수 + 차이 요약
if ! diff -q "$BE_MD" "$MIRROR_MD" >/dev/null 2>&1; then
  echo "===== diff (be vs mirror) ====="
  diff "$BE_MD" "$MIRROR_MD" | head -100
  echo "===== mtime 비교 ====="
  ls -la --time-style=full-iso "$BE_MD" "$MIRROR_MD"
fi
```

#### 2.1.2. 영역 2 — api-docs 3-way

```bash
GLOBAL_DIR="$HOME/.claude/docs/hongcafe_global_backend/api-docs"
BE_DIR="C:/Works/hongcafe_global_backend/api-docs"
DOCS_DIR="C:/Works/hongcafe_global_docs/be/api-docs"

# 1. 디렉토리 존재 확인 (각 미존재 시 SKIP)
for d in "$GLOBAL_DIR" "$BE_DIR" "$DOCS_DIR"; do
  [ -d "$d" ] || { echo "[VERIFY] SKIP: $d 미존재"; continue; }
done

# 2. file count 3-way + 누락 식별 (be 기준)
g_count=$(find "$GLOBAL_DIR" -maxdepth 3 -type f 2>/dev/null | wc -l)
b_count=$(find "$BE_DIR"     -maxdepth 3 -type f 2>/dev/null | wc -l)
d_count=$(find "$DOCS_DIR"   -maxdepth 3 -type f 2>/dev/null | wc -l)
echo "file count: global=$g_count / be=$b_count / docs=$d_count"

# 3. be 에만 존재 (글로벌·docs 누락)
echo "===== be 에만 존재 (글로벌·docs 누락) ====="
comm -23 \
  <(cd "$BE_DIR" && find . -maxdepth 3 -type f 2>/dev/null | sort) \
  <(cd "$GLOBAL_DIR" && find . -maxdepth 3 -type f 2>/dev/null | sort)

# 4. sha256 mismatch 식별 (3-way 비교)
echo "===== sha256 mismatch ====="
cd "$BE_DIR" && find . -maxdepth 3 -type f 2>/dev/null | sort | while read f; do
  g=$(sha256sum "$GLOBAL_DIR/$f" 2>/dev/null | awk '{print $1}')
  b=$(sha256sum "$BE_DIR/$f"     2>/dev/null | awk '{print $1}')
  d=$(sha256sum "$DOCS_DIR/$f"   2>/dev/null | awk '{print $1}')
  if [ "$g" != "$b" ] || [ "$g" != "$d" ]; then
    g_t=$(stat -c %Y "$GLOBAL_DIR/$f" 2>/dev/null || echo 0)
    b_t=$(stat -c %Y "$BE_DIR/$f"     2>/dev/null || echo 0)
    d_t=$(stat -c %Y "$DOCS_DIR/$f"   2>/dev/null || echo 0)
    newest="be"; max=$b_t
    [ "$g_t" -gt "$max" ] && newest="global" && max=$g_t
    [ "$d_t" -gt "$max" ] && newest="docs"   && max=$d_t
    echo "MISMATCH: $f (newest=$newest)"
  fi
done
```

**보고 형식 (양 영역 통합):**
- 영역 1 PASS / FAIL — CLAUDE.md sha256 + diff
- 영역 2 PASS / FAIL — api-docs file count + 누락 N건 + sha256 mismatch N건 + newest source 분포
- FAIL 시: 사용자에게 newest source 보고 → 적절한 sync 모드 권고. 자동 sync 진행 금지.

### 2.2. `sync-from-be` — be → 글로벌 + docs 강제

```bash
# 영역 1 — CLAUDE.md
BE_MD="C:/Works/hongcafe_global_backend/CLAUDE.md"
MIRROR_MD="$HOME/.claude/mirrors/hongcafe_global_backend/CLAUDE.md"
cp -f "$BE_MD" "$MIRROR_MD"
diff -q "$BE_MD" "$MIRROR_MD" && echo "[SYNC be→mirror CLAUDE.md] OK"

# 영역 2 — api-docs (be 기준 글로벌 + docs 양쪽 일괄 cp)
GLOBAL_DIR="$HOME/.claude/docs/hongcafe_global_backend/api-docs"
BE_DIR="C:/Works/hongcafe_global_backend/api-docs"
DOCS_DIR="C:/Works/hongcafe_global_docs/be/api-docs"

cd "$BE_DIR" && find . -maxdepth 3 -type f 2>/dev/null | while read f; do
  GP="$GLOBAL_DIR/$f"; BP="$BE_DIR/$f"; DP="$DOCS_DIR/$f"
  g=$(sha256sum "$GP" 2>/dev/null | awk '{print $1}')
  b=$(sha256sum "$BP" 2>/dev/null | awk '{print $1}')
  d=$(sha256sum "$DP" 2>/dev/null | awk '{print $1}')
  [ "$g" = "$b" ] && [ "$b" = "$d" ] && continue
  mkdir -p "$(dirname "$GP")" 2>/dev/null
  mkdir -p "$(dirname "$DP")" 2>/dev/null
  cp -f "$BP" "$GP" && echo "  G+ $f"
  cp -f "$BP" "$DP" && echo "  D+ $f"
done
```

- 글로벌 + docs 만 변경 → §3 Checkpoint 미발동 (be 프로젝트 git 추적 파일 무변경).
- 사용자 명시 요청 (`/mirror-be-claude sync-from-be` 또는 "be 기준으로 동기화") 시에만 실행.
- 결과: 양 영역 cp + sha256 재검증 + 보고.

### 2.3. `sync-from-global` — 글로벌 → be 강제 (§3 매칭)

> **§3 Checkpoint 발동** — be 프로젝트 파일이 덮어씌워진다. 사용자 명시 승인 (`승인` / `진행` / `ok` / `sync 해`) 키워드 확인 후에만 실행.
>
> **위험:** be 가 사실상의 SSOT 인 경우 (특히 api-docs 영역) 글로벌 본으로 덮어쓰면 **be 최신 작업 폐기 = 데이터 손실**. 본 모드 호출 전 `verify` 로 newest source 반드시 확인.

```bash
# Checkpoint: 사용자에게 영향 범위 보고 + newest source 확인 → 승인 대기
# 승인 키워드 확인 후:

# 영역 1 — CLAUDE.md
cp -f "$MIRROR_MD" "$BE_MD"
diff -q "$BE_MD" "$MIRROR_MD" && echo "[SYNC mirror→be CLAUDE.md] OK"

# 영역 2 — api-docs (글로벌 → be 단방향)
cd "$GLOBAL_DIR" && find . -maxdepth 3 -type f 2>/dev/null | while read f; do
  GP="$GLOBAL_DIR/$f"; BP="$BE_DIR/$f"
  g=$(sha256sum "$GP" 2>/dev/null | awk '{print $1}')
  b=$(sha256sum "$BP" 2>/dev/null | awk '{print $1}')
  [ "$g" = "$b" ] && continue
  mkdir -p "$(dirname "$BP")" 2>/dev/null
  cp -f "$GP" "$BP" && echo "  B+ $f"
done
```

- be 프로젝트 git 추적 파일 변경 → 사용자가 git diff 로 확인 가능.
- 결과: 양 영역 cp + sha256 재검증 + git status 보고.

---

## 3. 보고 형식

```
=== be 미러링 상태 (2 영역 통합) ===

[영역 1 — CLAUDE.md]
- be:     C:/Works/hongcafe_global_backend/CLAUDE.md ({byte_size}, mtime: {iso8601})
- mirror: ~/.claude/mirrors/hongcafe_global_backend/CLAUDE.md ({byte_size}, mtime: {iso8601})
- 결과: ✅ 동일 / ❌ 상이 ({라인수} 라인 차이)

[영역 2 — api-docs 3-way]
- file count: global={N} / be={N} / docs={N}
- be 만 존재 (누락): {N}건 → 파일 목록
- sha256 mismatch: {N}건 → newest source 분포 (be={N} / global={N} / docs={N})
- 결과: ✅ 정합 / ❌ 불일치

[상이 시 권고]
- newest source = be → /mirror-be-claude sync-from-be (글로벌 + docs 일괄 갱신)
- newest source = global → /mirror-be-claude sync-from-global (be 영향, §3 승인 필요)
- newest source = docs → 단독 케이스, 사용자 확인 필수 (mirror target 별도 편집 의심)
```

---

## 4. PostToolUse hook 과의 관계 (2026-05-18 갱신)

| 항목 | hook (`mirror-claude-md.sh`) | hook (`mirror-docs.sh` — 폐기됨) | 본 스킬 (`mirror-be-claude`) |
|------|-----------------------------|----------------------------------|------------------------------|
| 영역 | CLAUDE.md 양방향 | api-docs 3-way (글로벌 → be + docs) | CLAUDE.md + api-docs 양 영역 |
| 트리거 | Edit/Write 도구 호출 (자동) | ~~Edit/Write 도구 호출 (자동)~~ | 사용자 명시 호출 (수동) |
| 방향 | 수정된 쪽 → 반대편 (자동 결정) | ~~글로벌 → 외부 단방향~~ | 사용자 선택 (verify / from-be / from-global) |
| 차단 | exit 0 (작업 미차단) | ~~exit 0~~ | n/a (보고만) |
| 폐기 사유 | n/a (운영 중) | 정책 ↔ 실 사용 어긋남 — be 가 실 SSOT 인데 글로벌 → be 단방향이라 외부 IDE / be cwd 편집 미감지 (산출물 `output/analysis/2026-05-18-mirror-policy-redesign/`) | n/a |
| 누락 케이스 보완 | git checkout / 외부 IDE 편집 / 직접 cp | ~~동일~~ | 본 스킬이 두 영역 모두 보완 |

**보조 SessionStart 경량 검증 (2026-05-18 도입):** `mirror-sanity-check.sh` SessionStart hook 가 매 세션 시작 시 mtime 비교로 drift 감지 → stderr 경고만 (exit 0). 사용자에게 `/mirror-be-claude verify` 명시 호출 유도.

---

## 5. 산출물

본 스킬은 **읽기·복사 작업만** 수행한다. tasks/ · output/ · specs/ 산출물 생성 없음.

작업 결과는 채팅 보고로 종결한다. 단 `sync-from-global` 실행 시 be 프로젝트 변경 이력은 git 으로 자동 추적된다.

---

## 6. 제약·주의사항

- **be 프로젝트 미클론 환경:** `C:/Works/hongcafe_global_backend/` 디렉토리 미존재 시 `verify` / `sync-from-be` 는 SKIP, `sync-from-global` 은 FAIL 보고.
- **양방향 동시 수정:** hook 이 last-write-wins 이므로 단시간 내 양쪽 동시 수정은 보장 못함. 본 스킬 `verify` 로 정합성 확인 권장.
- **git 추적:** 미러본은 `~/.claude/mirrors/` 하위 — git 추적 정책은 `.gitignore` 에 따른다. (`vibe_setting` 분기에서 추적 여부는 `git status` 로 확인)
- **다른 프로젝트 확장:** 본 스킬은 `hongcafe_global_backend` 한정. infra·다른 프로젝트 미러링 추가 시 별도 스킬 (`mirror-{product}-claude`) 작성 또는 본 스킬을 다중 프로젝트 지원으로 확장 (skill-creator 경유).

---

## 7. 변경 로그

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-05-07 | 1.0.0 | 신규 생성 — be CLAUDE.md ↔ 글로벌 미러본 양방향 동기화 검증·강제 스킬 (사용자 결정: 양방향 + `~/.claude/mirrors/{product}/`) |
| 2026-05-18 | 1.1.0 | api-docs 3-way 영역 통합 — `mirror-docs.sh` 자동 hook 폐기 결정 (정책 ↔ 실 사용 어긋남, 산출물 `output/analysis/2026-05-18-mirror-policy-redesign/`) 후 본 스킬이 api-docs 3-way 단일 명시 진입점으로 확장. `verify` / `sync-from-be` / `sync-from-global` 3 모드 모두 양 영역 통합 처리 |
