---
문서명: Board — Interface Design Document
문서 ID: board-idd
버전: v2.0
상태: 승인됨
생성일: 2026-04-15
최종 수정일: 2026-04-15
작성자: jypark
대상 시스템: Board Module (HongCafe Global Backend)
관련 문서: board-sdd.md, board-srs.md
적용 표준: MIL-STD-498 (Interface Design Description)
---

# Board — Interface Design Document (IDD)

> MIL-STD-498 | version: 2.0 | lastUpdated: 2026-04-15 | module: Board

---

## 1. Scope / 적용 범위

### 1.1 Identification / 식별

본 Interface Design Document(IDD)는 HongCafe Global Backend의 Board Bounded Context에 대한 내부 및 외부 인터페이스를 MIL-STD-498 표준에 따라 정의한다. 문서 ID: `board-idd`, 기반 SDD: `board-sdd.md` v2.0.

### 1.2 System Overview / 시스템 개요

Board 모듈은 문의, 공지, 댓글, 포스팅, 채용 등 커뮤니티 게시판 기능을 담당하는 Bounded Context이다. 내부 인터페이스는 4개(Service 2, Repository 2), 외부 인터페이스는 1개(AWS S3)이다.

| Interface Type | Count | Description |
|---------------|-------|-------------|
| 내부 인터페이스 (Internal IF) | 4 | `BoardServiceInterface`, `CommentFormatterInterface`, `BoardRepositoryInterface`, `CommentRepositoryInterface` |
| 외부 인터페이스 (External IF) | 1 | AWS S3 (이미지 업로드) |

### 1.3 Document Overview / 문서 구성

| Section | Content |
|---------|---------|
| §2 | References — 참조 문서 |
| §3 | Internal Interfaces — 내부 인터페이스 (5-subsection 형식) |
| §4 | External Interfaces — 외부 인터페이스 (5-subsection 형식) |
| §5 | Events — 이벤트 계약 |
| §6 | Error Contract — 에러 처리 계약 |
| §7 | Data Formats — 데이터 포맷 및 JSON 예시 |
| §8 | 타당성 검토 |
| §9 | 변경 영향 기록 |
| §10 | Requirements Traceability Matrix |

---

## 2. References / 참조 문서

| Document | Location |
|----------|----------|
| MIL-STD-498 — Software Development and Documentation | US DoD Standard |
| board-srs.md v2.0 | `docs/specs/board-srs.md` |
| board-sdd.md v2.0 | `docs/specs/board-sdd.md` |
| OWASP API Security Top 10 2023 | https://owasp.org/API-Security/ |
| OWASP File Upload Cheat Sheet | https://cheatsheetseries.owasp.org/ |
| RFC 7807 — Problem Details for HTTP APIs | https://tools.ietf.org/html/rfc7807 |
| Google API Design Guide | https://cloud.google.com/apis/design |
| HongCafe Global Backend CLAUDE.md | Project root `CLAUDE.md` |

---

## 3. Internal Interfaces / 내부 인터페이스

### IF-INT-001: BoardServiceInterface

#### 3.1.1 Interface Identifier / 식별자

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-001 |
| 인터페이스명 | `BoardServiceInterface` |
| 파일 경로 | `app/Modules/Board/Interfaces/BoardServiceInterface.php` |
| 구현체 | `BoardService` |
| 제공 모듈 | Board |
| 소비 모듈 | Board (`BoardController`) |
| DI 등록 | `app/Modules/Board/Config/Services.php` |

#### 3.1.2 Data Elements / 데이터 요소

| Method | Parameters | Return Type | Description |
|--------|-----------|-------------|-------------|
| `buildCommentData` | `array $post, array $member` | `array` | 댓글 레코드 조립 (`st_code`, `ac_id`, `bcc_nick`, `timestamps`) |
| `buildCommentNotifyData` | `array $commentInfo, array $member, string $content` | `array` | 알림 레코드 조립 (`ce`/`cr` 분기) |
| `resolveNotifierId` | `array $member` | `string` | `ce_code` 또는 `cr_code` 반환 |
| `formatInquiryList` | `array $result, array $typeName` | `array` | 문의 목록 포맷 |
| `uploadInquiryImages` | `array $files, string $stCode` | `array` | S3 업로드 (최대 4개), `uf_codes` 수집 |
| `buildInquiryData` | `array $post, array $member, array $images` | `array` | 문의 INSERT 데이터 조립 |
| `formatNoticeList` | `array $result` | `array` | 공지 목록 포맷 |
| `buildRecruitData` | `array $post, array $files` | `array` | 채용 데이터 조립 (`cas_code` 자동 생성) |
| `formatPostingList` | `array $result, array $bestResult` | `array` | 베스트+일반 병합, `display_date` 포맷 |

