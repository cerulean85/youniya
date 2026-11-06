#!/bin/sh
# Bring the production database (Neon main branch) up to the latest schema.
# Run this from this machine before each Vercel deploy that adds a migration:
# Vercel never runs migrations itself. Reads server/.env.production.
set -e
cd "$(dirname "$0")/.."
[ -f .env.production ] || { echo "server/.env.production is missing" >&2; exit 1; }
set -a
. ./.env.production
set +a
.venv/bin/alembic upgrade head
.venv/bin/alembic current
