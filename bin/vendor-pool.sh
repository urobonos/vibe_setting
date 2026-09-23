#!/bin/bash
# vendor-pool.sh
# lock 해시별 vendor 물리 pool 을 만들고, worktree vendor 를 그 pool 로부터
# 하드링크 클론으로 전환한다. 짝 도구 = vendor-lock-stamp.sh (전환 후 정합 검증).
#
# 배경: worktree 들이 같은 composer.lock 을 쓰면서도 vendor 를 각자 실디렉토리로
#   들고 있어 313M 씩 중복된다 (2026-08-24 실측 7.8GB). junction 으로 묶는 방식은
#   시도했다가 폐기했다 — `git worktree remove --force` 가 junction 을 따라가
#   원본까지 지운다(실측 재현, 과거 vendor 소실 사고의 실제 메커니즘). 하드링크는
#   그 경로에서 원본이 살아남는다(실측 확인) — 그래서 클론 방식을 쓴다.
#
# pool 위치: ~/.claude/vendor-pool/{pool_key 16자}/ — lock 해시 + composer.json autoload 섹션 해시
#   (2026-09-23~, 그 전엔 lock 해시만). lock 정합 판정은 여전히 vendor/.lock-sha 의 전체 sha256 이 한다.
#
# 사용법:
#   bash ~/.claude/bin/vendor-pool.sh build <vendor 원본 디렉토리>
#     그 vendor 옆 composer.lock 해시로 pool 을 만든다 (이미 있으면 스킵).
#
#   bash ~/.claude/bin/vendor-pool.sh convert <worktree 루트>
#     그 worktree 의 lock 해시에 맞는 pool 을 찾아 vendor 를 하드링크 클론으로
#     교체한다. 2단계 스왑(vendor -> vendor.old -> 신규 클론 -> 검증 후 vendor.old 제거)
#     이라 클론 중 실패해도 기존 vendor 가 보존된다. 비교는 composer install 산출물이
#     아닌 런타임 캐시(phpunit 결과 캐시 등)를 제외한 파일 목록으로 한다.
#     선행조건: pool 이 이미 build 되어 있어야 함. vendor 가 이미 링크(junction 포함)면 거부.
#
#   bash ~/.claude/bin/vendor-pool.sh status
#     pool 목록 + 각 pool 용량.
#
#   bash ~/.claude/bin/vendor-pool.sh ensure <worktree 루트>
#     신규 worktree(vendor 없음)에 vendor 를 채운다 — build/convert 는 각각 "이미 있는
#     vendor" 를 전제해 신규 worktree(git worktree add 직후, vendor 는 gitignore 대상이라
#     처음부터 없음)에는 못 쓴다. pool 있으면 하드링크 클론(수 초) · 없으면 최초 1회
#     `composer install` 후 pool 화(다음부턴 재사용). vendor 가 이미 있으면 convert 로 위임.

HARNESS_ROOT="${HOME}/.claude"
POOL_ROOT="${HARNESS_ROOT}/vendor-pool"
CLONE_PS1="${HARNESS_ROOT}/bin/vendor-pool-clone.ps1"
STAMP_SH="${HARNESS_ROOT}/bin/vendor-lock-stamp.sh"
MODE="$1"

