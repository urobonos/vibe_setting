---
name: git-push
description: >
  커밋 메시지 포맷 정의 + 현재 브랜치에서 git push를 즉시 실행하는 스킬.
  커밋 포맷의 SSOT. Conventional Commits v1.0.0 표준 `type(scope): 제목` 형식을 정의한다.
triggers:
  - "push", "푸시해", "git push"
version: 2.0.0
user-invocable: true
depends_on: []
conflicts_with: []
min_claude_md_version: "4.0"
---

# Git Push Skill

현재 브랜치에서 `git push`를 즉시 실행한다.

---

## 커밋 메시지 컨벤션 (Conventional Commits v1.0.0)

### 포맷

```
type(scope): 제목 (72자 이내)

본문 (선택, 변경사항 상세)

footer (선택)
```

### type 목록

| type | 용도 |
|------|------|
| `feat` | 새로운 기능 |
| `fix` | 버그 수정 |
| `refactor` | 리팩토링 (기능 변경 없음) |
| `perf` | 성능 개선 |
| `test` | 테스트 추가/수정 |
| `docs` | 문서 변경 |
| `style` | 코드 스타일 (포맷팅, 로직 무변경) |
| `build` | 빌드/의존성 변경 (composer, npm) |
| `ci` | CI/CD 파이프라인 변경 |
| `chore` | 위에 해당 없는 기타 |

### scope 규칙

- **선택사항** — 특정 모듈에 한정된 변경일 때만 사용
- **BE:** 모듈명 PascalCase (`Auth`, `Payment`, `PhoneConsult`)
- **FE:** 페이지/기능 단위 (`Login`, `MyPage`, `Common`)
- **공통/인프라:** 소문자 (`config`, `infra`, `deps`)
- **여러 모듈에 걸친 변경:** scope 생략

### 핵심 규칙

1. 제목은 72자 이내, 명령형("추가", "수정", "제거")
2. 제목과 본문 사이 빈 줄 필수
3. **1커밋 = 1변경** — feat + refactor 혼합 금지
4. scope 안에 대괄호(`[]`) 사용하지 않음

### 예시

```
docs: CLAUDE.md 서버 경로 갱신 — BE/FE 디렉토리 실제 경로 반영
```

```
refactor(Auth): Phase 4C 완료 — new→service() DI 전환 150건+ 실행

- new *Service() → service('xxx') 전환 36건 (Type A/A*/C)
- new *Model() → service('xxxRepository')->getModel() 전환 104건+
- 1935 tests, 2285 assertions 전부 통과
```

```
refactor(Auth)!: session 인증 제거 → JWT 전환

BREAKING CHANGE: 기존 session 기반 인증이 제거됨
```

---

## 규칙

1. `git push`를 현재 브랜치에서 **즉시 실행**한다
2. push 실패 시 에러를 보여주고 수정 방안을 제안한다
3. **[High]** `--force` 또는 `--force-with-lease`는 사용자가 명시적으로 요청한 경우에만 사용한다
4. **실행 주체:** 모든 `git` 명령은 Claude 가 Bash 도구로 **직접 실행**한다. 사용자에게 `! git push` 또는 `! git commit ...` 형태로 떠넘기는 것은 지침 위반이다. 로컬/조회(`status`, `log`, `diff`, `add`, `commit`, `branch`, `checkout`)는 승인 대기 없이 즉시 실행. `push`, `--force`, main/master force push 등 공유 상태 변경은 승인 요청 후 **승인 확인 즉시 Claude 가 직접 호출**한다. 승인 후 실행하지 않고 텍스트만 출력하는 것은 지침 위반이다.
5. **[Critical]** `main`/`master` 브랜치에 force push 요청 시 **경고 후 사용자 확인**을 받는다 (히스토리 손상·공유 상태 비가역 변경)

---

## 자가 검증 체크리스트

push 실행 전후 반드시 확인:

- [ ] `git push`를 **즉시 실행**했는가 (사전 `git status`, `git log` 등 진단을 수행하지 않았는가)
- [ ] 사용자가 명시적으로 요청하지 않은 `--force` / `--force-with-lease` 옵션을 사용하지 않았는가
- [ ] `main`/`master` 브랜치에 force push 시 사용자 경고 + 확인을 받았는가
- [ ] push 실패 시 에러 메시지를 사용자에게 보여주고 수정 방안을 제안했는가
- [ ] upstream이 설정되지 않은 경우 `-u origin {branch}` 옵션을 포함했는가
- [ ] push 성공 시 결과(remote URL, 브랜치, 커밋 범위)를 간결하게 보고했는가
