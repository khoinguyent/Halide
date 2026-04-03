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
