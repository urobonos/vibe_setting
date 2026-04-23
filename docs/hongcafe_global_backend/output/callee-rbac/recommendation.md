# 상담사(Callee) 전용 EP Role 기반 접근 제어 권고안

> 작성일: 2026-04-14

## 작성 정보

| 항목 | 내용 |
|------|------|
| 작성자 | jypark |
| 작성일 | 2026-04-14 |
| 유형 | report |
| 상태 | 승인됨 |

> 근거: OWASP API Security Top 10 2023, OWASP Authorization Cheat Sheet, OWASP Proactive Controls C1

---

## 1. 현황 분석

### 현재 구조 (단일 계층)

```
[요청] → AuthFilter (JWT/Session 인증) → 컨트롤러 checkNeedLogin(true) → 비즈니스 로직
                                          ↑
                                    유일한 상담사 검증 지점
```

- **인증(Authentication)**: AuthFilter가 `api/*` 전역 적용 (JWT / API Key / Session)
- **인가(Authorization)**: 컨트롤러 메서드 내부 `checkNeedLogin(true)`에서만 수행
- **상담사 판별**: `$this->member['ce_code']` 존재 여부 (tb_account.ce_code 컬럼)
- **역할 enum**: `UserRole::Callee` / `UserRole::Caller` (2값)

### 위험 요소

| 위험 | 설명 | OWASP 분류 |
|------|------|-----------|
| **누락 위험** | 새 상담사 메서드 추가 시 `checkNeedLogin(true)` 호출을 빠뜨릴 수 있음 | API5:2023 Broken Function Level Authorization |
| **단일 방어** | 필터 레벨 role 검증 없음 — 컨트롤러 내부에만 의존 | Defense in Depth 미충족 |
| **감사 어려움** | role 체크가 30+ 메서드에 분산 — 정책 변경 시 전수 코드 탐색 필요 | — |

---

## 2. 업계 표준 (OWASP 근거)

### OWASP 권장: 3계층 접근 제어

| 계층 | 역할 | 검증 내용 |
|------|------|-----------|
| **Layer 1: 미들웨어/필터** | Function-Level Authorization | "이 엔드포인트에 접근할 수 있는 역할인가?" |
| **Layer 2: 비즈니스 로직** | Object-Level Authorization | "이 리소스가 요청자의 것인가?" |
| **Layer 3: 데이터 접근** | Row-Level Security | 쿼리에 소유권 조건 내장 |

> "Do not depend on any single framework, library, technology, or control to be the sole thing enforcing proper access control."
> — OWASP Authorization Cheat Sheet

### 미들웨어 vs 비즈니스 로직 — 상호 보완

| 관점 | 미들웨어 레벨 | 비즈니스 로직 레벨 |
|------|-------------|-------------------|
| **적합** | "상담사만 접근 가능" (function-level) | "자신이 담당한 고객만" (object-level) |
| **장점** | 자동 적용, 누락 방지, 감사 용이 | 세밀한 조건 표현, 도메인 컨텍스트 활용 |
| **단점** | 세밀한 소유권 체크 불가 | 분산, 누락 위험 |

**결론: 둘 다 필요** — Layer 1(필터)에서 role 차단 + Layer 2(컨트롤러/서비스)에서 소유권 검증

---

## 3. 권고안: CI4 Role 필터 도입

### 3-1. 목표 구조 (2계층)

```
[요청] → AuthFilter (인증) → RoleFilter:callee (역할 검증) → 컨트롤러 (소유권 검증) → 비즈니스 로직
         Layer 0               Layer 1                        Layer 2
```

### 3-2. 구현 방안

#### 방안 A: 라우트별 role 필터 (권장)

```php
// Routes.php — 상담사 전용 라우트에 필터 적용
$routes->group('api/goods', ['namespace' => '...'], function ($routes) {
    // 공개/일반 사용자
    $routes->post('get-list-mobile', 'GoodsController::getListMobile');
    $routes->post('buy-item', 'GoodsController::buyItem');

    // 상담사 전용 — role:callee 필터
    $routes->post('callee-goods-confirm', 'GoodsController::calleeGoodsConfirm', ['filter' => 'role:callee']);
    $routes->post('callee-goods-job', 'GoodsController::calleeGoodsJob', ['filter' => 'role:callee']);
    $routes->post('callee-goods-file-upload', 'GoodsController::calleeGoodsFileUpload', ['filter' => 'role:callee']);
});
```

#### 방안 B: URL prefix 기반 그룹 필터

```php
// 상담사 전용 EP를 별도 prefix로 분리
$routes->group('api/callee-goods', ['namespace' => '...', 'filter' => 'role:callee'], function ($routes) {
    $routes->post('confirm', 'GoodsController::calleeGoodsConfirm');
    $routes->post('job', 'GoodsController::calleeGoodsJob');
    $routes->post('file-upload', 'GoodsController::calleeGoodsFileUpload');
});
```

### 3-3. RoleFilter 설계

