# CallPing LoRA 서버 (참고용)

외부 실사용 서버를 빌린 것이기 때문에 서버 관련 정보는 삭제함. 그 외에는 원본.

## 구성
- 모델: Qwen3-8B 4bit + LoRA 어댑터 (어댑터 · 데이터는 포함하지 않음)
- 서버: FastAPI + uvicorn (`app.py` — 설정 config · 지시문 prompts · 모델 model · 대기열 gpu_queue · 화자 speakers · 파싱 parsing · 요약 검사 summary · 이벤트 events), GPU 하나로 요청을 들어온 순서대로 처리 — 처리 1 + 대기 7, 넘치면 503
- 운영: systemd 사용자 서비스(`systemd/`) · 리버스 SSH 터널 · 백엔드 도달 가드(불필요한 리소스 점유 예방)

## 엔드포인트
- `POST /lora/guides` — 통화 전 상황 → 말투 · 표현 가이드
- `POST /lora/feedback` — 통화 전사본 → 피드백 + 할 일(todos) + 통화 요약
- `GET /lora/health`

## 포함하지 않은 것
- 이벤트 캡처 — 요청 본문(통화 전사본, 개인정보)이 들어 있어 포함하지 않음