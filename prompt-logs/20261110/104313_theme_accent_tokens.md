# 테마 강조색 토큰화 (FIGMA DESIGN Session 전달, 기획 14.7)

- 보라 고정 에셋 색(BrandPrimary, BrandPrimaryText, BorderFocus, TintPrimary, TintPrimarySoft, PrimaryGradient*, PrimaryHoverGradient*)을 지우고, 같은 이름의 `Color` 토큰이 적용된 우주의 색을 따르게 함 (`AppliedSky`, SkyTheme.swift).
- SkyAccent에 focus(accent/focus)와 text(accent/primary-text-on-dark) 추가, 다섯 테마 값은 Figma Cosmos 컬렉션 값.
- 화면에 직접 쓴 보라 hex(#8555EF, #A78BFA, #8B5CF6) 16곳을 토큰으로 교체. 08 배경 빛은 테마 glow/a·b·c.
- 루트에 `.tint(accent/primary)`: 토글 등 시스템 컨트롤도 테마를 따름.
- 안내 배너 ⓘ 아이콘(보라 PNG)은 template + accent/tint.
- 확인: 다섯 테마 × 04 / 05 / 09-5 캡처, 보라 남은 곳 없음. 기분 색·금색·카드 색은 그대로.
- 커밋 안 함.

같은 턴: 인앱결제 무반응 → 상품 로드 실패(product_unavailable). 유료 앱 계약 「처리 중」이 원인으로 보임, 활성 필요.

## 이어서: 75 다른 이의 별 헤더 (Figma 75-4 428:17429)
- 큰 별 그림(220pt) 영역 삭제. 맨 위 Star Header: 56×56 금색 썸네일(10% 배경·35% 테두리, 모서리 16, 별 38pt) + 제목·칩.
- 제목은 사용자가 쓴 별 제목(liveText.title → fullTitle → starTitle → name). 글 전체 위 중복 제목 삭제.
- 75 / 75-3 / 75-4 캡처로 시안과 맞는지 확인. 커밋 안 함.

## 이어서: 75 썸네일 = 09-5 행 썸네일, 결제 실패 문구 구분, 빌드 3·4 업로드
- PlazaStarThumb(공용): 09-5 행 44pt, 75 헤더 56pt. 금색 상자 제거.
- 28 코인 충전: App Store가 상품을 못 주면(product_unavailable) "지금은 코인을 충전할 수 없어요"로 구분.
- 1.0.0 (3), (4) App Store Connect 업로드 성공. 심사 제출 안 함.
