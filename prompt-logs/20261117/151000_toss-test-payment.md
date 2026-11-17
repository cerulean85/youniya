# 토스페이먼츠 테스트 결제 확인 (Web Dev 세션 a6c527, 2026-11-17)

- 요청: "토스 페이먼츠 붙었지?" → "진행해줘"
- 운영 Vercel `NEXT_PUBLIC_TOSS_CLIENT_KEY`, 로컬 server/.env `TOSS_SECRET_KEY` 모두 test 키. `TOSS_TEST_OPEN=1`. 운영 서버 키는 확인 안 함.
- v1.1에서 Recharge.tsx는 모양·문구만 바뀜(결제 요청·successUrl·confirm 경로 그대로).
- 운영 웹은 Google·Apple 로그인만 돼서, 로컬 next dev(개발 API, DEV_LOGIN) + 헤드리스 Chrome으로 진행.
  - 110코인 선택 → 동의 → 주문 생성 → 토스 샌드박스 결제창(코인 110개, 1,100원, 테스트 표시) → 신한 → 일시불·필수 동의 → 다음 → 신한카드 인증창(vbv.shinhancard.com)에서 멈춤(앱 인증 필요).
  - 승인 후 confirm·코인 지급·/coins/done은 확인 못 함. 잔액 15 그대로.
- 남은 것: 사용자가 직접 휴대폰 앱 인증으로 테스트 결제 1회 완료 후 코인 지급 확인.
