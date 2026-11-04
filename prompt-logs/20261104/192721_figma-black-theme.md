# Figma 메인 테마 블랙 계열 전환

> **되돌림:** 사용자가 원한 것은 배경이 아니라 버튼 색이었다. 아래 배경 변경은 모두 원래 값으로 되돌렸다. 실제 반영 내용은 같은 폴더의 `*_figma-black-button.md`를 본다.

- 일시: 2026-11-04 19:27
- 요청: "메인은 블랙 계열 테마였으면 좋겠어." → "Figma 색 조정"
- 대상: Figma `YOUNIYA` (KoVuepUwkpLH6YqvVqgeMI)

## 과정
1. 화면 `03 First Night Sky`(8:43)의 색을 조사했다. 모든 배경·테두리가 변수(`bg/canvas`, `bg/surface`, `bg/surface-raised`, `border/default`)에 연결되어 있었다.
2. `Color` 컬렉션의 Night 모드는 `Primitives`의 남색 계열 값을 참조(alias)한다. Dawn 모드는 자체 값을 쓰므로 영향이 없다.
3. Primitives 값 4개만 바꿨다. Night 모드를 쓰는 모든 화면에 일괄 반영된다.

## 변경 내역 (Primitives, Value 모드)

| 변수 | 쓰이는 곳 | 이전 | 이후 |
|---|---|---|---|
| brand/void-space | bg/canvas | #0B0F19 | #050505 |
| brand/cosmic-blue | bg/surface | #131A2A | #121212 |
| brand/cosmic-blue-raised | bg/surface-raised | #1A2338 | #1C1C1C |
| brand/deep-starlight | border/default | #334155 | #2E2E2E |

## 그대로 둔 것
- 포인트 색(보라 #8B5CF6), 금색 힌트, 감정 색
- 텍스트 회색(neutral/100·400·500): 살짝 푸른 기가 있는 slate 계열
- Dawn 모드 값
- 변수 이름(`cosmic-blue` 등). 값은 이제 검정이지만 이름은 바꾸지 않았다.
- Mobile 페이지에서 토큰에 연결되지 않은 옛 남색은 1곳뿐이었다: `02 Login`의 Apple 로고 벡터(#0B0F19). 로고 색이라 그대로 두었다.

## 결과
- `03 First Night Sky` 스크린샷으로 배경이 블랙으로 바뀐 것을 확인했다. 별 배경과 성운 글로우는 그대로 보인다.
- 되돌리려면 위 표의 "이전" 값으로 다시 설정하거나 Figma 버전 기록을 쓰면 된다.
