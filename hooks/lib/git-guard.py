#!/usr/bin/env python3
"""
git-guard.py — 안전 hook 공유 명령 파서 (SSOT, 2026-06-05 도입)

목적: branch-enforce.sh / dangerous-ops-guard.sh 의 git 가드 파서를 단일 SSOT 로 수렴해
  §3 절대차단 우회 구멍(C-1 `git -C <path>` / H-1 rm 앵커 / H-5 push 변형 / force-push `-f`)을 닫는다.

위협 모델 (중요): 이 가드는 **Claude 자기 실수** 방지용이지 악의적 공격자 방어가 아니다.
  (사용자는 `! cmd` / `SKIP_HOOKS=1` 로 자명하게 우회 가능 — 적대적 회피는 가드 대상이 아님)
  → 승리 조건 = "Claude 명령 어휘(in-vocab)에 있는 형태 차단", "완전성"이 아님.
  난독화 꼬리(미지 변수전개 ${x}git / 명령·프로세스 치환 / eval·bash -c 문자열 재귀)는
  static parser 로 환원 불가 = KNOWN-LIMITATION (기존 grep/shlex 가드도 동일 altitude, 회귀 아님).

설계 (advisor 2026-06-05 1·2차 검증 + adversarial 82-survivor fan-out 반영):
  - clauses(cmd) → [(cmd_token, args), ...]: operator 경계 분할 후 각 절의 명령 위치 토큰.
    leading 으로 env-prefix(VAR=val) / wrapper(sudo·timeout·nice 등, 옵션·숫자 인자 동반) /
    shell 키워드(then·do·{ 등 명령위치 선행) 를 strip. ANSI-C `$'...'` 는 전처리 디코드.
  - git_subcommand(git_args) → (sub, rest): git 전역옵션 전수 정규화 후 진짜 subcommand.
    전역옵션은 **옵션별 arity** 로 정확히 — 값-취득(`-C`/`--git-dir` 분리·결합 양형) skip 2/1,
    flag skip 1, 미지 '-' 토큰 보수적 skip 1(놓침 방지). [Source: git(1) SYNOPSIS]
    `--` end-of-options 이후는 pathspec → ref/플래그 매칭에서 제외(detector 책임).
  - 소비자(bash hook)는 detector 를 CLI 호출/import. python 부재 fallback 은 소비자 책임.

회귀 방향 = tightening: 위험 = false POSITIVE(합법 git 워크플로우 차단). 새 DETECT 마다 짝
  MUST-PASS 를 매트릭스에 박는다. 검증 SSOT = 격리 mock 매트릭스(같은 폴더 step01 스크립트).

CLI:
  python3 git-guard.py <detector>   < command-on-stdin   → '1'/'0' (master-merge 는 패턴명/'0')
  detector ∈ { push, master-merge, cherry-pick, force-push, reset-hard, clean-f,
               branch-D, checkout-dot, restore-dot, rm-destructive }

SSOT: CLAUDE.md §4.3 worktree·push·머지 통합 정책 + working/ guard-tokenization-hardening
"""
import sys
import shlex
import re

# ── 정책 상수 (branch-enforce·dangerous-ops 에서 수렴) ──────────────────────
MASTER_TARGETS = {
    'main', 'master', 'origin/main', 'origin/master',
    'refs/heads/main', 'refs/heads/master',
    'upstream/main', 'upstream/master',
}
CHERRY_RECOVERY = {'--abort', '--quit', '--skip'}

# ── clause-splitter 상수 ───────────────────────────────────────────────────
# OPS: punctuation_chars=True 가 단일 토큰화하는 shell 연산자. '|&' = 결합 파이프.
_OPS = {'|', '||', '&&', ';', '&', '(', ')', '|&'}
# WRAP: 다음 토큰이 command-position 을 유지하는 래퍼(+옵션·숫자 인자 동반).
#   strip 후 진짜 명령 토큰을 노출. command -v rm/which rm 은 cmd_token 이 -v/git 이 아니라 통과.
#   adversarial fan-out 으로 timeout/nice/stdbuf/ionice/setsid/time/doas/chrt 추가(in-vocab wrapper).
_WRAP = {
    'sudo', 'xargs', 'command', 'exec', 'nohup', 'env',
    'timeout', 'nice', 'stdbuf', 'ionice', 'setsid', 'time', 'doas', 'chrt',
}
# 명령 위치 선행 shell 키워드 (compound command). leading 으로 오면 skip → 다음이 진짜 명령.
#   `if t; then git push; fi` → 'then' 절의 cmd_token 이 then 이 아니라 git 이 되도록.
_KEYWORDS = {'then', 'do', 'else', 'elif', '{', '}', 'fi', 'done', '!'}