```php
// app/Filters/RoleFilter.php
class RoleFilter implements FilterInterface
{
    public function before(RequestInterface $request, $arguments = null)
    {
        // AuthFilter가 설정한 authUser 확인
        if (!isset($request->authUser['ac_id'])) {
            return $this->respondForbidden();
        }

        $requiredRole = $arguments[0] ?? null;
        if ($requiredRole === 'callee') {
            // ce_code 존재 여부로 상담사 판별
            $memberModel = model('MemberModel');
            $account = $memberModel->AccountInfo('ac_id', $request->authUser['ac_id']);
            if (empty($account['ce_code'])) {
                return $this->respondForbidden();
            }
        }

        return null;
    }
}
```

### 3-4. 기존 checkNeedLogin(true) 유지

RoleFilter 도입 후에도 기존 `checkNeedLogin(true)` 호출은 **제거하지 않고 유지** (Defense in Depth).
- 필터: "상담사 role이 아니면 403" (자동, 누락 방지)
- 컨트롤러: "ce_code 없으면 403" (명시적, 이중 검증)

---

## 4. 적용 대상 EP 목록 (30건)

### CalleeController (전체 — 이미 상담사 전용)

| EP | 현재 보호 | 권고 |
|----|-----------|------|
| `callees/*` 전체 33건 | `checkNeedLogin(true)` | `role:callee` 필터 추가 |

### GoodsController (상담사 전용 10건)

| EP | 메서드 |
|----|--------|
| `goods/get-calleebuy-list` | getCalleebuyList |
| `goods/get-calleebuy-cnt` | getCalleebuyCnt |
| `goods/callee-goods-confirm` | calleeGoodsConfirm |
| `goods/callee-goods-job` | calleeGoodsJob |
| `goods/callee-goods-file-upload` | calleeGoodsFileUpload |
| `goods/update-goods` | updateGoods |
| `goods/delete-goods` | deleteGoods |
| `goods/delete-o2o` | deleteO2o |
| `goods/preview-goods` | previewGoods |
| `goods/callee-class-file-upload` | calleeClassFileUpload |

### ShopController (상담사 전용 7건)

| EP | 메서드 |
|----|--------|
| `shop/schedule-delete` | scheduleDelete |
| `shop/schedule-add` | scheduleAdd |
| `shop/callee-shop-confirm` | calleeShopConfirm |
| `shop/callee-shop-file-upload` | calleeShopFileUpload |
| `shop/callee-o2o-job` | calleeO2oJob |
| `shop/update-shop` | updateShop |
| `shop/preview-shop` | previewShop |

---

## 5. 구현 우선순위

| 단계 | 작업 | 영향 | 난이도 |
|------|------|------|--------|
| **Phase 1** | RoleFilter 생성 + Filters.php 등록 | 없음 (아직 적용 안 함) | 소 |
| **Phase 2** | 상담사 전용 라우트에 `['filter' => 'role:callee']` 추가 | 없음 (기존 checkNeedLogin과 이중 적용) | 소 |
| **Phase 3** | 테스트 (상담사/비상담사 접근 검증) | 없음 | 중 |
| **Phase 4** (선택) | checkNeedLogin(true) → checkNeedLogin(false) 전환 | 필터가 role 보장하므로 컨트롤러에서 재검증 불필요 | 대 (30+ 메서드) |

> Phase 4는 선택 사항. Defense in Depth 관점에서 이중 검증을 유지하는 것도 유효한 전략.

---

## 6. 타당성 검토

### 근거 문서

| 출처 | 핵심 원칙 |
|------|-----------|
| OWASP API5:2023 | Function-Level Authorization — 엔드포인트 레벨에서 role 검증 필수 |
| OWASP Authorization Cheat Sheet | Deny-by-Default + 다계층 적용 + 단일 의존 금지 |
| OWASP Proactive Controls C1 | Server-side enforcement + Least Privilege |
| OWASP API1:2023 | Object-Level Authorization — 소유권 검증은 비즈니스 로직에서 |

### 변경 영향

- **프론트엔드**: 없음 (API 동작 변경 없음, 추가 보안 레이어만 적용)
- **기존 코드**: 변경 없음 (checkNeedLogin 유지)
- **DB**: 변경 없음 (ce_code 기존 컬럼 활용)
- **성능**: 미미 (AuthFilter에서 이미 member 조회, RoleFilter에서 재활용 가능)

### 수행 이유

1. **OWASP API5:2023 준수**: 현재 단일 계층(컨트롤러) 의존은 Broken Function Level Authorization 위험
2. **누락 방지**: 새 상담사 EP 추가 시 `checkNeedLogin(true)` 호출 누락으로 인한 권한 우회 사전 차단
3. **감사 용이성**: Routes.php에서 `role:callee` 필터 유무로 즉시 상담사 EP 식별 가능

## 체크리스트

- [x] 문서 작성 완료

## 변경 기록

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-14 | 최초 작성 | jypark |
| 2026-04-15 | doc-template 양식 적용 | jypark |
