# iOS: 서사 다듬기 기능째 제거

- 요청: FIGMA 세션이 사용자 결정을 전달함 (2026-11-08). 83 성운 이야기에는 문장만 엮어 무료로 저장하는 기능만 남긴다.
- 83 NebulaStoryView
  - 다듬기 버튼, 이어 주는 말, ✦ 안내 문구, 코인 부족 처리를 지웠다.
  - 남은 버튼은 "문장만 엮어 두기" 하나이고, primary 스타일로 바꿨다.
  - ✦ 구분 기호는 그대로 둔다.
  - onNeedCoins 콜백도 없앴다(MainView).
- 84-2 모양 바꾸기
  - 안내 둘째 줄과 "다듬은 이야기가 지워져요" 확인 창을 지웠다.
  - 필요 없어진 newStarIDs도 지웠다.
- StoryAPI: polishStory, ServerStory의 bridges/polished/coins를 지웠다.
- AppModel
  - storyPolished, storyPolishCost, usedFreePolish, serverFreePolish, isPolishFree, memberHasStory를 지웠다.
  - memberLeftToday에서 story를 뺐고, applyFreeUses의 story 인자도 뺐다.
- CoinsAPI의 freeStory, MembershipAPI의 storyLeftToday를 지웠다.
- MembershipScreens 혜택 목록과 SettingsPages 이용약관 제4조에서 서사 다듬기를 뺐다.
- 코인 사용 내역은 서버가 준 제목을 그대로 보여 주므로, 과거 "서사 다듬기" 항목도 그대로 남는다.
- 확인: Debug 빌드 성공. `-debugScreen 83`과 `M1`을 캡처해 확인했다.
