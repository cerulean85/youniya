# 테마(68 우주의 색)가 강조색도 바꾸기 (2026-11-07)

- 요청: FIGMA DESIGN Session이 전한 사용자 결정. 테마는 배경의 성운 빛뿐 아니라 강조색도 바꾼다. 기준은 Figma "Themes · 우주의 색" 페이지(26:11320)다.

## SkyTheme.accent (`DesignSystem/SkyTheme.swift`)
- `SkyAccent`의 네 색
  - top / bottom: Primary 버튼과 FAB 그라데이션(위→아래)
  - tint: 배지 배경(16%), 버튼과 FAB 빛번짐(40%)
  - strong: 배지와 선택 칩 테두리, 77 연결선, 채워진 확대/축소 버튼, "별 보기" 링크
- 값(04 Home, Aurora 77 61:34546에서 읽음)
  - Violet: #855ADE→#6630CE, #8B5CF6, #8555EF
  - Aurora: #008473→#005448, #0E9F8E, #008475
  - Ember: #C15336→#B82500, #E0603E, #CA4B29
  - Ocean: #3672D5→#004ED2, #3B82F6, #2970E3
  - Rose: #C94086→#BD006B, #DB3F8C, #D13584

## 테마를 따르게 한 것
- `.primary` 버튼(누른 상태: Violet은 기존 Hover 그라데이션, 나머지는 아래 색)과 빛번짐
- FAB: 보라색이 들어간 이미지 대신 60pt 원을 테마 그라데이션으로 그린다. 4pt 어두운 테두리(#131A2A)와 빛번짐을 넣었다.
- StarlightBadge
- DotChip 선택 상태(09 정렬, 72 필터, 82 기간 등)
- 77: 꽃잎 연결선, 채워진 축소 버튼, 툴팁 "별 보기 ›"

## 그대로인 것
- 탭바 선택 라벨(금색 #FBBF24)
- 카드·메뉴 버튼 배경(#131A2A, 테두리 #334155)
- Secondary 버튼과 세그먼트 같은 그 밖의 보라색 요소: 이번 범위(04·77)에 없어 그대로 뒀다.

## 개발용
- `-debugTheme violet|aurora|ember|ocean|rose`: 테마를 정해 연다(-debugScreen과 함께 쓴다).

## 확인 (iOS Session Check 시뮬레이터)
- Aurora, Ember로 04와 77을 띄워 확인했다.
