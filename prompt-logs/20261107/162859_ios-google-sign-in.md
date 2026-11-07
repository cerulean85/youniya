# Google 로그인 연결 (2026-11-07)

- 요청: "올려줘"(문장 고르기 push, 완료 `76a5208`) 뒤 이어서 Google 로그인. 앞서 사용자가 "ID는 iOS 유형이 맞아. 그 값을 사용하면 돼."라고 했다.

## 구현 (새 파일 `App/API/GoogleSignIn.swift`)
- SDK를 넣지 않고 시스템 웹 로그인 시트(`ASWebAuthenticationSession`)로 Google OAuth를 연다.
  - 인증 코드 + PKCE(S256)를 쓴다. iOS 유형 클라이언트라 client secret이 없다.
  - redirect는 역순 클라이언트 ID 스킴 `com.googleusercontent.apps.<id>:/oauthredirect`다. 웹 세션의 콜백 스킴으로 받아서 Info.plist URL 스킴 등록은 필요 없다.
  - scope는 `openid`만 쓴다. 서버는 `sub`만 쓰고 이름이나 이메일은 받지 않는다.
  - `prefersEphemeralWebBrowserSession`이라 Safari 쿠키를 나누지 않는다. `prompt=select_account`로 계정을 고르게 한다.
  - state를 확인한다.
- 받은 코드를 `https://oauth2.googleapis.com/token`에서 바꿔 ID 토큰만 쓴다. 서버 `POST /v1/auth/google {id_token}`이 GOOGLE_CLIENT_IDS로 audience를 확인한다.
- 클라이언트 ID는 `server/.env.production`의 `GOOGLE_CLIENT_IDS` 값을 코드 상수로 넣었다. 파일은 읽기만 했고, 클라이언트 ID는 앱에 들어가는 공개 값이다.
- **오류 처리**
  - 시트를 닫거나 Google 화면에서 거부하면 아무것도 띄우지 않고 02에 머문다.
  - 그 밖의 실패는 "Google 로그인을 마치지 못했어요. 다시 시도해 주세요." 토스트를 띄운다.
- `AppModel.signIn(with: .google)`의 "곧 열려요" 안내를 실제 로그인으로 바꿨다.
- Debug 빌드는 여전히 개발 서버 로그인(`/v1/auth/dev`)을 쓴다. `-realSignIn YES`를 주면 Apple·Google 로그인을 쓴다.

## 확인
- 빌드 통과
- curl로 Google 인증 주소를 열어 봤다.
  - 이 클라이언트 ID와 redirect: 계정 입력 화면(`/v3/signin/identifier`)으로 넘어간다.
  - 없는 ID: `invalid_client`로 거절된다.

## 확인하지 않은 것
- 시뮬레이터에서 실제 Google 계정으로 로그인하는 흐름은 탭과 계정 입력이 필요해 보지 못했다.
- 개발 서버(Tailscale)에 GOOGLE_CLIENT_IDS가 있는지는 확인하지 않았다. 운영 서버에는 있다.

## 실제 로그인 확인
- 16:29:05 시뮬레이터(Mac): 개발 서버가 401 invalid_id_token으로 거절했다. 그때는 이유를 로그에 남기지 않아 원인을 알 수 없다.
  - API 세션이 서버 시계를 확인했다. NTP로 맞춰져 있고 Google 서명 키도 받아 온다.
  - API 세션이 거절 이유를 로그에 남기게 했고(`599b447`), 토큰 시각 확인에 leeway=60을 줬다(`c7db6ff`).
- 16:39:31 iPhone(Tailscale 켠 뒤): `POST /v1/auth/google` 200. 기기에서 Google 로그인이 된다.
- 기기에서 Debug 빌드로 시험하려면 iPhone에 Tailscale을 켜야 한다. 개발 서버가 Tailscale 주소다.
