---
name: push
description: >
  커밋 메시지 포맷 정의 + 현재 브랜치에서 git push를 즉시 실행하는 스킬.
  커밋 포맷의 SSOT. Conventional Commits v1.0.0 표준 `type(scope): 제목` 형식을 정의한다.
triggers:
  - "git push"
  - "푸시해"
  - "푸시 진행"
  - "원격 push"
  - "remote push"
  - "/git:push"
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

1. **[Critical · 2026-05-07 갱신] 자동 원격 push 전면 금지** — Claude 는 Bash 도구로 `git push` 를 직접 호출하지 않는다. 모든 분기(feature / source / personal / backup / relay) · 모든 옵션(`--force` / `--force-with-lease` / `--delete` / refspec push 등) 예외 0. `branch-enforce.sh` PreToolUse hook 이 모든 분기에서 `git push` 명령을 exit 2 차단한다. 본 룰은 종전 "승인 후 직접 실행" 정책을 폐기한다 (글로벌 CLAUDE.md §"자동 원격 push 전면 금지" 결정 우선).
2. **사용자 직접 실행 안내** — 사용자가 push 를 원하면 다음 두 경로 중 하나를 안내한다.
   - `! git push ...` (Bash prompt prefix `!` — hook 미적용)
   - PowerShell 셸에서 `git push ...` 직접 입력
3. **본 스킬 호출 시 동작** — `/git:push` 또는 푸시 관련 트리거 호출 시:
   - (a) 현재 분기 + 대상 refspec 확인 (`git rev-parse --abbrev-ref HEAD`, `git log @{u}..HEAD --oneline`)
   - (b) push 시 영향(commit 수, 신규/삭제 분기, force 여부) 보고
   - (c) 사용자에게 직접 실행할 명령 라인 제시 (`! git push origin <branch>` 형태)
   - (d) Claude 가 직접 `git push` 호출 시도하지 않음
4. **실행 주체 (push 외 명령):** 그 외 git 명령(`status`, `log`, `diff`, `add`, `commit`, `branch`, `checkout`, `merge` 등)은 Claude 가 Bash 도구로 직접 실행한다. 사용자에게 `! git commit ...` 텍스트로 떠넘기는 것은 지침 위반이다.
5. **[Critical] main/master 자동 force push 시도 자체 금지** — push 자체가 차단되므로 force push 도 자동 호출 불가. 사용자 직접 실행 시에도 main/master force 는 경고 안내.

---

## 자가 검증 체크리스트

본 스킬 호출 시 반드시 확인:

- [ ] Claude 가 Bash 도구로 `git push` 를 **직접 호출하지 않았는가** (자동 push 전면 금지 — 위반 0)
- [ ] 사용자에게 직접 실행할 명령 라인(`! git push ...` 또는 PowerShell)을 제시했는가
- [ ] 현재 분기 + 대상 refspec + push 영향(commit 수, force 여부)을 보고했는가
- [ ] `main`/`master` force push 의도 감지 시 경고를 안내했는가
- [ ] upstream 미설정 케이스에 `-u origin {branch}` 옵션 안내를 포함했는가
