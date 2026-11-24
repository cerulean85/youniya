# mini-server01에 AI CLI 4종 설치 (2026-11-21)

- 접속: 사용자가 서버에서 맥 공개 키(id_ed25519)를 authorized_keys에 직접 등록 (비밀번호 로그인은 거부됨)
- 서버: Ubuntu 24.04.2 x86_64, sudo는 비밀번호 필요 → 모두 사용자 폴더에 설치
- 설치 (공식 스크립트는 받아서 내용 확인 후 실행, 체크섬 검증 포함)
  - claude 2.1.330: claude.ai/install.sh → ~/.local/bin/claude
  - codex 0.171.0: npm -g --prefix ~/.local @openai/codex → ~/.local/bin/codex
  - agy 1.5.13: antigravity.google/cli/install.sh → ~/.local/bin/agy
  - grok 1.0.92: x.ai/cli/install.sh → ~/.grok/bin/grok (설치 스크립트가 .bashrc에 PATH·자동완성 블록 추가)
- .bashrc: 중복 PATH 줄을 실수로 넣었다가 백업으로 되돌림. 최종 .bashrc는 grok 설치 스크립트가 넣은 블록만 바뀐 상태
- 로그인·API 키는 하지 않음 (사용자가 서버에서 직접)

## agy 권한 설정 (추가)
- mini-server01 ~/.gemini/antigravity-cli/settings.json에 "toolPermission": "always-proceed" 추가. 백업: settings.json.bak-20261121
