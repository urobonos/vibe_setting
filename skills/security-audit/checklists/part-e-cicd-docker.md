# Part E: CI/CD + Docker 보안 체크리스트

**적용 시점:** CI/CD 파이프라인 설정, Dockerfile/docker-compose.yml/docker/ 하위 설정 변경 시

| 기반 표준 | URL |
|----------|-----|
| OWASP CI/CD Top 10 | https://owasp.org/www-project-top-10-ci-cd-security-risks/ |
| SLSA Framework v1.0 | https://slsa.dev/spec/v1.0/ |
| CIS Docker Benchmark | https://www.cisecurity.org/benchmark/docker |
| Docker Security | https://docs.docker.com/engine/security/ |
| NIST SSDF (SP 800-218) | https://csrc.nist.gov/publications/detail/sp/800-218/final |

---

## E1. CI/CD 파이프라인 보안 (OWASP CI/CD Top 10)

- [ ] 단일 사용자가 코드 커밋부터 프로덕션 배포까지 단독 수행 불가하도록 승인 단계가 강제되는가 (CICD-SEC-1)
- [ ] 프로덕션 브랜치에 branch protection rule이 설정되어 있는가 (CICD-SEC-1)
- [ ] 파이프라인 서비스 계정에 최소 권한 원칙이 적용되어 있는가 (CICD-SEC-2)
- [ ] CI 설정 파일이 리뷰 없이 수정/실행되는 것이 차단되어 있는가 (PPE 방지) (CICD-SEC-4)
- [ ] Makefile, 테스트 스크립트 등 파이프라인 참조 파일에도 코드 리뷰가 강제되는가 (CICD-SEC-4)
- [ ] 각 파이프라인 단계가 필요한 최소한의 시크릿에만 접근 가능한가 (CICD-SEC-5/6)
- [ ] CI 러너의 디버그 모드가 비활성화되고 관리 콘솔 접근이 제한되어 있는가 (CICD-SEC-7)
- [ ] CI/CD에 통합된 서드파티 도구가 보안 검증을 거쳤는가 (CICD-SEC-8)
- [ ] 파이프라인 실행, 설정 변경, 시크릿 접근에 대한 감사 로그가 기록되는가 (CICD-SEC-10)
- [ ] CI/CD에서 `echo ${{ secrets.* }}`로 시크릿이 노출되지 않는가

## E2. 공급망 무결성 (SLSA v1.0)

- [ ] composer.lock / requirements.txt가 Git에 커밋되어 있는가
- [ ] 서드파티 Action이 SHA 해시로 버전 고정되어 있는가
- [ ] 빌드 출처 증명(Provenance)이 생성되는가 (SLSA L1)
- [ ] 빌드가 개인 워크스테이션이 아닌 전용 CI 인프라에서 수행되는가 (SLSA L2)
- [ ] Provenance가 디지털 서명되어 위변조 감지가 가능한가 (SLSA L2)
- [ ] 동시 빌드 간 격리가 보장되는가 (SLSA L3)
- [ ] 각 빌드마다 새 환경이 프로비저닝되며 이전 상태가 잔존하지 않는가 (SLSA L3)
- [ ] 의존성과 베이스 이미지가 SHA256 다이제스트로 고정되어 있는가 (SLSA Threats-D)
- [ ] 빌드 산출물이 서명되고 배포 전 검증되는가 (CICD-SEC-9)
- [ ] 의존성 버전이 정확히 고정(`==`, `^` 미사용)되어 있는가

## E3. Dockerfile 보안 (CIS Docker Benchmark)

- [ ] Dockerfile에 `USER` 지시어로 non-root 사용자가 지정되어 있는가
- [ ] 베이스 이미지에 `:latest` 태그가 아닌 정확한 버전이 사용되는가
- [ ] `COPY .env` 또는 `ARG PASSWORD=xxx`가 Dockerfile에 없는가
- [ ] `HEALTHCHECK`가 정의되어 있는가
- [ ] 불필요한 패키지 설치가 없고 `--no-cache`가 사용되는가
- [ ] 멀티스테이지 빌드로 빌드 도구가 최종 이미지에 미포함되는가 (Docker Build)
- [ ] 최소 베이스 이미지(Alpine 등)를 사용하는가 (Docker Build)
- [ ] `COPY` vs `ADD`: 단순 복사에 `ADD` 대신 `COPY`를 사용하는가 (Docker Build)
- [ ] 파이프 사용 시 `set -o pipefail`이 설정되어 있는가 (Docker Build)
- [ ] 컨테이너당 하나의 프로세스/서비스만 실행되는가 (Docker Build)

## E4. docker-compose.yml 보안

- [ ] docker-compose에서 시크릿이 평문으로 노출되지 않는가
- [ ] PHP-FPM 포트(9000)가 외부에 직접 노출되지 않는가
- [ ] 컨테이너에 리소스 제한(mem_limit, cpus)이 설정되어 있는가
- [ ] 프론트/백엔드 네트워크가 분리되어 있는가
- [ ] `read_only: true` 파일시스템 설정이 적용되어 있는가 (Docker Security)
- [ ] `no-new-privileges:true`가 설정되어 있는가 (Docker Security)

## E5. Docker 엔진/런타임 보안 (Docker Docs)

- [ ] Docker 데몬 소켓에 신뢰할 수 있는 사용자만 접근 가능한가 (Docker Daemon)
- [ ] Docker API가 비암호화 HTTP로 노출되지 않는가 (Docker Daemon)
- [ ] 불필요한 Linux Capability가 drop 되어 있는가 (Docker Capabilities)
- [ ] User Namespace 매핑으로 컨테이너 root가 호스트 비특권 UID로 매핑되는가 (Docker User Namespaces)
- [ ] Seccomp 프로파일로 허용되지 않은 시스템 콜이 차단되는가 (Docker Seccomp)
- [ ] AppArmor/SELinux MAC 프로파일이 컨테이너에 적용되어 있는가 (Docker AppArmor)
- [ ] Docker Content Trust(DCT)가 활성화되어 서명된 이미지만 사용되는가 (Docker Content Trust)

## E6. .dockerignore 보안

- [ ] `.dockerignore`에 `.env`, `.env.*`가 제외되어 있는가
- [ ] `*.pem`, `key/`, `*.key`가 제외되어 있는가
- [ ] `.git`이 제외되어 있는가
- [ ] `tests/`가 제외되어 있는가 (프로덕션 이미지 불필요)
- [ ] `vendor/`가 제외되어 있는가 (이미지 내 composer install 시)

## E7. 설정 파일 보안

- [ ] php.ini에서 `memory_limit = -1`이 아닌 명시적 제한이 설정되어 있는가
- [ ] php.ini에서 `display_errors = Off`가 프로덕션에 설정되어 있는가
- [ ] 프로덕션 Dockerfile에 설정 파일이 COPY로 포함되어 이미지 자체 완결성이 보장되는가
- [ ] 이미지 취약점 스캔(`docker scout cves` / Trivy)이 정기 수행되는가

## E8. 보안 스캔 통합

- [ ] SAST(정적 분석)가 CI/CD 파이프라인에 통합되어 있는가
- [ ] DAST(동적 분석)가 CI/CD 파이프라인에 통합되어 있는가
- [ ] 보안 결함이 있는 아티팩트가 프로덕션으로 진행되지 못하도록 빌드 게이트가 설정되어 있는가
