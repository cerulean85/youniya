#!/bin/sh
# 월간 마음 리포트 was removed (2026-11-09); tools/monthly_reports.py now does nothing. Don't install the timer.
set -e
cd "$(dirname "$0")/.."
set -a
. ./.env.production
set +a
exec .venv/bin/python tools/monthly_reports.py
