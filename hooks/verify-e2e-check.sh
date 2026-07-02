#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "verify-e2e-check" "enter" "pid=$$"
# verify-e2e-check.sh
# PostToolUse:Edit|Write Hook — e2e 5점 검증 (env / 함수·클래스 / DB 스키마 / 프로덕션 curl / mock 분리) 강제
#
# SSOT:
#   - php8 §"e2e 검증" SSOT
#   - CLAUDE.md §4.3 "e2e 검증 (필수)"
#   - commands/검증.md (사용자 진입점)
#
# 대상:
#   ~/.claude/docs/working/**/*.md
#   ~/.claude/docs/{product}/tasks/YYYYMMDD/{작업명}/{yyyy-mm-dd}-{작업명}-unified.md
#
# 검증 항목 (5점):
#   1. env / .env / DOTENV 키워드 ≥ 1건
#   2. function | class | 메서드 시그니처 키워드 ≥ 1건
#   3. schema | migration | table | ALTER 키워드 ≥ 1건
#   4. curl | http | fetch | production 키워드 ≥ 1건
#   5. mock | stub | fake 키워드 ≥ 1건 (검증 모드 명시)
#
# 정책:
#   - 5점 모두 PASS = exit 0
#   - 일부 FAIL = exit 2 + stderr `[BLOCKED] e2e 5점 중 N점 누락`
#   - 역소급 면제: 생성일 < 2026-05-15 산출물 = hint 강등 (exit 0)
#
# 설치:
#   - settings.json PostToolUse Edit|Write 블록 등록됨 (2026-05-15~).
#   - 추가 등록 또는 disable 시 settings.json 직접 편집 (update-config 스킬).

# --- self-test ---
if [ "${1:-}" = "--self-test" ]; then
    echo "[verify-e2e-check] self-test mode"
    tmp=$(mktemp)
    cat > "$tmp" <<'EOF'
# Test unified doc
생성일: 2026-05-15

## § 검증
- env: APP_ENV=production
- function calcPrice() class PriceService
- migration / schema / ALTER TABLE
- curl -i https://api.example.com (production)
- mock stub fake — 분리 검증

## Self-Critique
- [x] 5점 통과
EOF
    JSON_INPUT="{\"tool_response\":{\"filePath\":\"$tmp\"}}"
    echo "$JSON_INPUT" | "$0"
    rc=$?
    rm -f "$tmp"
    echo "[verify-e2e-check] self-test exit: $rc (expected: 0)"
    exit $rc
fi

input=$(cat)

