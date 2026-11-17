# 웹 초대 계정 로그인 (Web Dev 세션 acf73f, 2026-11-17)

- 요청: 토스 심사용 appreview(초대 계정)로 웹 로그인 → 웹에 02-1 초대 계정으로 로그인 추가 (사용자 선택 1번)
- 브랜치: feat/web-v11 (운영 웹앱의 출처), worktree ../youniya-webv11
- 변경: /login 하단 '초대 계정으로 로그인' 링크, /login/invite (아이디·비밀번호·보기·오류·로그인·취소, iOS InviteLoginSheet 문구), Server Action → POST /v1/auth/invite, 성공 시 /welcome 또는 /
- 확인: tsc·eslint 통과. 로컬 API(scratch SQLite, INVITE_LOGIN=1, 로컬 테스트 초대 계정)로 틀린 비밀번호 → 오류 문구·입력 유지, 맞는 비밀번호 → /welcome. 운영 API /v1/auth/invite는 401(켜져 있음).
- 못 본 것: 390px 너비 화면