# ── git 전역옵션 (git(1) SYNOPSIS: <command> 앞, 옵션별 arity) ──────────────
# 값-취득 (다음 토큰이 값 → skip 2). 분리형(`--git-dir /p`) 과 결합형(`--git-dir=/p`, 아래 EQ) 양형.
_GLOBAL_VAL = {'-C', '-c', '--namespace', '--git-dir', '--work-tree', '--config-env', '--attr-source'}
# '=' 결합 단일 토큰 (skip 1, prefix 매칭)
_GLOBAL_EQ = (
    '--namespace=', '--git-dir=', '--work-tree=', '--exec-path=', '--config-env=', '--attr-source=',
)
# 값 없는 flag (skip 1)
_GLOBAL_FLAG = {
    '-p', '--paginate', '-P', '--no-pager', '--bare', '--no-replace-objects',
    '--literal-pathspecs', '--glob-pathspecs', '--noglob-pathspecs', '--icase-pathspecs',
    '--no-optional-locks', '--no-lazy-fetch', '--no-advice',
    '--html-path', '--man-path', '--info-path', '--exec-path',
}


def _decode_ansi_c(cmd):
    """ANSI-C quoting `$'...'` 전처리 디코드 ($'git'→git). shlex 가 $'...' 를 미해석하므로.
    디코드 결과에 공백이 생기면(예: $'git\\x20push' → 'git push') 단일 인자 의미라 따옴표 재보호
    (그 형태는 실존 바이너리 없음=무위협). 디코드 실패 시 원형 보존."""
    def _repl(m):
        body = m.group(1)
        try:
            dec = bytes(body, 'utf-8').decode('unicode_escape')
        except Exception:
            return m.group(0)
        if re.search(r'\s', dec):
            return "'" + dec.replace("'", "'\\''") + "'"
        return dec
    return re.sub(r"\$'((?:[^'\\]|\\.)*)'", _repl, cmd)


def _tokenize(cmd):
    """따옴표 밖 newline = 절 분리(';' 치환), shlex(punctuation_chars).
    parse 실패(따옴표 깨짐 등) 시 cmd.split() 보수 fallback."""
    cmd = _decode_ansi_c(cmd)
    cmd = cmd.replace('\n', ' ; ')
    try:
        lx = shlex.shlex(cmd, posix=True, punctuation_chars=True)
        lx.whitespace_split = True
        return list(lx)
    except ValueError:
        return cmd.split()


def clauses(cmd):
    """명령을 operator(OPS) 경계로 분할 → 각 절의 (cmd_token, args) 리스트.

    leading strip 순서(반복): env-prefix(VAR=val) → shell 키워드(then/do/{ 등) →
    wrapper(sudo/timeout/... + 그 옵션 '-x' 및 숫자 인자). 첫 실제 토큰 = cmd_token.
    명령 토큰 없는 절(전부 strip) 제외. subshell '(' ')' 는 OPS 라 경계로 작동.
    """
    toks = _tokenize(cmd)
    groups = []
    cur = []
    for t in toks:
        if t in _OPS:
            if cur:
                groups.append(cur)
            cur = []
        else:
            cur.append(t)
    if cur:
        groups.append(cur)

    out = []
    for g in groups:
        i = 0
        n = len(g)
        while i < n:
            tk = g[i]
            if re.match(r'^\w+=', tk):          # env-prefix (VAR=val), 복수 연속 가능
                i += 1
                continue
            if tk in _KEYWORDS:                 # compound 키워드 (then/do/{ 등)
                i += 1
                continue
            if tk in _WRAP:                      # wrapper passthrough + 옵션·숫자 인자 skip
                i += 1
                while i < n and (g[i].startswith('-') or re.match(r'^\d+$', g[i])):
                    i += 1                       # -u / -n / -o0 / 5(duration) 등
                continue
            break
        if i < n:
            out.append((g[i], g[i + 1:]))
    return out


