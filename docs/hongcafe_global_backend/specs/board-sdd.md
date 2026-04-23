---
문서명: Board — Software Design Document
문서 ID: board-sdd
버전: v2.0
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-15
작성자: jypark
대상 시스템: Board Module (HongCafe Global Backend)
관련 문서: board-srs.md, board-idd.md
적용 표준: IEEE 1016-2009 (Software Design Description)
---

# Board — Software Design Document (SDD)

> IEEE 1016-2009 | version: 2.0 | lastUpdated: 2026-04-15 | module: Board

---

## 1. Introduction / 소개

### 1.1 Purpose

This Software Design Document (SDD) describes the software design of the Board Module of HongCafe Global Backend in conformance with IEEE 1016-2009. It covers design decisions, module decomposition, data structures, interface contracts, and architectural rationale derived from the Software Requirements Specification `board-srs.md` v2.0.

### 1.2 Scope

This SDD covers all components within `app/Modules/Board/`: two controllers, two services, two repositories, four interfaces, and configuration files. It addresses 12 endpoints (BoardController 10, CommentController 2).

### 1.3 Definitions, Acronyms, and Abbreviations / 용어 정의

| Term | Definition |
|------|------------|
| SDD | Software Design Document |
| BC | Bounded Context |
| ADR | Architecture Decision Record |
| DI | Dependency Injection |
| VO | Value Object |
| GoF | Gang of Four (Design Patterns, Gamma et al., 1994) |
| DDL | Data Definition Language |
| FSM | Finite State Machine |
| MIME | Multipurpose Internet Mail Extensions |

### 1.4 References / 참조 문서

| Document | Location |
|----------|----------|
| IEEE 1016-2009 — Software Design Description | IEEE Standards |
| board-srs.md v2.0 | `docs/specs/board-srs.md` |
| board-idd.md v2.0 | `docs/specs/board-idd.md` |
| OWASP API Security Top 10 2023 | https://owasp.org/API-Security/ |
| OWASP File Upload Cheat Sheet | https://cheatsheetseries.owasp.org/ |
| GoF Design Patterns | Gamma et al., 1994 |
| MySQL 8.0 Reference Manual | https://dev.mysql.com/doc/refman/8.0/en/ |
| HongCafe Global Backend CLAUDE.md | Project root `CLAUDE.md` |

### 1.5 Overview / 개요

This document is organized using the eight design viewpoints defined in IEEE 1016-2009.

| Section | IEEE 1016 Viewpoint | Content |
|---------|---------------------|---------|
| §2 | Context Viewpoint | 모듈 경계 및 외부 시스템 관계 |
| §3 | Composition Viewpoint | 디렉토리 구조 및 컴포넌트 분해 |
| §4 | Logical Viewpoint | 클래스 설계 — Controller, Service, Repository, Entity/VO |
| §5 | Dependency Viewpoint | 모듈 간 의존성 및 DI 등록 |
| §6 | Information Viewpoint | DB 스키마 및 데이터 흐름 |
| §7 | Patterns Viewpoint | 설계 패턴 및 ADR |
| §8 | Interface Viewpoint | 컴포넌트 인터페이스 계약 |
| §9 | Interaction Viewpoint | 주요 흐름 시퀀스 |
| §10 | Design Overlay | 보안/에러/로깅/트랜잭션 횡단 관심사 |
| §11 | Traceability Matrix | FR↔SDD 추적성 |
| §12 | 타당성 검토 | 설계 결정 검토 |
| §13 | 변경 영향 기록 | 변경 영향 기록 |
| §14 | Document History | 개정 이력 |

---

## 2. Context Viewpoint / 컨텍스트 관점

### 2.1 Module Boundaries / 모듈 경계

Board 모듈은 HongCafe Global Backend Modular Monolith 내의 독립적인 Bounded Context이다. 인접 모듈과의 통신은 선언된 인터페이스를 통해서만 수행한다 (직접적인 교차 모듈 Repository 접근 금지).

```text
+---------------------------------------------------------------+
|                   HongCafe Global Backend                     |
|  +----------------------------------------------------------+ |
|  |                    Board Module                          | |
|  |  BoardController (10 EP)  CommentController (2 EP)      | |
|  |  +------------------+    +------------------------+     | |
|  |  | BoardService     |    | CommentFormatter       |     | |
|  |  +--------+---------+    +----------+-------------+     | |
|  |           |                         |                   | |
|  |  +--------v-------------------------v----------------+  | |
|  |  | BoardRepository (29 methods) | CommentRepository  |  | |
|  |  +---------------------+--------+-------------------+  | |
|  +-------------------------------+--------------------------+ |
|                                  | Aurora MySQL              |
|  +--------------------+  +-------v--------------------------+ |
|  |  Member Module     |  |  Service Module                  | |
|  |  (tb_account)      |  |  (tb_items — it_cmt_cnt)        | |
|  +--------------------+  +----------------------------------+ |
+----------------------------------+----------------------------+
                                   | REST HTTPS
                          +--------v--------+     +----------+
                          |  Next.js 16     |     |  AWS S3  |
                          |  Frontend       |     | (Images) |
                          +-----------------+     +----------+
```