#### 3.1.3 Communication Protocol / 통신 프로토콜

PHP DI (CodeIgniter `service()` 함수). 동기 메서드 호출. 예외 없음 — 실패 시 빈 배열 또는 false 반환.

#### 3.1.4 Error Handling / 에러 처리

| Error Condition | Handling |
|----------------|---------|
| S3 업로드 실패 | `uploadInquiryImages()` 500 `INTERNAL` 반환 |
| 빈 결과 | 빈 배열(`[]`) 반환, 예외 미발생 |
| 잘못된 `qa_part` enum | Controller 레벨 입력 검증에서 400 처리 |

#### 3.1.5 Data Flow / 데이터 흐름

```
BoardController → BoardServiceInterface::uploadInquiryImages()
                           ├─ [파일별] 확장자 검증 → mime_content_type() 검증
                           ├─ Awss3::upload() → S3 URL
                           └─ uf_codes 수집 → array 반환
BoardController → BoardServiceInterface::buildInquiryData($post, $member, $images)
                           └─ INSERT 데이터 조립 → array 반환
BoardController → BoardRepository::insertInquiry($data) → qa_no
```

---

### IF-INT-002: CommentFormatterInterface

#### 3.2.1 Interface Identifier / 식별자

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-002 |
| 인터페이스명 | `CommentFormatterInterface` |
| 파일 경로 | `app/Modules/Board/Interfaces/CommentFormatterInterface.php` |
| 구현체 | `CommentFormatter` |
| 제공 모듈 | Board |
| 소비 모듈 | Board (`CommentController`), Member (`MypageController`) |
| DI 등록 | `app/Modules/Board/Config/Services.php` |

#### 3.2.2 Data Elements / 데이터 요소

```php
public function formatCommentList(
    array    $comments,
    callable $fetchChildren,
    ?callable $fieldFormatter = null
): array;
// 반환: ['comments' => [...], 'hasNext' => bool]
// $fetchChildren: fn(int $parentCmNo): array — 자식 댓글 조회 콜백
// $fieldFormatter: null 시 기본 포맷 (stripslashes, regist_date → Y.m.d)
//                  소비자별 커스텀 필드 변환 주입 가능 (GoF Strategy)
```

#### 3.2.3 Communication Protocol / 통신 프로토콜

PHP DI (CodeIgniter `service()` 함수). `$fetchChildren` callable은 `CommentRepository::getItemListComment()` 기반 클로저로 주입. 동기 호출.

#### 3.2.4 Error Handling / 에러 처리

| Error Condition | Handling |
|----------------|---------|
| 빈 `$comments` | `['comments' => [], 'hasNext' => false]` 반환 |
| `$fetchChildren` 예외 | 호출자에게 전파 (Controller에서 500 처리) |

#### 3.2.5 Data Flow / 데이터 흐름

```
CommentController::getItemComment()
  → CommentRepository::getItemListComment($params) → 부모 댓글 배열
  → CommentFormatter::formatCommentList(
        $comments,
        fn($parentNo) => CommentRepository::getChildren($parentNo),
        null
     )
  → 반환: { 'comments': [...(cmReply 포함)], 'hasNext': bool }
  → 200 OK { "data": [...], "meta": { "currentPage", "perPage", "total", "lastPage" } }
```

---

### IF-INT-003: BoardRepositoryInterface

#### 3.3.1 Interface Identifier / 식별자

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-003 |
| 인터페이스명 | `BoardRepositoryInterface` |
| 파일 경로 | `app/Modules/Board/Interfaces/BoardRepositoryInterface.php` |
| 구현체 | `BoardRepository` |
| 제공 모듈 | Board |
| 소비 모듈 | Board (`BoardService`, `BoardController`) |
| 메서드 수 | **29** |

#### 3.3.2 Data Elements / 데이터 요소 (카테고리별)

