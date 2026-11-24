# 사용자 이메일 수집 여부 확인 (2026-11-24)

## 요청
- 현재 프로젝트에서 이메일도 수집하고 있는지 확인 요청.

## 확인 결과
1. **로그인 계정 이메일 (`users.email_enc`)**
   - `server/youniya_api/routers/auth.py` (`email_of`, `_session_for`): Apple/Google 로그인 시 ID 토큰의 `email` 클레임을 추출해 Fernet 암호화(`DATA_ENCRYPTION_KEY`)하여 `users.email_enc` 컬럼에 저장함.
   - 목적: **코인 소멸 예정 안내 이메일 발송 전용** (`web/privacy.html` 1조·2조 및 개정 이력에 명시).
   - 관리자 콘솔(`admin_ops.py`)의 별지기 목록/상세 조회에서는 개인정보 보호 원칙상 `users.email_enc`를 복호화해 노출하지 않고 `#번호(keeper_no)`와 `nickname`만 표시함.
2. **1:1 문의 이메일 (`inquiries.email_enc`)**
   - 사용자가 문의하기(`POST /v1/inquiries`) 작성 시 답장받을 이메일을 입력하면 암호화해 `inquiries.email_enc`에 저장하며, 관리자 콘솔에서는 마스킹된 형태(`email_masked`)로만 보이고 답장 발송 시에만 복호화해 Resend로 전송함.
3. **운영자 계정 이메일 (`operators.email`)**
   - 관리자 콘솔 로그인용 운영자 테이블(`operators`)에는 평문 이메일(`zhwan85@gmail.com`)이 저장됨.
