# 코인 1년 미이용 소멸 — 서버 (API Session, 2026-11-19)

요청: 토스페이먼츠 등록 준비 세션 (runs/handoff/20261119_coin-expiry.md). 사용자 결정: 만료 알림 메일은 로그인 이메일을 저장해 보낸다.

바꾼 것 (로컬, 미커밋·미배포)
- models/migration 20261119_8d1f3b6e2a47: users.coins_active_at, coins_notice_days, email_enc(암호화), auth_handoffs.email_enc. 백필 없음(12-01 이전 활동은 12-01부터 셈).
- coins.py: 충전·사용 때 coins_active_at 갱신. last_day()(KST, +1년, 2/29→2/28), expire_due(): 30·7일 전 알림함+푸시+메일, 다음 날 잔액 0 + '기간 만료 소멸' 내역. 알림은 원자적으로 선점(Codex 리뷰 반영).
- cron marketing-reconfirm(10:00 KST)에 소멸 작업 추가. GET /v1/coins·관리자 회원 행에 coins_expire_after.
- 로그인(/v1/auth/{provider}, Apple 웹 흐름)에서 ID 토큰 email 저장, Apple 웹 흐름 scope=email.
- tests/test_coin_expiry.py 추가, openapi.json 갱신. 전체 215 통과.
- 처리방침 개정 시행(초안 2026-12-19) 전에는 이메일 저장 안 함: auth.EMAIL_FROM. iOS '권한 전 App Store 코인 소멸 예외' 결정 대기로 운영 배포 보류.

## 이어서: App Store 코인 소멸 예외 (사용자 "1번으로", iOS 세션 경유)
- coin_lots 테이블: 충전 묶음별 출처·소멸 여부·남은 수. 차감은 오래된 묶음부터, 환불은 그 결제 묶음부터, 별빛 받기 그만두기는 가져간 묶음으로 되돌림(starlight_attempts.charged_lots).
- 기존 App Store 상품(coin_110·330·1100, 판매 중단 50·120·300)은 소멸 안 함. 나머지 묶음은 마지막 충전·사용 +1년에 함께 소멸.
- 마이그레이션이 coin_entries를 재생해 기존 잔액의 묶음을 만듦(어긋나면 이용자에게 유리하게).
- API: GET /v1/coins·관리자 회원 행에 coins_expiring, coins_expire_after.
- Codex 리뷰 2회: 알림 중복 선점, 소멸 시 계정 행 잠금 반영. 테스트 218 통과. 미커밋·미배포.

## 운영 배포 (사용자 승인 "운영 배포까지")
- 백업: ~/backups/youniya-premigration/youniya-20261119-072921.tar.gz (rev 5c9e2a7d4b13, 308행). 현재 코드로는 백업 도구가 새 컬럼을 찾아 실패해서 HEAD 워크트리로 떴음 → home-desktop 백업 타이머도 코드 갱신 필요.
- 개발 DB·운영 DB 마이그레이션 8d1f3b6e2a47: 잔액과 묶음 합계 불일치 0 (dev 23명, prod 5명).
- 커밋 b2f034b(서버 파일만) → main 푸시 → youniya-api 운영 배포 Ready, 공개 spec에 새 코드 확인.
- 정책 점검(웹·앱 문구): 결과는 대화 답변에 정리. 운영 공지 0건.
- 사용자 결정: 이메일 저장을 지금부터(EMAIL_FROM 제거), 커밋 ac2881f 배포. iOS·Android·Web Dev·토스 세션에 할 일 전달.
- kind 'expire' 추가, 커밋 e3d0260 운영 배포. 처리방침 시행일 2026-12-01 사용자 확정 → 토스·iOS·Android·Web Dev 세션에 전달.
- 지원 메일 yuni-support@dycdyp.com: 서버 발신 기본값 변경(커밋 28a84c1), 토스·iOS·Android·Web Dev 세션에 바꿀 곳 전달.
