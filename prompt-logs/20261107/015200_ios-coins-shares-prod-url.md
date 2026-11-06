# Figma·API 변경 반영: 코인, 나눈 성운, 운영 주소 (2026-11-07)

- 요청: FIGMA DESIGN Session이 사용자 지시 "앱에 반영해"를 전했다. 그동안 공유된 Figma(17·18·31·95·120·121·122·28·46)와 API 변경을 iOS에 반영한다.
- 120·122·28·46은 이미 넣었다(`018f6f8`, rebase 뒤 `e65b707`). 이번에는 나머지를 했다.

## 1. 빌드별 서버 주소 (`APIConfig.defaultBaseURL`)
- Debug: 개발 서버 `http://100.126.111.107:8000`. 개발용 로그인과 테스트 충전이 되고, 최소 버전은 0.1이다.
- Release/TestFlight: 운영 `https://youniya-api.dycdyp.com`. 최소 버전 1.0.0, 개발용 로그인 없음, StoreKit 검증이 필요하다.
- Release 빌드에는 HTTP 예외(ATS)가 들어가지 않는 것을 확인했다(Debug-Info.plist는 Debug에만).
- `-apiBaseURL`로 바꿀 수 있다.

## 2. 코인 (새 파일 `App/API/CoinsAPI.swift`)
- `loadCoins()`: `GET /v1/coins`(잔액, 첫 망원경 무료)와 `GET /v1/coins/history`
  - 로그인할 때, 28 충전 화면, 33 내역 화면을 열 때 부른다.
- **121:** `CoinEntry.kind`(purchase·spend·refund)를 추가했다. kind가 refund면 제목을 "충전 취소 · App Store 환불"로 보여 준다. 0개를 거둔 환불 행은 서버가 빼서 준다.
- **28 충전(실제 API):** `POST /v1/coins/purchases`에 `consumption_consent: true`를 보낸다.
  - Debug는 개발 서버의 테스트 충전을 쓴다(`product_id: coin_N`, 고유 `transaction_id`).
  - Release는 StoreKit 2 연결 전이라 서명 없이 보내고, 서버가 확인하지 못해 38(결제가 끝나지 않았어요)이 뜬다. TODO: StoreKit 2
  - 성공하면 102(충전이 끝났어요)가 뜬다.
- 목업과 실제 API의 코인을 따로 저장한다(`coins`/`coins-live`, `coinHistory`/`coinHistory-live`). 앞서 서버 값이 목업 모드에 남던 문제가 풀렸다.

## 3. 17·18 나눈 성운
- 실제 API에서는 `GET /v1/me/shares`의 `stars`로 목록을 만든다.
  - 행: 제목 · 쓴 시각(KST) · 별빛
  - 안내 문구의 N은 목록 길이다. 빈 배열이면 18이다.
- "광장에서 거두기"는 `DELETE /v1/stars/{star_id}/share`다. 성공하면 목록에서 빼고 토스트를 띄운다.
- 목업 모드는 전처럼 기기의 공유 표시로 거른다.

## 4. 31·95 문구
- 31은 Figma와 앱 문구(4개 섹션, 시행일)가 같다.
- 95 시트 문구는 앱 코드를 바탕으로 그린 화면이라 바꿀 것이 없다.

## 확인 (iPhone 17, Debug, 실제 API)
- 앱에 저장된 로그인이 서버에서 더 이상 유효하지 않아 39(다시 로그인해 주세요)가 떴다(서버 DB 이동 후). 의도한 처리다.
- 개발용 로그인으로 다시 들어가 28을 열었다. curl로 테스트 충전한 120개가 "지금 코인 120개"로 보인다.
- Release 빌드가 되고, Info.plist에 ATS 예외가 없다.

## 확인하지 않은 것
- 앱에서 직접 충전하기, 내역 121, 나눈 성운 거두기는 탭을 할 수 없어 보지 못했다. 같은 API를 curl로 확인했다.
- 마음 망원경(무료 1회, 30코인 차감, 리포트)은 아직 목업이다. 실제 API 모드에서 망원경을 켜면 기기 잔액만 줄어든다. 다음 단계에서 옮긴다.
- 운영 서버로는 아직 로그인할 수 없다(Sign in with Apple 연결 필요).
