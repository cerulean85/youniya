"""Vercel entry point. vercel.json sends every path here; settings come from the project's environment variables.

The schema is not created here: run the migrations before each deploy (see README › 운영 배포)."""

from youniya_api.main import create_app

app = create_app()
