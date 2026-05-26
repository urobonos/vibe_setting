#!/bin/bash
[ "${SKIP_HOOKS:-0}" = "1" ] && exit 0
source "$(dirname "${BASH_SOURCE[0]}")/lib/log-helper.sh" 2>/dev/null && log_event "php-quality" "enter" "pid=$$"
# PostToolUse Hook: PHP 코드 품질 검증
# 통합: php-syntax-check.sh + php-pattern-lint.sh
#
# Phase 1: 구문 검증 (php -l) → exit 1 on parse error
# Phase 2: 패턴 린트 (14개 안티패턴) → exit 0 warnings

STDIN_DATA=$(cat)

FILE=$(echo "$STDIN_DATA" | python -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# PHP 파일만 검사
if [[ "$FILE" != *.php ]]; then
  exit 0
fi

# ===== Phase 1: PHP 구문 검증 =====
if [ -f "$FILE" ]; then
  RESULT=$(php -l "$FILE" 2>&1)
  if echo "$RESULT" | grep -q "Parse error\|Fatal error"; then
    echo "PHP 문법 오류 감지: $RESULT — 해당 라인을 확인하고 Edit 도구로 수정하세요."
    # exit 0 정합: 다른 패턴 + PHPDoc 분기 모두 exit 0 (stderr 경고).
    # PostToolUse exit 1 은 차단력 없는 노이즈 — Claude 가 stderr 보고 자가복구.
  fi
fi

# ===== Phase 2: PHP 패턴 린트 =====

if [ ! -f "$FILE" ]; then
  exit 0
fi

# Legacy 모드 파일은 검사 제외
if echo "$FILE" | grep -qE '(app/Libraries/|app/Controllers/Api/|app/Models/)'; then
  exit 0
fi

# Modules 내 파일만 검사
if ! echo "$FILE" | grep -qE 'app/Modules/'; then
  exit 0
fi

WARNINGS=""
COUNT=0

# 파일의 레이어 판별
LAYER="unknown"
if echo "$FILE" | grep -qE '/Controllers/'; then
  LAYER="controller"
elif echo "$FILE" | grep -qE '/Services/'; then
  LAYER="service"
elif echo "$FILE" | grep -qE '/Repositories/'; then
  LAYER="repository"
elif echo "$FILE" | grep -qE '/Models/'; then
  LAYER="model"
fi

# 1. DI 위반: new XxxService(), new XxxRepository()
DI_HITS=$(grep -nE 'new\s+\w+(Service|Repository)\s*\(' "$FILE" 2>/dev/null)
if [ -n "$DI_HITS" ]; then
  WARNINGS="${WARNINGS}\n[DI 위반] new Service()/Repository() 직접 생성 감지 → service() DI 함수를 사용하세요:\n${DI_HITS}\n"
  ((COUNT++))
fi

# 2. 레이어 위반: Controller/Service에서 Model 직접 참조
if [[ "$LAYER" == "controller" || "$LAYER" == "service" ]]; then
  MODEL_IMPORT=$(grep -nE 'use\s+App\\(Models|Modules\\[A-Za-z]+\\Models)\\' "$FILE" 2>/dev/null)
  if [ -n "$MODEL_IMPORT" ]; then
    WARNINGS="${WARNINGS}\n[레이어 위반] ${LAYER}에서 Model 직접 참조 감지 → Repository를 통해 접근하세요:\n${MODEL_IMPORT}\n"
    ((COUNT++))
  fi
fi

# 3. Raw SQL 위반: Controller/Service에서 $this->db 사용
if [[ "$LAYER" == "controller" || "$LAYER" == "service" ]]; then
  RAW_DB=$(grep -nE '\$this->db->' "$FILE" 2>/dev/null)
  if [ -n "$RAW_DB" ]; then
    WARNINGS="${WARNINGS}\n[Raw SQL 위반] ${LAYER}에서 DB 직접 접근 감지 → Repository에서만 DB 접근 허용:\n${RAW_DB}\n"
    ((COUNT++))
  fi
fi

# 4. SELECT * 사용
SELECT_STAR=$(grep -niE "select\s+\*\s+(from|,)" "$FILE" 2>/dev/null)
if [ -n "$SELECT_STAR" ]; then
  WARNINGS="${WARNINGS}\n[SELECT * 금지] 필요 컬럼만 명시하세요 (mysql8 스킬 규칙):\n${SELECT_STAR}\n"
  ((COUNT++))
fi

# 5. 모듈 간 직접 클래스 참조 (Interface 외)
CURRENT_MODULE=$(echo "$FILE" | grep -oE 'Modules/[A-Za-z]+' | head -1 | sed 's|Modules/||')
if [ -n "$CURRENT_MODULE" ]; then
  CROSS_REF=$(grep -nE 'use\s+App\\Modules\\[A-Za-z]+\\(Controllers|Services|Repositories|Models)\\' "$FILE" 2>/dev/null \
    | grep -vE "Modules\\\\${CURRENT_MODULE}\\\\" 2>/dev/null \
    | grep -vE 'Interface' 2>/dev/null)
  if [ -n "$CROSS_REF" ]; then
    WARNINGS="${WARNINGS}\n[모듈 경계 위반] 타 모듈 클래스 직접 참조 감지 → Interface를 통해 통신하세요:\n${CROSS_REF}\n"
    ((COUNT++))
  fi
fi

# 6. Raw query named binding 미사용 (Repository)
if [[ "$LAYER" == "repository" ]]; then
  RAW_CONCAT=$(grep -nE '\$.*db->query\s*\(.*\$' "$FILE" 2>/dev/null \
    | grep -vE ':[a-zA-Z_]+' 2>/dev/null)
  if [ -n "$RAW_CONCAT" ]; then
    WARNINGS="${WARNINGS}\n[SQL Injection 위험] raw query에 변수 연결 감지 → named binding (:param) 사용:\n${RAW_CONCAT}\n"
    ((COUNT++))
  fi
fi

# 7. Entity/VO 외부 의존성 감지
if echo "$FILE" | grep -qE '/(Entities|ValueObjects)/'; then
  FRAMEWORK_DEP=$(grep -nE 'use\s+(CodeIgniter|App\\Models|App\\Libraries|App\\Config)\\' "$FILE" 2>/dev/null)
  if [ -n "$FRAMEWORK_DEP" ]; then
    WARNINGS="${WARNINGS}\n[Entity/VO 순수성 위반] 프레임워크 의존성 감지 → Entity/VO는 순수 PHP만 허용:\n${FRAMEWORK_DEP}\n"
    ((COUNT++))
  fi
fi

# 8. Service/Repository Interface 미구현 감지
if [[ "$LAYER" == "service" || "$LAYER" == "repository" ]]; then
  CLASS_DECL=$(grep -nE '^\s*class\s+\w+' "$FILE" 2>/dev/null | head -1)
  if [ -n "$CLASS_DECL" ]; then
    if ! echo "$CLASS_DECL" | grep -qE 'implements\s'; then
      if ! echo "$CLASS_DECL" | grep -qE '(abstract\s+class|trait\s|interface\s)'; then
        WARNINGS="${WARNINGS}\n[Interface 미구현] ${LAYER} 클래스에 implements 누락 → Interface 정의 후 구현하세요:\n${CLASS_DECL}\n"
        ((COUNT++))
      fi
    fi
  fi
fi

# 9. 위험 PHP 함수 감지
DANGEROUS_FUNCS=$(grep -nE '\b(eval|exec|system|passthru|shell_exec|popen|proc_open|unserialize)\s*\(' "$FILE" 2>/dev/null \
  | grep -vE '^\s*(//|/\*|\*\s|#)' 2>/dev/null)
if [ -n "$DANGEROUS_FUNCS" ]; then
  WARNINGS="${WARNINGS}\n[보안 Critical] 위험 PHP 함수 감지 → 안전한 대안을 사용하세요:\n${DANGEROUS_FUNCS}\n  eval() → 절대 금지\n  exec/system/shell_exec → Process 라이브러리 또는 제거\n  unserialize → json_decode 사용\n"
  ((COUNT++))
fi

# 10. var_dump/print_r/dd 잔존 감지
DEBUG_FUNCS=$(grep -nE '\b(var_dump|print_r|dd)\s*\(' "$FILE" 2>/dev/null \
  | grep -vE '^\s*(//|/\*|\*\s|#)' 2>/dev/null)
if [ -n "$DEBUG_FUNCS" ]; then
  WARNINGS="${WARNINGS}\n[디버그 코드 잔존] var_dump/print_r/dd 감지 → 프로덕션 코드에서 제거하세요:\n${DEBUG_FUNCS}\n"
  ((COUNT++))
fi

# 11. WHERE 함수 감싼 조건 (인덱스 무효화)
WHERE_FUNC=$(grep -niE '(YEAR|MONTH|DATE|DAY|SUBSTR|SUBSTRING|EXTRACT|LOWER|UPPER|TRIM|LEFT|RIGHT)\s*\(' "$FILE" 2>/dev/null \
  | grep -iE '(where|condition|find)' 2>/dev/null \
  | grep -vE '^\s*(//|/\*|\*\s|#)' 2>/dev/null)
if [ -z "$WHERE_FUNC" ]; then
  WHERE_FUNC=$(grep -nE "[\x27\x22](YEAR|MONTH|DATE|DAY|SUBSTR|EXTRACT|LOWER|UPPER|TRIM)\s*\(" "$FILE" 2>/dev/null \
    | grep -vE '^\s*(//|/\*|\*\s|#)' 2>/dev/null)
fi
if [ -n "$WHERE_FUNC" ]; then
  WARNINGS="${WARNINGS}\n[인덱스 무효화] WHERE 조건에 함수 감싼 컬럼 감지 → Functional Index 또는 조건 변환 사용:\n${WHERE_FUNC}\n  예: WHERE YEAR(created_at) = 2026 → WHERE created_at >= '2026-01-01' AND created_at < '2027-01-01'\n"
  ((COUNT++))
fi

# 12. FORCE INDEX / USE INDEX / IGNORE INDEX 쿼리 힌트 금지
QUERY_HINT=$(grep -niE '(FORCE|USE|IGNORE)\s+INDEX|STRAIGHT_JOIN' "$FILE" 2>/dev/null \
  | grep -vE '^\s*(//|/\*|\*\s|#)' 2>/dev/null)
if [ -n "$QUERY_HINT" ]; then
  WARNINGS="${WARNINGS}\n[쿼리 힌트 금지] FORCE/USE/IGNORE INDEX 감지 → 옵티마이저를 신뢰하고 인덱스 설계로 해결하세요:\n${QUERY_HINT}\n"
  ((COUNT++))
fi

# 13. 로깅에 민감정보 포함 감지
LOG_SENSITIVE=$(grep -nE '(log_message|logger->|->log)\s*\([^)]*\$(password|token|secret|apiKey|api_key|private_key|access_token)' "$FILE" 2>/dev/null)
if [ -n "$LOG_SENSITIVE" ]; then
  WARNINGS="${WARNINGS}\n[로깅 민감정보] 로그에 비밀번호/토큰/시크릿 변수 포함 감지 → 마스킹 처리하세요:\n${LOG_SENSITIVE}\n"
  ((COUNT++))
fi

# 14. ValueObject 가변성 감지
if echo "$FILE" | grep -qE '/(ValueObjects)/'; then
  VO_MUTABLE=$(grep -nE '\$this->[a-zA-Z_]+\s*=' "$FILE" 2>/dev/null \
    | grep -vE '__construct' 2>/dev/null)
  if [ -n "$VO_MUTABLE" ]; then
    WARNINGS="${WARNINGS}\n[VO 불변성 위반] __construct 외부에서 프로퍼티 변경 감지 → ValueObject는 불변이어야 합니다:\n${VO_MUTABLE}\n"
    ((COUNT++))
  fi
fi

# 15. PHPDoc 누락/불완전 감지 (public/protected 함수에 PHPDoc 표준 양식 필수)
MISSING_DOC=""
INCOMPLETE_DOC=""
MISSING_COUNT=0
INCOMPLETE_COUNT=0
while IFS= read -r line; do
  LINENO_NUM=$(echo "$line" | cut -d: -f1)
  FUNC_SIG=$(echo "$line" | cut -d: -f2-)
  # 해당 라인 위 20줄 내에서 PHPDoc 블록 추출
  START=$((LINENO_NUM - 20))
  [ "$START" -lt 1 ] && START=1
  DOC_BLOCK=$(sed -n "${START},$((LINENO_NUM - 1))p" "$FILE" 2>/dev/null)
  HAS_DOC=$(echo "$DOC_BLOCK" | grep -c '/\*\*')
  if [ "$HAS_DOC" -eq 0 ]; then
    MISSING_DOC="${MISSING_DOC}\n  L${LINENO_NUM}: ${FUNC_SIG}"
    ((MISSING_COUNT++))
  else
    # 파라미터가 있는 함수인지 확인
    HAS_PARAMS=$(echo "$FUNC_SIG" | grep -cE '\(\s*[^)]+\)')
    EMPTY_PARAMS=$(echo "$FUNC_SIG" | grep -cE '\(\s*\)')
    # @param 태그 확인 (파라미터가 있는 함수만)
    if [ "$HAS_PARAMS" -gt 0 ] && [ "$EMPTY_PARAMS" -eq 0 ]; then
      HAS_PARAM_TAG=$(echo "$DOC_BLOCK" | grep -c '@param')
      if [ "$HAS_PARAM_TAG" -eq 0 ]; then
        INCOMPLETE_DOC="${INCOMPLETE_DOC}\n  L${LINENO_NUM}: @param 누락 — ${FUNC_SIG}"
        ((INCOMPLETE_COUNT++))
      fi
    fi
    # @return 태그 확인 (void/생성자 제외)
    IS_CONSTRUCTOR=$(echo "$FUNC_SIG" | grep -c '__construct')
    HAS_VOID=$(echo "$FUNC_SIG" | grep -cE ':\s*void')
    if [ "$IS_CONSTRUCTOR" -eq 0 ] && [ "$HAS_VOID" -eq 0 ]; then
      HAS_RETURN_TAG=$(echo "$DOC_BLOCK" | grep -c '@return')
      if [ "$HAS_RETURN_TAG" -eq 0 ]; then
        INCOMPLETE_DOC="${INCOMPLETE_DOC}\n  L${LINENO_NUM}: @return 누락 — ${FUNC_SIG}"
        ((INCOMPLETE_COUNT++))
      fi
    fi
  fi
done < <(grep -nE '^\s*(public|protected)\s+function\s+\w+' "$FILE" 2>/dev/null)
if [ "$MISSING_COUNT" -gt 0 ]; then
  WARNINGS="${WARNINGS}\n[PHPDoc 누락] ${MISSING_COUNT}건의 메서드에 PHPDoc 블록이 없습니다:${MISSING_DOC}\n  양식: /** 목적 한 줄(~한다) + @param 타입 \$변수 설명 + @return 타입 설명 + @throws 예외 조건 */\n"
  ((COUNT++))
  PHPDOC_MISSING=1
fi
if [ "$INCOMPLETE_COUNT" -gt 0 ]; then
  WARNINGS="${WARNINGS}\n[PHPDoc 불완전] ${INCOMPLETE_COUNT}건의 태그 누락:${INCOMPLETE_DOC}\n  @param: 파라미터가 있는 메서드에 필수 | @return: void/생성자 외 필수\n"
  ((COUNT++))
  PHPDOC_MISSING=1
fi

# 경고가 있으면 Claude에게 주입
if [ "$COUNT" -gt 0 ]; then
  echo ""
  echo "━━━ PHP Pattern Lint: ${COUNT}건 위반 감지 (${FILE}) ━━━"
  echo -e "$WARNINGS"
  if [ "${PHPDOC_MISSING:-0}" -eq 1 ]; then
    echo "PHPDoc 누락 메서드에 /** @param @return 목적 한 줄 */ 블록을 추가하세요. 추가 완료 후 다시 저장하세요."
  fi
  echo "위 위반 사항을 확인하세요. php8 스킬 규칙 참조."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# 정합성 정책: 다른 14개 패턴은 모두 stderr 경고 (exit 0) 인데
# PHPDoc 만 exit 1 차단으로 격리되어 있던 비대칭 해소.
# 모든 패턴 위반은 정보성 경고로 통일 (Claude 가 후속 수정 자가 판단).
exit 0
