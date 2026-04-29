---
type: reference
for: task-docs/SKILL.md Part 5-5
title: STP — Software Test Plan (IEEE 29119-3:2021)
---

## 5-5. STP — Software Test Plan (IEEE 29119-3:2021)

### 파일 경로
```
~/.claude/docs/{product}/specs/project-stp.md
```

### 필수 섹션

```markdown
---
문서명: Project — Software Test Plan
문서 ID: project-stp
버전: v{버전}
상태: {초안|승인됨}
생성일: {YYYY-MM-DD}
최종 수정일: {YYYY-MM-DD}
작성자: jypark
대상 시스템: HongCafe Global Backend
관련 문서: project-sdp.md, {모듈}-srs.md, {모듈}-std.md
적용 표준: IEEE 29119-3:2021
---

# Project — Software Test Plan (STP)

> IEEE 29119-3:2021 | version: {버전} | lastUpdated: {YYYY-MM-DD}

## 1. Introduction
### 1.1 Purpose
### 1.2 Scope
### 1.3 Definitions
### 1.4 References
### 1.5 Overview

## 2. Test Strategy
- 테스트 수준: Unit / Feature / Integration
- 접근법 (구조적, 행위적, 경험 기반)
- 설계 기법

## 3. Test Environment
- PHP/PHPUnit/CI4 버전
- phpunit.xml 설정
- Mock/Stub 전략

## 4. Test Schedule & Resources
- SDP 마일스톤 연동

## 5. Test Deliverables
- 모듈별 STD 참조 테이블

## 6. Entry/Exit Criteria
- Entry 조건 (테스트 시작 요건)
- Exit 조건 (테스트 종료 요건)
- Suspension 조건

## 7. Risk Analysis
- 테스트 리스크 식별 및 대응

## 8. Module Coverage Matrix
- 13개 모듈별 테스트 파일 수, 테스트 수, 커버리지 목표

## 9. 타당성 검토 (Feasibility Review)

## 10. 변경 영향 기록

## 11. 변경 로그
```
