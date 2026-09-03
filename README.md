<<<<<<< HEAD
# callping

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
=======
# callPing
2026 캡스톤 &&  2026 마이크로스톤

callPing [LoRA&RAG 상황기반 통화보조어플리케이션]


## 프로젝트 소개
본 시스템은 사용자의 통화 데이터를 수집/분석/활용하여 통화 전/중/후 과정을 전면적으로 지원하는 개인화 비서 시스템을 구축하는 것을 목표로 한다.

## 주요 기능
- 통화 전:
LoRA로 튜닝된 sLLM 모델의 통화 목적 기반 대본 생성
RAG 보조 sLLM 모델의 정보 서치 보조로 불필요한 통화 감소

- 통화 후:
통화 데이터(.txt)를 기반으로 내용 요약 및 개선 피드백 제공(말투/표현)
통화 전/후 불안도 측정(척도 1~10 기준) 및 주간 통계 그래프 제공

## 프로젝트 폴더 구조
callPing/
|--- android/ 	# 안드로이드 클라이언트(UI, 로컬 DB 등)
|--- server/ 	# Spring Boot 백엔드(세션 제어, API 라우팅 등)
|--- ai/	# AI 튜닝 및 LLM 파이프라인 (RAG 로직, 모델 서빙...)


## 깃헙 가이드
원활한 프로젝트 진행을 위해 모든 팀원은 아래의 작업 순서와 규칙을 반드시 숙지해 주시기 바랍니다. Git이 설치되어있으며 CLI 작업 경험이 있다는 가정 하에 작성된 가이드입니다. 기타 방식을 이용하실 경우 방법은 본인이 직접 숙지하시기 바랍니다.

## (1) Git Storage 세팅 (최초 1회만 실행)

# 1. 원격 저장소 복제하기
git clone [url] ## **clone 전 반드시 `git config` 되어 있는지 확인하세요!**

## (2) 작업 시작 전 주의사항
main 브랜치에서 직접 코드를 수정하시면 안됩니다.
작업을 시작하기 전에는 항상 최신 코드를 동기화하고(git pull origin main) 개인 작업이 진행될 본인만의 브랜치를 만드셔야 합니다.

```
# 1. 메인 브랜치로 이동
git switch main  (또는 git checkout main)

# 2. 메인 브랜치의 최신 코드 동기화
git pull origin main

# 3. 새로운 작업 브랜치 생성 및 이동 (브랜치 이름 예시: feature/로그인기능)
git switch -c feature/[작업할기능]  (또는 git checkout -b feature/[작업할기능])

```

## (3) 작업 후 커밋 (명령어 순서)
할당된 작업이 완수되면 하단의 순서를 따라 업로드하시면 됩니다.

```
# 1. 지금까지 수정한 파일 확인 (자신 있으시면 생략 ok)
git status

# 2. 변경된 사항을 로컬 저장소(클론된 리포지토리)에 저장 (특정 파일만 담거나, . 을 찍어 전체 담기)
git add . 

# 3. 작업 내용 확정해 메모 남기기
git commit -m "feat: 카카오 로그인 버튼 추가" (예시입니다.)

# 4. 로컬 저장소에 저장된 내용을 github의 브랜치에 등록하기
git push origin feature/[작업한기능]

```
절차 완수 후, 깃헙 사이트로 이동하여 **`Compare & pull request`** 버튼을 누르고 메인 브랜치에 합쳐달라는 요청(PR)을 남기시면 됩니다. 요청 후 각 팀원들의 확인이 진행되면 merge 됩니다.
>>>>>>> 10490b973338eb6be956346135a708590c47ee41
