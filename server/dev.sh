#!/bin/sh
# Development server on all interfaces, so a Mac on the same network can reach it.
# The first run writes server/.env with fresh secrets; keep that file, or every star
# written so far can no longer be read.
set -e
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  cat > .env <<EOF
JWT_SECRET=$(.venv/bin/python -c "import secrets; print(secrets.token_urlsafe(48))")
DATA_ENCRYPTION_KEY=$(.venv/bin/python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
DATABASE_URL=sqlite:///./youniya-dev.db
DEV_LOGIN=1
TRUST_PURCHASES=1
EOF
  chmod 600 .env
  echo "wrote server/.env"
fi

set -a
. ./.env
set +a
exec .venv/bin/uvicorn --factory youniya_api.main:create_app --host 0.0.0.0 --port "${PORT:-8000}"
