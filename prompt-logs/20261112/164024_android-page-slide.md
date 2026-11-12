# 화면 전환 좌우 슬라이드 (Android)

## 요청
"좌우 슬라이드 모션이 구현 안 되어 있넹?"

## 원인
- iOS MainView는 쌓인 화면마다 `.transition(.move(edge: .trailing))`, easeInOut 0.32초.
- Android MainScreen은 navStack 맨 위 화면만 그려서, 화면이 움직임 없이 바뀜.

## 변경
- MainScreen의 화면 분기를 AnimatedContent로 감쌈.
  - 열 때: 새 화면이 오른쪽에서 들어오고 아래 화면은 그대로.
  - 뒤로: 위 화면이 오른쪽으로 빠지고, 깊은 화면이 위에 그려지도록 z-index 지정.
  - 동작 줄이기 설정이면 바로 바뀜.
- 커밋 6e67de7.

## 확인
- 에뮬레이터 애니메이션 속도를 10배로 늦춰, 여는 중간과 뒤로 가는 중간 장면을 찍어 확인. 속도는 1배로 되돌림.
- 갤럭시 S25(운영 서버용 디버그 빌드)에 설치.