### 2.2 External System Relationships / 외부 시스템 관계

| External System | Protocol | Purpose | Failure Mode |
|-----------------|----------|---------|-------------|
| AWS S3 (Awss3 라이브러리) | REST HTTPS | 문의 이미지(최대 4개), 채용 신청 첨부파일 업로드 | 500 `INTERNAL` 반환 |
| Member 모듈 (`tb_account`) | 내부 DB | 사용자 `ac_id`, `ce_code`, `cr_code` 참조 | DB 접근 실패 시 500 |
| Service 모듈 (`tb_items`) | 내부 DB | 아이템 댓글 수(`it_cmt_cnt`) 증감 | 트랜잭션 롤백 |

---

## 3. Composition Viewpoint / 구성 관점

### 3.1 Directory Structure / 디렉토리 구조

```text
app/Modules/Board/
├── Controllers/
│   ├── BoardController.php         -- 10 endpoints (문의/공지/댓글/채용/포스팅)
│   └── CommentController.php       -- 2 endpoints (아이템 댓글/도움)
├── Services/
│   ├── BoardService.php            -- 게시판 비즈니스 로직 (9 메서드)
│   └── CommentFormatter.php        -- 부모-자식 댓글 포맷팅
├── Repositories/
│   ├── BoardRepository.php         -- 게시판 데이터 접근 (29 메서드)
│   └── CommentRepository.php       -- 아이템 댓글 데이터 접근 (3 메서드)
├── Interfaces/
│   ├── BoardServiceInterface.php
│   ├── CommentFormatterInterface.php
│   ├── BoardRepositoryInterface.php
│   └── CommentRepositoryInterface.php
└── Config/
    ├── Routes.php                  -- 12 라우트 명시적 등록
    └── Services.php                -- DI 등록 (4개 바인딩)
```

### 3.2 Endpoint Distribution / 엔드포인트 분포

| Controller | Endpoint Count | Authentication | Responsibility |
|------------|---------------|----------------|----------------|
| `BoardController` | 10 | JWT (일부 공개) | 문의/공지/댓글/신고/채용/포스팅 |
| `CommentController` | 2 | JWT (일부 공개) | 아이템 댓글 스레딩, 도움 토글 |

---

## 4. Logical Viewpoint / 논리 관점

### 4.1 Controller Layer / 컨트롤러 계층

| Class | Method | HTTP | URL | Authentication |
|-------|--------|------|-----|----------------|
| `BoardController` | `getInquiry()` | GET | `/api/boards/get-inquiry` | JWT |
| `BoardController` | `insertInquiry()` | POST | `/api/boards/insert-inquiry` | JWT |
| `BoardController` | `getNotice()` | GET | `/api/boards/get-notice` | 공개 |
| `BoardController` | `insertColumnComment()` | POST | `/api/boards/insert-column-comment` | JWT |
| `BoardController` | `deleteColumnComment()` | DELETE | `/api/boards/delete-column-comment` | JWT |
| `BoardController` | `commentReport()` | POST | `/api/boards/comment-report` | JWT |
| `BoardController` | `commentReportNotify()` | POST | `/api/boards/comment-report-notify` | JWT |
| `BoardController` | `insertRecruit()` | POST | `/api/boards/insert-recruit` | JWT |
| `BoardController` | `getPosting()` | GET | `/api/boards/get-posting` | 공개 |
| `BoardController` | `postingLike()` | POST | `/api/boards/posting-like` | JWT |
| `CommentController` | `getItemComment()` | POST | `/api/comments/get-item-comment` | 공개 |
| `CommentController` | `updateCommentHelp()` | POST | `/api/comments/update-comment-help` | JWT |

모든 컨트롤러는 `BaseController`를 상속하며 JWT 인증 요구 EP에서 `checkNeedLogin(true)`를 사용한다.

### 4.2 Service Layer / 서비스 계층

