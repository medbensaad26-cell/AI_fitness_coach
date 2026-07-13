#!/bin/sh
set -e

echo "Waiting for database..."
until python -c "
from sqlalchemy import create_engine, text
from app.core.config import SYNC_DATABASE_URL
engine = create_engine(SYNC_DATABASE_URL)
with engine.connect() as conn:
    conn.execute(text('SELECT 1'))
" 2>/dev/null; do
  sleep 1
done

echo "Running migrations..."
alembic upgrade head

echo "Starting: $*"
exec "$@"
