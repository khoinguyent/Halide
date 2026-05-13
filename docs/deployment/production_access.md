# Halide Production Access

This document contains instructions and details for accessing the production environment of the Halide backend.

## Server Information

| Detail | Value |
| :--- | :--- |
| **Provider** | DigitalOcean |
| **Droplet IP** | `165.22.63.89` |
| **Api Domain** | `https://api.smartconnector.io.vn` |
| **SSL Status** | **ACTIVE** (Caddy managed) |
| **OS** | Ubuntu 24.04 LTS |
| **User** | `root` |
| **SSH Key** | `id_ed25519` (Local: `~/.ssh/id_ed25519`) |

## How to Connect

```bash
ssh root@165.22.63.89
# or
ssh root@api.smartconnector.io.vn
```

## Initial Setup Tasks

- [ ] Update System: `apt update && apt upgrade -y`
- [ ] Configure Firewall:
  ```bash
  ufw allow ssh
  ufw allow 8000/tcp
  ufw enable
  ```
- [ ] Install Docker & Docker Compose
- [ ] Set up Swap File (2GB recommended for $6 Droplet)

## Deployment

The backend is deployed using Docker Compose.

- **Compose File**: `docker-compose.prod.yml`
- **Environment**: `.env.prod`

### Staging (`backend-staging`)

- **API host**: `https://stagging-api.smartconnector.io.vn` (see `backend/Caddyfile`)
- **On the droplet** (after SSH per above), backend path is typically `/root/Halide/backend` (not always a full `git` clone).
- **Deploy script** (runs on the server; builds image, restarts service, runs Alembic):

  ```bash
  ssh root@165.22.63.89
  cd /root/Halide/backend
  ./scripts/deploy_staging_droplet.sh
  ```

- **From your laptop** (sync code then deploy): rsync this repo’s `backend/` to `/root/Halide/backend/` on the droplet (do not overwrite server-only `.env.staging` / `.env.prod`), then SSH and run the script above.
- **Postgres**: staging uses its own database name from `DATABASE_URL` in `.env.staging` (e.g. `halide_staging`). Create it if missing:  
  `docker compose -f docker-compose.prod.yml exec -T db psql -U halide_user -d postgres -c 'CREATE DATABASE halide_staging OWNER halide_user;'`