| Class | Method | Description |
|-------|--------|-------------|
| `BoardService` | `buildCommentData(array $post, array $member): array` | 댓글 레코드 조립 (`st_code`, `ac_id`, `bcc_nick`, `timestamps`) |
| `BoardService` | `buildCommentNotifyData(array $commentInfo, array $member, string $content): array` | 알림 레코드 조립 (`ce`/`cr` 분기, `UserRole` enum) |
| `BoardService` | `resolveNotifierId(array $member): string` | `ce_code` 또는 `cr_code` 반환 |
| `BoardService` | `formatInquiryList(array $result, array $typeName): array` | 문의 목록 포맷 (`qa_part→typeName`, 상태 일본어 매핑) |
| `BoardService` | `uploadInquiryImages(array $files, string $stCode): array` | S3 업로드 (Awss3, 확장자 검증, 최대 4개) |
| `BoardService` | `buildInquiryData(array $post, array $member, array $images): array` | 문의 데이터 조립 |
| `BoardService` | `formatNoticeList(array $result): array` | 공지 목록 포맷 |
| `BoardService` | `buildRecruitData(array $post, array $files): array` | 채용 데이터 조립 (`cas_code=CAS-{timestamp}-{random}`) |
| `BoardService` | `formatPostingList(array $result, array $bestResult): array` | 베스트+일반 병합, `display_date` 포맷 |
| `CommentFormatter` | `formatCommentList(array $comments, callable $fetchChildren, ?callable $fieldFormatter): array` | 부모 댓글 처리 → 자식 댓글 조회 → 연결, hasNext 판별 |

### 4.3 Repository Layer / 저장소 계층

| Class | Method Count | Categories |
|-------|-------------|------------|
| `BoardRepository` | **29** | 문의(2), 공지(1), FAQ(1), 포스팅(2), 댓글(3), 좋아요(3), 신고(4), 채용(2), 기타(11) |
| `CommentRepository` | 3 | `getItemListComment`, `firstCheckWriteComment`, `countCalleeCommentList` |

### 4.4 Entity and Value Object / 엔터티 및 값 객체

현재 Board 모듈은 레거시 PHP 배열(`array`) 기반 데이터 전달 방식을 사용한다. `dev/migration` 브랜치에서 점진적 Entity 전환 예정.

| Target | Current State | Migration Target | Branch |
|--------|--------------|-----------------|--------|
| 댓글 데이터 | PHP `array` | `CommentEntity` (`cm_no`, `cm_content`, `cm_parent`, `cm_child_exist`, `cm_reply`, `regist_date`) | `dev/migration` |
| 포스팅 데이터 | PHP `array` | `PostingEntity` (`po_no`, `po_title`, `like_cnt`, `is_best`) | `dev/migration` |
| 문의 데이터 | PHP `array` | `InquiryEntity` (`qa_no`, `qa_part`, `qa_status`, `qa_content`) | `dev/migration` |

---

## 5. Dependency Viewpoint / 의존성 관점

### 5.1 DI Registration / DI 등록

모든 DI 바인딩은 `app/Modules/Board/Config/Services.php`에 등록한다. 중앙 `app/Config/Services.php` 바인딩 금지.

| Interface | Concrete Class | Scope |
|-----------|---------------|-------|
| `BoardServiceInterface` | `BoardService` | Shared (singleton) |
| `CommentFormatterInterface` | `CommentFormatter` | Shared (singleton) |
| `BoardRepositoryInterface` | `BoardRepository` | Shared (singleton) |
| `CommentRepositoryInterface` | `CommentRepository` | Shared (singleton) |

### 5.2 Cross-Module Dependencies / 모듈 간 의존성

| Dependency Direction | Method | Description |
|---------------------|--------|-------------|
| Board → Member | 내부 DB (`tb_account`) | `ac_id`, `ce_code`, `cr_code` 참조 |
| Board → Service | 내부 DB (`tb_items`) | 댓글 등록/삭제 시 `it_cmt_cnt` 갱신 |
| Board → Shared | `service('csrfTokenService')` | CSRF 검증 (횡단 관심사) |

### 5.3 Filter Chain / 필터 체인

상태 변경 요청(POST/DELETE)은 다음 순서로 필터를 통과한다.

```
ratelimit → csrftoken → auth → Controller
```

공개 EP (getNotice, getPosting, getItemComment)는 `auth` 필터 제외.

---

## 6. Information Viewpoint / 정보 관점

### 6.1 Core Tables / 핵심 테이블

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `tb_board_comment` | 컬럼 댓글 | `bcc_no`, `bcc_content`, `bcc_parent`, `ac_id`, `it_code` |
| `tb_comment` | 아이템 댓글 (부모-자식 스레딩) | `cm_no`, `cm_parent`, `cm_content`, `cm_child_exist`, `cm_status` |
| `tb_comment_notify` | 댓글 신고 알림 | `cn_no`, `cm_no`, `reporter_id`, `report_type` |
| `tb_qna` | 1:1 문의 | `qa_no`, `qa_part`, `qa_status`, `qa_content`, `uf_codes` |
| `tb_notice` | 공지사항 | `no_no`, `no_title`, `no_content` |
| `tb_posting` | 포스팅/블로그 | `po_no`, `po_title`, `like_cnt`, `is_best` |
| `tb_board_like` | 좋아요 | `bl_no`, `po_no`, `ac_id` |
| `tb_cast` | 상담사 채용 신청 | `cas_no`, `cas_code`, `ac_id` |
| `tb_reject` | 신고/차단 | `rj_no`, `cm_no`, `report_type` |