def git_subcommand(git_args):
    """'git' 다음 토큰들(git_args)에서 전역옵션 정규화 후 (subcommand, rest) 반환.

    호출 전제: cmd_token == 'git' 확인은 호출자 책임.
    옵션별 arity 로 정확히 skip — 값-취득(-C/--git-dir 분리·결합) / flag / 미지'-'(보수 skip 1).
    `--` = end-of-options → 바로 다음 토큰이 subcommand.
    subcommand 없으면(전부 옵션) (None, []).
    """
    i = 0
    n = len(git_args)
    while i < n:
        t = git_args[i]
        if t == '--':
            return (git_args[i + 1], git_args[i + 2:]) if i + 1 < n else (None, [])
        if t in _GLOBAL_VAL:
            i += 2                       # -C <path> / --git-dir <path> / -c <k=v> 등 분리형
            continue
        if t.startswith(_GLOBAL_EQ):
            i += 1                       # --git-dir=... 등 '=' 결합
            continue
        if t in _GLOBAL_FLAG:
            i += 1
            continue
        if t.startswith('-'):
            i += 1                       # 미지 전역옵션: 보수적 skip 1 (놓침 방지)
            continue
        return (t, git_args[i + 1:])     # 첫 비옵션 = subcommand
    return (None, [])


def _git_clauses(cmd):
    """clauses 중 cmd_token=='git' 인 절의 (subcommand, rest) 를 순회 (subcommand None 제외)."""
    for cmd_token, args in clauses(cmd):
        if cmd_token == 'git':
            sub, rest = git_subcommand(args)
            if sub is not None:
                yield sub, rest


def _before_dashdash(args):
    """'--' 이후(pathspec)를 잘라낸 ref/flag 영역만 반환."""
    return args[:args.index('--')] if '--' in args else args


# ── detector (소비자가 CLI/import 로 호출) ─────────────────────────────────
def detect_push(cmd):
    """어떤 절이든 git subcommand == push."""
    return any(sub == 'push' for sub, _ in _git_clauses(cmd))


def detect_master_merge(cmd):
    """merge/checkout/switch 의 ref 인자에 MASTER_TARGETS → 패턴명, 아니면 ''.

    **checkout 만** '--' 이후를 pathspec(파일명 main 등)으로 보고 ref 매칭에서 제외(FP 가드).
    merge/switch 는 '--' 이후도 ref 다 — `git merge -- main` = main 머지 / `git switch -- master`
    = master 전환 (real git 2.51 실측: merge/switch 모두 '--' 뒤 토큰을 ref 로 소비) → rest 전체 스캔.
    (checkout 용 '--' 수정을 merge/switch 에 일괄 적용하면 master 머지 우회 = §3 회귀 — advisor 2026-06-08)
    """
    label = {'merge': 'merge-target', 'checkout': 'checkout-master', 'switch': 'switch-master'}
    for sub, rest in _git_clauses(cmd):
        if sub in label:
            ref_args = _before_dashdash(rest) if sub == 'checkout' else rest
            if any(t in MASTER_TARGETS for t in ref_args):
                return label[sub]
    return ''


def detect_cherry_pick(cmd):
    """git cherry-pick (--abort/--quit/--skip 복구계 제외). BRANCH=master/main 조건은 소비자 책임."""
    for sub, rest in _git_clauses(cmd):
        if sub == 'cherry-pick' and not any(t in CHERRY_RECOVERY for t in rest):
            return True
    return False


def _is_short_flag_with(letter, token):
    """단일 대시 단축 플래그 묶음(-rf, -fd 등)에 letter 포함 여부. '--' 롱옵션 제외."""
    return token.startswith('-') and not token.startswith('--') and letter in token


def detect_force_push(cmd):
    """git push 에 --force / --force-with-lease / 단축 -f(결합 묶음 포함)."""
    for sub, rest in _git_clauses(cmd):
        if sub != 'push':
            continue
        for t in rest:
            if t == '--force' or t.startswith('--force=') or t.startswith('--force-with-lease'):
                return True
            if _is_short_flag_with('f', t):
                return True
    return False


