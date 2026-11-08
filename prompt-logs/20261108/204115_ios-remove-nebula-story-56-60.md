# iOS: 56–60 성운 스토리 제거

- 요청: FIGMA 세션이 사용자 결정을 전달함 (2026-11-08). 56~60 성운 스토리는 필요 없으니 뺀다.
- 지운 것
  - `Screens/StoryScreens.swift`: NebulaStoryIntroView. 파일 전체를 지웠다.
  - `MainView`: 성운 탭에 처음 들어올 때 띄우던 오버레이
  - `AppModel.hasSeenNebulaStory`: 선언, 불러오기, 탈퇴 시 초기화
  - `DebugScreen`: "56" 처리. 주석도 고쳤다.
- 그대로 둔 것
  - `-debugScreen 56`은 08 성운 탭을 연다.
  - 83 NebulaStoryView는 다른 기능이라 그대로 둔다.
- 확인: Debug 빌드 성공. `-debugScreen 56`으로 실행하면 인트로 없이 08이 열린다.
- 주의: StoryScreens.swift 삭제는 내가 스테이징해 둔 상태였다. 그 사이 API 세션이 커밋 fba754f를 만들면서 이 삭제가 함께 들어갔고, 이미 푸시됐다. 나머지 세 파일은 아직 커밋하지 않았다. 지금 origin/main은 iOS 빌드가 깨진 상태다.
