# 안 쓰는 MCP 서버·플러그인 정리 (토큰 절약)

- 요청: "Sentry와 Vercel는 놔두고 나머지 정리해줘."
- 사용자 범위 MCP 제거(`claude mcp remove -s user`): ollama(매번 연결 실패), gemini-cli(지원 종료로 미사용), composio(claude.ai 커넥터와 중복)
- 플러그인 끔: andrej-karpathy-skills (CLAUDE.md 코딩 지침과 중복) — settings.json enabledPlugins false
- 유지: sentry, vercel 플러그인
- 백업: ~/.claude.json.bak-20261117, ~/.claude/settings.json.bak-20261117
- 다음 세션부터 적용. claude.ai 쪽 composio 커넥터는 손대지 않음.
- agy/Codex/Grok 위임: 없음 (설정 3줄 변경)
