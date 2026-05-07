---
name: mirror-be-claude
description: >
  be 프로젝트(`hongcafe_global_backend`) CLAUDE.md ↔ 글로벌 미러본
  (`~/.claude/mirrors/hongcafe_global_backend/CLAUDE.md`) 양방향 동기화
  검증·강제 스킬. PostToolUse hook(`mirror-claude-md.sh`) 의 수동 진입점.
  3개 모드 — `verify` (양쪽 diff 비교), `sync-from-be` (be → 글로벌 강제),
  `sync-from-global` (글로벌 → be 강제). 자동 트리거 (be 지침 미러·동기화
  키워드) + `/mirror-be-claude` 슬래시 커맨드. 호출 주체 = Claude 본체.
  산출물 없음 (보고만).
triggers:
  - "be CLAUDE 미러"
  - "be CLAUDE.md 미러"
  - "be 지침 미러"
  - "be 지침 동기화"
  - "be claude 동기화"
  - "be 미러 검증"
  - "/mirror-be-claude"
version: 1.0.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Mirror BE CLAUDE.md Skill

be 프로젝트 CLAUDE.md (`C:/Works/hongcafe_global_backend/CLAUDE.md`) 와 글로벌 미러본 (`~/.claude/mirrors/hongcafe_global_backend/CLAUDE.md`) 간 양방향 동기화 상태를 검증하고, 필요 시 한쪽 방향으로 강제 동기화한다.

> **[용도 한정]** 본 스킬은 **수동 진입점** 이다. 자동 동기화는 PostToolUse hook (`hooks/mirror-claude-md.sh`) 가 담당한다. 본 스킬은 (1) hook 회피 후 동기화 깨짐 의심 시 검증, (2) 한쪽이 손상돼 강제 복구가 필요한 경우, (3) 수동 cp 누락 점검에만 사용한다.
>
> **Why:** PostToolUse hook 은 Edit/Write 도구 호출 시점에만 trigger 된다. git checkout / 외부 IDE 편집 / 파일 직접 cp 등 도구 외 변경은 hook 이 잡지 못한다. 본 스킬이 그 회피 경로의 안전망이다.

> **[실행 주체]** Claude 본체 단독. 외부 Agent spawn 불필요. cp / diff 단순 작업.

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
| `verify` | 양쪽 diff 비교 + 상태 보고 (read-only) | 없음 |
| `sync-from-be` | be → 글로벌 강제 cp (글로벌 미러본 덮어씀) | 없음 (글로벌 영향만) |
| `sync-from-global` | 글로벌 → be 강제 cp (be 프로젝트 파일 덮어씀) | **§3 Checkpoint 발동** — be 프로젝트 변경, 사용자 명시 승인 필수 |

---

## 2. 절차

### 2.1. `verify` (default)

```bash
BE="C:/Works/hongcafe_global_backend/CLAUDE.md"
MIRROR="$HOME/.claude/mirrors/hongcafe_global_backend/CLAUDE.md"

# 1. 두 파일 존재 확인
[ -f "$BE" ]     || echo "[VERIFY] FAIL: be CLAUDE.md 없음 ($BE)"
[ -f "$MIRROR" ] || echo "[VERIFY] FAIL: 글로벌 미러본 없음 ($MIRROR)"

# 2. diff 실행
diff -q "$BE" "$MIRROR"
#   동일: "Files ... and ... identical" → PASS
#   상이: "Files ... and ... differ"    → FAIL + 상세 diff 표시

# 3. 상이 시 라인 수 + 차이 요약
if ! diff -q "$BE" "$MIRROR" >/dev/null 2>&1; then
  echo "===== diff (be vs mirror) ====="
  diff "$BE" "$MIRROR" | head -100
  echo "===== mtime 비교 ====="
  ls -la --time-style=full-iso "$BE" "$MIRROR"
fi
```

**보고 형식:**
- PASS: "✅ be ↔ mirror 동기화 정상 (md5 일치)"
- FAIL: 사용자에게 diff + mtime 보고 → sync 모드 권고. 자동 sync 진행 금지.

### 2.2. `sync-from-be`

```bash
cp -f "$BE" "$MIRROR"
diff -q "$BE" "$MIRROR" && echo "[SYNC be→mirror] OK"
```

- 글로벌 미러본만 변경 → §3 Checkpoint 미발동.
- 사용자 명시 요청(`/mirror-be-claude sync-from-be` 또는 "be 기준으로 동기화") 시에만 실행.
- 결과: 1회 cp + diff 검증 + 보고.

### 2.3. `sync-from-global`

> **§3 Checkpoint 발동** — be 프로젝트 파일이 덮어씌워진다. 사용자 명시 승인(`승인` / `진행` / `ok` / `sync 해`) 키워드 확인 후에만 실행.

```bash
# Checkpoint: 사용자에게 영향 범위 보고 → 승인 대기
# 승인 키워드 확인 후:
cp -f "$MIRROR" "$BE"
diff -q "$BE" "$MIRROR" && echo "[SYNC mirror→be] OK"
```

- be 프로젝트 git 추적 파일 변경 → 사용자가 git diff 로 확인 가능.
- 결과: cp + diff 검증 + git status 보고.

---

## 3. 보고 형식

```
=== be CLAUDE.md 미러 상태 ===
- be:     C:/Works/hongcafe_global_backend/CLAUDE.md ({byte_size}, mtime: {iso8601})
- mirror: ~/.claude/mirrors/hongcafe_global_backend/CLAUDE.md ({byte_size}, mtime: {iso8601})

[verify 결과]
✅ 동일 / ❌ 상이 ({라인수} 라인 차이)

[상이 시 권고]
- be 가 최신 → /mirror-be-claude sync-from-be
- mirror 가 최신 → /mirror-be-claude sync-from-global (be 영향, 승인 필요)
```

---

## 4. PostToolUse hook 과의 관계

| 항목 | hook (`mirror-claude-md.sh`) | 본 스킬 (`mirror-be-claude`) |
|------|-----------------------------|------------------------------|
| 트리거 | Edit/Write 도구 호출 (자동) | 사용자 명시 호출 (수동) |
| 방향 | 수정된 쪽 → 반대편 (자동 결정) | 사용자 선택 (verify / from-be / from-global) |
| 차단 | exit 0 (작업 미차단) | n/a (보고만) |
| 누락 케이스 보완 | git checkout / 외부 IDE 편집 / 직접 cp | 본 스킬이 그 보완 역할 |

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

| 날짜 | 내용 |
|------|------|
| 2026-05-07 | 신규 생성 — be CLAUDE.md ↔ 글로벌 미러본 양방향 동기화 검증·강제 스킬 (사용자 결정: 양방향 + `~/.claude/mirrors/{product}/`) |