```php
// --- 문의 (Inquiry) ---
public function getBoardInquiry(array $params): array;     // 암호화 포함
public function insertInquiry(array $data): int;           // 반환: qa_no

// --- 공지 (Notice) ---
public function getBoardNotice(array $params): array;

// --- 댓글 (Comment) ---
public function insertColumnComment(array $data): int;          // 반환: bcc_no
public function deleteColumnComment(int $bccNo, string $acId): bool;
public function updateCommentCnt(string $itCode, int $delta): void; // +1 or -1

// --- 포스팅 (Posting) ---
public function getBoardPosting(array $params): array;
public function getBoardBestPosting(string $stCode): array;  // 랜덤 3건

// --- 좋아요 (Like) ---
public function addPostingLike(int $poNo, string $acId): void;
public function deletePostingLike(int $poNo, string $acId): void;
public function getCounselLike(string $acId, int $poNo): bool;

// --- 신고 (Report) ---
public function boardCommentReportUpdate(array $data): void;
public function getCommentReportYesNo(int $cmNo): bool;
public function getCommentUserReportYesNo(int $cmNo, string $acId): bool;
public function insertCommentNotify(array $data): int;

// --- 채용 (Recruit) ---
public function insertCast(array $data): int;
public function getCastInfo(string $casCode): ?array;

// --- 댓글 정보 (Comment Info) ---
public function getCommentInfo(int $cmNo): ?array;

// [이하 기타 11개 메서드 — 암호화 처리, FAQ, 통계 등]
```

#### 3.3.3 Communication Protocol / 통신 프로토콜

PHP DI. CI4 Query Builder (`$this->db->table(...)`) 우선. CTE/Window Function은 `$db->query()` + named binding 사용. DB charset: `utf8mb4`.

#### 3.3.4 Error Handling / 에러 처리

| Error Condition | Handling |
|----------------|---------|
| INSERT 실패 | 0 또는 false 반환 (Controller에서 500 처리) |
| 레코드 미존재 | null 또는 빈 배열 반환 |
| UNIQUE 제약 위반 (좋아요 중복) | DB 예외 → Controller에서 409 처리 |
| 트랜잭션 실패 | 롤백 후 예외 전파 |

#### 3.3.5 Data Flow / 데이터 흐름

```
BoardController::postingLike()
  → BoardRepository::getCounselLike($acId, $poNo) → bool
  → [false] DB::transStart()
              BoardRepository::addPostingLike($poNo, $acId)      -- tb_board_like INSERT
              BoardRepository::updatePostingLikeCount($poNo, +1) -- tb_posting.like_cnt +1
             DB::transComplete()
  → 200 OK
```

---

### IF-INT-004: CommentRepositoryInterface

#### 3.4.1 Interface Identifier / 식별자

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-INT-004 |
| 인터페이스명 | `CommentRepositoryInterface` |
| 파일 경로 | `app/Modules/Board/Interfaces/CommentRepositoryInterface.php` |
| 구현체 | `CommentRepository` |
| 제공 모듈 | Board |
| 소비 모듈 | Board (`CommentController`), Call (`CalleeController`) |

#### 3.4.2 Data Elements / 데이터 요소

```php
public function getItemListComment(array $params): array;
// params: { item_code: string, keyword?: string, limit: int, offset: int }
// 반환: 아이템 댓글 배열 (고정 댓글 포함, 태그 검색 지원)

public function firstCheckWriteComment(array $params): bool;
// params: { ce_code: string, it_code: string }
// 반환: true = 작성 가능

public function countCalleeCommentList(string $ceCode): int;
// 반환: 상담사 댓글 총 수

public function updateCommentHelp(int $cmNo, string $acId): string;
// cmNo: 댓글 PK, acId: 요청자 계정 ID
// 반환: 'add' (도움 등록) 또는 'del' (도움 해제) — 토글 결과
```

#### 3.4.3 Communication Protocol / 통신 프로토콜

PHP DI. CI4 Query Builder. 태그 검색 시 `LIKE '#tag%'` 조건 사용.

#### 3.4.4 Error Handling / 에러 처리

| Error Condition | Handling |
|----------------|---------|
| 빈 결과 | 빈 배열 반환 |
| 잘못된 `item_code` | 빈 배열 반환 (404 불필요 — 공개 조회) |

#### 3.4.5 Data Flow / 데이터 흐름

