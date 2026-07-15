---
name: search-chat
description: Claude Code 대화 기록(세션 트랜스크립트)을 정규식으로 검색합니다. "이전 대화/채팅 기록 검색", "예전에 X 논의한 세션 찾기" 등에 사용.
---

# tools:search-chat — 대화 기록 검색

사용자가 `/tools:search-chat <검색어 및 옵션>` 형태로 호출합니다.

아래 명령을 **그대로 실행**하고 결과를 그대로(또는 표로 정리해) 보여주세요.
**직접 파일을 열어 검색하지 마세요** — `chat-search.py` 가 검색 엔진입니다.

```bash
python "${CLAUDE_PLUGIN_ROOT}/scripts/chat-search.py" $ARGUMENTS
```

## 옵션
- `--all` : 서브에이전트·워크플로우 트랜스크립트까지 포함 (기본: top-level 세션만)
- `--case` : 대소문자 구분 (기본: 무시)
- `--thinking` : assistant 의 thinking 블록도 검색
- `--project <슬러그>` : 프로젝트 부분일치 필터 (예: hongcafe)
- `--role user|assistant` : 해당 role 만
- `--since / --until YYYY-MM-DD` : 파일 수정일 기준 기간 필터
- `--json` / `--count` : JSON 출력 / 건수만
- `--context N` / `--limit N` : 스니펫 문맥 글자수 / 최대 출력 수

## 예시
- `/tools:search-chat 회원가입`
- `/tools:search-chat "결제 취소" --project hongcafe --since 2026-06-01`
- `/tools:search-chat TODO --role assistant --count`

여러 단어 패턴은 따옴표로 묶습니다.
