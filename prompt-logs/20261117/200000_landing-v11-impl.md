# 랜딩 v1.1 구현 (정적 소개 사이트)

- 바꾼 것: web/index.html 본문(main)을 Figma W-01 v1.1(662:37107) 구조로 교체(히어로 좌측 정렬, 3단계 흐름, 우주 광장, 약속 2x2, 요금 표, 닫는 띠), 상단 nav에 "웹에서 시작하기" 버튼 추가. web/styles.css 끝에 landing 블록 추가(기존 규칙은 그대로, 다른 페이지용).
- 제거: 앱 스크린샷 갤러리 섹션(새 디자인에 없음). 닫는 띠의 카드 박스.
- 추가 이미지(web/img, webp): landing-write(오늘·쓰기), landing-plaza(우주 광장), step-star, step-glow, step-constellation.
- 애니메이션: 별 코어 깜빡임 5s, 글로우 맥동 6s(시차), prefers-reduced-motion에서 정지.
- 확인: 로컬 http.server + Chrome에서 1440 폭 확인, 390 폭은 iframe으로 가로 스크롤 없음 확인. 커밋·배포는 하지 않음.
- 한계: 별자리 그림은 Figma 이미지에 구워진 글로우 위에 CSS 글로우·코어를 덧씌움. 단계 2의 별은 코어만 따로 깜빡임.
