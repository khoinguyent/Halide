#!/usr/bin/env bash
# Build and restart the **production** API on the droplet.
# Run on the server from the directory that owns the live stack (e.g. /root/halide-backend).
#
# Prerequisites:
#   - Code synced (git pull or rsync); server `.env.prod` present (not in git)
#   - docker compose v2 (`docker compose`)
#   - Compose project name should match the stack that binds :80/:443 (often the directory name)
#
# Usage:
#   cd /root/halide-backend
#   git pull   # or rsync from your laptop
#   chmod +x scripts/deploy_prod_droplet.sh
#   ./scripts/deploy_prod_droplet.sh

set -euo pipefail

BACKEND_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="${BACKEND_ROOT}/docker-compose.prod.yml"
SERVICE="backend"

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
  echo "Warning: alembic upgrade failed — check logs." >&2
fi

echo "==> Last 40 log lines:"
docker compose -f "$COMPOSE_FILE" logs --tail=40 "$SERVICE"

echo "Done. Production: https://api.smartconnector.io.vn"
