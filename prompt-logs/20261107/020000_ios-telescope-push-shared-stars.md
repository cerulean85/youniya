# 마음 망원경 연동, 원격 알림 등록, "나눈 별"과 122-1 (2026-11-07)

- 요청: "Push Notifications는 켜뒀어. 순서대로 진행해줘"
  1. 지난 변경을 커밋했다(`acdd88d`, rebase 뒤 `b992563`).
  2. 마음 망원경을 서버에 연결했다.
  3. 원격 알림 기기 등록을 넣었다.
- 진행 중에 FIGMA DESIGN Session이 전한 사용자 결정 두 가지도 반영했다.

## 2. 마음 망원경 (새 파일 `App/API/TelescopeAPI.swift`)
- 서버는 리포트를 만든 뒤에 코인을 차감한다(첫 회는 무료). 그래서 실제 API에서는 흐름을 이렇게 맞췄다.
  - **24 켜기:** 기기에서 코인을 빼지 않고, 첫 회 무료이거나 잔액이 30개 이상인지만 본다. 모자라면 29를 띄운다.
  - **25 스캔:** 시작할 때 `POST /v1/telescope/reports {star_ids:[id]}`를 보낸다. 별마다 한 번만 보내고(`pendingReports`), 응답이 오면 그 별에 리포트를 붙이고 잔액과 무료 여부를 갱신한다.
  - **10 리포트:** 응답을 기다리는 동안 "리포트를 만들고 있어요"를 보여 준다. 실패하면 서버 문구를 토스트로 띄운다(402 코인 부족, 502 분석 실패, 429는 120).
- **26 목록:** 로그인할 때 `GET /v1/telescope/reports`로 별 하나짜리 리포트를 가져와 각 별에 붙인다.
- **10 보관하기:** `POST /v1/telescope/reports/{id}/save`. 리포트에 서버 id(`serverID`)를 저장한다.
- 남은 일(TODO): 별 여러 개를 묶은 주간 리포트(98에서 별을 고르지 않고 켠 경우)는 붙일 별이 하나가 아니라 아직 목록에 넣지 않는다.

## 3. 원격 알림 (새 파일 `App/PushNotifications.swift`)
- **권한 파일:** `Config/Youniya.entitlements`(aps-environment development)를 넣고, 앱 타깃의 Debug·Release에 `CODE_SIGN_ENTITLEMENTS`를 연결했다. 보관(archive)할 때 Xcode가 production으로 바꾼다.
- **`AppDelegate`(`@UIApplicationDelegateAdaptor`)**
  - 기기 토큰을 받으면 `PUT /v1/me/devices {token, environment}`로 보낸다. Debug는 sandbox, Release는 production이다.
  - 앱이 열려 있을 때도 배너를 보여 준다.
  - 알림을 누르면 앱만 연다. 101과 공지 모두 따로 열 화면이 없다.
- **`PushRegistration`**
  - 로그인할 때·실행할 때(`refreshMe` 끝) 알림이 허용돼 있으면 토큰을 다시 받는다.
  - iOS 설정에서 알림이 꺼져 있으면 `DELETE /v1/me/devices/{token}`를 보낸다.
  - 로그아웃하기 전에도 등록을 지운다.
  - 설정 토글에서 처음 알림을 허용한 직후에도 등록한다.

## Figma 추가 결정 (FIGMA DESIGN Session 전달)
- **"나눈 성운" → "나눈 별":** 설정 행 제목, 17·18 위 바 제목, 라우팅 문자열과 주석을 바꿨다. 92 시트 제목("나눈 성운을 모두 거둘까요?")은 사용자 결정 대기라 그대로 뒀다.
- **122-1 리포트를 찾을 수 없음(308:13616)**
  - `NotFoundView(kind: .report)`: 망원경 아이콘, "리포트를 찾을 수 없어요", "이미 지웠거나 다른 기기에서 정리한 리포트예요.", 버튼 "리포트 목록으로"(26으로 바꿔 연다).
  - 아이콘 `iconTelescope`는 Figma Icon/telescope(12:71)를 SVG로 내보내 넣었다.
- 개발용 `-debugRoute`에 `missingReport`(122-1), `missingStar`(122)를 추가했다.

## 확인 (iPhone 17)
- 26: curl로 만든 서버 리포트가 "11월 첫째 주 · 별 1개"로 보인다.
- 원격 알림: 실제 API로 실행하니 토큰을 받았고, `PUT /v1/me/devices`가 2xx로 성공했다. 확인용 출력은 지웠다.
- 122-1 화면과 설정의 "나눈 별" 행을 띄워 봤다.

## 확인하지 않은 것
- 앱에서 직접 망원경 켜기, 스캔, 보관하기는 탭을 할 수 없어 보지 못했다.
- 실제 원격 알림 수신은 서버에 APNs 키가 아직 없어 볼 수 없다.
- 기기(실제 iPhone) 빌드의 서명과 Push 프로비저닝은 시뮬레이터에서 확인할 수 없다. Xcode에서 실제 기기로 한 번 빌드해 보면 확인된다.
