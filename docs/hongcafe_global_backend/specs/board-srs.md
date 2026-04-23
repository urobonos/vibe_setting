---
문서명: Board — Software Requirements Specification
문서 ID: board-srs
버전: v2.0
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-15
작성자: jypark
대상 시스템: Board Module (HongCafe Global Backend)
관련 문서: board-sdd.md, board-idd.md
적용 표준: IEEE 29148:2018
---

# Board — Software Requirements Specification (SRS)

> IEEE 29148:2018 | version: 2.0 | lastUpdated: 2026-04-15 | module: Board

---

## 1. Introduction / 소개

### 1.1 Purpose / 목적

본 Software Requirements Specification(SRS)은 HongCafe Global Backend의 Board Bounded Context에 대한 기능/비기능 요구사항을 IEEE 29148:2018 표준에 따라 정의한다. 본 문서는 설계(board-sdd.md), 인터페이스(board-idd.md), 테스트 케이스 작성의 기준이 된다.

### 1.2 Scope / 범위

| 항목 | 내용 |
|------|------|
| 모듈(BC) | Board |
| 목적 | 문의, 공지, 댓글, 포스팅, 채용 등 커뮤니티 게시판 기능 제공 |
| 이해관계자 | 일반 사용자(Caller), 상담사(Callee), 관리자 |
| 포함 EP (BoardController) | `GET /api/boards/get-inquiry`, `POST /api/boards/insert-inquiry`, `GET /api/boards/get-notice`, `POST /api/boards/insert-column-comment`, `DELETE /api/boards/delete-column-comment`, `POST /api/boards/comment-report`, `POST /api/boards/comment-report-notify`, `POST /api/boards/insert-recruit`, `GET /api/boards/get-posting`, `POST /api/boards/posting-like` |
| 포함 EP (CommentController) | `POST /api/comments/get-item-comment`, `POST /api/comments/update-comment-help` |
| EP 총수 | 12개 |

### 1.3 Definitions, Acronyms, and Abbreviations / 용어 정의

| 용어 | 정의 |
|------|------|
| SRS | Software Requirements Specification |
| FR | Functional Requirement — 기능 요구사항 |
| NFR | Non-Functional Requirement — 비기능 요구사항 |
| BC | Bounded Context — 독립 모듈 경계 |
| Caller | 일반 사용자 (상담 서비스 이용자) |
| Callee | 상담사 (`ce_code` 보유 계정) |
| MIME | Multipurpose Internet Mail Extensions — 파일 형식 식별자 |
| UPSERT | UPDATE + INSERT — 존재 시 갱신, 없으면 삽입 |
| XSS | Cross-Site Scripting — 스크립트 삽입 공격 |
| cas_code | 상담사 채용 신청 고유 코드 (`CAS-{timestamp}-{random}`) |
| bcc_no | 컬럼 댓글 번호 (Board Column Comment) |
| cm_no | 아이템 댓글 번호 (Comment) |
| cm_parent | 부모 댓글 번호 (0 = 최상위) |

### 1.4 References / 참조 문서

| 문서 | 경로/출처 |
|------|---------|
| 설계 문서 | `docs/specs/board-sdd.md` v2.0 |
| 인터페이스 문서 | `docs/specs/board-idd.md` v2.0 |
| 프로젝트 지침 | `CLAUDE.md` |
| IEEE 29148:2018 | ISO/IEC/IEEE 29148:2018 — Requirements Engineering |
| OWASP XSS Prevention | OWASP Cross-Site Scripting Prevention Cheat Sheet |
| OWASP File Upload | OWASP File Upload Cheat Sheet |
| RFC 6585 | Additional HTTP Status Codes (429 Too Many Requests) |
| RFC 7231 | HTTP/1.1 Semantics and Content |
| MySQL 8.0 Reference | https://dev.mysql.com/doc/refman/8.0/en/ |

### 1.5 Overview / 개요

본 SRS는 다음 섹션으로 구성된다.

- §2 Overall Description — 시스템 관점, 기능 개요, 사용자 분류, 제약사항, 가정
- §3 Functional Requirements — FR별 선행조건/후행조건/입력검증/우선순위/관련 API/검증방법
- §4 Non-Functional Requirements — 정량 기준 및 검증 방법
- §5 External Interface Requirements — 외부 시스템 인터페이스
- §6 Use Cases — 주요 유스케이스 정상/대안/에러 흐름
- §7 Verification Matrix — FR↔UC↔Test↔SDD 4-way 매핑
- §8 Data Dictionary — 핵심 데이터 요소 정의
- §9 타당성 검토
- §10 변경 영향 기록
- §11 변경 로그

