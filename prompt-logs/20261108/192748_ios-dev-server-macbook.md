# 개발 서버를 맥북으로 옮김 (2026-11-08)

- 요청: "기존 서버 세션이 꺼져서 macbook에 API Dev Session에서 개발할꺼야"
- 예전 home-desktop 개발 서버(`100.126.111.107:8000`)는 응답이 없다.
- 새 API Dev Session(이 맥북): 개발 서버 포트 8001. 8000은 Antigravity, 8077은 Web 세션이 쓴다.
  - 시뮬레이터 `http://localhost:8001`, 휴대폰 `http://100.117.103.2:8001`(맥북 Tailscale)
  - 켜 둔 설정: DEV_LOGIN, TRUST_PURCHASES, MIN_APP_VERSION 0.1, MEMBERSHIP=1, INVITE_LOGIN=1
  - 아직 다른 점: DB가 새 로컬 SQLite라 예전 테스트 계정이 없다. GEMINI_API_KEY가 없어 별 분석·망원경 같은 AI가 실패한다. 둘 다 사용자에게 Neon dev URL과 키를 받아야 한다.

## 앱
- **Debug 기본 주소:** `http://100.117.103.2:8001`. 이 Mac의 시뮬레이터와 Tailscale 휴대폰 모두에서 닿는다. `-apiBaseURL`로 바꿀 수 있는 것은 그대로다.
- **서버가 바뀌면 다시 로그인**
  - 로그인할 때 그 서버 주소를 기억한다(`signedInBaseURL`).
  - 앱을 켤 때 지금 주소와 다르면 로그아웃 상태로 시작한다. 예전 서버의 별 캐시와 토큰도 지운다.
  - Debug에서는 주소가 기록되기 전의 로그인도 바뀐 것으로 본다(이번 이동). Release는 기록이 있을 때만 비교한다.
  - 이 처리가 없을 때는 예전 서버 토큰으로 새 서버에 붙으면서 예전 별 하나만 보이고, 동의 화면이 나오지 않았다.

## 확인
- 두 주소 모두 /docs 200, POST /v1/auth/dev 성공
- 시뮬레이터에서 실제 API로 실행하니 새 서버의 새 계정이라 11 가입 동의 화면이 나온다.

## 같은 주소에서 서버 키가 바뀔 때 (API 세션 안내)
- Neon dev로 바꾸면 서버의 JWT_SECRET과 DATA_ENCRYPTION_KEY도 바뀐다. 지금 토큰은 서명이 맞지 않아 401 `unauthorized`("로그인이 필요해요.")를 받는다. 개발 서버에 잘못된 토큰을 보내 이 응답을 확인했다.
- 앱은 이 코드를 공통 토스트로만 처리해서, 로그인된 상태로 예전 화면이 남았다.
- 이제 `unauthorized`도 `token_expired`처럼 39 "다시 로그인해 주세요"로 처리한다. 39의 「로그인」은 로그아웃하고 02로 돌아간다.
