# API 연동 1단계와 서버가 알려 준 앱 버그 (2026-11-06)

- 요청: "진행해주세요". 순서는 ① 그동안의 변경 커밋, ② 서버가 알려 준 앱 버그 두 가지, ③ 연동 1단계.
- 서버: home-desktop의 "API DEV Session"(youniya-81)이 만든 FastAPI. 주소는 `http://100.126.111.107:8000`(Tailscale)이다.

## 1. 커밋
- `aee7c38` 서랍 헤더, 격자 아이콘, 알림 권한, 05·06 문구
  - 처음 커밋은 74afb6e였다. 서버 커밋 a5f7400 위로 rebase하면서 해시가 바뀌었다.

## 2. 서버가 알려 준 앱 버그
- **초신성 기준:** `StarAnalysis.isSupernova`를 별빛 700 이상에서 900 이상으로 바꿨다. Figma와 서버가 900이다.
- **개인정보 가리기(20 공유 전 확인)**
  - 문제: 조사가 붙은 전화번호("010-1234-5678로")와 장소("강남역에서")를 가리지 못했다.
  - 원인: `\b`가 한글을 단어 글자로 본다.
  - 수정: `PrivacyScan`이 서버 `privacy.py`와 같은 패턴을 쓰게 했다. 숫자 앞뒤 확인과 장소 뒤 조사를 넣었다.
  - Swift `Regex`는 앞쪽 확인(lookbehind)을 지원하지 않아서 `NSRegularExpression`으로 바꿨다.
  - 확인: 문장 5개로 서버 Python 결과와 비교했다. 가린 결과와 개수가 모두 같다.

## 3. 연동 1단계
- **`App/API/APIClient.swift`** (actor)
  - JSON은 snake_case를 자동으로 바꾼다. 날짜는 Python isoformat(마이크로초 포함)을 읽는다.
  - Bearer 토큰과 `X-App-Version`을 붙인다.
  - 401 `token_expired`가 오면 refresh를 한 번 하고 다시 보낸다. 동시에 여러 요청이 와도 refresh는 한 번만 한다. 새 refresh 토큰은 항상 저장한다.
  - 에러는 `{"error":{code,message,until}}`을 `APIError`로 바꾼다.
- **`App/API/TokenStore.swift`:** 세션을 키체인에 저장한다(이 기기 전용, 첫 잠금 해제 후).
- **AppModel**
  - `useLiveAPI`: 목업과 실제 서버를 오가는 스위치. 저장되고, 서랍 개발용 "서버: 목업 / 실제 API"로 바꾼다. 서버 세션 없이 실제 API로 바꾸면 로그인 화면으로 간다.
  - 로그인(02): 실제 API에서는 `/v1/auth/dev`를 쓴다(이름 `devLoginName`, 기본 "ios-dev"). Apple/Google은 TODO다.
  - 가입 동의(11): `/v1/me/consent`
  - 로그아웃: `/v1/auth/logout`
  - 계정 삭제(91): `DELETE /v1/me`를 먼저 하고 기기 데이터를 지운다.
  - 실행할 때와 로그인할 때 `/v1/me`로 동의 여부, 마케팅 수신, 코인, 첫 망원경 무료 여부를 가져온다.
  - `handle(_:)`가 에러를 화면으로 잇는다: 401은 39, 426은 40, 503은 41(종료 시각 표시), `consent_required`는 11, 나머지는 서버 문구를 토스트로 보여 준다(429 포함).
- **ATS:** Debug 빌드만 `Config/Debug-Info.plist`로 HTTP를 허용했다.
  - Tailscale IP(100.x)는 `NSAllowsLocalNetworking`로 풀리지 않았다(-1022). ATS 예외는 IP를 지정할 수 없어서 Debug에만 `NSAllowsArbitraryLoads`를 넣었다.
  - Release는 ATS를 그대로 둔다. TODO: 서버에 HTTPS 주소가 생기면 지운다.
- **개발용 실행 인자:** `-useLiveAPI YES`, `-autoDevSignIn YES`, `-devLoginName 이름`, `-apiBaseURL URL`, `-appVersionOverride 1.0.0`

## 확인 (iPhone 17)
- 처음에는 ATS에 막혔다. Debug 예외를 넣은 뒤 통신이 됐다.
- 서버 최소 버전이 1.0.0이라 426이 왔고, 40 화면이 떴다. API DEV Session이 개발 서버 최소 버전을 0.1로 낮췄다(server main 89bd57d).
- 개발용 로그인 → 서버가 동의 필요로 답해 11 화면이 떴다.
- 같은 계정으로 서버에 동의를 보낸 뒤 앱을 다시 열었다. `/v1/me`를 읽고 홈으로 들어갔다.

## 아직 하지 않은 것
- 별, 망원경, 코인, 광장, 성운 데이터는 아직 기기 목업이다(2단계부터).
- 11 화면에서 직접 동의 버튼을 누르는 건 시뮬레이터 조작 도구가 끊겨 보지 못했다. 같은 API를 curl로 확인했다.
- 음수 코인 표시, PDF 내보내기는 해당 기능을 연동할 때 넣는다.
