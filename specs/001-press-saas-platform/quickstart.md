# Quickstart — Press SaaS Platform (developer)

This quickstart helps you bring up a local developer environment for Press (developer mode). It uses Docker & Docker Compose.

Prereqs
- Docker Engine (20.x+) and Docker Compose v2
- Linux (or WSL2)

1. Copy the example env and configure a few secrets

```bash
cp .env.example .env
# Edit .env for local ports / keys
# required values: POSTGRES_PASSWORD, MINIO_ROOT_USER, MINIO_ROOT_PASSWORD, KEYCLOAK_ADMIN, KEYCLOAK_ADMIN_PASSWORD
```

2. Start the stack

```bash
docker compose -f docker/compose.yaml up -d
# or if you have a production compose file (docker/docker-compose.production.yml) use that
```

3. Check container health

```bash
docker compose ps
docker compose logs -f fcs-press-manager
```

4. Open UI
- Press manager: https://press.localhost:48543 (configure hosts / /etc/hosts for local mapping)

5. Create a site
- Use the Press UI to create a site. The manager will create a schema in Postgres, push files to MinIO, and start the site containers.

6. Backups & Restore
- Trigger "Backup Now" in the UI to create a daily backup saved to MinIO
- Restores are available for soft-deleted sites while the retention window is active

Notes
- This is a developer quickstart. For a production deployment use per-host volumes, Docker secrets and a managed TLS solution behind Traefik.
- The project implements schema-per-site tenancy and daily backups (30 days retention) by default.
