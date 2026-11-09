# iOS: Debug 기본 서버를 home-desktop으로 되돌림

- 요청: 사용자가 서버 개발을 다시 home-desktop의 API Dev Session에서 하기로 했다(FIGMA 세션이 전달).
- APIConfig.defaultBaseURL(DEBUG)
  - "http://100.117.103.2:8001"을 "http://100.126.111.107:8000"으로 바꿨다. e7d5e9a 이전 값이다.
  - 주석도 home-desktop으로 고쳤다.
- 그대로 둔 것
  - "다른 서버의 세션이면 로그아웃" 처리와 401 → 39 처리
  - Release 주소(youniya-api.dycdyp.com)
- 확인
  - Debug 빌드 성공.
  - 이 Mac에서 home-desktop 서버가 응답한다(Tailscale). 시뮬레이터도 같은 네트워크를 쓴다.
  - -useLiveAPI YES로 실행했더니, 저장된 세션이 다른 서버 것이라 01 로그인 화면으로 시작했다(의도한 동작).
  - 새 개발 DB에 계정을 만드는 개발 로그인은 하지 않았다.
- home-desktop 개발 DB는 오늘 만든 Neon dev 브랜치(운영 복사본)다. MacBook 개발 서버의 데이터는 없다.
