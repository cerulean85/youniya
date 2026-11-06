# 우주 광장 서버 연결 1부 (2026-11-07)

- 요청: "진행해줘" (우주 광장·성운 연결)
- 중간에 FIGMA DESIGN Session이 시각 검수용 실행 인자와 87 아이콘을 요청해서 먼저 처리했다(`13a747d`).

## 검수 지원 (`13a747d`)
- `-debugRoute` 값을 추가했다. 목업 데이터로 탭 없이 화면을 연다.
  - sharedStars(17), sharedStarsEmpty(18), withdrawShares(92), notificationsOff(95)
  - policyPayment(46), policyMarketing(31), coinsAgreed(28-1), coinHistoryRefund(121)
- 87: "진동"은 Icon/vibrate, "앰비언스 사운드"는 Icon/sound를 쓴다. Figma에서 SVG로 내보냈다.

## 광장 연결 (새 파일 `App/API/PlazaAPI.swift`)
- 화면은 그대로 두고 데이터 출처만 바꿨다.
  - `model.plazaStarItems`: 목업이면 샘플, 실제 API면 서버 목록
  - `model.galaxyNebulae`: 같은 방식
  - `model.lines(for:)`: 같은 방식
- **09 별 피드 · 72 성운 피드:** `GET /v1/plaza/stars?sort=new|similar`, `GET /v1/plaza/nebulae?filter=new|similar`
  - "새로 뜬 것" 순서와 "나와 결이 비슷한" 순서를 각각 받아, 화면이 쓰는 order·similarity로 바꾼다.
  - 실루엣 모양(A/B)과 72의 위치는 공유 id로 정한다.
  - 광장 탭을 열 때 불러온다.
- **공명:** `PUT/DELETE /v1/plaza/{star|nebula}/{id}/resonance`
  - 앱은 성운의 공명과 "곁에 둔"을 하나로 보여 줘서(80 컬렉션), 성운은 beside도 함께 보낸다.
  - 먼저 화면에 반영하고, 실패하면 되돌린다.
  - 불러올 때 서버의 resonated·beside 표시를 앱에 반영한다.
  - 성운 안의 별(75)은 서버에 따로 없어서 기기에만 남는다.
- **72 공명 수:** 서버는 다른 사람의 공명 수를 주지 않는다. 실제 API에서는 "공명 N" 태그를 숨긴다.
- **73·74 별빛 한 줄:** `GET /v1/plaza/nebulae/{id}/lines`. 내 줄은 `nebulaLines`에 둔다.
  - 보내기: `POST …/lines`
    - 상처가 될 수 있는 말(hurtful)이면 99 화면 상태로 둔다.
    - 너무 긺(too_long), 이미 남김(already_left), 받지 않는 성운(lines_closed)이면 서버 문구를 토스트로 띄운다.
- **100 신고:** `POST /v1/plaza/lines/{id}/report`. 신고 시트에서 처음 고른 사유를 hurtful·personal_info·spam·other로 보낸다. 바로 가리는 동작은 그대로다.
- **19·20 나누기:** `PUT /v1/stars/{id}/share {quote}`. 거두기는 `DELETE`다.
  - quote는 본문에서 300자 이하인 가장 긴 문장이다. 서버가 개인정보를 다시 가린다.
  - TODO: Figma 75처럼 사용자가 직접 문장을 고르게 하기
- 개발용 `-debugRoute plaza`를 추가했다(광장 탭).

## 확인 (iPhone 17, 실제 API)
- 두 번째 테스트 계정(plaza-friend)으로 별 "새벽 공기"를 띄우고 나눴다.
- ios-sim-test 계정의 앱 광장 탭에 그 별이 카드로 나온다. 제목과 가려진 한 문장이 보인다.

## 확인하지 않은 것
- 공명, 별빛 한 줄 보내기·신고, 나누기 버튼은 탭을 할 수 없어 보지 못했다. 같은 API는 서버 코드와 curl로 확인했다.
- 72 성운 피드는 서버에 띄운 성운이 없어 빈 상태다. 성운 그리기·띄우기(51~55, 71) 연결이 남았다.

## 남은 일
- 성운 그리기·저장·하늘에 띄우기(51~55, 71) → `/v1/nebulae`
- 69 오늘 밤 통계 → `/v1/plaza/tonight`
- 성장 단계·밝기 흐름(08·86·66·82) → `/v1/growth`, `/v1/starlight/trend`
- 같은 이름이 둘 이상인 광장 항목: 지금은 이름으로 화면을 찾는다. 서버 id로 바꾸는 게 안전하다.