### 6.2 ERD (Text Representation) / ERD

```text
[tb_comment] 1──N [tb_comment] (self-ref: cm_parent → cm_no, 2단계 고정)
[tb_posting] 1──N [tb_board_like] (UNIQUE: po_no + ac_id)
[tb_account] 1──N [tb_qna]       (ac_id FK)
[tb_account] 1──N [tb_comment]   (ac_id FK)
[tb_account] 1──N [tb_board_comment] (ac_id FK)
[tb_items]   1──N [tb_comment]   (it_code FK, it_cmt_cnt 동기화)
```

### 6.3 SQL DDL (Primary Tables) / SQL DDL

#### tb_comment (아이템 댓글, self-referencing)

```sql
CREATE TABLE tb_comment (
    cm_no          INT UNSIGNED     AUTO_INCREMENT PRIMARY KEY,
    it_code        VARCHAR(50)      NOT NULL,
    ac_id          VARCHAR(256)     NOT NULL,
    cm_content     TEXT             NOT NULL,
    cm_parent      INT UNSIGNED     DEFAULT 0      COMMENT '부모 댓글 번호 (0=최상위)',
    cm_child_exist ENUM('y','n')    DEFAULT 'n',
    cm_point5      DECIMAL(3,1)     DEFAULT 0.0,
    cm_img         VARCHAR(500)     DEFAULT NULL,
    cm_status      ENUM('y','n')    DEFAULT 'y',
    regist_date    DATETIME         DEFAULT CURRENT_TIMESTAMP,
    st_code        VARCHAR(20)      DEFAULT 'hongcafe',
    INDEX idx_it_code (it_code, cm_parent),
    INDEX idx_ac_id   (ac_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### tb_qna (1:1 문의)

```sql
CREATE TABLE tb_qna (
    qa_no       INT UNSIGNED     AUTO_INCREMENT PRIMARY KEY,
    ac_id       VARCHAR(256)     NOT NULL,
    qa_part     VARCHAR(50)      NOT NULL       COMMENT 'normal/refund/require/report/info/block',
    qa_title    VARCHAR(300)     DEFAULT NULL,
    qa_content  TEXT             NOT NULL,
    qa_status   VARCHAR(20)      DEFAULT 'standby' COMMENT 'standby/complete',
    uf_codes    VARCHAR(500)     DEFAULT NULL   COMMENT '이미지 코드 | 구분',
    regist_date DATETIME         DEFAULT CURRENT_TIMESTAMP,
    st_code     VARCHAR(20)      DEFAULT 'hongcafe',
    INDEX idx_ac_id     (ac_id),
    INDEX idx_qa_status (qa_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### tb_posting (포스팅/블로그)

```sql
CREATE TABLE tb_posting (
    po_no       INT UNSIGNED     AUTO_INCREMENT PRIMARY KEY,
    ac_id       VARCHAR(256)     NOT NULL,
    po_title    VARCHAR(300)     NOT NULL,
    po_content  LONGTEXT         DEFAULT NULL,
    po_img      VARCHAR(500)     DEFAULT NULL,
    like_cnt    INT UNSIGNED     DEFAULT 0,
    is_best     ENUM('y','n')    DEFAULT 'n',
    po_status   ENUM('y','n')    DEFAULT 'y',
    regist_date DATETIME         DEFAULT CURRENT_TIMESTAMP,
    st_code     VARCHAR(20)      DEFAULT 'hongcafe',
    INDEX idx_ac_id     (ac_id),
    INDEX idx_is_best   (is_best),
    INDEX idx_po_status (po_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### tb_board_like (좋아요)

```sql
CREATE TABLE tb_board_like (
    bl_no       INT UNSIGNED     AUTO_INCREMENT PRIMARY KEY,
    po_no       INT UNSIGNED     NOT NULL,
    ac_id       VARCHAR(256)     NOT NULL,
    regist_date DATETIME         DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_po_ac (po_no, ac_id),
    INDEX idx_po_no (po_no),
    FOREIGN KEY fk_po_no (po_no) REFERENCES tb_posting(po_no) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 6.4 cas_code Generation Rule / cas_code 생성 규칙

```
CAS-{YYYYMMDDHHmmss}-{XXX}
     creation timestamp       random 3 characters
```

- Timestamp: UTC 기반 `DateTimeImmutable`, `YYYYMMDDHHmmss` 형식
- Random segment: 생성 시점 3자리 영숫자
- `cas_code` UNIQUE 제약으로 중복 방지

---

## 7. Patterns Viewpoint / 패턴 관점

### 7.1 Applied Design Patterns / 적용 설계 패턴

| Pattern | Location | Rationale |
|---------|----------|-----------|
| Strategy (GoF, callable variant) | `CommentFormatter::formatCommentList(callable $fetchChildren, ?callable $fieldFormatter)` | Board/Member 두 모듈이 동일 포맷터를 다른 필드 변환 규칙으로 재사용. PHP callable 주입으로 DRY 원칙 충족, 모의 주입(unit test)으로 테스트 가능 |
| Repository | `BoardRepository`, `CommentRepository` | DB 접근을 비즈니스 로직에서 격리. 서비스 계층의 독립 단위 테스트 가능 |
| Facade | `BoardService::uploadInquiryImages()` | Awss3 라이브러리의 복잡한 S3 업로드 과정을 단순하고 테스트 가능한 인터페이스로 래핑 |

### 7.2 Architecture Decision Records / 아키텍처 결정 기록

| ADR | Decision | Rationale | Alternative |
|-----|----------|-----------|-------------|
| ADR-001 | Self-referencing 댓글 스레딩 (`cm_parent`) | 2단계 스레딩만 필요. 단순 Self-join으로 구현 가능. Nested Set/Closure Table은 현 요구사항(2단계) 대비 과잉 복잡도 | Nested Set, Closure Table |
| ADR-002 | S3 업로드 서버 경유 방식 | 서버 사이드 MIME 검증(OWASP File Upload) 보장. 기존 Awss3 인프라 재사용. 최대 4개 이미지 제한으로 서버 메모리 부하 허용 가능 수준 | Presigned URL 직접 업로드 (검증 우회 위험) |
| ADR-003 | 1초 쿠키 기반 쿨다운 (`last_comment`) | 클라이언트 측 경량 UX 제어. 서버 상태 불필요. 전역 `ratelimit` 필터가 서버 수준 Rate Limit 담당 | 서버 측 Redis Rate Limit (이미 전역 적용) |
| ADR-004 | ENUM 타입 (`cm_child_exist`, `is_best`, `po_status`) | 고정 값 집합에서 DB 레벨 타입 안전성 제공(OWASP API6:2023). 인덱스 효율성. 잘못된 값 저장 레이어에서 거부 | VARCHAR + CHECK 제약 |
| ADR-005 | 명시적 라우팅 (ResourceController 미사용) | Board 모듈은 `get-inquiry`, `insert-column-comment` 등 도메인 특화 액션이 많아 RESTful 7개 메서드 전제의 ResourceController 패턴 미적합. Auto Routing 비활성화 정책과 일치 | CI4 ResourceController |

---

## 8. Interface Viewpoint / 인터페이스 관점

### 8.1 Internal Interface Contracts / 내부 인터페이스 계약

**BoardServiceInterface**

```php
public function buildCommentData(array $post, array $member): array;
public function buildCommentNotifyData(array $commentInfo, array $member, string $content): array;
public function resolveNotifierId(array $member): string;          // ce_code 또는 cr_code
public function formatInquiryList(array $result, array $typeName): array;
public function uploadInquiryImages(array $files, string $stCode): array; // S3, max 4개
public function buildInquiryData(array $post, array $member, array $images): array;
public function formatNoticeList(array $result): array;
public function buildRecruitData(array $post, array $files): array;       // cas_code 자동 생성
public function formatPostingList(array $result, array $bestResult): array;
```

**CommentFormatterInterface**

```php
public function formatCommentList(
    array $comments,
    callable $fetchChildren,
    ?callable $fieldFormatter = null
): array;
// 반환: ['comments' => [...], 'hasNext' => bool]
// $fieldFormatter null 시 기본 포맷: stripslashes, regist_date→Y.m.d
```

**BoardRepositoryInterface** (29 methods)

주요 카테고리별 시그니처:

```php
// 문의
public function getBoardInquiry(array $params): array;
public function insertInquiry(array $data): int;

// 공지
public function getBoardNotice(array $params): array;

// 댓글
public function insertColumnComment(array $data): int;
public function deleteColumnComment(int $bccNo, string $acId): bool;
public function updateCommentCnt(string $itCode, int $delta): void; // +1 or -1

// 포스팅
public function getBoardPosting(array $params): array;
public function getBoardBestPosting(string $stCode): array;  // 랜덤 3건

// 좋아요
public function addPostingLike(int $poNo, string $acId): void;      // 트랜잭션 내
public function deletePostingLike(int $poNo, string $acId): void;   // 트랜잭션 내
public function getCounselLike(string $acId, int $poNo): bool;

// 신고
public function boardCommentReportUpdate(array $data): void;
public function getCommentReportYesNo(int $cmNo): bool;
public function getCommentUserReportYesNo(int $cmNo, string $acId): bool;
public function insertCommentNotify(array $data): int;

// 채용
public function insertCast(array $data): int;
public function getCastInfo(string $casCode): ?array;

// 댓글 정보
public function getCommentInfo(int $cmNo): ?array;
```

**CommentRepositoryInterface**

```php
public function getItemListComment(array $params): array;    // 아이템 댓글 (고정+일반, 태그 검색)
public function firstCheckWriteComment(array $params): bool; // 댓글 작성 가능 여부
public function countCalleeCommentList(string $ceCode): int; // 상담사 댓글 수
```

### 8.2 API Response Contracts / API 응답 계약

| Condition | HTTP Status | Response Body |
|-----------|-------------|---------------|
| 성공 (조회) | 200 | `{ "data": { ... } }` |
| 성공 (생성) | 201 | `{ "data": { ... } }` |
| 에러 | 4xx / 5xx | `{ "error": { "code": "...", "message": "..." } }` |

DB `snake_case` 필드는 모든 응답에서 API `camelCase`로 변환 (예: `cm_no` → `cmNo`, `po_no` → `poNo`).

---

## 9. Interaction Viewpoint / 인터랙션 관점

### 9.1 Comment Insert — Normal Flow / 댓글 등록 정상 흐름

```text
Client → BoardController::insertColumnComment()
           ├─ checkNeedLogin(true) — JWT 검증
           ├─ bcc_content 최소 5자 검증
           ├─ last_comment 쿠키 1초 체크 (존재 시 429)
           ├─ BoardService::buildCommentData($post, $member)
           ├─ BoardRepository::insertColumnComment($data) → bcc_no
           ├─ BoardRepository::updateCommentCnt($itCode, +1)
           ├─ Set-Cookie: last_comment (1초 TTL)
           └─ 200 OK { "data": { "bccNo": 1234 } }
```

### 9.2 Comment Insert — Error Flows / 댓글 등록 에러 흐름

```text
Client → BoardController::insertColumnComment()
           ├─ [5자 미만] bcc_content 길이 검증 실패
           │         → 400 { "error": { "code": "INVALID_INPUT" } }
           │
           └─ [1초 쿨다운] last_comment 쿠키 존재
                     → 429 { "error": { "code": "TOO_MANY_REQUESTS" } }
```

### 9.3 Inquiry Insert — S3 Upload Flow / 문의 등록 + S3 흐름

```text
Client → BoardController::insertInquiry()
           ├─ checkNeedLogin(true)
           ├─ qa_part enum 검증
           ├─ [이미지 있을 시] 확장자 검증 → mime_content_type() 검증
           ├─ BoardService::uploadInquiryImages($files, $stCode)
           │         ├─ Awss3::upload() → S3 URL 획득 (최대 4회)
           │         └─ uf_codes 배열 수집
           ├─ BoardService::buildInquiryData($post, $member, $images)
           ├─ BoardRepository::insertInquiry($data) → qa_no
           └─ 201 Created { "data": { "qaNno": 5678 } }
```

### 9.4 Posting Like Toggle / 포스팅 좋아요 토글

```text
Client → BoardController::postingLike()
           ├─ checkNeedLogin(true)
           ├─ BoardRepository::getCounselLike(ac_id, po_no)
           │
           ├─ [미존재] addPostingLike() + like_cnt+1 (트랜잭션)
           │         → 200 { "data": { "action": "add", "likeCnt": 37 } }
           │
           └─ [존재] deletePostingLike() + like_cnt-1 (트랜잭션)
                     → 200 { "data": { "action": "del", "likeCnt": 36 } }
```

---

## 10. Design Overlay / 설계 오버레이

### 10.1 Security Overlay / 보안 횡단 관심사

| Concern | Implementation |
|---------|---------------|
| XSS 방어 | 출력 시 `htmlspecialchars(ENT_QUOTES, 'UTF-8')` + `stripslashes()` 이중 처리 |
| MIME 이중 검증 | 확장자 화이트리스트 (`jpg`, `png`, `jpeg`, `gif`) + `mime_content_type()` |
| 소유권 검증 | 댓글 삭제 시 Repository 쿼리에 `WHERE bcc_no = ? AND ac_id = ?` 조건 내장 |
| 신고 사유 enum | `report_type` 화이트리스트 검증 (4개 항목) |
| CSRF | 모든 POST/DELETE 요청에 `X-CSRF-TOKEN` 헤더 검증 (`CsrfTokenFilter`) |

### 10.2 Error Handling Overlay / 에러 처리 횡단 관심사

| Error Condition | HTTP Code | Error Code |
|----------------|-----------|------------|
| 입력값 검증 실패 (5자 미만 등) | 400 | `INVALID_INPUT` |
| 미인증 | 401 | `UNAUTHORIZED` |
| 소유권 불일치 | 403 | `FORBIDDEN` |
| 리소스 미존재 | 404 | `NOT_FOUND` |
| 중복 신고 | 409 | `CONFLICT` |
| 쿨다운 위반 | 429 | `TOO_MANY_REQUESTS` |
| S3 업로드 실패 | 500 | `INTERNAL` |

### 10.3 Logging Overlay / 로깅 횡단 관심사

- S3 업로드 실패: 에러 로그 기록 (재시도 없음)
- 신고 처리: 신고 레코드 생성 이력 로그

### 10.4 Transaction Overlay / 트랜잭션 횡단 관심사

| Operation | Transactional Scope |
|-----------|---------------------|
| `addPostingLike()` + `like_cnt +1` | 단일 트랜잭션 (UNIQUE 제약 + count 동기화) |
| `deletePostingLike()` + `like_cnt -1` | 단일 트랜잭션 |
| `insertColumnComment()` + `updateCommentCnt(+1)` | 단일 트랜잭션 |
| `deleteColumnComment()` + `updateCommentCnt(-1)` | 단일 트랜잭션 |

---

## 11. Traceability Matrix / 추적성 매트릭스 (FR↔SDD)

| FR ID | FR 명 | SDD Viewpoint | SDD Section | Controller | Service | Repository | Table |
|-------|-------|---------------|-------------|-----------|---------|------------|-------|
| FR-001 | 문의 조회 | Logical | §4.1, §4.3 | `BoardController::getInquiry()` | — | `BoardRepository::getInquiryList()` | `tb_qna` |
| FR-002 | 문의 등록 | Interaction | §9.3 | `BoardController::insertInquiry()` | `BoardService::buildInquiryData()` | `BoardRepository::insertInquiry()` | `tb_qna` |
| FR-003 | 공지 조회 | Logical | §4.1 | `BoardController::getNotice()` | — | `BoardRepository::getNoticeList()` | `tb_board` |
| FR-004 | 컬럼 댓글 등록 | Interaction | §9.1 | `CommentController::insertColumnComment()` | `BoardService::buildCommentData()` | `BoardRepository::insertComment()` | `tb_board_comment` |
| FR-005 | 컬럼 댓글 삭제 | Design Overlay | §10.1 | `CommentController::deleteColumnComment()` | — | `BoardRepository::deleteComment()` | `tb_board_comment` |
| FR-006 | 댓글 신고 | Design Overlay | §10.1 | `CommentController::commentReport()` | — | `BoardRepository::insertCommentReport()` | `tb_reject` |
| FR-007 | 댓글 신고 알림 | Logical | §4.3 | `CommentController::commentReportNotify()` | — | `BoardRepository::getCommentReportYesNo()` | `tb_reject` |
| FR-008 | 상담사 채용 신청 | Information | §6.4 | `BoardController::insertRecruit()` | — | `BoardRepository::insertRecruit()` | `tb_cast` |
| FR-009 | 포스팅 목록 조회 | Logical | §4.2 | `BoardController::getPosting()` | `BoardService::formatPostingList()` | `BoardRepository::getPostingList()` | `tb_posting` |
| FR-010 | 포스팅 좋아요 토글 | Interaction | §9.4 | `BoardController::postingLike()` | — | `BoardRepository::togglePostingLike()` | `tb_board_like` |
| FR-011 | 아이템 댓글 조회 | Patterns | §7.1 | `CommentController::getItemComment()` | `CommentFormatter::formatCommentList()` | `CommentRepository::getItemListComment()` | `tb_comment` |
| FR-012 | 댓글 도움 토글 | Logical | §4.1 | `CommentController::updateCommentHelp()` | — | `CommentRepository::updateCommentHelp()` | `tb_comment` |

---

## 12. 타당성 검토 (Feasibility Review)

> 근거: GoF Design Patterns (Gamma et al., 1994), OWASP API Security Top 10 2023, OWASP File Upload Cheat Sheet, MySQL 8.0 Reference Manual

| Review ID | Topic | Conclusion | Rationale | Alternative | Trade-offs |
|-----------|-------|------------|-----------|-------------|------------|
| FEA-001 | CommentFormatter callable 패턴 | GoF Strategy variant 적합 | Board/Member 두 모듈이 동일 포맷터를 다른 필드 변환 규칙으로 재사용. PHP callable 주입(GoF Strategy variant)으로 DRY 원칙 충족. Mock callable 주입으로 단위 테스트 가능 | 각 모듈별 별도 Formatter 구현 (코드 중복) | Callable: 높은 유연성, Interface로 타입 안전성 보완. 별도 Formatter: 타입 안전하나 코드 중복 |
| FEA-002 | Self-referencing 댓글 스레딩 | Self-join 2단계 고정 적합 | 요구사항이 2단계 스레딩만 요구. MySQL 8.0 공식 문서 — Self-join으로 계층 관계 단순 표현 가능. Nested Set/Closure Table은 INSERT/DELETE 비용 증가 | Nested Set, Closure Table | Self-join: 단순, 2단계 고정으로 재귀 DoS 방어. Nested Set: 조회 빠르나 쓰기 복잡 |
| FEA-003 | S3 서버 경유 업로드 | 서버 경유 적합 (최대 4개 제한 조건) | OWASP File Upload Cheat Sheet — 서버 사이드 MIME 검증 후 업로드 권고. 클라이언트 직접 업로드(Presigned URL)는 검증 우회 위험. 현재 최대 4개 이미지로 서버 메모리 부하 허용 가능 | Presigned URL 직접 업로드 | 서버 경유: 검증 보장, 대용량 시 메모리 부하. Presigned URL: 서버 부하 없으나 검증 우회 위험 |
| FEA-004 | UNIQUE 제약 + 트랜잭션 좋아요 | UNIQUE + 트랜잭션 적합 | MySQL UNIQUE 제약은 동시 요청에서도 중복 좋아요 방지 보장. 트랜잭션 내 count 증감으로 데이터 정합성 보장. OWASP API6:2023 — DB 수준 타입 안전성 | Application 레벨 중복 체크 | UNIQUE: DB 레벨 보장, 중복 시 예외 처리 필요. Application 레벨: 경쟁 조건(Race Condition) 취약 |
| FEA-005 | 레거시 배열 기반 데이터 전달 점진적 전환 | 점진적 Entity 전환 채택 | 즉각적 전환은 29개 BoardRepository 메서드 동시 변경 필요 — 허용 불가 위험. `dev/migration` 브랜치에서 CommentEntity, PostingEntity, InquiryEntity 순차 전환으로 운영 위험 최소화 | 즉각적 전체 Entity 전환 | 점진적: 운영 안정성, 일시적 이중 관리. 즉각: 코드 품질 향상, 단기 위험 높음 |

---

## 13. 변경 영향 기록 (Change Impact Log)

| Change Item | Impact Scope | Improvement | Rationale |
|-------------|-------------|-------------|-----------|
| IEEE 1016-2009 8개 Viewpoint로 전면 재구성 | 문서 전체 재구성 | Context, Composition, Logical, Dependency, Information, Patterns, Interface, Interaction 8개 관점으로 모든 설계 차원 명시적 분류 | IEEE 1016-2009 준수: 8개 Viewpoint 필수 |
| Dependency Viewpoint 신설 (§5) | 신규 섹션 | DI 등록 테이블 및 필터 체인 명시적 문서화. 모듈 간 의존성 방향 가시화 | IEEE 1016-2009 Dependency Viewpoint 요구 |
| Patterns Viewpoint 신설 (§7) | 신규 섹션 | 설계 패턴(Strategy, Repository, Facade)과 ADR 5건을 근거·대안과 함께 공식 문서화 | IEEE 1016-2009 Patterns Viewpoint 요구 |
| Design Overlay 신설 (§10) | 신규 섹션 | 보안/에러/로깅/트랜잭션 횡단 관심사 일괄 정의. 개발자가 단일 섹션에서 전체 보안 정책 확인 가능 | 횡단 관심사 가시화로 누락 방지 |
| Traceability Matrix 신설 (§11) | 신규 섹션 | FR 12건 전체가 SDD의 어느 Viewpoint·섹션에서 설계되었는지 추적 가능 | IEEE 1016-2009 추적성 요구 |
| Interaction Viewpoint 확장 (§9) | 신규 섹션 | 댓글 등록, 에러 흐름, 문의 S3 업로드, 좋아요 토글 4개 시퀀스 형식화 | IEEE 1016-2009 Interaction Viewpoint 요구 |

---

## 14. Document History / 문서 이력

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2026-04-15 | 1.0.0 | 초기 작성 | jypark |
| 2026-04-15 | 1.2.0 | SQL DDL (4개 테이블), Entity/VO 섹션, 타당성 검토, 변경 영향 기록 추가 | jypark |
| 2026-04-15 | 2.0.0 | IEEE 1016-2009 8개 Viewpoint 전면 재구성. Context, Composition, Logical, Dependency, Information, Patterns, Interface, Interaction, Design Overlay, Traceability Matrix 신설. ADR 5건, DI 테이블, 필터 체인, 4개 시퀀스 추가 | jypark |
