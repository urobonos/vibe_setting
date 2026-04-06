---
name: git-push
description: >
  현재 브랜치에서 git push를 즉시 실행하는 스킬.
  사전 진단이나 브랜치 상태 확인 없이 바로 push한다.
  실패 시 에러를 보여주고 수정 방안을 제안한다.
triggers:
  - "push", "푸시해", "git push"
version: 1.1.0
depends_on: []
conflicts_with: []
min_claude_md_version: "3.2"
---

# Git Push Skill

현재 브랜치에서 `git push`를 즉시 실행한다.

---

## 규칙

1. `git push`를 현재 브랜치에서 **즉시 실행**한다
2. push 실패 시 에러를 보여주고 수정 방안을 제안한다
3. 사전에 브랜치 상태 확인이나 진단을 **수행하지 않는다**
4. `--force` 또는 `--force-with-lease`는 사용자가 명시적으로 요청한 경우에만 사용한다
5. `main`/`master` 브랜치에 force push 요청 시 **경고 후 사용자 확인**을 받는다

---

## 자가 검증 체크리스트

push 실행 전후 반드시 확인:

- [ ] `git push`를 **즉시 실행**했는가 (사전 `git status`, `git log` 등 진단을 수행하지 않았는가)
- [ ] 사용자가 명시적으로 요청하지 않은 `--force` / `--force-with-lease` 옵션을 사용하지 않았는가
- [ ] `main`/`master` 브랜치에 force push 시 사용자 경고 + 확인을 받았는가
- [ ] push 실패 시 에러 메시지를 사용자에게 보여주고 수정 방안을 제안했는가
- [ ] upstream이 설정되지 않은 경우 `-u origin {branch}` 옵션을 포함했는가
- [ ] push 성공 시 결과(remote URL, 브랜치, 커밋 범위)를 간결하게 보고했는가