def detect_reset_hard(cmd):
    """git reset --hard."""
    for sub, rest in _git_clauses(cmd):
        if sub == 'reset' and '--hard' in rest:
            return True
    return False


def detect_clean_f(cmd):
    """git clean 에 --force / 단축 -f(결합 -fd 등)."""
    for sub, rest in _git_clauses(cmd):
        if sub != 'clean':
            continue
        for t in rest:
            if t == '--force':
                return True
            if _is_short_flag_with('f', t):
                return True
    return False


def detect_branch_D(cmd):
    """git branch -D 검출. 단 worktree 정리용 '단일 절' 'git branch -D wip/…' 만 면제.

    면제: 전체가 단일 git branch 절 + rest 정확히 ['-D', 'wip/…']. 결합 명령 안 -D 는 면제 안 함.
    """
    cls = clauses(cmd)
    matched = False
    for cmd_token, args in cls:
        if cmd_token != 'git':
            continue
        sub, rest = git_subcommand(args)
        if sub == 'branch' and '-D' in rest:
            matched = True
    if not matched:
        return False
    if len(cls) == 1:
        cmd_token, args = cls[0]
        if cmd_token == 'git':
            sub, rest = git_subcommand(args)
            if sub == 'branch' and len(rest) == 2 and rest[0] == '-D' and rest[1].startswith('wip/'):
                return False
    return True


def detect_checkout_dot(cmd):
    """git checkout . (작업트리 전체 되돌리기). 인자 마지막이 '.'."""
    for sub, rest in _git_clauses(cmd):
        if sub == 'checkout' and rest and rest[-1] == '.':
            return True
    return False


def detect_restore_dot(cmd):
    """git restore . (작업트리 전체 되돌리기). 인자 마지막이 '.'."""
    for sub, rest in _git_clauses(cmd):
        if sub == 'restore' and rest and rest[-1] == '.':
            return True
    return False


def detect_rm_destructive(cmd):
    """rm 에 파괴 플래그(-r/-R/-f/--recursive/--force) 동반 시만 True. plain 'rm file' 통과.
    wrapper(sudo/xargs) 안 rm 도 clauses() 가 strip 후 노출. '--' 이후는 파일명 → 플래그 검사 제외(FP 가드)."""
    for cmd_token, args in clauses(cmd):
        if cmd_token != 'rm':
            continue
        for t in _before_dashdash(args):
            if t in ('--recursive', '--force'):
                return True
            if t.startswith('-') and not t.startswith('--') and ('r' in t or 'R' in t or 'f' in t):
                return True
    return False


_DETECTORS = {
    'push': detect_push,
    'cherry-pick': detect_cherry_pick,
    'force-push': detect_force_push,
    'reset-hard': detect_reset_hard,
    'clean-f': detect_clean_f,
    'branch-D': detect_branch_D,
    'checkout-dot': detect_checkout_dot,
    'restore-dot': detect_restore_dot,
    'rm-destructive': detect_rm_destructive,
}


def main(argv):
    if len(argv) < 2:
        sys.stderr.write('usage: git-guard.py <detector>  (stdin=command)\n')
        sys.stderr.write('detector: push|master-merge|cherry-pick|force-push|reset-hard|'
                         'clean-f|branch-D|checkout-dot|restore-dot|rm-destructive\n')
        return 2
    name = argv[1]
    cmd = sys.stdin.read()
    if name == 'all':
        # dangerous-ops-guard 배칭용: 모든 detector 를 단일 프로세스로 판정 (python 起動 7회→1회).
        # 출력 = 'detector=1/0' 라인들 + 'master-merge=<패턴명|0>'. 소비자는 라인 매칭으로 조회.
        out = ['%s=%s' % (k, '1' if f(cmd) else '0') for k, f in _DETECTORS.items()]
        mm = detect_master_merge(cmd)
        out.append('master-merge=%s' % (mm if mm else '0'))
        sys.stdout.write('\n'.join(out) + '\n')
        return 0
    if name == 'master-merge':
        r = detect_master_merge(cmd)
        sys.stdout.write((r if r else '0') + '\n')
        return 0
    fn = _DETECTORS.get(name)
    if fn is None:
        sys.stderr.write('unknown detector: %s\n' % name)
        return 2
    sys.stdout.write(('1' if fn(cmd) else '0') + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
