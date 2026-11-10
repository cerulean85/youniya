# 별 탄생 모양 · 별빛 받기 그만두기 (FIGMA 요청, 기획서 20장)

- 커밋 656aafa · 빌드 11 업로드(사용자 승인). 망원경 파일 삭제는 Web 4d9b02a에 함께 들어감.
- StarAnalysis.shape: 서버 analysis.shape {points, sharpness}. 글로 꼭짓점을 정하던 StarShapeSpec(star:) 삭제. 목업만 61-1 규칙을 흉내 냄.
- StarBirthView(61–64): 0.3/0.8/1.1–1.7초. 셋째 장면은 보라 원 안의 반투명한 모양, 넷째 장면은 마음 색의 선명한 모양. 모양이 없으면 예전 금색 원, 별빛 없는 별은 작은 마음 색 원. 동작 줄이기는 마지막 장면만.
- PrismAnalysisView 06-1: 8초 뒤 문구가 바뀌고 Ghost 그만두기가 나옴. 누르면 06-2(별 상세와 토스트).
- stopStarlight: id가 있는 별은 임시 POST /v1/stars/{id}/starlight/cancel(Web과 같음). 새 별은 API 계약을 기다림(nil, "그만두지 못했어요" 토스트).
- 별빛 받기 요청만 timeout 90초(AppModel.starlightTimeout, API 값 대기). 나머지는 20초.
- 디버그 화면 63, 64, 6-1 추가. 시뮬레이터에서 63, 64, 06-1, 06-2 확인. 커밋 안 함.

## API 계약 반영 (ad4a0f0)
- 별빛 받기마다 attempt_id(UUID 소문자): POST /v1/stars는 별빛 받기일 때만, /v1/stars/{id}/float는 본문에 넣음(/float가 attempt_id를 받는지 API에 확인 요청).
- 그만두기: POST /v1/starlight/attempts/{id}/cancel. star가 있으면 바로 12-1. 없으면 원래 요청의 409 starlight_cancelled star_id로 연다. 404면 아무것도 쓰지 않은 것으로 봄.
- 60초가 지나거나 연결이 끊기면(offline) 그만두기를 자동으로 보냄. 시간 제한은 별빛 받기만 60초, 나머지는 20초.
- ServerStar: starlight_cancelled, shape(analysis.shape가 없을 때 대신 씀).
- 개발 서버 라우트 확인: cancel 401(있음), 없는 경로 404. 실제 그만두기는 로그인 토큰이 없어 못 해 봄.

## 운영 배포 후 (965e932)
- 운영에 /v1/stars/{id}/starlight, /v1/starlight/attempts/{id}/cancel이 있음을 확인(인증 없이 401, 없는 경로 404).
- 있는 별의 별빛 받기를 /float에서 /starlight로, 새 별 mode를 float/keep에서 lit/unlit로 바꿈(계약대로).

## 그만두기 경쟁 상태 (Web 9845197과 같은 문제)
- 그만두기를 누르는 순간 stopTask를 만들고, 원래 별빛 받기 응답은 성공이든 오류든 stopTask 결과를 기다림.
- 그만두기 성공: 원래 응답은 무시하고 그만두기 응답의 별, 또는 원래 별 id나 409 star_id로 12-1을 연다. 그만두기 실패(cancel_too_late 등): 원래 응답대로 진행한다.
- /float→/starlight, mode lit/unlit, already_lit 처리. 빌드 통과. 실제 서버로는 시험하지 못함.

## 홈 → '오늘' (FIGMA 요청, 기획서 21장, 사용자 승인 2026-11-10)
- 탭바 첫 탭 '밤하늘' → '오늘' (SkyTabBar), 03/04 제목 '나의 밤하늘' → '오늘' (SkyHeader).
- 홈의 이번 달 별자리 카드(그림·진행 막대)를 빼고 최근 별 아래 맨 끝에 한 줄 링크 MonthConstellationLink (Figma 554:14661): '이번 달 별자리 · N / M 자리 채움' + '별자리 보기 ›', itemCard 배경·테두리, 좌우 16·위아래 14.
- 122 버튼 '밤하늘로 돌아가기' → '오늘로 돌아가기'.
- 로그인·설정·테마·알림·별지기 페이지의 '밤하늘'은 그대로.
- Debug 빌드, 시뮬레이터 04 확인. 커밋·업로드 안 함(사용자 승인 대기).