---

## 2. Overall Description / 전체 설명

### 2.1 System Perspective / 시스템 관점

Board 모듈은 HongCafe Global Backend의 커뮤니티/게시판 Bounded Context이다. 사용자가 문의를 등록하고 공지사항을 확인하며, 상담사 아이템에 댓글을 달고, 포스팅을 작성하고, 채용 신청을 할 수 있다. AWS S3와 연동하여 이미지 업로드를 처리한다.

```
[Client (Next.js)] ─── JWT + CSRF 쿠키 ───► [AuthFilter] ───► [BoardController / CommentController]
                                                                        │
                                                               [BoardService / CommentFormatter]
                                                                        │
                                                        [BoardRepository / CommentRepository]
                                                                        │
                                                               Aurora MySQL (tb_comment, tb_qna, ...)
                                                                        │
                                              [BoardService::uploadInquiryImages()] ───► AWS S3
```

### 2.2 Functions / 기능 개요

| 기능 그룹 | 설명 |
|----------|------|
| 문의 관리 | 1:1 문의 조회 + 이미지 첨부 등록 (S3) |
| 공지사항 | 공지 목록 페이지네이션 조회 |
| 컬럼 댓글 | 댓글 등록 (쿨다운), 삭제 (소유권), 신고 |
| 아이템 댓글 | 부모-자식 2단계 스레딩, 태그 검색, 도움 토글 |
| 포스팅 | 목록 조회 (베스트 포함), 좋아요 토글 |
| 채용 신청 | 상담사 채용 신청서 등록 (파일 업로드) |

### 2.3 User Classes and Characteristics / 사용자 분류

| 사용자 분류 | 설명 | 인증 수준 |
|-----------|------|----------|
| Caller (일반 사용자) | 문의 등록, 댓글 작성, 포스팅 좋아요 등 | JWT 인증 필수 |
| Callee (상담사) | 아이템 댓글에 대한 응답, 상담사 채용 이력 조회 | JWT 인증 필수 |
| 비인증 사용자 | 공지 조회, 포스팅 목록 조회 가능 | 인증 불필요 |
| 관리자 | 신고 처리, 공지 등록 등 (별도 관리자 모듈) | 관리자 인증 |

### 2.4 Constraints / 제약사항

- Auto Routing 비활성화 (`setAutoRoute(false)`). 모든 EP는 `Routes.php`에 명시적 등록 필수.
- MIME 이중 검증 필수 (확장자 화이트리스트 + `mime_content_type()`).
- 허용 업로드 확장자: `jpg`, `png`, `jpeg`, `gif`.
- 댓글 최소 길이: 5자 이상.
- 댓글 쿨다운: 1초 (쿠키 `last_comment` 기반).
- 신고 사유: `personalInfo`, `externalCommercial`, `counselorSlander`, `badComments` enum 화이트리스트.
- XSS 방어: 출력 시 `htmlspecialchars()` + `stripslashes()` 처리 필수.
- DB charset: `utf8mb4` 통일.
- `DateTimeImmutable` 강제 (`date()`, `time()` 사용 금지).

### 2.5 Assumptions and Dependencies / 가정 및 의존성

| 항목 | 내용 |
|------|------|
| 가정-1 | AWS S3 버킷 및 접근 권한이 환경변수로 사전 설정되어 있음 |
| 가정-2 | `tb_account` 테이블(Member 모듈 소유)을 통해 사용자 정보를 조회함 |
| 가정-3 | `ratelimit` 필터가 전역 적용되어 서버 수준 Rate Limit을 담당함 |
| 의존성-1 | `tb_account` (Member 모듈 소유) — `ac_id`, `ce_code`, `cr_code` 참조 |
| 의존성-2 | `tb_items` (Service 모듈 소유) — 아이템 댓글 수(`it_cmt_cnt`) 갱신 |
| 의존성-3 | AWS S3 (Awss3 라이브러리) — 문의·채용 신청 이미지 업로드 |

---

## 3. Functional Requirements / 기능 요구사항

### FR-001: 문의 조회 (Inquiry Retrieve)

