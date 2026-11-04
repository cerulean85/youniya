# Figma Primary 버튼을 블랙 계열로 변경

- 일시: 2026-11-04 19:30
- 요청: "잠깐만! 내 말은 배경보다는 버튼 칼라를 의미한 거였어."
- 대상: Figma `YOUNIYA` (KoVuepUwkpLH6YqvVqgeMI), Components 페이지의 Button 컴포넌트 세트 (4:20)

## 과정
1. 앞서 바꾼 배경 Primitives 4개를 원래 값으로 되돌렸다. (#0B0F19, #131A2A, #1A2338, #334155)
2. 사용자 선택: 버튼 스타일은 "블랙 + 얇은 테두리", 범위는 "Primary 버튼만".
3. Button 세트에서 Primary 변형만 수정했다.

## 변경 내역

| 변형 | 채움 (이전 → 이후) | 테두리 | 효과 |
|---|---|---|---|
| Style=Primary, State=Default (4:2) | brand/primary #8B5CF6 → #000000 | 없음 → 1px 안쪽 #3A3A3A | 보라 드롭섀도 제거 |
| Style=Primary, State=Hover (4:4) | brand/primary-hover #7C4DFF → #141414 | 없음 → 1px 안쪽 #4A4A4A | 보라 드롭섀도 제거 |

- 글자색은 text/on-brand(흰색)를 그대로 쓴다.
- 새 색은 변수에 연결되지 않은 hex 값이다.

## 그대로 둔 것
- Primary Disabled, Secondary, Ghost 변형
- brand/primary 토큰. 별 슬롯 점선, 하단 연필 플로팅 버튼(FAB), 탭 강조 등의 보라는 유지된다.
- 배경 토큰 (원래 남색으로 복구)

## 검증
- 인스턴스: Mobile 49개, Mobile · Dawn 48개. 모두 컴포넌트 값을 그대로 받고 있고, 덮어쓴(override) 인스턴스는 0개였다.
- 스크린샷: `03 First Night Sky`(Night)와 `[Dawn] 03 First Night Sky`에서 검정 버튼, 회색 테두리, 흰 글자를 확인했다.