```
CommentController::getItemComment()
  → CommentRepository::getItemListComment($params)
       ├─ offset=0: 고정 댓글 먼저 조회 (cm_status='fixed')
       ├─ keyword 포함 시: WHERE cm_content LIKE '#tag%'
       └─ 일반 댓글 LIMIT/OFFSET 조회
  → CommentFormatter::formatCommentList(
        $parentComments,
        fn($parentNo) => CommentRepository::getChildren($parentNo)
     )
  → 200 OK { "data": [...], "meta": {...} }
```

---

## 4. External Interfaces / 외부 인터페이스

### IF-EXT-001: AWS S3 (이미지 업로드)

#### 4.1.1 Interface Identifier / 식별자

| 항목 | 내용 |
|------|------|
| 인터페이스 ID | IF-EXT-001 |
| 인터페이스명 | AWS S3 / Naver Cloud Object Storage |
| 연동 모듈 | Board (`BoardService::uploadInquiryImages()`) |
| 프로토콜 | REST HTTPS (Awss3 라이브러리 래핑) |
| 기본 URL | `{S3_ENDPOINT}/{BUCKET_NAME}/` |
| 인증 방식 | AWS Access Key / Secret Key (환경변수) |

#### 4.1.2 Data Elements / 데이터 요소

**업로드 요청:**

| Parameter | Type | Description |
|-----------|------|-------------|
| 파일 바이너리 | binary | 이미지 원본 |
| 파일명 | string | UUID 기반 고유 파일명 |
| Content-Type | string | `image/jpeg`, `image/png`, `image/gif` |
| 버킷명 | string | 환경변수 `S3_BUCKET_NAME` |

**업로드 응답:**

| Field | Type | Description |
|-------|------|-------------|
| `uf_code` | string | 업로드된 파일 코드 (DB 저장용) |
| `url` | string | S3 공개 URL |

#### 4.1.3 Communication Protocol / 통신 프로토콜

| 항목 | 내용 |
|------|------|
| 프로토콜 | REST HTTPS |
| 래퍼 | Awss3 라이브러리 (서버 사이드 업로드) |
| 타임아웃 | 30초 |
| 재시도 정책 | 실패 시 에러 반환 (재시도 없음) |
| 파일 제한 | 최대 4개 (`comment_img`, `comment_img1`, `comment_img2`, `comment_img3`) |
| 허용 확장자 | `jpg`, `png`, `jpeg`, `gif` |
| 검증 방식 | 확장자 화이트리스트 + `mime_content_type()` 이중 검증 |

#### 4.1.4 Error Handling / 에러 처리

| Error Condition | HTTP Code | Error Code | Description |
|----------------|-----------|------------|-------------|
| 허용되지 않는 MIME | 400 | `INVALID_INPUT` | 확장자 또는 MIME 검증 실패 |
| S3 업로드 실패 (네트워크) | 500 | `INTERNAL` | Awss3 업로드 에러 |
| S3 인증 실패 | 500 | `INTERNAL` | 환경변수 오류 |

#### 4.1.5 Data Flow / 데이터 흐름

```
BoardController::insertInquiry()
  → [파일 존재 시] 확장자 검증 → mime_content_type() 검증
  → BoardService::uploadInquiryImages($files, $stCode)
       └─ [파일별, 최대 4회] Awss3::upload($file) → {uf_code, url}
       └─ uf_codes = implode('|', collected_uf_codes)
  → BoardService::buildInquiryData($post, $member, $images)
  → BoardRepository::insertInquiry($data)   -- uf_codes 컬럼에 저장
  → 201 Created { "data": { "qaNo": 5678 } }
```

---

## 5. Events / 이벤트 계약

| Event | Trigger | Target | Description |
|-------|---------|--------|-------------|
| 댓글 수 갱신 | `insertColumnComment` / `deleteColumnComment` | `tb_items.it_cmt_cnt` | 댓글 추가/삭제 시 카운트 동기 갱신 (트랜잭션 내) |
| 좋아요 수 갱신 | `addPostingLike` / `deletePostingLike` | `tb_posting.like_cnt` | 트랜잭션 내 카운트 증감 |
| 신고 알림 생성 | `commentReportNotify` | `tb_comment_notify` | 신고 접수 시 알림 레코드 생성 |
| S3 이미지 업로드 | `insertInquiry` / `insertRecruit` | AWS S3 버킷 | 문의/채용 신청 이미지 비동기 없이 즉시 업로드 |

---

## 6. Error Contract / 에러 처리 계약

