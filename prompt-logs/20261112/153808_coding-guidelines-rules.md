# 전역 규칙에 코딩 행동 지침·작업 로그 추가 (2026-11-12)

## 요청
붙여 넣은 GEMINI.md 지침(1~4 코딩 행동, 5 작업 로그)을 규칙에 추가.

## 한 일
- ~/.claude/CLAUDE.md 끝에 '코딩 행동 지침' 1~5절을 한국어로 추가(백업: CLAUDE.md.bak-20261112-2).
- 작업 로그 파일명은 기존 prompt-logs 형식에 맞춰 `HHmmss_<summary>.md`로 정함.
- 비어 있던 ~/.gemini/GEMINI.md에 같은 지침을 넣어 agy도 따르게 함.

## 남은 일
- home-desktop의 CLAUDE.md도 새 버전으로 다시 보내야 함(이전 전송본에는 이 지침이 없음).

## 추가 (home-desktop 적용)
- 사용자가 home-desktop에서 `sudo tailscale set --ssh` 실행 → 맥북에서 Tailscale SSH로 접속.
- home-desktop의 기존 CLAUDE.md는 맥북 옛 판과 똑같아서(전용 내용 없음) 그대로 교체. 백업: ~/.claude/CLAUDE.md.bak-20261112.
- ~/.gemini/GEMINI.md 새로 만듦. sha256이 맥북과 같음을 확인.
- home-desktop에는 codex CLI와 Codex MCP가 없음.

## 추가 (Codex)
- Codex 전역 지침 파일 ~/.codex/AGENTS.md(없었음)를 새로 만들어 같은 '코딩 행동 지침' 1~5절을 넣음.
- home-desktop에도 ~/.codex/AGENTS.md 생성(맥북과 sha256 같음). codex는 아직 미설치.
