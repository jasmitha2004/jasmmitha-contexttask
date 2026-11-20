#!/usr/bin/env bash
# Start ContextBridge AI locally (Django API on :8000 + Streamlit on :8501)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [ ! -d .venv ]; then
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -r requirements-dev.txt
else
  source .venv/bin/activate
fi

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example — edit it if needed."
fi

export SQLITE_PATH="${SQLITE_PATH:-$ROOT/backend/db.sqlite3}"
export CONTEXTBRIDGE_API="${CONTEXTBRIDGE_API:-http://127.0.0.1:8000/api}"
export DJANGO_SETTINGS_MODULE=contextbridge.settings

cd backend
python manage.py migrate --noinput
# Seed demo data only when the demo user does not exist yet (never overwrite existing data)
if ! python -c "import django; django.setup(); from django.contrib.auth.models import User; raise SystemExit(0 if User.objects.filter(username='demo').exists() else 1)" 2>/dev/null; then
  python sample_data_generator.py
fi

echo "Starting API on :8000 ..."
python manage.py runserver 0.0.0.0:8000 &
API_PID=$!
trap 'kill $API_PID 2>/dev/null || true' EXIT
sleep 2

cd "$ROOT"
echo "Starting Streamlit on :8501 ..."
streamlit run frontend/app.py --server.port 8501 --server.address 0.0.0.0
