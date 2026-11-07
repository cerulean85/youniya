#!/bin/sh
# Daily copy of the production database (Neon main branch) to this machine.
# Keeps the last 14 in ~/backups/youniya. Restore: see tools/backup_db.py.
# The writing in it is still encrypted: keep DATA_ENCRYPTION_KEY somewhere safe as well.
set -e
cd "$(dirname "$0")/.."
[ -f .env.production ] || { echo "server/.env.production is missing" >&2; exit 1; }
set -a
. ./.env.production
set +a
exec .venv/bin/python tools/backup_db.py dump "$DATABASE_URL" "${BACKUP_DIR:-$HOME/backups/youniya}" --keep 14
