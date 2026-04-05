#!/usr/bin/env bash
# Build and restart the staging API on the droplet.
# Run from the machine that hosts Docker (SSH into the droplet first).
#
# Prerequisites:
#   - Repo cloned on the droplet (e.g. ~/Halide), on the branch you want
#   - backend/.env.staging and backend/.env.prod present (not in git)
#   - docker compose v2 (`docker compose`)
#
# Usage:
#   cd /path/to/Halide/backend
#   git pull
#   chmod +x scripts/deploy_staging_droplet.sh
#   ./scripts/deploy_staging_droplet.sh

set -euo pipefail

BACKEND_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="${BACKEND_ROOT}/docker-compose.prod.yml"
SERVICE="backend-staging"

cd "$BACKEND_ROOT"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Missing $COMPOSE_FILE" >&2
  exit 1
fi

echo "==> Building ${SERVICE}..."
docker compose -f "$COMPOSE_FILE" build "$SERVICE"

echo "==> Starting ${SERVICE} (and dependencies if needed)..."
docker compose -f "$COMPOSE_FILE" up -d "$SERVICE"

echo "==> Applying DB migrations (Alembic)..."
if docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" alembic upgrade head; then
  :
else
  echo "Warning: alembic upgrade failed — check logs. App may still use create_all fallback." >&2
fi

echo "==> Last 40 log lines:"
docker compose -f "$COMPOSE_FILE" logs --tail=40 "$SERVICE"

echo "Done. Staging host: stagging-api.smartconnector.io.vn (see backend/Caddyfile)"