| 항목 | 내용 |
|------|------|
| 설명 | 문의 목록 조회. 유형별 분류, limit+1 패턴 페이지네이션, 본인 문의만 조회 |
| 선행 조건 | JWT 인증 완료 |
| 후행 조건 | 200 OK + 문의 목록 JSON (유형명, 상태 매핑 포함) |
| 입력 검증 | `limit` 양의 정수, `offset` 0 이상. 미제공 시 기본값 적용 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `GET /api/boards/get-inquiry` |
| 검증 방법 | JWT 인증 후 조회 결과가 본인 문의만 포함하는지 확인. 유형명(`qa_part_name`) 매핑 확인 |

### FR-002: 문의 등록 (Inquiry Insert)

| 항목 | 내용 |
|------|------|
| 설명 | 문의 등록 + S3 이미지 업로드 (최대 4개). MIME 이중 검증 |
| 선행 조건 | JWT 인증 완료 |
| 후행 조건 | 201 Created + 등록된 `qa_no`. S3에 이미지 업로드 완료 |
| 입력 검증 | `qa_content` 필수. `qa_part` enum 검증 (`normal/refund/require/report/info/block`). 이미지: 확장자 + `mime_content_type()` 이중 검증, 최대 4개 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/boards/insert-inquiry` |
| 검증 방법 | 유효한 이미지 4개 업로드 후 DB + S3 저장 확인. 허용되지 않는 MIME 업로드 시 400 확인 |

### FR-003: 공지 조회 (Notice Retrieve)

| 항목 | 내용 |
|------|------|
| 설명 | 공지사항 목록 페이지네이션 조회. 비인증 공개 EP |
| 선행 조건 | 없음 (공개 EP) |
| 후행 조건 | 200 OK + 공지 목록 + 페이지네이션 meta |
| 입력 검증 | `limit`, `offset` 양의 정수 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `GET /api/boards/get-notice` |
| 검증 방법 | 비인증 상태에서 200 응답 확인. 페이지네이션 meta(`currentPage`, `perPage`, `total`, `lastPage`) 존재 확인 |

### FR-004: 컬럼 댓글 등록 (Column Comment Insert)

| 항목 | 내용 |
|------|------|
| 설명 | 댓글 등록 (최소 5자). 1초 쿨다운 (`last_comment` 쿠키). 댓글 수 증가 |
| 선행 조건 | JWT 인증 완료. 이전 댓글 등록 후 1초 이상 경과 |
| 후행 조건 | 200 OK + `bcc_no`. `it_cmt_cnt` +1. `last_comment` 쿠키 설정 (1초 TTL) |
| 입력 검증 | `bcc_content` 필수 + 최소 5자. `st_code` 필수. `bcc_parent` 정수 (기본 0). `last_comment` 쿠키 체크 (존재 시 429 반환) |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/boards/insert-column-comment` |
| 검증 방법 | 5자 미만 → 400 `INVALID_INPUT`. 1초 이내 재요청 → 429 `TOO_MANY_REQUESTS`. 정상 등록 → `it_cmt_cnt` 증가 확인 |

### FR-005: 컬럼 댓글 삭제 (Column Comment Delete)

| 항목 | 내용 |
|------|------|
| 설명 | 댓글 소유권 검증 후 삭제. 댓글 수 감소 |
| 선행 조건 | JWT 인증 완료. 댓글 소유자 본인 |
| 후행 조건 | 200 OK + `{ "deleted": true }`. `it_cmt_cnt` -1 |
| 입력 검증 | `bcc_no` 필수 + 양의 정수. 댓글 존재 여부 확인. 소유자 `ac_id` 일치 확인 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `DELETE /api/boards/delete-column-comment` |
| 검증 방법 | 비소유자 삭제 시도 → 403 `FORBIDDEN`. 소유자 삭제 → 200 + `it_cmt_cnt` 감소 확인 |

### FR-006: 댓글 신고 (Comment Report)

| 항목 | 내용 |
|------|------|
| 설명 | 사유 enum 검증 후 댓글 신고. XSS 클리닝 |
| 선행 조건 | JWT 인증 완료 |
| 후행 조건 | 200 OK. 신고 레코드 저장 (`tb_reject`) |
| 입력 검증 | `report_type` enum 화이트리스트 (`personalInfo`, `externalCommercial`, `counselorSlander`, `badComments`). XSS: `htmlspecialchars()` 처리 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/boards/comment-report` |
| 검증 방법 | 유효하지 않은 `report_type` → 400. XSS 페이로드 입력 → 이스케이프 처리 확인 |

### FR-007: 댓글 신고 알림 (Comment Report Notify)

| 항목 | 내용 |
|------|------|
| 설명 | 중복 신고 체크 (댓글 레벨 + 사용자 레벨). 알림 레코드 생성 |
| 선행 조건 | JWT 인증 완료 |
| 후행 조건 | 200 OK. `tb_comment_notify`에 알림 레코드 생성 |
| 입력 검증 | `cm_no` 필수 + 양의 정수. 중복 신고 여부 `getCommentReportYesNo()` + `getCommentUserReportYesNo()` 조회 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/boards/comment-report-notify` |
| 검증 방법 | 동일 사용자 중복 신고 → 409 `CONFLICT`. 최초 신고 → 알림 레코드 생성 확인 |

