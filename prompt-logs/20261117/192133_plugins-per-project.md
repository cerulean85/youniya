# Vercel·Sentry 플러그인을 필요한 프로젝트에서만 켜기

- ~/.claude/settings.json: sentry·vercel 플러그인 false (백업 ~/.claude/settings.json.bak-20261117-plugins)
- 각 폴더 .claude/settings.local.json에 enabledPlugins true 추가 (git에 안 잡힘 확인)
  - Vercel(.vercel 연결된 곳): youniya/admin, youniya/web, youniya/webapp, youniya-webv11/webapp, iyunote-web, review-journal
  - Sentry(의존성 있는 곳): youniya/server, youniya-webv11/server, trade-diary, cogfeed
- 다른 저장소는 저장소 최상위에 둠(그 위치에서 세션을 연다고 가정).
- youniya 최상위에서 연 세션에는 두 플러그인이 꺼짐. 다음 세션부터 적용.
- agy/Codex/Grok 위임: 없음 (설정 파일 몇 개라 직접 처리)
