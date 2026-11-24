# Zoho Mail DNS 매핑 준비 (dycdyp.com)
- Zoho 화면에서 요구 레코드 확인: MX 3개(mx/mx2/mx3.zoho.com 10/20/50), SPF TXT @, DKIM zmail._domainkey, ZeptoMail CNAME bounce-zem, DKIM 1905821._domainkey.
- AWS CLI(default·dycdyp 프로필, IAM user kkennib)는 Route 53 권한 없음(AccessDenied).
- 공개 DNS(8.8.8.8): 루트 MX가 Google Workspace(aspmx.l.google.com 외 4개), 루트 TXT는 zoho-verification 하나. 나머지 Zoho 레코드 이름은 비어 있음.
- 결정 대기: Google MX를 Zoho로 바꿀지. 아직 아무 레코드도 만들지 않음.
- 사용자 "Zoho로 바꿔" → Route 53 콘솔에서 MX 교체, 루트 TXT에 SPF 추가, DKIM 2·CNAME 1 새로 만듦. Zoho '모든 레코드 확인됨'. 기록: runs/server_setup.md.
