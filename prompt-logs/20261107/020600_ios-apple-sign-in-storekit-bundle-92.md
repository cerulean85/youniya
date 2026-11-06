# Sign in with Apple, StoreKit 2, 번들 ID, 92 문구 (2026-11-07)

- 요청: "변경 커밋하고, 남은 큰 일을 해줘. 확인하지 못한 건 어떻게 하라고?"
- 지난 변경을 커밋했다(`8c41c6a`).
- 남은 큰 일은 운영 출시에 꼭 필요한 것부터 했다: Apple 로그인, StoreKit 충전. 우주 광장·성운 연결은 다음이다.

## 번들 ID 변경 (API DEV Session 전달, 사용자 확인)
- `PRODUCT_BUNDLE_IDENTIFIER`를 `com.youniya.app`에서 `com.dycdyp.youniya`로 바꿨다. Apple Developer와 App Store Connect에 등록된 ID다.
- 그대로 두면 Apple 로그인(aud 불일치)과 결제 검증(bundleId 불일치)이 모두 실패한다.
- 시뮬레이터에는 예전 번들의 앱이 따로 남는다. 새 앱은 로그인과 데이터를 처음부터 시작한다.

## Sign in with Apple (`App/API/AppleSignIn.swift`)
- `ASAuthorizationAppleIDProvider`로 identityToken을 받아 `POST /v1/auth/apple`로 보낸다. 이름과 이메일은 요청하지 않는다.
- 시트를 닫으면 02에 그대로 남는다.
- 권한 파일에 `com.apple.developer.applesignin`을 추가했다.
- Debug 빌드는 시뮬레이터 편의상 개발용 로그인을 쓴다. `-realSignIn YES`로 실행하면 Apple 로그인을 쓴다.
- **Google:** 아직 없다. Google Cloud OAuth 클라이언트와 SDK가 필요하다. 실제 API에서 누르면 "Google 로그인은 곧 열려요. 지금은 Apple로 계속해 주세요." 토스트를 띄운다.

## 출시 빌드 정리
- Release는 항상 실제 API를 쓴다(`useLiveAPI` 고정, 서버 전환 불가).
- 서랍의 개발용 메뉴는 Debug에서만 보인다.

## StoreKit 2 (`App/API/StoreKitCoins.swift`)
- 상품 ID는 서버와 같은 `coin_50`, `coin_120`, `coin_300`(소모품)이다. App Store Connect에도 같은 ID로 만들어야 한다.
- 구매 흐름
  1. `appAccountToken`에 `/v1/me` id를 넣어 산다.
  2. `POST /v1/coins/purchases {signed_transaction, consumption_consent: true}`를 보낸다.
  3. 200을 받으면 `finish()`한다.
- 결과에 따른 처리
  - 취소: 아무것도 하지 않는다.
  - 승인 대기 또는 확인 실패: 38을 띄운다.
  - 서버 오류: finish하지 않고 남겨 둔다.
- 앱을 실행할 때 `Transaction.unfinished`와 `.updates`를 듣고, 아직 서버에 반영되지 않은 결제를 다시 보낸다.
- Debug는 개발 서버의 테스트 충전을 쓴다. `-realPurchases YES`면 StoreKit을 쓴다. Xcode StoreKit 설정 파일로 산 결제는 Apple 서명이 아니라 서버를 통과하지 못해서 설정 파일은 넣지 않았다.

## 92 모든 공유 거두기 (Figma 154:336, FIGMA DESIGN Session 전달)
- 제목: "나눈 별과 성운을 모두 거둘까요?"
- 본문: "우주 광장에서 나눈 별 N개와 성운 M개를 거둬요. 그동안 받은 공명과 별빛 한 줄은 그대로 간직돼요. 언제든 다시 나눌 수 있어요."
  - 한쪽이 0개면 그 부분을 뺀다.
  - 실제 API에서는 `GET /v1/me/shares`의 stars·nebulae 길이를 쓴다.
- "모두 거두기"는 실제 API에서 `DELETE /v1/me/shares`다. 목업에서는 그린 성운의 공유도 함께 거둔다.

## 확인
- Debug와 Release(시뮬레이터) 빌드가 모두 성공했다.
- 새 번들 ID(`com.dycdyp.youniya`)로 설치해 개발 서버에 로그인했고, 설정 화면이 열린다.

## 확인하지 않은 것
- Apple 로그인 실제 동작: Apple ID로 로그인한 기기나 시뮬레이터, `-realSignIn YES`가 필요하다.
- StoreKit 실제 구매: App Store Connect 상품, Sandbox 계정, 실기기 또는 TestFlight가 필요하다.
- 92 시트 화면: 탭을 할 수 없어 띄워 보지 못했다.
