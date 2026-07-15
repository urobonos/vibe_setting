---
description: Claude Code 프로세스 + 세션 sid 매핑 조회 + REGISTRY/lock orphan 분류·정리. 3 모드 — 기본 (read-only 분류), `cleanup` (REGISTRY orphan + lock 잔존 정리), `kill` (좀비 PID 종료 명령 안내, 사용자 직접 실행)
allowed-tools: Bash, Read
argument-hint: "[cleanup|kill]  # 생략 = read-only 조회"
---

`claude.exe` 프로세스 + `~/.claude/projects/{sid}.jsonl` transcript birth time 매칭으로 sid 식별, REGISTRY 상태 + lock 파일 정합성 확인, orphan/좀비 분류 후 정리.

## 동작 3 모드

| 모드 | 동작 | 비가역성 |
|------|------|---------|
| 기본 (`/taskflow:ps`) | 분류 + 권고만 (read-only) | 없음 |
| `cleanup` (`/taskflow:ps cleanup`) | REGISTRY orphan entry 제거 + lock orphan 정리 | §3 매칭 — 사용자 명시 인자가 승인 신호 |
| `kill` (`/taskflow:ps kill`) | 좀비 PID 종료 명령 안내 (사용자 직접 `! ` prefix 실행) | Claude 자동 X — 안내만 |

## 직병렬 실행 지침

**원칙:** 할당된 하위 태스크는 의존성을 먼저 판단 → 독립 태스크는 단일 응답 내 병렬(multi tool_use / Agent spawn), 의존 태스크는 직렬. 동일 파일 mutation·순서 의존 시 직렬 fallback (race 방지). 강제 병렬 modifier = `/taskflow:parallel`.

| 태스크 | 직렬·병렬 | 방법 |
|--------|----------|-----|
| ① 프로세스 스캔 + transcript sid 매핑 | **병렬 가능** | `ps -W` 와 transcript `find`+`stat` 를 단일 응답 내 동시 조회 |
| ④ cleanup: orphan-lock + orphan-registry 정리 | **병렬 가능** | 두 정리 루프 독립 → 동시 진행 (REGISTRY race 시 registry-utils.sh 가 직렬화) |
| 기본 모드 ②③ 분류 → 출력 | **직렬** | 매칭 결과로 분류, 분류 결과로 출력 |

## ① 프로세스 + sid 매칭

```bash
# claude.exe 프로세스 PID + 시작 시각 (Git Bash on Windows: ps -W)
ps -W 2>/dev/null | grep -i claude.exe | awk '{printf "%s|%s\n", $1, $7}'

# transcript birth time → sid 매핑
find ~/.claude/projects -name '*.jsonl' ! -path '*/subagents/*' 2>/dev/null | while read f; do
  birth=$(stat -c '%w' "$f" 2>/dev/null | cut -d. -f1)
  mtime=$(stat -c '%y' "$f" | cut -d. -f1)
  sid=$(basename "$f" .jsonl | cut -c1-8)
  echo "$sid|$birth|$mtime|$f"
done
```

birth time 시각 매칭 (HH:MM 동일) → PID ↔ sid 매핑.

## ② 분류 매트릭스

| 분류 | 조건 |
|------|------|
| `live` | PID 살아있음 + transcript mtime < 5분 |
| `idle` | PID 살아있음 + transcript mtime 5~30분 |
| `stale` | PID 살아있음 + transcript mtime > 30분 (사용자 자리 비움 또는 잊힌 세션) |
| `paused` | REGISTRY status=paused (Stop hook 정상 작동) |
| `orphan-process` | PID 살아있음 + 매칭 sid 없음 또는 transcript 무존재 (helper/좀비 프로세스) |
| `orphan-registry` | REGISTRY active entry + 매칭 PID 없음 + transcript mtime > 30분 (사용자 종료했으나 entry 잔존) |
| `orphan-lock` | lock 파일 존재 + REGISTRY 매칭 entry 없음 |

## ③ 출력 형식 (기본 모드)

```
=== 활성 Claude Code 세션 ===

| sid       | PID     | started  | last_activity | REGISTRY | 분류           |
|-----------|---------|----------|---------------|----------|---------------|
| 8f5fe9fb  | 4218260 | 09:55:11 | 1분 전        | 미등록   | live (본 세션) |
| a6c2fe4d  | ...     | ...      | 1분 전        | 미등록   | live          |
| 06539f53  | 4218892 | 09:03:07 | 34분 전       | paused   | stale + paused (사용자 종료 추정) |

=== REGISTRY 정합 ===

orphan-registry: 0건
orphan-lock:     0건

=== 권고 ===

- /taskflow:ps cleanup → REGISTRY/lock orphan 정리
- /taskflow:ps kill   → 좀비 PID 종료 명령 안내
```

## ④ cleanup 모드 동작

```bash
source ~/.claude/hooks/lib/registry-utils.sh

# orphan-registry 정리: PID 매칭 없는 active/paused entry 의 lock 제거 + status 변경
# 좁은 정의 = transcript 부재 또는 mtime > 30분 + PID 매칭 없는 sid
# 광범위 정의 = paused 전체 (사용자 결정 영역)

# orphan-lock 정리: REGISTRY 매칭 없는 lock 파일 제거
find ~/.claude/state/sessions -name '*.lock' -type f 2>/dev/null | while read lock; do
  sid=$(basename "$lock" .lock)
  slug=$(basename "$(dirname "$lock")")
  if ! registry_find "$slug" | grep -q "$sid"; then
    session_lock_remove "$slug" "$sid"
    echo "[cleanup] orphan-lock removed: $slug/$sid"
  fi
done
```

**범위 제한:** cleanup 모드 = orphan-lock + transcript 명백 부재인 orphan-registry 만 자동 정리. **paused 전체 정리는 사용자 추가 확인 필수** (사용자가 일시 종료 후 재개 의도일 수 있음).

## ⑤ kill 모드 동작 (안내만)

좀비 PID 발견 시 다음 명령을 사용자가 직접 실행:

```
! powershell.exe Stop-Process -Id {PID} -Force
```

복수 PID:
```
! powershell.exe "Stop-Process -Id 4218892,4208528 -Force"
```

**Claude 자동 실행 금지** — §3 비가역 (외부 시스템 영향). PID 매핑 오인 시 본 세션도 종료될 위험.

## §3 Checkpoint 우선 적용

- 기본 모드 = read-only, §3 비대상
- `cleanup` 모드 = REGISTRY entry / lock 파일 삭제 = 비가역. 사용자 명시 인자 = 승인 신호로 해석. 단 paused 전체 정리는 추가 확인 필수
- `kill` 모드 = OS 프로세스 종료. Claude 자동 호출 금지, 명령 안내만

## 호출 예

```
/taskflow:ps           ← 분류 + 권고 (read-only)
/taskflow:ps cleanup   ← REGISTRY orphan + lock orphan 정리
/taskflow:ps kill      ← 좀비 PID 종료 명령 안내 (사용자 직접)
```

## SSOT

| SSOT | 역할 |
|------|------|
| `~/.claude/docs/working/REGISTRY.md` | 작업 단위 sid 매핑 |
| `~/.claude/state/sessions/{slug}/{sid}.lock` | 세션 lifecycle 마커 |
| `~/.claude/projects/{...}/{sid}.jsonl` | transcript birth/mtime = 세션 활성 신호 |
| `~/.claude/hooks/lib/registry-utils.sh` | CRUD lib (cleanup 모드에서 호출) |
| `~/.claude/CLAUDE.md` §File Paths "Active Task Registry" | 정책 SSOT |
