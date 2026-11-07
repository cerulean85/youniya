# 앱 버전 1.0.0 (2026-11-07)

- 요청: "응 1.0.0으로 올려줘" (TestFlight 빌드가 운영 서버를 쓰는데, 운영 서버는 1.0.0 미만이면 426 업데이트 필요를 돌려준다)
- `MARKETING_VERSION`을 Debug·Release 모두 0.1에서 1.0.0으로 올렸다. 빌드 번호(`CURRENT_PROJECT_VERSION`)는 1 그대로다.
- 개발 서버의 최소 버전은 0.1이라 Debug 빌드도 그대로 접속된다.

## 확인
- 빌드한 앱의 CFBundleShortVersionString이 1.0.0이다.
- 운영 서버 `/v1/me`
  - X-App-Version 1.0.0: 401(로그인 필요). 버전 확인은 통과한다.
  - X-App-Version 0.1: 426(업데이트 필요)

## 참고
- TestFlight에 올릴 때마다 빌드 번호를 하나씩 올려야 한다(App Store Connect가 같은 번호를 거절한다).
- `project.pbxproj`에는 Xcode가 바꾼 `INFOPLIST_FILE` 따옴표 표기도 함께 들어간다(동작은 같다).
