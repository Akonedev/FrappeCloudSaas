# Implementation Plan: Press SaaS Platform

**Branch**: `001-press-saas-platform` | **Date**: 2025-12-08 | **Spec**: ./spec.md
**Input**: Feature specification from `/specs/001-press-saas-platform/spec.md`

## Summary

Build a composable Docker-based hosting platform (Press) to create and operate multiple Frappe/ERPNext sites using Frappe v16 and PostgreSQL 16. The platform must be production-usable for development and small-scale production: multi-tenancy (schema-per-site), SSO integration with Keycloak (with fallback to local auth), object storage via MinIO, reverse-proxy via Traefik, Redis queues and cache, and a robust daily backup + retention plan.

Architecture highlights:
- Docker Compose stack with small set of well-defined services: press manager, frappe site runner/bench, Postgres (single server, schema-per-site), Redis (cache & queue), MinIO (object store), Keycloak (SSO), Traefik (ingress), and support services (healthcheck, backups).
- Container names all prefixed with `fcs-press-*` and ports restricted to constitution range 48510-49800.
- DB tenancy: one Postgres instance with separate schemas per site. Per-schema backups and restores supported.
- Resilience: soft-delete lifecycle (30-day retention), Keycloak fallback to local auth, daily backups (30d retention) with automatic pruning.

## Technical Context

- Language / Runtime: Python 3.11+ (Frappe uses Python)
- Primary Dependencies: Frappe v16, PostgreSQL 16.x, Redis 7.x, Traefik 3.x, Keycloak 22.x+, MinIO
- Storage: PostgreSQL 16 (schema-per-site), MinIO S3 for files and backups
- Testing: pytest (backend), integration tests with docker-compose for system tests, lightweight smoke tests
- Target Platform: Linux servers with Docker (Docker Engine + Docker Compose v2) — both local dev and small cloud VMs
- Project Type: multi-service server (docker-compose manifests, management CLI)
- Performance Goals: support 10+ small sites on a single host, reasonable RTO/RPO (daily backup, RPO ≤ 24h, RTO depends on restore speed)
- Constraints: container prefixes `fcs-press-*`, port range 48510-49800, Frappe v16 + Postgres 16

## Constitution Check

All decisions respect the existing constitution rules:
- Database: PostgreSQL 16 (conformance ✔)
- Ports: all services limited to 48510-49800 (conformance ✔)
- Container naming: uses `fcs-press-*` prefix (conformance ✔)
- Security: secrets via environment or docker secrets; SSO via Keycloak (conformance ✔)

## Project Structure

Documentation (this feature)
```
specs/001-press-saas-platform/
├── spec.md
├── plan.md          # THIS FILE
├── research.md      # Phase 0 output (optional)
├── data-model.md    # Phase 1 output
├── quickstart.md    # Phase 1 output
├── contracts/       # Phase 1 output (API & infra contract skeletons)
└── tasks.md         # Phase 2 output (created by /speckit.tasks)
```

Source layout (repository-level, components we will add under `docker/` and top-level helpers):
```
# top-level composition
docker/
├── compose.yaml                # example developer-friendly compose
├── docker-compose.production.yml  # production-ready compose with secrets and volumes
└── press/                      # per-service dockerfiles and config
    ├── press-manager/          # service for Press UI / control plane
    ├── press-worker/           # orchestration workers (site build/install/backup)
    └── bench/                  # runner images for site containers
```

**Structure Decision**: Use a single repository to host compose manifests, scripts, and config under `docker/press/` with the rest of the code in `press/` and tooling. This keeps everything related to the platform together and avoids cross-repo complexity.

## System Architecture & Components

