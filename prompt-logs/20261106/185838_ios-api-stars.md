# API 연동 2단계: 별 (2026-11-06)

- 요청: "진행해줘". 1단계를 커밋하고(`a73a931`, server main 위로 rebase), 2단계 별 연동을 했다.

## 새 파일 `App/API/StarsAPI.swift`
- **서버 응답 형식:** `ServerStar`, `ServerAnalysis`, `StarCreated(star, crisis)`
- **변환**
  - 서버 별 → `StarItem`. 텔레스코프 리포트처럼 앱에만 있는 값은 기존 별에서 이어받는다.
  - 서버 분석 → `StarAnalysis`. 감정은 비율이 큰 순서로 넣는다.
- **id:** 서버 id는 소문자 UUID 문자열이라 보낼 때 `UUID.apiID`(소문자)를 쓴다.
- **AppModel 확장**
  - `loadStars()`: 목록을 받고, 목록에 없는 본문과 분석은 별마다 상세를 동시에 받는다.
  - `publishLive(_:floated:rewriteOf:)`: `POST /v1/stars`. mode는 float 또는 keep이다. 다시 쓰기는 rewrite_of를 보낸다.
  - `floatAgain(_:)`: 36 다시 시도. `POST /v1/stars/{id}/float`
  - `deleteStarLive(_:)`: 15 삭제. 서버에서 먼저 지운다.
  - `syncDraft(_:)`, `loadDraft()`: 34 임시 저장을 서버와 맞춘다. 기기에 임시 글이 없을 때만 서버 것을 가져온다.

## AppModel
- 별 저장 파일을 나눴다. 목업은 `stars.json`, 실제 API는 `stars-live.json`(서버 사본)이다. 서버 모드를 바꾸면 그쪽 별을 불러온다.
- `refreshMe()` 다음에 별 목록과 임시 글을 불러온다(실행할 때, 로그인할 때, 서버 모드로 바꿀 때).
- 실제 API에서 로그아웃하면 이 기기의 서버 사본을 지운다.
- `deleteStar`, `saveDraft`는 실제 API일 때 서버로도 보낸다.

## 쓰기 흐름 (`ComposeFlowView`)
- 실제 API에서 05·14의 "별 띄우기·조용히 품기"를 누르면 서버에 저장한다. 기다리는 동안 화면을 어둡게 하고 진행 표시를 띄운다.
- 서버 답에 따라 갈라진다.
  - crisis → 37 위기 돌봄 → 13(서버가 분석 없이 간직한다)
  - 떠 있고 분석이 있음 → 06(서버 분석) → 탄생 → 07/16
  - 띄우기를 골랐는데 간직됨(analysis_failed) → 36. "다시 시도"는 `floatAgain`이다.
  - 연결 실패 → 35. "다시 시도"는 같은 글을 다시 보낸다.
  - 422(too_short 등)와 429(요청 수 초과) → 서버 문구를 토스트로 띄운다.
- 실제 API에서는 개발용 "실패 흉내" 스위치를 쓰지 않는다.

## 확인 (iPhone 17, 실제 API)
- curl로 띄운 별(별빛 535)이 홈의 최근 별에 나온다.
- 목업 별은 `stars.json`에 그대로 남았다.

## 확인하지 않은 것
- 시뮬레이터 조작 도구가 끊겨서 앱에서 별을 직접 쓰고, 삭제하고, 다시 시도하지 못했다.
  - 같은 API는 curl로 확인했다(`POST /v1/stars` float, 1,000자 미만이면 422).
- 별 공유·공명·성운, 망원경 리포트는 아직 목업이다. 3·4단계에서 옮긴다.
- 별 목록이 200개를 넘을 때의 페이지 넘김은 TODO다.
- 82 밝기 흐름과 성장 단계(08·86·66)는 아직 앱에서 계산한다. 서버의 `/v1/starlight/trend`, `/v1/growth`로 옮기는 건 다음에 한다.
