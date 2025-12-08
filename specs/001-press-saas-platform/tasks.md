---
description: "Task list for Press SaaS Platform implementation"
---

# Tasks: Press SaaS Platform

**Input**: Design documents from `/specs/001-press-saas-platform/` (spec.md, plan.md, data-model.md, contracts/)
**Prerequisites**: plan.md and spec.md are complete

## Phase 1: Setup (Shared Infrastructure)

Purpose: Project initialization and basic structure (developer-first, reproducible locally)

- [ ] T001 Create repository structure for Press platform: add `docker/press/`, `docker/compose.yaml`, `press/` (code) and `scripts/` (scripts/README.md)
- [ ] T002 [P] Add `.env.example` for local development with placeholders for POSTGRES_PASSWORD, MINIO_ROOT_USER, MINIO_ROOT_PASSWORD, KEYCLOAK_ADMIN, KEYCLOAK_ADMIN_PASSWORD
- [ ] T003 [P] Add `docker/compose.yaml` (development) referencing services: press-manager, postgres, redis, minio, keycloak, traefik, bench runner
- [ ] T004 [P] Add `docker/compose.production.yml` skeleton and `docker/compose.override.yml` for host-specific config
- [ ] T005 Add `docs/quickstart.md` in `specs/001-press-saas-platform/quickstart.md` (ensure file exists and validated)

---

## Phase 2: Foundational (Blocking Prerequisites)

Purpose: Core infrastructure pieces that MUST be in place before implementing user stories

- [ ] T006 Setup Postgres 16 compose service and confirm schema-per-site capability in `docker/compose.yaml` and `docker/press/postgres/README.md`
- [ ] T007 [P] Create Postgres schema management tooling `press/tools/schema_manager.py` with basic API to create/drop schemas (tests will call this)
- [ ] T008 [P] Add Redis 7.x compose service and `press/tools/queue.py` worker skeleton
- [ ] T009 [P] Add MinIO compose service and `press/tools/minio_client.py` wrapper for buckets and object operations
- [ ] T010 [P] Add Traefik 3.x compose service with basic dynamic configuration in `docker/press/traefik/` and dev TLS config
- [ ] T011 Implement Press Manager API scaffold `press/manager/app.py` with OpenAPI contract stub from `specs/001-press-saas-platform/contracts/press-api.yaml`
- [ ] T012 [P] Add healthcheck endpoints for manager and workers (e.g., `/health`) and configure Compose healthchecks
- [ ] T013 Configure environment management `.env.example` and `docker/compose.override.yml` for secret injection (documented in `docs/`)

Checkpoint: After these are implemented the infrastructure should stand up locally and the API scaffold should be reachable

---

## Phase 3: User Story 1 - Démarrer l'infrastructure complète (Priority: P1) 🎯 MVP

Goal: 1-command dev experience: `docker compose up -d` boots full stack healthy

Independent Test: `tests/integration/test_boot_stack.py` which runs compose and checks all services become healthy

### Tests for User Story 1 (TDD-first)

- [ ] T014 [P] [US1] Add integration test `tests/integration/test_boot_stack.py` asserting `docker compose up -d` and health of services (press-manager, postgres, redis, minio, keycloak, traefik)

### Implementation for User Story 1

- [ ] T015 [US1] Implement `docker/compose.yaml` healthchecks and service definitions (fill missing pieces from Phase 1)
- [ ] T016 [US1] Implement `press/manager/health.py` and wire into manager `app.py`
- [ ] T017 [US1] Add scripted local mapping instructions in `docs/quickstart.md` for hosts and TLS entries

Checkpoint: `docker compose up -d` should bring a healthy stack and `tests/integration/test_boot_stack.py` passes

---

## Phase 4: User Story 2 - Créer un nouveau site Frappe (Priority: P1)

Goal: Admin can create a new Frappe site via Press API and site is reachable

Independent Test: API contract + integration test that posts to `/api/sites` and asserts site exists and is reachable

### Tests for User Story 2 (TDD-first)

- [ ] T018 [P] [US2] Add contract test `tests/contract/test_create_site.py` validating OpenAPI `POST /api/sites` behavior
- [ ] T019 [US2] Add integration test `tests/integration/test_create_site_flow.py` that exercises create → schema create → site runner start → site reachable

### Implementation for User Story 2

