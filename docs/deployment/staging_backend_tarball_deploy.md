# Staging backend deploy (tarball → droplet)

This is the fastest way to ship backend changes to the staging service (`backend-staging`) on the DigitalOcean droplet without needing a full git clone on the server.

## Target

- **Droplet**: `165.22.63.89`
- **Staging API**: `https://stagging-api.smartconnector.io.vn`
- **Compose file on droplet**: `~/halide-backend/docker-compose.prod.yml`
- **Staging service name**: `backend-staging`
- **Staging DB name** (from `.env.staging`): typically `halide_staging`

## 1) Build a backend tarball locally

From the repo root on your laptop:

```bash
cd /path/to/Halide
# macOS: avoid AppleDouble `._*` files inside the tarball (they break Alembic in Docker).
COPYFILE_DISABLE=1 tar -czf backend.tgz -C backend .
```

This packages the `backend/` directory contents.

## 2) Copy to droplet and extract

```bash
scp backend.tgz root@165.22.63.89:/root/backend.tgz
ssh root@165.22.63.89

mkdir -p /root/halide-backend
tar -xzf /root/backend.tgz -C /root/halide-backend
```

## 3) Rebuild + restart staging backend

On the droplet:

```bash
cd /root/halide-backend
docker compose -f docker-compose.prod.yml build backend-staging
docker compose -f docker-compose.prod.yml up -d backend-staging
docker logs --tail 50 halide-backend-backend-staging-1
```

## 4) Verify storage add-on sync (common check)

If you’re debugging quota updates:

- The staging backend uses **`halide_staging`** (not `halide`) when `.env.staging` points at it.
- Confirm webhook history:

```bash
docker exec -i halide-backend-db-1 psql -U halide_user -d halide_staging -c \
"SELECT created_at, user_id, event_type, product_id, transaction_id
 FROM purchase_history
 ORDER BY created_at DESC
 LIMIT 20;"
```

Then open the app (staging flavor) to trigger:

- `GET /api/v1/me` (profile and quota come from Postgres)
- Optional: `POST /api/v1/billing/sync` (default: **DB-only** — recomputes `additional_storage_bytes` from `purchase_history`, no RevenueCat). Use `POST /api/v1/billing/sync?force_remote=true` only when you need a full REST reconcile (e.g. right after purchase/restore while webhooks catch up).

The UI should reflect `total_storage_limit` = base + `additional_storage_bytes`.

## 5) Run database migrations (after schema changes)

Inside the staging container (same compose project):

```bash
docker exec halide-backend-backend-staging-1 sh -c "cd /app && python -m alembic upgrade head"
```

If Alembic fails with **`SyntaxError: source code string cannot contain null bytes`**, the image picked up macOS **`._*.py`** junk under `alembic/versions/`. Rebuild the image from a tarball built with **`COPYFILE_DISABLE=1`** (see step 1); the backend `Dockerfile` also deletes `._*.py` after `COPY`.

## 6) `purchase_history` transaction columns

`purchase_history` includes **`transaction_id`**, **`original_transaction_id`**, and **`rc_event_id`** (RevenueCat `event.id`). Webhooks populate all three where present; older rows can be backfilled from `payload` by migration **`a3f9e1c2b4d8`**.

Example:

```bash
docker exec -i halide-backend-db-1 psql -U halide_user -d halide_staging -c \
"SELECT id, created_at, product_id, transaction_id, original_transaction_id, rc_event_id
 FROM purchase_history
 WHERE product_id LIKE 'halide_storage%'
 ORDER BY created_at DESC
 LIMIT 10;"
```

