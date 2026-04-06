---
name: frontend-guard
description: >
  프론트엔드(Next.js) 프로젝트의 파일 작성 및 수정을 절대 금지하는 가드레일 스킬.
  프론트엔드 관련 파일(.tsx, .ts, .jsx, .js, next.config.*, tailwind.config.*, package.json 등)에 대한
  생성, 수정, 삭제 요청이 들어오면 즉시 거부하고 사용자에게 안내한다.
triggers:
  - 프론트엔드 관련 파일(.tsx, .ts, .jsx, .js, next.config.*, tailwind.config.*, package.json) 생성/수정/삭제 요청 시 자동 적용
  - "프론트엔드 수정", "React 컴포넌트", "Next.js 페이지"
version: 1.0.0
depends_on: []
conflicts_with: []
min_claude_md_version: "3.2"
---

# Frontend Guard Skill

프론트엔드 프로젝트에 대한 **작성 및 수정을 절대 금지**하는 가드레일.

---

## 규칙

- 프론트엔드는 **Next.js**로 구현되어 있다.
- 해당 프로젝트의 프론트엔드 코드는 **절대 작성, 수정, 삭제하지 않는다**.
- 프론트엔드 관련 요청이 들어오면 즉시 거부하고 아래와 같이 안내한다:

```
[거부] 프론트엔드(Next.js) 프로젝트의 파일은 작성/수정/삭제가 금지되어 있습니다.
백엔드(CI4) API 변경만 수행 가능합니다.
```

## 금지 대상

- 프론트엔드 소스 파일 (`.tsx`, `.ts`, `.jsx`, `.js`, `.css`, `.scss`)
- Next.js 설정 파일 (`next.config.*`, `middleware.ts`)
- 프론트엔드 패키지 설정 (`package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`)
- 스타일/UI 설정 (`tailwind.config.*`, `postcss.config.*`)
- 프론트엔드 환경 설정 (`.env.local`, `.env.development`, `.env.production` — 프론트엔드 프로젝트 내)

## 허용 범위

- 프론트엔드 코드를 **읽기 전용으로 참조**하여 백엔드 API 설계에 반영하는 것은 허용한다.
- 백엔드 API 응답 형식을 프론트엔드 요구에 맞추기 위해 프론트엔드 코드를 **분석**하는 것은 허용한다.
- 수정은 반드시 **백엔드(CI4) 프로젝트 내에서만** 수행한다.

---

## 자가 검증 체크리스트

프론트엔드 관련 요청 수신 시 반드시 확인:

- [ ] 요청 대상 파일이 금지 대상 확장자(`.tsx`, `.ts`, `.jsx`, `.js`, `.css`, `.scss`)에 해당하는가
- [ ] 요청 대상 파일이 금지 대상 설정 파일(`next.config.*`, `tailwind.config.*`, `package.json`, `middleware.ts`)에 해당하는가
- [ ] 금지 대상에 해당하면 `Edit`, `Write`, `Bash(rm/mv)` 등 **변경 도구를 사용하지 않았는가**
- [ ] 금지 대상에 해당하면 즉시 거부 메시지를 출력했는가
- [ ] `Read`, `Grep`, `Glob` 등 **읽기 전용 도구만** 사용했는가 (참조/분석 목적)
- [ ] 프론트엔드 코드 분석 결과를 백엔드(CI4) 프로젝트 내 파일에만 반영했는가
- [ ] 프론트엔드 프로젝트의 `.env.local`, `.env.development`, `.env.production` 파일을 수정하지 않았는가
