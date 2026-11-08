#!/bin/sh
# Deletes deleted accounts' purchase records once they are 5 years old. Run daily by youniya-purge.timer.
set -e
cd "$(dirname "$0")/.."
set -a
. ./.env.production
set +a
exec .venv/bin/python tools/purge_purchase_records.py "$@"