### 6.1 Standard Error Response / 표준 에러 응답 형식

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "에러 메시지"
  }
}
```

### 6.2 Error Code Table / 에러 코드 목록

| HTTP Status | Error Code | Trigger Condition | Consumer Action |
|-------------|------------|------------------|----------------|
| 400 | `INVALID_INPUT` | 입력값 검증 실패 (5자 미만, 잘못된 enum, 빈 필드) | 입력값 수정 후 재요청 |
| 401 | `UNAUTHORIZED` | JWT 미인증 또는 만료 | 토큰 갱신 또는 재로그인 |
| 403 | `FORBIDDEN` | 댓글 삭제 소유권 불일치 | 본인 댓글만 삭제 가능 안내 |
| 404 | `NOT_FOUND` | 리소스 미존재 | 재조회 |
| 409 | `CONFLICT` | 중복 신고 (댓글/사용자 레벨) | 이미 신고됨 안내 |
| 429 | `TOO_MANY_REQUESTS` | 1초 쿨다운 위반 (`last_comment` 쿠키) | 1초 후 재시도 안내 |
| 500 | `INTERNAL` | S3 업로드 실패, 서버 내부 오류 | 재시도 또는 고객 지원 |

---

## 7. Data Formats / 데이터 포맷

### 7.1 DTO Definitions / DTO 정의

**Inquiry (문의) DTO**

| Field | API Key (camelCase) | Type | Description |
|-------|---------------------|------|-------------|
| `qa_no` | `qaNo` | int | 문의 번호 |
| `qa_part` | `qaPart` | string | 유형 코드 (`normal/refund/require/report/info/block`) |
| `qa_part_name` | `qaPartName` | string | 유형명 일본어 |
| `qa_status` | `qaStatus` | string | 상태 (`standby` → 回答待ち, `complete` → 回答完了) |
| `qa_content` | `qaContent` | string | 문의 내용 |
| `uf_codes` | `ufCodes` | string | 업로드 이미지 코드 (`\|` 구분) |

**Comment (댓글) DTO**

| Field | API Key (camelCase) | Type | Description |
|-------|---------------------|------|-------------|
| `cm_no` | `cmNo` | int | 댓글 번호 |
| `cm_parent` | `cmParent` | int | 부모 댓글 번호 (0=최상위) |
| `cm_content` | `cmContent` | string | 내용 (`htmlspecialchars` 처리) |
| `cm_child_exist` | `cmChildExist` | string | 자식 존재 (`y`/`n`) |
| `cm_reply` | `cmReply` | array | 자식 댓글 배열 (2단계 스레딩) |
| `regist_date` | `registYmd` | string | 등록일 (`Y.m.d` 포맷) |

**Posting (포스팅) DTO**

| Field | API Key (camelCase) | Type | Description |
|-------|---------------------|------|-------------|
| `po_no` | `poNo` | int | 포스팅 번호 |
| `po_title` | `poTitle` | string | 제목 |
| `like_cnt` | `likeCnt` | int | 좋아요 수 |
| `display_date_ymd` | `displayDateYmd` | string | 표시 날짜 (`Y.m.d`) |
| `is_best` | `isBest` | bool | 베스트 포스팅 여부 |

### 7.2 Request / Response JSON Examples / 요청/응답 JSON 예시

#### POST /api/boards/insert-column-comment (컬럼 댓글 등록)

**요청**
```json
{
  "st_code": "hongcafe",
  "bcc_content": "좋은 상담 감사합니다",
  "bcc_parent": 0
}
```

**응답 200 OK**
```json
{
  "data": { "bccNo": 1234 }
}
```

**응답 400 Bad Request** — 5자 미만
```json
{
  "error": {
    "code": "INVALID_INPUT",
    "message": "댓글은 최소 5자 이상 입력해 주세요."
  }
}
```

**응답 429 Too Many Requests** — 1초 쿨다운 위반
```json
{
  "error": {
    "code": "TOO_MANY_REQUESTS",
    "message": "잠시 후 다시 시도해 주세요."
  }
}
```

---

#### POST /api/comments/get-item-comment (아이템 댓글 조회)

**요청**
```json
{
  "item_code": "IT-20260101-001",
  "keyword": "#운세",
  "limit": 20,
  "offset": 0
}
```

**응답 200 OK**
```json
{
  "data": [
    {
      "cmNo": 100,
      "cmContent": "정확한 상담이었습니다",
      "cmParent": 0,
      "cmChildExist": "y",
      "cmReply": [
        {
          "cmNo": 101,
          "cmContent": "감사합니다",
          "cmParent": 100,
          "registYmd": "2026.04.15"
        }
      ],
      "registYmd": "2026.04.15"
    }
  ],
  "meta": {
    "currentPage": 1,
    "perPage": 20,
    "total": 150,
    "lastPage": 8
  }
}
```

---

#### POST /api/boards/posting-like (포스팅 좋아요 토글)

**요청**
```json
{
  "po_no": 42
}
```

**응답 200 OK** — 좋아요 추가
```json
{
  "data": {
    "action": "add",
    "likeCnt": 37
  }
}
```

**응답 200 OK** — 좋아요 취소
```json
{
  "data": {
    "action": "del",
    "likeCnt": 36
  }
}
```

---

#### DELETE /api/boards/delete-column-comment (댓글 삭제)

**요청** (Query string)
```
DELETE /api/boards/delete-column-comment?bcc_no=1234
```

**응답 200 OK**
```json
{
  "data": { "deleted": true }
}
```

**응답 403 Forbidden** — 소유권 불일치
```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "본인이 작성한 댓글만 삭제할 수 있습니다."
  }
}
```

---

#### POST /api/boards/insert-inquiry (문의 등록)

**요청** (multipart/form-data)
```
qa_part=normal
qa_content=서비스 이용 중 문제가 발생했습니다.
comment_img=<image_file>
```

**응답 201 Created**
```json
{
  "data": { "qaNo": 5678 }
}
```

**응답 400 Bad Request** — MIME 검증 실패
```json
{
  "error": {
    "code": "INVALID_INPUT",
    "message": "허용되지 않는 파일 형식입니다."
  }
}
```

---

## 8. 타당성 검토 (Feasibility Review)

> 근거: PHP 공식 문서, OWASP 공식 문서, RFC 7807, Google API Design Guide

| Interface Decision | Adopted Approach | Basis | Conclusion |
|-------------------|-----------------|-------|------------|
| CommentFormatter callable 패턴 | `formatCommentList()`에 `$fetchChildren` + `$fieldFormatter` callable 주입 | PHP 공식 문서 — First-class callable syntax (PHP 8.1+). GoF Strategy Pattern — 알고리즘을 인터페이스로 분리하여 소비자별 커스터마이징 허용 | **타당** — Board/Member 두 모듈이 동일 포맷터를 다른 필드 변환 규칙으로 재사용. DRY 원칙 충족 |
| 에러 응답 표준 (현상 서술형 코드) | `INVALID_INPUT`, `NOT_FOUND`, `CONFLICT` 등 suffix 없는 현상 서술형 | RFC 7807 Problem Details — 에러 타입을 명확한 식별자로 표현 권고. 프로젝트 `CLAUDE.md` 에러 코드 정책과 일치 | **타당** — 프론트엔드(Next.js)가 에러 코드 기반 분기 처리 가능. 일관된 에러 계약 제공 |
| S3 업로드 서버 경유 방식 | Client → Server(PHP) → S3. Awss3 라이브러리 래핑 | OWASP File Upload Cheat Sheet — 서버 사이드 검증(MIME, 확장자) 후 업로드 권고. 클라이언트 직접 업로드(Presigned URL)는 검증 우회 위험. 현재 최대 4개 이미지 제한으로 서버 메모리 부하 허용 가능 | **타당** — MIME 이중 검증이 서버 경유를 통해 보장됨 |
| 응답 필드 camelCase 변환 | DB `snake_case` → API 응답 `camelCase` | 프로젝트 `CLAUDE.md` — "DB snake_case → API 응답 camelCase 변환 필수". Google API Design Guide — camelCase 권장 | **타당** — Next.js 프론트엔드 JavaScript 관행(camelCase)과 일치. DB 컬럼명 변경 시 API 계약 영향 최소화 |

---

## 9. 변경 영향 기록 (Change Impact Log)

| Change Item | Impact Scope | Improvement | Rationale |
|-------------|-------------|-------------|-----------|
| MIL-STD-498 5-subsection 형식 전면 적용 | 문서 전체 재구성 | 각 인터페이스를 Identifier/Data/Communication/Error/Flow 5개 subsection으로 구조화. 인터페이스 계약의 완전성 보장 | MIL-STD-498 표준 준수 |
| Requirements Traceability Matrix 신설 (§10) | 신규 섹션 | FR 12건 전체 ↔ IDD 인터페이스 추적성 확보 | MIL-STD-498 추적성 요구 |
| Data Flow 다이어그램 추가 (각 §x.x.5) | 각 인터페이스 섹션 | 각 인터페이스의 실제 호출 흐름을 텍스트 시퀀스로 명세. 구현자가 흐름 즉시 파악 가능 | 인터페이스 구현 명확성 향상 |
| Events 섹션 강화 (§5) | 이벤트 계약 | 4개 이벤트(댓글 수 갱신, 좋아요 갱신, 신고 알림, S3 업로드)의 트리거·대상·설명 명세 | 부수 효과(side effects) 가시화 |
| Error Contract 정규화 (§6) | 에러 처리 계약 | 7개 에러 코드 전체에 HTTP 상태코드·트리거 조건·소비자 대응 3-way 명세 | 소비 모듈의 에러 처리 구현 완전성 향상 |

---

## 10. Requirements Traceability Matrix / 요구사항 추적성 매트릭스

| FR ID | FR 명 | IDD Interface | Interface Method |
|-------|-------|--------------|-----------------|
| FR-001 | 문의 조회 | IF-INT-003 `BoardRepositoryInterface` | `getBoardInquiry()` |
| FR-002 | 문의 등록 | IF-INT-001 `BoardServiceInterface`, IF-EXT-001 AWS S3 | `uploadInquiryImages()`, `buildInquiryData()`, S3 Upload |
| FR-003 | 공지 조회 | IF-INT-003 `BoardRepositoryInterface` | `getBoardNotice()` |
| FR-004 | 컬럼 댓글 등록 | IF-INT-001 `BoardServiceInterface`, IF-INT-003 `BoardRepositoryInterface` | `buildCommentData()`, `insertColumnComment()`, `updateCommentCnt()` |
| FR-005 | 컬럼 댓글 삭제 | IF-INT-003 `BoardRepositoryInterface` | `deleteColumnComment()`, `updateCommentCnt()` |
| FR-006 | 댓글 신고 | IF-INT-003 `BoardRepositoryInterface` | `boardCommentReportUpdate()` |
| FR-007 | 댓글 신고 알림 | IF-INT-003 `BoardRepositoryInterface` | `getCommentReportYesNo()`, `getCommentUserReportYesNo()`, `insertCommentNotify()` |
| FR-008 | 채용 신청 | IF-INT-001 `BoardServiceInterface`, IF-INT-003 `BoardRepositoryInterface` | `buildRecruitData()`, `insertCast()` |
| FR-009 | 포스팅 목록 조회 | IF-INT-001 `BoardServiceInterface`, IF-INT-003 `BoardRepositoryInterface` | `formatPostingList()`, `getBoardPosting()`, `getBoardBestPosting()` |
| FR-010 | 포스팅 좋아요 토글 | IF-INT-003 `BoardRepositoryInterface` | `getCounselLike()`, `addPostingLike()`, `deletePostingLike()` |
| FR-011 | 아이템 댓글 조회 | IF-INT-002 `CommentFormatterInterface`, IF-INT-004 `CommentRepositoryInterface` | `formatCommentList()`, `getItemListComment()` |
| FR-012 | 댓글 도움 토글 | IF-INT-004 `CommentRepositoryInterface` | `updateCommentHelp()` |

---

## 11. 변경 로그

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|-------|
| 2026-04-15 | 1.0.0 | 초기 작성 | jypark |
| 2026-04-15 | 1.1.0 | PHP 시그니처 전체 추가, 이벤트 계약 3건, 에러 7건, DTO 3종, Repository 29메서드 카테고리 분류 추가 | jypark |
| 2026-04-15 | 1.2.0 | 요청/응답 JSON 예시 (4개 엔드포인트), 타당성 검토, 변경 영향 기록 추가 | jypark |
| 2026-04-15 | 2.0.0 | MIL-STD-498 전면 재구성. Scope(3 sub), References, 내부 IF(4개 × 5-subsection), 외부 IF(1개 × 5-subsection), Events, Error Contract, Data Formats, 타당성, 변경 영향, Requirements Traceability Matrix 신설. JSON 예시 5개 엔드포인트로 확장 | jypark |