### FR-008: 상담사 채용 신청 (Recruit Insert)

| 항목 | 내용 |
|------|------|
| 설명 | 채용 신청서 등록. MIME 이중 검증. `cas_code` 자동 생성 (`CAS-{timestamp}-{random}`) |
| 선행 조건 | JWT 인증 완료 |
| 후행 조건 | 201 Created + `cas_code`. 첨부파일 S3 업로드 완료 |
| 입력 검증 | 필수 필드 확인. 파일: 확장자 + `mime_content_type()` 이중 검증 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/boards/insert-recruit` |
| 검증 방법 | `cas_code` 형식 `CAS-YYYYMMDDHHmmss-XXX` 확인. 파일 MIME 오류 → 400. S3 저장 확인 |

### FR-009: 포스팅 목록 조회 (Posting Retrieve)

| 항목 | 내용 |
|------|------|
| 설명 | 첫 로드 시 베스트 포스팅 포함. 키워드 검색. 페이지네이션 |
| 선행 조건 | 없음 (공개 EP) |
| 후행 조건 | 200 OK + 포스팅 목록. `offset=0` 시 베스트 포스팅(랜덤 3) 포함 |
| 입력 검증 | `keyword` 선택. `limit`, `offset` 양의 정수 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `GET /api/boards/get-posting` |
| 검증 방법 | `offset=0` 응답에 `isBest: true` 항목 확인. `keyword` 파라미터로 필터링 확인 |

### FR-010: 포스팅 좋아요 토글 (Posting Like Toggle)

| 항목 | 내용 |
|------|------|
| 설명 | 좋아요 추가/취소 토글. 트랜잭션 내 `like_cnt` 증감 |
| 선행 조건 | JWT 인증 완료 |
| 후행 조건 | 200 OK + `{ "action": "add"|"del", "likeCnt": int }`. `tb_posting.like_cnt` 업데이트 |
| 입력 검증 | `po_no` 필수 + 양의 정수. 기존 좋아요 존재 여부로 add/del 판별 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/boards/posting-like` |
| 검증 방법 | 좋아요 추가 → `likeCnt` +1. 좋아요 취소 → `likeCnt` -1. `tb_board_like` UNIQUE 제약 위반 방지 확인 |

### FR-011: 아이템 댓글 조회 (Item Comment Retrieve)

