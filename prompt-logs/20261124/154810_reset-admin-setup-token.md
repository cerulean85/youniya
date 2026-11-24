# 운영자(owner) 1회용 재설정 토큰 발급 (2026-11-24)

## 요청
- 운영(Production) DB의 `zhwan85@gmail.com` (`owner`) 계정에 대해 비밀번호 및 TOTP 재설정용 1회용 setup 토큰 발급 요청.

## 수행 내용 및 결과
- `server/.env.production` 환경의 `operators` 테이블에서 `zhwan85@gmail.com` 계정 상태를 `invited`로 전환하고 잠금/실패 카운트(`failed_count`, `locked_until`) 및 기존 세션을 초기화한 뒤 `operators.invite()`로 3일 유효 1회용 `setup_token` 재발급 및 `admin_audit` 기록 완료.
- 관리자 콘솔 `/setup?token=<발급된_토큰>` 경로에서 새 비밀번호(12자 이상)와 OTP 등록 후 6자리 코드로 즉시 재활성화(`active`) 가능.