- [ ] T020 [P] [US2] Implement `press/manager/api/sites.py` POST handler to validate request and enqueue provisioning job
- [ ] T021 [US2] Implement `press/worker/provision.py` worker that creates Postgres schema using `press/tools/schema_manager.py` and initializes site files
- [ ] T022 [US2] Implement site runner template under `docker/press/bench/` which knows how to run a Frappe site with given schema
- [ ] T023 [US2] Add database migration runner `press/tools/migrate.py` able to run Frappe migrations in a target schema
- [ ] T024 [US2] Add tests for schema manager `tests/unit/test_schema_manager.py` (create, exists, drop)

Checkpoint: Site creation flow should be covered by contract and integration tests and be demonstrable locally

---

## Phase 5: User Story 3 - Authentification SSO via Keycloak (Priority: P2)

Goal: Users can authenticate via Keycloak OIDC; fallback to local auth when Keycloak is down

Independent Test: Contract/integration tests that perform OIDC flow and fallback scenario

### Tests for User Story 3 (TDD-first)

- [ ] T025 [P] [US3] Add contract test `tests/contract/test_sso_oidc.py` for OIDC endpoints and expected responses
- [ ] T026 [US3] Add integration test `tests/integration/test_sso_fallback.py` simulating Keycloak down -> local auth used

### Implementation for User Story 3

- [ ] T027 [P] [US3] Implement Keycloak realm config and press `press/integrations/keycloak.py` (setup OIDC client)
- [ ] T028 [US3] Implement manager login endpoints to redirect to Keycloak and handle callbacks `press/manager/auth.py`
- [ ] T029 [US3] Add fallback login flow `press/manager/auth_local.py` that activates when Keycloak unreachable

Checkpoint: OIDC flow validated and local fallback works when Keycloak unreachable

---

## Phase 6: User Story 4 - Stockage S3 pour les fichiers (Priority: P2)

Goal: Files uploaded to Frappe sites are stored in MinIO

Independent Test: Integration test uploading a file to a site and verifying object in MinIO

### Tests for User Story 4 (TDD-first)

- [ ] T030 [P] [US4] Add integration test `tests/integration/test_file_upload_minio.py` that uploads to a site and checks MinIO bucket

### Implementation for User Story 4

- [ ] T031 [US4] Configure Frappe site template to use MinIO via `press/bench/minio_config.py` and ensure credentials come from `.env`
- [ ] T032 [US4] Add MinIO bucket creation script in `press/tools/minio_client.py` and ensure bucket policy for uploads
- [ ] T033 [US4] Add unit tests for MinIO client wrapper `tests/unit/test_minio_client.py`

Checkpoint: Files saved to MinIO and retrievable; tests verify this

---

## Phase 7: User Story 5 - Backup automatique des sites (Priority: P3)

Goal: Daily backups of each site's schema + files to MinIO, restore within 30-day retention

Independent Test: Integration tests schedule and trigger backup, restore, and retention pruning

### Tests for User Story 5 (TDD-first)

- [ ] T034 [P] [US5] Add integration test `tests/integration/test_backup_and_restore.py` that triggers backup, verifies object in MinIO, simulates restore, and verifies retention

### Implementation for User Story 5

- [ ] T035 [P] [US5] Implement `press/worker/backup.py` to perform per-schema pg_dump and upload to MinIO
- [ ] T036 [US5] Implement restore functionality `press/worker/restore.py` to run per-schema restore from MinIO
- [ ] T037 [US5] Implement scheduled job `press/cron/backup_scheduler.py` and retention pruning job `press/cron/prune_backups.py`

Checkpoint: Backups created daily, retained 30 days, restore works for soft-deleted sites

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T038 [P] Add comprehensive integration CI workflow `/.github/workflows/integration.yml` that runs smoke tests against docker-compose
- [ ] T039 [P] Add logging and monitoring scaffolding `press/monitoring/` (health & simple metrics)
- [ ] T040 [P] Add documentation polish: finalize `specs/001-press-saas-platform/quickstart.md`, `README.md`, and operator playbooks
- [ ] T041 Add end-to-end acceptance tests `tests/e2e/test_create_site_to_backup_to_restore.py`

---

## Dependencies & Execution Order

- Foundation (Phase 2) MUST finish before user stories begin (Phase 3+). Tests are written first and should fail.
- Parallel opportunities: many [P] tasks across phases can be implemented in parallel by different team members.

---

## Notes

- Each task mentions an exact file path so work can be started without further clarification
- Tests are prefixed and added before implementation tasks (TDD-first)
- After implementing tasks for each story, run the associated tests and CI to validate
