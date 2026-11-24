# 관리자 콘솔에서 사용자 이메일 확인 가능 여부 조회 (2026-11-24)

## 요청
- 수집된 사용자 이메일(`users.email_enc`)을 현재 관리자 콘솔(Admin)에서도 확인할 수 있는지 질문.

## 확인 결과
1. **별지기 목록/상세 (`GET /v1/admin/keepers`, `GET /v1/admin/keepers/{id}`, `admin/app/(console)/keepers/`)**
   - 현재 **확인 불가능**함. `server/youniya_api/routers/admin_ops.py`의 `_keeper_row` 및 `keeper_detail`에서 `user.email_enc`를 반환하지 않으며, 관리자 화면에서도 `#번호(no)`, `별지기 이름(nickname)`, `로그인 방식(provider)`만 표시함.
2. **1:1 문의 상세 (`GET /v1/admin/inquiries/{id}`)**
   - 문의자가 입력한 이메일만 앞뒤를 가린 마스킹 형태(`_mask_email`: 예 `zh***@gmail.com`)로 표시됨.
3. **결론**
   - DB(`users.email_enc`)에는 암호화되어 들어 있지만 현재 관리자 콘솔 UI/API에는 노출되지 않도록 막혀 있음. 필요 시 `admin_ops.py`와 `admin/app/(console)/keepers/`에 복호화(또는 마스킹) 필드를 추가하면 확인 가능.
