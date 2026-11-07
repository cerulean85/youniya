#!/bin/sh
# 월간 마음 리포트 for production, run daily by youniya-monthly.timer. Does nothing unless MEMBERSHIP=1.
set -e
cd "$(dirname "$0")/.."
set -a
. ./.env.production
set +a
exec .venv/bin/python tools/monthly_reports.py