| 항목 | 내용 |
|------|------|
| 설명 | 고정 댓글 (offset=0), 태그 검색 (#tag), 자식 댓글(cm_reply), 페이지네이션 |
| 선행 조건 | 없음 (공개 EP, 비인증 조회 가능) |
| 후행 조건 | 200 OK + 댓글 배열 + 페이지네이션 meta. 부모 댓글에 `cmReply` 배열 포함 |
| 입력 검증 | `item_code` 필수. `keyword` 태그 검색 시 `#` 포함. `limit` 양의 정수, `offset` 0 이상 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/comments/get-item-comment` |
| 검증 방법 | `offset=0` 응답에 고정 댓글 포함 확인. 태그(`#운세`) 검색 시 해당 댓글만 반환 확인. `cmReply` 배열 구조 확인 |

### FR-012: 댓글 도움 토글 (Comment Help Toggle)

| 항목 | 내용 |
|------|------|
| 설명 | 도움 카운트 추가/삭제 토글 (`add`/`del` 반환) |
| 선행 조건 | JWT 인증 완료 |
| 후행 조건 | 200 OK + `{ "action": "add"|"del" }` |
| 입력 검증 | `cm_no` 필수 + 양의 정수 |
| 우선순위 | 필수 (Priority 1) |
| 관련 API | `POST /api/comments/update-comment-help` |
| 검증 방법 | 도움 추가 → 카운트 증가. 도움 취소 → 카운트 감소. action 반환값 `add`/`del` 확인 |

---

## 4. Non-Functional Requirements / 비기능 요구사항

| ID | 구분 | 요구사항 | 정량 기준 | 검증 방법 |
|----|------|---------|---------|---------|
| NFR-001 | 보안 | XSS 방어 | `htmlspecialchars(ENT_QUOTES, 'UTF-8')` + `stripslashes()` 출력 이중 처리 | 코드 리뷰 + XSS 페이로드 입력 후 이스케이프 확인 |
| NFR-002 | 보안 | MIME 이중 검증 | 확장자 화이트리스트 + `mime_content_type()` 병행 검증 필수 | 허용되지 않는 MIME 파일 업로드 → 400 확인 |
| NFR-003 | 성능 | 댓글 쿨다운 | 1초 (`last_comment` 쿠키 기반). 위반 시 429 | 1초 이내 연속 등록 → 429 확인 |
| NFR-004 | 보안 | 신고 사유 검증 | enum 화이트리스트 4개 항목 (`personalInfo` 등) | 범위 외 값 입력 → 400 확인 |
| NFR-005 | 성능 | 페이지네이션 | CI4 4.7.2 빌트인 Pager (`paginate()` + `pager` 프로퍼티). meta: `currentPage`, `perPage`, `total`, `lastPage` | meta 필드 전체 존재 확인 |
| NFR-006 | 보안 | 파일 업로드 허용 타입 | `jpg`, `png`, `jpeg`, `gif` 만 허용. S3 업로드 | 허용 외 타입 → 400. 허용 타입 → S3 저장 확인 |
| NFR-007 | 보안 | 소유권 검증 | 댓글 삭제 시 `ac_id` 일치 확인 (DB 레벨 WHERE 조건 내장) | 비소유자 삭제 → 403 `FORBIDDEN` 확인 |
| NFR-008 | 신뢰성 | 좋아요 중복 방지 | `tb_board_like(po_no, ac_id)` UNIQUE 제약. 트랜잭션 내 count 증감 | 동시 좋아요 중복 INSERT 시 UNIQUE 위반 처리 확인 |
| NFR-009 | 유지보수성 | DateTimeImmutable 강제 | `date()`, `time()` 사용 금지. `new DateTimeImmutable()` 사용 | 코드 리뷰 (`date()`, `time()` 검색) |
| NFR-010 | 응답 표준 | API 응답 camelCase | DB `snake_case` → API 응답 `camelCase` 변환 필수 | 응답 JSON 키 `cmNo`, `poNo`, `likeCnt` 등 확인 |

---

## 5. External Interface Requirements / 외부 인터페이스 요구사항

### 5.1 User Interface / 사용자 인터페이스

- HTTP/HTTPS REST API. JSON 응답 전용.
- 쿠키 기반 인증 (`hc_access`, `hc_csrf`).
- 모든 POST/PUT/DELETE 요청: `X-CSRF-TOKEN` 헤더 필수.

### 5.2 Hardware Interface / 하드웨어 인터페이스

- 해당 없음.

### 5.3 Software Interface / 소프트웨어 인터페이스

| 외부 시스템 | 프로토콜 | 설명 |
|-----------|---------|------|
| AWS S3 (Awss3 라이브러리) | REST HTTPS | 문의 이미지(최대 4개), 채용 신청 첨부파일 업로드 |
| Member 모듈 (`tb_account`) | 내부 DB | `ac_id`, `ce_code`, `cr_code` 참조 |
| Service 모듈 (`tb_items`) | 내부 DB | 아이템 댓글 수(`it_cmt_cnt`) 갱신 |

### 5.4 Communication Interface / 통신 인터페이스

- HTTPS 전용. ALB → Nginx → PHP-FPM 체인.
- `X-Forwarded-Proto: https` 헤더 필수 (모든 요청).

---

## 6. Use Cases / 유스케이스

### UC-001: 댓글 작성 및 스레딩

- **액터**: 인증된 사용자 (Caller / Callee)
- **관련 FR**: FR-004, FR-011
- **사전조건**: JWT 인증 완료. 이전 댓글 등록 후 1초 이상 경과
- **정상 흐름**:
  1. 댓글 입력 → 최소 5자 검증 통과
  2. `last_comment` 쿠키 1초 쿨다운 체크 통과
  3. `BoardService::buildCommentData()` 레코드 조립
  4. `BoardRepository::insertColumnComment()` 저장
  5. `BoardRepository::updateCommentCnt(+1)` 카운트 증가
  6. `Set-Cookie: last_comment` (1초 TTL)
  7. 200 OK + `{ "data": { "bcc_no": 1234 } }`
- **대안 흐름 (A1)**: 대댓글 (`bcc_parent` 지정) → 부모-자식 연결
- **에러 흐름 (E1)**: 1초 이내 재요청 → 429 `TOO_MANY_REQUESTS`
- **에러 흐름 (E2)**: 5자 미만 → 400 `INVALID_INPUT`

### UC-002: 문의 등록 (이미지 첨부)

- **액터**: 인증된 사용자 (Caller)
- **관련 FR**: FR-002
- **사전조건**: JWT 인증 완료
- **정상 흐름**:
  1. 문의 내용 + 이미지(최대 4개) 전송
  2. `qa_part` enum 검증 통과
  3. 각 이미지 확장자 + `mime_content_type()` 이중 검증
  4. `BoardService::uploadInquiryImages()` → S3 업로드 → `uf_codes` 수집
  5. `BoardRepository::insertInquiry()` 저장
  6. 201 Created + `{ "data": { "qa_no": 5678 } }`
- **에러 흐름 (E1)**: 허용되지 않는 MIME → 400 `INVALID_INPUT`

### UC-003: 포스팅 좋아요 토글

- **액터**: 인증된 사용자
- **관련 FR**: FR-010
- **사전조건**: JWT 인증 완료
- **정상 흐름 (좋아요 추가)**:
  1. `POST /api/boards/posting-like` `{ "po_no": 42 }`
  2. `BoardRepository::getCounselLike(ac_id, po_no)` → 미존재 확인
  3. 트랜잭션: `addPostingLike()` + `like_cnt +1`
  4. 200 OK + `{ "action": "add", "likeCnt": 37 }`
- **정상 흐름 (좋아요 취소)**:
  1. `getCounselLike()` → 존재 확인
  2. 트랜잭션: `deletePostingLike()` + `like_cnt -1`
  3. 200 OK + `{ "action": "del", "likeCnt": 36 }`

### UC-004: 댓글 신고

- **액터**: 인증된 사용자
- **관련 FR**: FR-006, FR-007
- **사전조건**: JWT 인증 완료
- **정상 흐름**:
  1. `POST /api/boards/comment-report` (신고 사유 포함)
  2. `report_type` enum 검증 통과
  3. XSS 클리닝 (`htmlspecialchars()`)
  4. 신고 레코드 저장 (`tb_reject`)
  5. `POST /api/boards/comment-report-notify`
  6. 중복 신고 체크 (`getCommentReportYesNo`, `getCommentUserReportYesNo`)
  7. 알림 레코드 생성 (`tb_comment_notify`)
- **에러 흐름 (E1)**: 중복 신고 → 409 `CONFLICT`

---

## 7. Verification Matrix / 검증 매트릭스 (FR↔UC↔Test↔SDD)

| FR ID | FR 명 | UC ID | 테스트 케이스 | SDD 참조 |
|-------|-------|-------|-------------|---------|
| FR-001 | 문의 조회 | N/A (단일 조회, UC 불필요 — 테스트 케이스로 직접 검증) | `test_get_inquiry_returns_own_inquiries_only` | board-sdd.md §4 Logical |
| FR-002 | 문의 등록 | UC-002 | `test_insert_inquiry_uploads_images_to_s3`, `test_insert_inquiry_rejects_invalid_mime` | board-sdd.md §4 Logical |
| FR-003 | 공지 조회 | N/A (공개 조회, UC 불필요 — 테스트 케이스로 직접 검증) | `test_get_notice_returns_paginated_list`, `test_get_notice_no_auth_required` | board-sdd.md §4 Logical |
| FR-004 | 컬럼 댓글 등록 | UC-001 | `test_insert_comment_min_length`, `test_insert_comment_cooldown_429` | board-sdd.md §4 Logical |
| FR-005 | 컬럼 댓글 삭제 | N/A (단일 액션, UC 불필요 — 소유권 검증을 테스트로 직접 검증) | `test_delete_comment_ownership_check`, `test_delete_comment_forbidden_non_owner` | board-sdd.md §4 Logical |
| FR-006 | 댓글 신고 | UC-004 | `test_comment_report_valid_type`, `test_comment_report_invalid_type_400` | board-sdd.md §4 Logical |
| FR-007 | 댓글 신고 알림 | UC-004 | `test_comment_report_notify_duplicate_409`, `test_comment_report_notify_creates_record` | board-sdd.md §4 Logical |
| FR-008 | 채용 신청 | N/A (단일 액션, UC 불필요 — 테스트 케이스로 직접 검증) | `test_insert_recruit_cas_code_format`, `test_insert_recruit_invalid_mime` | board-sdd.md §4 Logical |
| FR-009 | 포스팅 목록 조회 | N/A (단일 조회, UC 불필요 — 테스트 케이스로 직접 검증) | `test_get_posting_first_load_includes_best`, `test_get_posting_keyword_filter` | board-sdd.md §4 Logical |
| FR-010 | 포스팅 좋아요 토글 | UC-003 | `test_posting_like_add`, `test_posting_like_del`, `test_posting_like_count_sync` | board-sdd.md §4 Logical |
| FR-011 | 아이템 댓글 조회 | UC-001 | `test_get_item_comment_with_children`, `test_get_item_comment_tag_search` | board-sdd.md §4 Logical |
| FR-012 | 댓글 도움 토글 | N/A (단일 토글, UC 불필요 — 테스트 케이스로 직접 검증) | `test_update_comment_help_add`, `test_update_comment_help_del` | board-sdd.md §4 Logical |

---

## 8. Data Dictionary / 데이터 사전

| 데이터 요소 | 타입 | 크기/형식 | 범위/허용값 | 출처/목적지 |
|-----------|------|---------|-----------|-----------|
| `qa_no` | int unsigned | INT UNSIGNED | 1 이상 자동증가 | `tb_qna.qa_no` |
| `qa_part` | string | VARCHAR(50) | `normal/refund/require/report/info/block` | `tb_qna.qa_part` |
| `qa_status` | string | VARCHAR(20) | `standby`, `complete` | `tb_qna.qa_status` |
| `uf_codes` | string | VARCHAR(500) | S3 파일 코드, `\|` 구분 | `tb_qna.uf_codes` |
| `bcc_no` | int unsigned | INT UNSIGNED | 1 이상 자동증가 | `tb_board_comment.bcc_no` |
| `bcc_content` | string | TEXT | 최소 5자 | `tb_board_comment.bcc_content` |
| `bcc_parent` | int | INT UNSIGNED | 0 (최상위) 또는 부모 `bcc_no` | `tb_board_comment.bcc_parent` |
| `cm_no` | int unsigned | INT UNSIGNED | 1 이상 자동증가 | `tb_comment.cm_no` |
| `cm_parent` | int unsigned | INT UNSIGNED | 0 (최상위) 또는 부모 `cm_no` | `tb_comment.cm_parent` |
| `cm_content` | string | TEXT | 최소 5자 | `tb_comment.cm_content` |
| `cm_child_exist` | string | ENUM('y','n') | `y` 또는 `n` | `tb_comment.cm_child_exist` |
| `po_no` | int unsigned | INT UNSIGNED | 1 이상 자동증가 | `tb_posting.po_no` |
| `like_cnt` | int unsigned | INT UNSIGNED | 0 이상 | `tb_posting.like_cnt` |
| `is_best` | string | ENUM('y','n') | `y` 또는 `n` | `tb_posting.is_best` |
| `cas_code` | string | VARCHAR(50) | `CAS-YYYYMMDDHHmmss-XXX` 형식 | `tb_cast.cas_code` |
| `report_type` | string | VARCHAR(50) | `personalInfo`, `externalCommercial`, `counselorSlander`, `badComments` | `tb_reject.report_type` |
| `last_comment` | cookie | string | 댓글 등록 시각 | HTTP Cookie (`last_comment`, TTL 1초) |

---

## 9. 타당성 검토 (Feasibility Review)

> 근거: OWASP 공식 문서, RFC 표준, PHP 공식 문서, MySQL 8.0 Reference Manual

| 요구사항 | 채택 방식 | 근거 (공식 표준/문서) | 결론 |
|---------|----------|----------------------|------|
| 부모-자식 댓글 스레딩 | Self-referencing FK (`cm_parent → cm_no`), 2단계 고정 | OWASP Input Validation Cheat Sheet — 계층 구조는 최대 깊이를 제한하여 재귀 DoS 방어 권고. MySQL 8.0 공식 문서 — Self-join으로 계층 관계 표현 가능. Nested Set/Closure Table은 현 요구사항(2단계) 대비 과잉 복잡도 | **타당** — 2단계 고정으로 재귀 없이 구현 가능. 요구사항 범위 내 최적 선택 |
| XSS 방어 | `htmlspecialchars(ENT_QUOTES, 'UTF-8')` + `stripslashes()` 출력 이중 처리 | OWASP XSS Prevention Cheat Sheet Rule #1 — "HTML Encode Data" 원칙. PHP 내장 `htmlspecialchars(ENT_QUOTES, 'UTF-8')` 권고 패턴과 일치 | **타당** — 별도 라이브러리 없이 PHP 내장 함수로 OWASP 권고 충족 가능 |
| 파일 업로드 MIME 검증 | 확장자 화이트리스트 + `mime_content_type()` 이중 검증 | OWASP File Upload Cheat Sheet — "Validate file type using magic bytes or server-side MIME check" 권고. 확장자 단독 검증은 우회 가능하므로 이중 검증 필수. `mime_content_type()`은 libmagic 기반 magic bytes 검증에 해당 | **타당** — 이중 검증으로 OWASP 권고 충족 |
| Rate Limiting (댓글 쿨다운) | 1초 쿠키 기반 클라이언트 제어 (`last_comment` 쿠키) | RFC 6585 §4 — 429 Too Many Requests. 전역 `ratelimit` 필터가 서버 수준 Rate Limit을 담당하며, 쿠키 기반 쿨다운은 추가적인 UX 수준 제어 | **조건부 타당** — 쿠키 조작으로 우회 가능하나, 전역 Rate Limit이 서버 수준 방어를 담당함. UX 보조 수단으로 적합 |
| 좋아요 UNIQUE 제약 | `tb_board_like(po_no, ac_id)` UNIQUE KEY + 트랜잭션 내 count 증감 | MySQL 8.0 공식 문서 — UNIQUE 제약은 DB 레벨 중복 방지 보장. OWASP API6:2023 — DB 수준 타입 안전성으로 비즈니스 규칙 위반 방지 | **타당** — 동시 요청에서도 UNIQUE 제약으로 중복 좋아요 방지 보장 |

**타당성 검토 결론**: 5개 요구사항 모두 OWASP, RFC, MySQL 8.0 공식 표준 대비 검토 완료. Rate Limiting 쿠키 우회 가능성은 전역 ratelimit 필터로 보완되어 허용 가능 수준으로 판단.

---

## 10. 변경 영향 기록 (Change Impact Log)

| 변경 사항 | 개선점 | 수행 이유 |
|----------|--------|----------|
| v1.x → v2.0: IEEE 29148:2018 표준 재구성 | Introduction(5 sub), Overall Description(5 sub), FR별 선행/후행조건·입력검증·검증방법, NFR 정량 기준, External IF, Use Cases, Verification Matrix, Data Dictionary 전 섹션 완비 | IEEE 29148:2018 표준 준수 — v1.x는 개요·FR·NFR·UC·타당성만 포함하여 표준 섹션 미비. SDD/IDD와의 추적성 강화를 위해 Verification Matrix 신설 |
| Verification Matrix 신설 (§7) | FR↔UC↔테스트케이스↔SDD 4-way 매핑으로 추적성 전면 확보 | v1.x에 없던 핵심 IEEE 섹션. 테스트 케이스 누락 방지 및 SDD 섹션 참조로 설계-요구사항 연결 보장 |
| Data Dictionary 신설 (§8) | 12개 핵심 데이터 요소의 타입·크기·범위·출처 명세. DB 컬럼과 API 응답 간 계약 명확화 | IEEE 29148:2018 §9.5.16 Data Dictionary 요구. 개발자가 단일 문서에서 데이터 요소 전체 스펙 확인 가능 |
| NFR 정량 기준 강화 | 기존 '보안', '성능' 분류에서 정량 기준(응답 코드, 길이 제한, TTL 등) + 검증 방법 추가 | IEEE 29148:2018은 NFR이 측정 가능한 기준(measurable criteria)을 포함해야 함. 정성적 요구사항만으로는 검증 불가 |
| External Interface Requirements 신설 (§5) | AWS S3, Member 모듈, Service 모듈 의존성 명시 | IEEE 29148:2018 §9.5.8 External Interface Requirements 요구. v1.x에서 암묵적이었던 외부 시스템 의존성을 명시적으로 문서화 |

---

## 11. 변경 로그

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|-------|
| 2026-04-15 | 1.0.0 | 초기 작성 | jypark |
| 2026-04-15 | 1.2.0 | 타당성 검토 (4건), 변경 영향 기록 추가 | jypark |
| 2026-04-15 | 2.0.0 | IEEE 29148:2018 전면 재구성. Introduction(5 sub), Overall Description(5 sub), FR 선행/후행/검증 강화, NFR 정량 기준, External IF, Use Cases(4건), Verification Matrix, Data Dictionary 신설 | jypark |