# 파일 경로 추출 — bash 내장 (python 起動 제거). tool_response.filePath 우선, 없으면 tool_input.file_path (원본 우선순위 보존).
file_path=""
[[ "$input" =~ \"filePath\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && file_path="${BASH_REMATCH[1]}"
[ -z "$file_path" ] && [[ "$input" =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && file_path="${BASH_REMATCH[1]}"

[ -z "$file_path" ] && exit 0

# .md 파일만 검증
[[ "$file_path" != *.md ]] && exit 0

basename="${file_path##*/}"

# 제외 대상
case "$basename" in
    summary.md|history.md|MEMORY.md|CLAUDE.md|README.md|SKILL.md|CHANGELOG.md)
        exit 0
        ;;
esac

# 대상 경로: working/ 또는 tasks/*/unified
case "$file_path" in
    */docs/working/*|*/docs/*/tasks/*-unified.md|*/docs/*/tasks/*/*-unified.md)
        ;; # 검증 대상
    *)
        exit 0
        ;;
esac

# 윈도우 경로 → unix 경로 변환
unix_path=$(echo "$file_path" | sed 's|\\|/|g' | sed 's|^C:|/c|')
[ -f "$unix_path" ] || unix_path="$file_path"
[ -f "$unix_path" ] || exit 0

# === 역소급 면제 ===
# 생성일 < 2026-05-15 = hint 강등
created_date=""
if grep -qE "^---" "$unix_path"; then
    created_date=$(awk '/^---/{c++; next} c==1 && /^생성일:/ {sub(/^생성일:[[:space:]]*/,""); sub(/[[:space:]]*$/,""); print; exit}' "$unix_path")
fi
if [ -z "$created_date" ]; then
    created_date=$(echo "$basename" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
fi
if [ -z "$created_date" ]; then
    folder_date=$(echo "$file_path" | grep -oE '/(tasks|working)/[0-9]{8}/' | grep -oE '[0-9]{8}' | head -1)
    if [ -n "$folder_date" ]; then
        created_date="${folder_date:0:4}-${folder_date:4:2}-${folder_date:6:2}"
    fi
fi

GRANDFATHER="0"
if [ -n "$created_date" ]; then
    # date string comparison (YYYY-MM-DD format works lexically)
    if [[ "$created_date" < "2026-05-15" ]]; then
        GRANDFATHER="1"
    fi
fi

# === 5점 검증 ===
fail_points=()

# 1. env / 설정
if ! grep -qiE "(env\(|\.env|DOTENV|APP_ENV|환경 ?변수|환경 ?설정)" "$unix_path"; then
    fail_points+=("1. env/설정 키워드 누락 (env\\(|.env|DOTENV|APP_ENV|환경 변수)")
fi

# 2. 함수·클래스 시그니처
if ! grep -qiE "(\bfunction\b|\bclass\b|public function|메서드|시그니처|signature)" "$unix_path"; then
    fail_points+=("2. 함수/클래스 시그니처 누락 (function|class|메서드)")
fi

# 3. DB 스키마
if ! grep -qiE "(\bschema\b|\bmigration\b|\btable\b|ALTER|CREATE TABLE|DDL|스키마|마이그레이션|해당 없음)" "$unix_path"; then
    fail_points+=("3. DB 스키마 키워드 누락 (schema|migration|table|ALTER|스키마)")
fi

# 4. 프로덕션 curl
if ! grep -qiE "(\bcurl\b|\bhttp\b|fetch|production|프로덕션|엔드포인트|endpoint)" "$unix_path"; then
    fail_points+=("4. 프로덕션 curl 키워드 누락 (curl|http|fetch|production|엔드포인트)")
fi

# 5. mock 분리
if ! grep -qiE "(\bmock\b|\bstub\b|\bfake\b|모의|검증 모드)" "$unix_path"; then
    fail_points+=("5. mock 검증 분리 키워드 누락 (mock|stub|fake|모의)")
fi

FAIL_COUNT=${#fail_points[@]}

# === [hint, 비차단] 테스트 통과 주장 ↔ 사용자-체크 가능 증거 (2026-06-02~) ===
# 산문 단언("phpunit 16/16"·"pipeline #364")만으로는 검증 결과가 재현·확인 불가 (audit 2026-06-02).
# pipeline URL+빌드번호 / junit .xml 경로 / 러너 원문 코드블록 동반을 권장 — 사용자가 spot-check 가능한 증거.
# 단 regex 는 claim↔evidence 를 묶지 못하고(문서 어딘가 URL 1개로 전부 통과 가능) fenced 블록도
# 산문만큼 위조 가능하므로, 차단(exit 2)이 아닌 hint 로만 surface (advisor 권고, §4.4 over-enforce 금지).
CAPTURE_STRICT_FROM="2026-06-02"
capture_in_scope="1"
if [ -n "$created_date" ] && [[ "$created_date" < "$CAPTURE_STRICT_FROM" ]]; then
    capture_in_scope="0"   # 역소급 면제 — 도입일 이전 문서엔 hint 미발화
fi
if [ "$capture_in_scope" = "1" ] \
   && grep -qiE 'OK \([0-9]+ tests|[0-9]+ tests?,? [0-9]+ assertion|[0-9]+/[0-9]+ ?(통과|passed)|[0-9]+ passed|pipeline ?#?[0-9]+' "$unix_path" \
   && ! grep -qE '```|\.xml|https?://|junit' "$unix_path"; then
    echo "[hint] verify-e2e-check: 테스트 통과를 주장하나 사용자-체크 가능 증거 미동반 — pipeline URL+빌드번호 / junit .xml 경로 / 러너 원문 코드블록 권장 (산문 단언은 재현 불가, audit 2026-06-02). 비차단(hint)." >&2
fi

# 전체 PASS
if [ "$FAIL_COUNT" -eq 0 ]; then
    exit 0
fi

# === 역소급 면제 시 hint 강등 ===
if [ "$GRANDFATHER" = "1" ]; then
    {
        echo "[hint] verify-e2e-check: e2e 5점 중 $FAIL_COUNT 점 누락 (역소급 면제 — 생성일 $created_date)"
        for p in "${fail_points[@]}"; do
            echo "  · $p"
        done
    } >&2
    exit 0
fi

# === 차단 ===
{
    echo "[BLOCKED] verify-e2e-check: e2e 5점 중 $FAIL_COUNT 점 누락"
    echo "  파일: $file_path"
    for p in "${fail_points[@]}"; do
        echo "  · $p"
    done
    echo ""
    echo "SSOT: php8 §\"e2e 검증\" + CLAUDE.md §4.3 \"e2e 검증 (필수)\""
    echo "진입점: /검증  (~/.claude/commands/검증.md)"
} >&2
command -v log_event >/dev/null 2>&1 && log_event "verify-e2e-check" "block" "reason=e2e-incomplete"
exit 2
