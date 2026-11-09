# iOS 2단계 2C: 83 별자리 이야기(월별), 81 문구, 예전 성운 화면 정리

- 요청: 사용자가 2단계를 이어서 "진행해줘"라고 했다.
- 83 NebulaStoryView
  - month 값을 받는다(Route.constellationStory("YYYY-MM")).
  - 제목은 「11월 · 페가수스자리 이야기」, 상단 바는 「별자리 이야기」다.
  - 그달 별(별빛 받은 별과 없는 별 모두)의 마지막 문장을 시간순으로 엮는다.
  - 라이브는 GET /v1/constellations/{month}/story를 쓴다.
  - 「✦ 표시는 문장 사이를 잇는 자리예요.」를 다시 넣었다(Figma 83).
  - 08-3과 70의 칩은 보고 있는 달의 이야기를 연다. 토스트는 「별자리 이야기를 엮어 두었어요」다.
- 81 나의 은하수: 설명을 Figma 문구로 바꿨다. 달을 넘는 별 잇기의 은빛 점선은 3단계에서 넣는다.
- 정리(16.3)
  - 지운 경로: myNebulaZoom(예전 77), nebulaStory, drawNebula(51–55·84·85), reshapeNebula, growth / moments / stages(65·66·86), 71 경로와 관련 디버그
  - 지운 구조체: NebulaView(예전 08), MyNebulaZoomView, NebulaGrowthView, GrowthMomentsView, GrowthStagesView, NebulaDrawingFlow, FloatNebulaSheet, ConnectStage, SilhouetteMini, SilhouettePreview, NameField, StarStage, StarTooltip, ZoomPanCanvas, NebulaInfoTable, NebulaArt, HeroConstellation, NebulaDetailSkeleton
  - 아무 데서도 참조하지 않는 구조체가 없는 것을 확인했다.
  - DrawnNebula, GuestStar, NebulaSilhouette 같은 모델과 API는 남겼다(광장 성운 72 / 73 / 74와 함께 5단계에서 정리한다).
  - 디버그 지원 목록에서 51 / 65 / 66 / 71 / 71-1 / 84-1 / 86 / 86-1 / 112를 뺐다.
- 확인: Debug 빌드 성공. 83과 81을 캡처했다.
