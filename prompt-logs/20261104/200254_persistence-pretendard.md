# 별 저장 기능 추가, Noto Sans KR → Pretendard 교체

- 일시: 2026-11-04 20:02
- 요청: "저장 기능 추가하고, 글꼴은 Noto Sans KR을 Pretendard로 변경해줘."

## 1. 글꼴: Noto Sans KR → Pretendard
- 공식 저장소(orioncactus/pretendard, OFL)에서 Pretendard Light / Regular / Medium(.otf)을 받았다.
- `NotoSansKR-*.otf` 3개를 지우고 Pretendard 3개를 넣었다.
- `Theme.swift`의 Sans 텍스트 스타일을 Pretendard로 바꿨다.
  - 대상: metric, bodyM, bodyS, labelM, labelS, caption
- 제목·일기 본문의 Noto Serif KR은 그대로 둔다.
- 줄 간격: 이전에는 Noto 기준 비율(1.448em)을 고정값으로 썼다.
  - Pretendard는 기본 줄 높이가 더 작다(약 1.19em).
  - 이제 글꼴마다 실제 줄 높이(`UIFont.lineHeight`)를 재서 Figma 줄 높이까지 채운다.

## 2. 저장 기능
- `LocalStore`를 추가했다.
  - Application Support/Youniya/ 아래에 JSON 파일로 저장한다.
  - 파일 보호 옵션 `.completeFileProtection`을 쓴다. 기기가 잠기면 읽을 수 없다.
  - `.atomic` 쓰기라 저장 도중 앱이 꺼져도 기존 파일이 깨지지 않는다.
- `stars.json`: 별 목록. 바뀔 때마다 저장하고 앱을 켤 때 불러온다.
- `draft.json`: 05 작성 중인 초안.
  - 이전에는 UserDefaults에 저장했다. 일기 내용이라 파일로 옮겼다.
  - 예전 UserDefaults 초안은 한 번 옮긴 뒤 지운다.
- 파일이 깨져 읽을 수 없으면 `*.corrupt-<시각>.json`으로 옮겨 두고 빈 목록으로 시작한다. 덮어써서 잃지 않게 하려는 것이다.
- `StarItem`, `StarAnalysis`가 Codable이 됐다. `id`는 저장된 값을 유지하도록 `var`로 바꿨다.
- 로그아웃 동작을 바꿨다.
  - 이전에는 로그아웃할 때 별을 지웠다.
  - 서버 사본이 아직 없어서 지우면 일기가 사라지므로, 이제 로그아웃해도 별은 남는다.
  - 지우려면 드로어의 "별 모두 비우기(개발용)"를 쓴다.

## 검증 (iPhone 17 Pro 시뮬레이터)
- 빌드 성공, 경고 없음.
- 드로어에서 "샘플 별 채우기" → 앱 강제 종료 → `stars.json`에 별 4개가 저장된 것을 확인했다.
- 다시 실행하니 04 홈에 별 4개가 그대로 표시됐다.
- 화면 캡처로 Pretendard 적용을 확인했다 (부제, 버튼, 배지, 날짜).

## 남은 일
- 서버 동기화나 백업은 없다. 앱을 지우면 데이터도 지워진다.
- 기기 잠금 상태에서 백그라운드로 쓰기가 필요해지면 파일 보호 수준을 다시 정해야 한다.
