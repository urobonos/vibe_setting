# Part F: 프로세스 및 거버넌스 보안 체크리스트

**적용 시점:** 신규 기능 설계(Team 1), 아키텍처 변경, 보안 관련 설계 결정, 정기 보안 점검 시

| 기반 표준 | URL |
|----------|-----|
| OWASP SAMM | https://owaspsamm.org/model/ |
| Microsoft Threat Modeling Tool | https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats |
| NIST CSF 2.0 | https://csrc.nist.gov/projects/cybersecurity-framework |
| OWASP Risk Rating Methodology | https://owasp.org/www-community/OWASP_Risk_Rating_Methodology |

---

## F1. STRIDE 위협 모델링 (Microsoft TMT)

- [ ] 신규 기능/아키텍처 변경 시 STRIDE 위협 모델링이 수행되었는가
- [ ] **Spoofing:** 인증되지 않은 사용자의 위장 가능성이 차단되어 있는가
- [ ] **Tampering:** 전송 중/저장 중 데이터 변조 방지가 적용되어 있는가
- [ ] **Repudiation:** 악의적 행위 부인 방지를 위한 감사 로그가 존재하는가
- [ ] **Information Disclosure:** 민감 정보가 의도치 않게 노출되지 않는가
- [ ] **DoS:** 과도한 요청에 대한 서비스 거부 방어가 적용되어 있는가
- [ ] **Elevation of Privilege:** 일반 사용자의 관리자 권한 획득이 차단되어 있는가

## F2. 민감 데이터 보호 (Microsoft TMT - Sensitive Data)

- [ ] 민감 데이터(PII, 금융정보)가 브라우저 캐시/로컬 스토리지에 저장되지 않는가
- [ ] 설정 파일의 민감 정보 섹션이 암호화되어 있는가
- [ ] DB 컬럼 수준 암호화 또는 TDE가 활성화되어 있는가
- [ ] DB 백업이 암호화되어 있는가
- [ ] 민감 데이터가 화면 표시 시 마스킹 처리되고 있는가
- [ ] 비권한 사용자에 대해 동적 데이터 마스킹이 적용되어 있는가

## F3. 인증 강화 (Microsoft TMT - Authentication)

- [ ] 인증 실패 시나리오가 안전하게 처리되는가 (일반 에러 메시지, 계정 잠금)
- [ ] 민감 정보 접근 시 Step-up/Adaptive 인증(MFA)이 적용되어 있는가
- [ ] 관리자 인터페이스가 IP 제한 또는 추가 인증으로 잠겨 있는가
- [ ] 비밀번호 재설정이 시간 제한 토큰 기반으로 구현되어 있는가
- [ ] 사용자명 열거(Username Enumeration) 방지 대책이 적용되는가
- [ ] 비밀번호 정책(최소 길이, 복잡성, 만료, 재사용 금지)이 시행되는가
- [ ] 토큰 재생 공격(Token Replay Attack) 방지 메커니즘이 구현되어 있는가

## F4. 암호화 (Microsoft TMT - Cryptography)

- [ ] 승인된 대칭 블록 암호(AES-128/192/256)와 적절한 키 길이만 사용되는가
- [ ] 비대칭 알고리즘 키 길이가 RSA >= 2048bit, ECDSA >= 256bit인가
- [ ] CSPRNG만 사용되고 있는가
- [ ] SHA-2 계열만 사용되고 MD5/SHA-1은 사용되지 않는가
- [ ] 비밀번호가 salt + 적응형 해시(bcrypt/scrypt/PBKDF2)로 저장되는가
- [ ] 서명 키가 주기적으로 롤오버되고 있는가

## F5. 감사 및 로깅 (Microsoft TMT - Auditing)

- [ ] 감사 로그에 사용자 컨텍스트가 포함되고 중요 이벤트가 기록되는가
- [ ] 중앙 집중 로깅이 구현되어 있는가
- [ ] 로그 로테이션 및 분리 저장이 적용되어 있는가
- [ ] 로그에 민감 데이터가 기록되지 않도록 보장되어 있는가
- [ ] 감사/로그 파일에 대한 접근 권한이 적절히 제한되어 있는가
- [ ] 사용자 관리 이벤트(로그인, 비밀번호 변경, 계정 잠금)가 기록되는가
- [ ] 오용 탐지(CSRF 위반, 브루트포스) 방어 메커니즘이 내장되어 있는가

## F6. 접근 제어 정책

- [ ] 접근 제어 정책이 코드로 관리되고 Git에 포함되어 있는가
- [ ] 정책 변경 이력이 추적되는가
- [ ] 배포 전 정책 검증이 CI/CD에 포함되어 있는가

## F7. OWASP SAMM - 거버넌스

- [ ] 보안 프로그램의 목표와 KPI가 정의되어 있는가 (Strategy & Metrics)
- [ ] 애플리케이션 보안 전략 로드맵이 수립/공유되어 있는가 (Strategy & Metrics)
- [ ] 외부 법규/규제 컴플라이언스 요구사항이 식별되고 매핑되어 있는가 (Policy & Compliance)
- [ ] 개별 애플리케이션의 정책 준수 여부가 측정/보고되는가 (Policy & Compliance)
- [ ] 모든 개발 인원에게 보안 인식 교육이 제공되는가 (Education & Guidance)
- [ ] 각 팀에 Security Champion이 지정되어 있는가 (Education & Guidance)
- [ ] 기술/역할별 맞춤 보안 가이드라인이 제공되는가 (Education & Guidance)

## F8. OWASP SAMM - 설계

