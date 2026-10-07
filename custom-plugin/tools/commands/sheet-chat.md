---
description: 구글 시트 `채팅` 탭 B1 요청을 읽어 이 세션 맥락 그대로 답하고 B2 에 기록
---

# /tools:sheet-chat

`채팅` 탭(gid 568626710) B1 에 사용자가 적은 요청에 **지금 대화 중인 세션이** 답한다. 헤드리스로 새 세션을 띄우지 않는다 — 새 세션은 진행 중 작업을 몰라 근거 없는 답을 낸다.

## 실행

Claude 가 직접 Bash 로 부른다.

1. 새 요청 조회

   ```bash
   python -I "$(cygpath -w ~/.claude/custom-plugin/tools/scripts/gsheet-chat-reply.py)" peek
   ```

   출력이 비었으면 "새 요청 없음" 한 줄로 끝낸다.

2. 출력된 요청에 **이 세션의 현재 상태**(진행 중 작업·최근 결과·대기 항목)를 근거로 답을 쓴다. 시트에서 읽히므로 마크다운 표·코드블록 대신 평문 줄바꿈으로 쓴다. 답변 파일은 세션 scratchpad 에 둔다.

3. B2 기록

   ```bash
   python -I "$(cygpath -w ~/.claude/custom-plugin/tools/scripts/gsheet-chat-reply.py)" reply {답변 파일}
   ```

## 보고

화면에는 요청 요지 1줄 + "B2 기록 (N자)" 만 낸다. 답변 전문은 시트에 있다.

## 반복

주기는 사용자가 정한다. `/loop {주기} /tools:sheet-chat`.

## SSOT

| 파일 | 역할 |
|---|---|
| `custom-plugin/tools/scripts/gsheet-chat-reply.py` | 시트 입출력·답변 여부 판정 (sha256 상태 `~/.cache/gsheet-chat/`) |
| `custom-plugin/tools/skills/cli-gsheet/SKILL.md` | 자격증명·쓰기 규약 |