lock_sha() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
# pool 디렉토리 키 = lock 해시 + composer.json autoload·autoload-dev 섹션.
# lock 만 키로 쓰면 lock 불변 + autoload 매핑 변경(2026-09-23 develop 54695f7c)을
# 같은 pool 로 보고 옛 autoload 를 계속 클론한다. .lock-sha stamp 는 lock 해시 그대로 둔다
# (vendor-lock-stamp.sh 계약 유지) — 이 키는 디렉토리 선택에만 쓴다.
pool_key() {
    local root="$1" autoload
    autoload=$(php -r '$j = json_decode(file_get_contents($argv[1]), true);
        echo json_encode([$j["autoload"] ?? null, $j["autoload-dev"] ?? null]);' "$root/composer.json" 2>/dev/null)
    printf '%s\n%s' "$(lock_sha "$root/composer.lock")" "$autoload" | sha256sum | cut -c1-16
}
to_winpath() { cygpath -w "$1" 2>/dev/null || echo "$1"; }

cmd_build() {
    local vdir="$1"
    [ -d "$vdir" ] || { echo "vendor 디렉토리 없음: $vdir" >&2; exit 1; }
    local lock="$(dirname "$vdir")/composer.lock"
    [ -f "$lock" ] || { echo "composer.lock 없음: $lock" >&2; exit 1; }

    local pool="${POOL_ROOT}/$(pool_key "$(dirname "$vdir")")"

    if [ -d "$pool" ]; then
        echo "pool 이미 존재: $pool (스킵)"
        return 0
    fi

    echo "pool 생성: $pool"
    echo "  원본: $vdir"
    powershell -NoProfile -ExecutionPolicy Bypass -File "$(to_winpath "$CLONE_PS1")" \
        -Source "$(to_winpath "$vdir")" -Dest "$(to_winpath "$pool")" || { echo "클론 실패" >&2; exit 1; }

    lock_sha "$lock" > "$pool/.lock-sha"
    echo "pool stamp 완료: $pool/.lock-sha"
}

cmd_convert() {
    local wt="$1"
    local vdir="$wt/vendor"
    local lock="$wt/composer.lock"
    [ -f "$lock" ] || { echo "composer.lock 없음: $wt" >&2; exit 1; }
    [ -d "$vdir" ] || { echo "vendor 없음(신규 설치는 범위 밖): $wt" >&2; exit 1; }
    if [ -L "$vdir" ]; then
        echo "거부: vendor 가 이미 링크(junction/symlink) — 수동 확인 필요: $vdir" >&2
        exit 1
    fi

    local sha; sha=$(lock_sha "$lock")
    local pool="${POOL_ROOT}/$(pool_key "$wt")"
    [ -d "$pool" ] || { echo "pool 없음 — 먼저 build 필요: $pool" >&2; exit 1; }

    local pool_stamp; pool_stamp=$(cat "$pool/.lock-sha" 2>/dev/null | tr -d '[:space:]')
    if [ "$pool_stamp" != "$sha" ]; then
        echo "거부: pool stamp 불일치 (pool 오염 의심) — pool=$pool_stamp lock=$sha" >&2
        exit 1
    fi

    local old="${vdir}.old"
    [ -e "$old" ] && { echo "거부: $old 이미 존재 — 이전 실패분 정리 필요" >&2; exit 1; }

    echo "전환: $wt"
    mv "$vdir" "$old" || { echo "vendor 대피 실패" >&2; exit 1; }

    powershell -NoProfile -ExecutionPolicy Bypass -File "$(to_winpath "$CLONE_PS1")" \
        -Source "$(to_winpath "$pool")" -Dest "$(to_winpath "$vdir")"
    if [ $? -ne 0 ] || [ ! -f "$vdir/autoload.php" ]; then
        echo "클론 실패 — 롤백" >&2
        rm -rf "$vdir" 2>/dev/null
        mv "$old" "$vdir"
        exit 1
    fi

    lock_sha "$lock" > "$vdir/.lock-sha"

    # composer install 산출물이 아닌 런타임 캐시(phpunit 결과 캐시 등)는 vendor 정합과
    # 무관하므로 비교에서 제외한다 — 이 파일들이 old 에만 있어도 실패로 잡지 않는다.
    local noise_pattern='(^|/)\.phpunit\.result\.cache$'
    find "$old" -type f | sed "s#^$old/##" | grep -vE "$noise_pattern" | sort > "${old}.filelist"
    find "$vdir" -type f | sed "s#^$vdir/##" | grep -vE "$noise_pattern" | sort > "${vdir}.filelist"

    local missing
    missing=$(comm -23 "${old}.filelist" "${vdir}.filelist")
    rm -f "${old}.filelist" "${vdir}.filelist"

    if [ -n "$missing" ]; then
        echo "경고: pool 에 없는 파일이 구 vendor 에 존재 — 실제 내용 차이 의심, vendor.old 보존" >&2
        echo "$missing" | head -20 >&2
        exit 1
    fi

    rm -rf "$old"
    echo "전환 완료: $vdir ($(find "$vdir" -type f | wc -l)개 파일, 구 vendor 제거)"
}

cmd_ensure() {
    local wt="$1"
    local vdir="$wt/vendor"
    local lock="$wt/composer.lock"
    [ -f "$lock" ] || { echo "composer.lock 없음(PHP 레포 아님) — skip: $wt"; return 0; }

    if [ -e "$vdir" ]; then
        echo "vendor 이미 존재 — convert 로 위임: $vdir"
        cmd_convert "$wt"
        return $?
    fi

    local sha; sha=$(lock_sha "$lock")
    local pool="${POOL_ROOT}/$(pool_key "$wt")"
    if [ -d "$pool" ] &&[ "$(cat "$pool/.lock-sha" 2>/dev/null | tr -d '[:space:]')" = "$sha" ]; then
        echo "pool 적중 — 하드링크 클론: $pool -> $vdir"
        if powershell -NoProfile -ExecutionPolicy Bypass -File "$(to_winpath "$CLONE_PS1")" \
            -Source "$(to_winpath "$pool")" -Dest "$(to_winpath "$vdir")" && [ -f "$vdir/autoload.php" ]; then
            lock_sha "$lock" > "$vdir/.lock-sha"
            echo "완료(하드링크): $vdir"
            return 0
        fi
        echo "클론 실패 — composer install 로 폴백" >&2
        rm -rf "$vdir" 2>/dev/null
    fi

    echo "pool 없음 — composer install 실행 (최초 1회, 다음부턴 pool 재사용)"
    ( cd "$wt" && composer install --no-interaction --no-progress ) || { echo "composer install 실패" >&2; return 1; }
    lock_sha "$lock" > "$vdir/.lock-sha"
    cmd_build "$vdir"
}

cmd_status() {
    [ -d "$POOL_ROOT" ] || { echo "pool 없음"; return 0; }
    printf "%-20s %-10s %s\n" "pool" "용량" "stamp"
    for p in "$POOL_ROOT"/*/; do
        [ -d "$p" ] || continue
        local sz; sz=$(du -sh "$p" 2>/dev/null | cut -f1)
        local st; st=$(cat "$p/.lock-sha" 2>/dev/null | cut -c1-12)
        printf "%-20s %-10s %s\n" "$(basename "$p")" "$sz" "${st:-없음}"
    done
}

case "$MODE" in
    build)   cmd_build "$2" ;;
    convert) cmd_convert "$2" ;;
    ensure)  cmd_ensure "$2" ;;
    status)  cmd_status ;;
    *) sed -n '2,31p' "$0"; exit 2 ;;
esac