- [ ] 애플리케이션별 리스크 프로필이 작성/검토되는가 (Threat Assessment)
- [ ] 요구사항 프로세스에서 보안 요구사항이 명시적으로 고려되는가 (Security Requirements)
- [ ] 서드파티 공급업체의 보안 준수 여부가 계약에 반영/검증되는가 (Security Requirements)
- [ ] 보안 참조 아키텍처(Secure-by-default 패턴)가 수립/재사용되는가 (Secure Architecture)
- [ ] 승인된 기술/프레임워크 목록이 표준화되어 적용되는가 (Secure Architecture)

## F9. OWASP SAMM - 구현

- [ ] SAST/DAST 스캐닝이 빌드에 통합되어 있는가 (Secure Build)
- [ ] 보안 결함 아티팩트가 프로덕션 진행이 차단되도록 빌드 게이트가 설정되어 있는가 (Secure Build)
- [ ] SBOM(Software Bill of Materials)이 생성/관리되는가 (Secure Build)
- [ ] 서드파티 의존성 보안 취약점 추적 및 대응 절차가 수립되어 있는가 (Secure Build)
- [ ] 배포 프로세스에 보안 검증 마일스톤이 포함되어 있는가 (Secure Deployment)
- [ ] 시크릿이 보안 저장소(Vault)에서 동적 주입되는가 (Secure Deployment)
- [ ] 배포된 소프트웨어의 무결성이 독립적으로 검증되는가 (Secure Deployment)
- [ ] 시크릿/키가 주기적으로 자동 로테이션되는가 (Secure Deployment)
- [ ] 보안 결함에 대한 심각도별 SLA가 정의/이행되는가 (Defect Management)
- [ ] 보안 결함 추적 메트릭이 우선순위 결정에 활용되는가 (Defect Management)

## F10. OWASP SAMM - 검증

- [ ] 아키텍처 보안 메커니즘의 완전성과 효과가 주기적으로 검증되는가 (Architecture Assessment)
- [ ] 보안 요구사항에서 도출된 테스트 케이스가 작성/실행되는가 (Requirements-driven Testing)
- [ ] 남용 사례(Abuse Case) 및 비즈니스 로직 결함 테스트가 수행되는가 (Requirements-driven Testing)
- [ ] 보안 퍼징(Fuzzing) 테스트가 실행되는가 (Requirements-driven Testing)
- [ ] 고위험 컴포넌트에 대한 전문가 수동 침투 테스트가 정기 수행되는가 (Security Testing)

## F11. OWASP SAMM - 운영

- [ ] 보안 인시던트 탐지를 위한 로그 자동 분석 프로세스가 구축되어 있는가 (Incident Management)
- [ ] 공식적인 인시던트 대응 프로세스가 수립되고 담당자가 훈련되어 있는가 (Incident Management)
- [ ] 전담 인시던트 대응팀이 구성되어 있는가 (Incident Management)
- [ ] 보안 구성 하드닝 베이스라인이 수립/적용되어 있는가 (Environment Management)
- [ ] 전체 기술 스택에 정기 패치 적용 스케줄이 운영되는가 (Environment Management)
- [ ] 구성 베이스라인 비준수가 자동 모니터링되는가 (Environment Management)
- [ ] 데이터 자산 카탈로그가 작성되고 데이터 보호 정책이 수립되어 있는가 (Operational Management)
- [ ] 미사용 애플리케이션 폐기 및 레거시 마이그레이션 로드맵이 관리되는가 (Operational Management)

## F12. NIST CSF 2.0 - 거버넌스 (GOVERN)

- [ ] 조직의 미션, 법적 요구사항, 위험 환경이 문서화되어 있는가 (GV.OC)
- [ ] 사이버보안 리스크 허용 범위가 설정되고 자원 배분이 이루어지는가 (GV.RM)
- [ ] 보안 역할, 책임, 권한이 명시적으로 할당되어 있는가 (GV.RR)
- [ ] 보안 정책, 표준, 절차가 수립/유지 관리되는가 (GV.PO)
- [ ] 보안 프로그램에 대한 감독, 감사, 검토가 이루어지는가 (GV.OV)
- [ ] 서드파티/공급망 보안 리스크가 관리되는가 (GV.SC)

## F13. NIST CSF 2.0 - 식별/보호 (IDENTIFY/PROTECT)

- [ ] 자산이 중요도/미션 영향도 기반으로 우선순위화되어 관리되는가 (ID.AM)
- [ ] 리스크 평가가 수행되어 위협/취약점/영향이 식별되는가 (ID.RA)
- [ ] 보안 프로그램의 지속적 개선 프로세스가 운영되는가 (ID.IM)
- [ ] 플랫폼 보안(OS, 컨테이너, 클라우드)이 관리되는가 (PR.PS)
- [ ] 기술 인프라 복원력(이중화, 장애 복구)이 확보되어 있는가 (PR.IR)

## F14. NIST CSF 2.0 - 탐지/대응/복구 (DETECT/RESPOND/RECOVER)

- [ ] 지속적 모니터링으로 잠재 위협 이벤트가 탐지되는가 (DE.CM)
- [ ] 탐지된 이상 이벤트에 대한 분석이 수행되어 공격 여부가 판별되는가 (DE.AE)
- [ ] 인시던트 관리 절차(탐지→분류→대응)가 수립되어 있는가 (RS.MA)
- [ ] 인시던트 분석(근본 원인, 규모 추정)이 수행되는가 (RS.AN)
- [ ] 인시던트 대응 보고 및 커뮤니케이션 체계가 구축되어 있는가 (RS.CO)
- [ ] 인시던트 확산 방지 및 완화 조치가 정의되어 있는가 (RS.MI)
- [ ] 인시던트 복구 계획이 수립되고 테스트되는가 (RC.RP)
- [ ] 백업/복원 자산의 무결성이 사용 전 검증되는가 (RC.RP)