- Traefik (ingress, HTTPS via dev cert or production Let's Encrypt): front gateway for Press and sites
- Press Manager (control-plane): UI and API to create sites, manage backups and settings
- Postgres 16: single instance, manage per-site schemas (schema-per-site tenancy model)
- Redis 7: queue (worker) and cache channels
- MinIO: S3-compatible object storage for user files and backups
- Keycloak: SSO provider (OIDC), primary login; fallback to local Frappe auth when Keycloak is unavailable
- Bench/Worker: per-site runtime & background tasks (bench process), managed by Press manager

Network & Ports (reserved within 48510-49800):
- Redis queue: 48511 (internal)
- Postgres: 48532
- Traefik HTTP: 48580
- Traefik HTTPS: 48543
- MinIO API: 48590
- MinIO Console: 48591
- Keycloak: 48595
- Press Manager (UI/API): 48550
- Site runners: allocated per-site (e.g., 48600+ dynamic)

## Data & Backups

- Tenancy approach: schema-per-site on Postgres (single cluster). Each site gets its own schema, mapped to press-managed Roles/Users.
- Backups: per-schema (pg_dump/pg_restore capable) + file storage in MinIO. Daily full backups; older than 30 days pruned. A site restore reconstitutes schema + files.
- Soft-delete: when deleting a site, the site is marked deleted and retained for 30 days — during this period restore from backups is allowed. After 30 days, data is removed and prunable backups are deleted.

## Observability & Health

- Healthchecks for all services exposed on internal health endpoints
- Logs available via `docker compose logs <service>` and preserved in local volumes
- Simple metrics: container health, backup status, job queue metrics; plan to add Prometheus-compatible endpoints later

## Security

- Secrets are passed via `.env` for dev; production must use Docker secrets or an equivalent secret manager
- Keycloak handles SSO/OIDC, JWT sessions; fallback uses Frappe's local accounts
- MinIO access keys stored as secrets

## Automated Tests & CI

- Unit tests for manager and workers
- Integration tests using docker-compose in CI for the full stack (smoke tests)
- Acceptance tests verifying: stack boots, site creation, SSO flows (mock Keycloak or local test realm), backups and restore workflow

## Implementation Roadmap (High level phases)

Phase 1 — Minimal Developer-Ready MVP (2–3 sprints)
1. Compose skeleton + individual Dockerfiles for Press manager, worker, bench images.
2. Local developer quickstart: compose up, create admin, login to Press manager.
3. Implement Postgres (single instance) and schema-per-site plumbing in manager: create schema, grant, run migrations for new schematic site.
4. Integrate Redis and MinIO (development config), implement file storage mapping and basic backups to MinIO.
5. Implement site creation UI + basic end-to-end flow (create site → site runner starts → site reachable)
6. Healthchecks, simple tests, documentation and quickstart.

Phase 2 — Harden & Integrate (production-ready)
1. Traefik integration (HTTPS, routing to Press & sites), production compose and secrets.
2. Implement Keycloak SSO integration + fallback local auth.
3. Backup scheduler and retention job (daily at configurable time; prune older than 30 days).
4. Add per-schema backup/restore tooling and user-facing restore flows.
5. Autoscaling and resource constraints; per-site resource limits and monitoring.
6. End-to-end integration tests in CI and a staging environment.

Phase 3 — Polish & Operability
1. Add logging, metrics, backups monitoring alerting, restores audit and rollback verification.
2. Performance tuning and load tests (10+ sites target by default).
3. Documentation, CLI, and operator playbooks for upgrades and migration.

## Risks & Mitigations

- SSO outage: mitigation is fallback local auth (already chosen).
- Backup/restore complexity: provide robust per-schema backup tooling, tests for restore workflows, and global verification on restore.
- Postgres schema management: adopt migrations that can target a schema and robust versioning.

## Deliverables (this /speckit.plan run)
- `specs/001-press-saas-platform/plan.md` (this file)
- `specs/001-press-saas-platform/data-model.md` (next)
- `specs/001-press-saas-platform/contracts/press-api.yaml` (next)
- `specs/001-press-saas-platform/quickstart.md` (next)

---

Next step: generate `data-model.md`, `contracts/press-api.yaml` and `quickstart.md` then commit everything and continue to task breakdown (/speckit.tasks).
