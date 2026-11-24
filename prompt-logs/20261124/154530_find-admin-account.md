# 관리자 계정 조회 (2026-11-24)

## 요청
- 관리자(Operator) 계정 정보를 잊어버려 어디에 무엇으로 등록되어 있는지 확인 요청.

## 확인 과정 및 결과
1. **운영(Production) DB (`server/.env.production` → Neon main branch) `operators` 테이블 조회**
   - `server/tools/admin_operator.py list` 실행 결과:
     - **이메일:** `zhwan85@gmail.com`
     - **권한 / 상태:** `owner` / `active` (`2026-11-09T12:22:38Z` 생성)
2. **개발(Dev) DB (`server/.env` → Neon dev branch) `operators` 테이블 조회**
   - 등록된 운영자 계정 없음 (비어 있음).
3. **로컬 Mock 콘솔 계정 (`admin/README.md`)**
   - `owner@youniya.test` / `mock-owner-pass` / OTP `123456`
   - `moderator@youniya.test` / `mock-mod-pass` / OTP `123456`
4. **서버 `X-Admin-Token` (`server/.env.production`)**
   - `ADMIN_TOKEN=CNV6cY5pFZPi6LGjVGWt70fif3Q9mqAxfPjeEQs57GI`
5. **앱 심사용 초대 계정 (`invite_accounts`, Production DB)**
   - 로그인 ID: `appreview`
