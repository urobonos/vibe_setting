#!/bin/bash
# PostToolUse Hook: PHP 안티패턴 린터
# Phase 4 Harness — 차단이 아닌 경고. Claude에게 위반 사항을 주입하여 자동 수정 유도.
#
# 감지 패턴:
#   1. DI 위반: new XxxService/Repository/Model() (Modules 내)
#   2. 레이어 위반: Controller/Service에서 Model 직접 참조
#   3. Raw SQL 위반: Controller/Service에서 $this->db 사용
#   4. SELECT * 사용
#   5. 모듈 간 직접 클래스 참조 (Interface 외)
#   6. Raw query named binding 미사용
#   7. Entity/VO 프레임워크 의존성
#   8. Service/Repository Interface 미구현
#   9. 위험 PHP 함수 (eval, exec, system, shell_exec, unserialize 등)
#  10. var_dump/print_r/dd 디버그 코드 잔존
#  11. WHERE 함수 감싼 조건 (인덱스 무효화)
#  12. FORCE/USE/IGNORE INDEX 쿼리 힌트
#  13. 로깅에 민감정보 포함
#  14. ValueObject 가변성 (불변 위반)

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

# 파일 존재 확인
if [ ! -f "$FILE" ]; then
  exit 0
fi

# Legacy 모드 파일은 검사 제외 (app/Libraries/, app/Controllers/Api/, app/Models/)
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

# 1. DI 위반: new XxxService(), new XxxRepository(), new XxxModel()
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

# 4. SELECT * 사용 (전 레이어)
SELECT_STAR=$(grep -niE "select\s+\*\s+(from|,)" "$FILE" 2>/dev/null)
if [ -n "$SELECT_STAR" ]; then
  WARNINGS="${WARNINGS}\n[SELECT * 금지] 필요 컬럼만 명시하세요 (mysql8 스킬 규칙):\n${SELECT_STAR}\n"
  ((COUNT++))
fi

# 5. 모듈 간 직접 클래스 참조 (Interface 외)
# App\Modules\{A}\Services\XxxService, App\Modules\{A}\Repositories\XxxRepository 등을 직접 use
# 자기 모듈 참조는 허용, 타 모듈 참조만 감지
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

# 6. Raw query named binding 미사용 (Repository에서)
if [[ "$LAYER" == "repository" ]]; then
  # $db->query() 또는 $this->db->query()에서 변수 연결(. $var) 사용 감지
  RAW_CONCAT=$(grep -nE '\$.*db->query\s*\(.*\$' "$FILE" 2>/dev/null \
    | grep -vE ':[a-zA-Z_]+' 2>/dev/null)
  if [ -n "$RAW_CONCAT" ]; then
    WARNINGS="${WARNINGS}\n[SQL Injection 위험] raw query에 변수 연결 감지 → named binding (:param) 사용:\n${RAW_CONCAT}\n"
    ((COUNT++))
  fi
fi

# 7. Entity/VO 외부 의존성 감지 (순수 PHP 강제)
if echo "$FILE" | grep -qE '/(Entities|ValueObjects)/'; then
  FRAMEWORK_DEP=$(grep -nE 'use\s+(CodeIgniter|App\\Models|App\\Libraries|App\\Config)\\' "$FILE" 2>/dev/null)
  if [ -n "$FRAMEWORK_DEP" ]; then
    WARNINGS="${WARNINGS}\n[Entity/VO 순수성 위반] 프레임워크 의존성 감지 → Entity/VO는 순수 PHP만 허용:\n${FRAMEWORK_DEP}\n"
    ((COUNT++))
  fi
fi

# 8. Service/Repository Interface 미구현 감지
if [[ "$LAYER" == "service" || "$LAYER" == "repository" ]]; then
  # class 선언에 implements 키워드가 없으면 경고
  CLASS_DECL=$(grep -nE '^\s*class\s+\w+' "$FILE" 2>/dev/null | head -1)
  if [ -n "$CLASS_DECL" ]; then
    if ! echo "$CLASS_DECL" | grep -qE 'implements\s'; then
      # abstract class, trait 등은 제외
      if ! echo "$CLASS_DECL" | grep -qE '(abstract\s+class|trait\s|interface\s)'; then
        WARNINGS="${WARNINGS}\n[Interface 미구현] ${LAYER} 클래스에 implements 누락 → Interface 정의 후 구현하세요:\n${CLASS_DECL}\n"
        ((COUNT++))
      fi
    fi
  fi
fi

# 9. 위험 PHP 함수 감지 (security-audit Critical)
DANGEROUS_FUNCS=$(grep -nE '\b(eval|exec|system|passthru|shell_exec|popen|proc_open|unserialize)\s*\(' "$FILE" 2>/dev/null \
  | grep -vE '^\s*(//|/\*|\*\s|#)' 2>/dev/null)
if [ -n "$DANGEROUS_FUNCS" ]; then
  WARNINGS="${WARNINGS}\n[보안 Critical] 위험 PHP 함수 감지 → 안전한 대안을 사용하세요:\n${DANGEROUS_FUNCS}\n  eval() → 절대 금지\n  exec/system/shell_exec → Process 라이브러리 또는 제거\n  unserialize → json_decode 사용\n"
  ((COUNT++))
fi

# 10. var_dump/print_r/dd 잔존 감지 (디버그 코드)
DEBUG_FUNCS=$(grep -nE '\b(var_dump|print_r|dd)\s*\(' "$FILE" 2>/dev/null \
  | grep -vE '^\s*(//|/\*|\*\s|#)' 2>/dev/null)
if [ -n "$DEBUG_FUNCS" ]; then
  WARNINGS="${WARNINGS}\n[디버그 코드 잔존] var_dump/print_r/dd 감지 → 프로덕션 코드에서 제거하세요:\n${DEBUG_FUNCS}\n"
  ((COUNT++))
fi

# 11. WHERE 함수 감싼 조건 (인덱스 무효화)
# CI4 Query Builder: ->where('YEAR(col)', val) / raw SQL: WHERE YEAR(col) =
WHERE_FUNC=$(grep -niE '(YEAR|MONTH|DATE|DAY|SUBSTR|SUBSTRING|EXTRACT|LOWER|UPPER|TRIM|LEFT|RIGHT)\s*\(' "$FILE" 2>/dev/null \
  | grep -iE '(where|condition|find)' 2>/dev/null \
  | grep -vE '^\s*(//|/\*|\*\s|#)' 2>/dev/null)
if [ -z "$WHERE_FUNC" ]; then
  # 문자열 안에서 함수 감싼 컬럼: 'YEAR(col)' 또는 "YEAR(col)"
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

# 14. ValueObject 가변성 감지 (불변 강제)
if echo "$FILE" | grep -qE '/(ValueObjects)/'; then
  VO_MUTABLE=$(grep -nE '\$this->[a-zA-Z_]+\s*=' "$FILE" 2>/dev/null \
    | grep -vE '__construct' 2>/dev/null)
  if [ -n "$VO_MUTABLE" ]; then
    WARNINGS="${WARNINGS}\n[VO 불변성 위반] __construct 외부에서 프로퍼티 변경 감지 → ValueObject는 불변이어야 합니다:\n${VO_MUTABLE}\n"
    ((COUNT++))
  fi
fi

# 경고가 있으면 Claude에게 주입
if [ "$COUNT" -gt 0 ]; then
  echo ""
  echo "━━━ PHP Pattern Lint: ${COUNT}건 위반 감지 (${FILE}) ━━━"
  echo -e "$WARNINGS"
  echo "위 위반 사항을 즉시 수정하세요. php8 스킬 규칙 참조."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

exit 0
