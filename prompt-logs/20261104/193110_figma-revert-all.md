# Figma 색 변경 전부 원복

- 일시: 2026-11-04 19:31
- 요청: "음.. 아니다 그냥 원래대로 가자"
- 대상: Figma `YOUNIYA` (KoVuepUwkpLH6YqvVqgeMI)

## 원복 내역
- 배경 Primitives 4개: 직전 작업(193005)에서 이미 원래 값으로 되돌렸다. (#0B0F19, #131A2A, #1A2338, #334155)
- Button 세트의 Primary 변형
  - Default (4:2): 채움을 `brand/primary` 변수(#8B5CF6)에 다시 연결했다.
  - Hover (4:4): 채움을 `brand/primary-hover` 변수(#7C4DFF)에 다시 연결했다.
  - 두 변형 모두 테두리를 지우고, 효과는 `Glow/Violet` 이펙트 스타일로 되돌렸다.

## 참고
- 원래 버튼의 그림자가 스타일에 연결돼 있었는지는 기록하지 않았다. 값(#8B5CF6, 불투명도 40%)이 `Glow/Violet`과 같고 FAB도 이 스타일을 쓰므로 스타일로 연결했다. 반경은 24, 오프셋은 0이다.
- `03 First Night Sky` 스크린샷으로 보라 버튼과 글로우가 돌아온 것을 확인했다.
- 결과적으로 파일 내용은 작업 전과 같다.
