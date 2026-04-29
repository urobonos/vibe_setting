---
type: reference
for: task-docs/SKILL.md Part 5-1
title: SDP — Software Development Plan (IEEE/ISO 12207)
---

## 5-1. SDP — Software Development Plan (IEEE/ISO 12207)

### 파일 경로
```
~/.claude/docs/{product}/specs/project-sdp.md
```

### 템플릿

```markdown
# Software Development Plan
> version: 1.0 | lastUpdated: YYYY-MM-DD | standard: IEEE/ISO/IEC 12207:2017

## 1. Introduction
### 1.1 Purpose
### 1.2 Scope (포함/제외 범위)
### 1.3 Definitions, Acronyms, Abbreviations
### 1.4 References (관련 표준/문서)
### 1.5 Overview (문서 구성 설명)

## 2. Project Overview
| 항목 | 내용 |
|------|------|
| 프로젝트명 | {프로젝트명} |
| 목적 | {비즈니스 목적} |
| 범위 | {포함/제외} |

## 3. Technical Stack
| 항목 | 버전 | 비고 |
|------|------|------|

## 4. Architecture
- {Modular Monolith, Dual Mode 등}

## 5. Milestones
| # | 마일스톤 | 목표일 | 산출물 | 상태 |
|---|---------|--------|--------|------|

## 6. Development Methodology
- {3-Team, Conventional Commits, 브랜치 전략}

## 7. Configuration Management
| 항목 | 내용 |
|------|------|
| VCS | Git (Bitbucket) |
| 브랜치 전략 | {전략} |
| CI/CD | {파이프라인} |

## 8. Risk Management
| # | 리스크 | 확률 | 영향도 | 대응 방안 |
|---|--------|------|--------|----------|

## 9. Quality Assurance
- 테스트 전략 (Unit / Feature / Integration)
- 코드 리뷰 프로세스
- 산출물 검토 프로세스 (3-Round IEEE Review)

## 10. 타당성 검토 (Feasibility Review)
| # | 항목 | 근거 | 출처 |
|---|------|------|------|

## 11. 변경 영향 기록 (Change Impact Log)
| # | 변경 사항 | 개선점 | 수행 이유 |
|---|----------|--------|----------|

## 12. 검토 체크리스트
(IEEE 12207 기반 — 완전성/일관성/실행가능성/추적성 4축)

## 13. 변경 로그
| 일자 | 버전 | 변경 내용 |
|------|------|----------|
```
