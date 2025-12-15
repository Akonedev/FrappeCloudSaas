---
description: "Task list for Press SaaS Platform implementation"
---

# Tasks: Press SaaS Platform

**Input**: Design documents from `/specs/001-press-saas-platform/` (spec.md, plan.md, data-model.md, contracts/)
**Prerequisites**: plan.md and spec.md are complete

## Phase 1: Setup (Shared Infrastructure)

Purpose: Project initialization and basic structure (developer-first, reproducible locally)

- [x] T001 Create repository structure for Press platform: add `docker/press/`, `docker/compose.yaml`, `press/` (code) and `scripts/` (scripts/README.md)
- [x] T002 [P] Add `.env.example` for local development with placeholders for POSTGRES_PASSWORD, MINIO_ROOT_USER, MINIO_ROOT_PASSWORD, KEYCLOAK_ADMIN, KEYCLOAK_ADMIN_PASSWORD
- [x] T003 [P] Add `docker/compose.yaml` (development) referencing services: press-manager, postgres, redis, minio, keycloak, traefik, bench runner
- [x] T004 [P] Add `docker/compose.production.yml` skeleton and `docker/compose.override.yml` for host-specific config
- [x] T005 Add `docs/quickstart.md` in `specs/001-press-saas-platform/quickstart.md` (ensure file exists and validated)

---

## Phase 2: Foundational (Blocking Prerequisites)

Purpose: Core infrastructure pieces that MUST be in place before implementing user stories

- [x] T006 Setup Postgres 16 compose service and confirm schema-per-site capability in `docker/compose.yaml` and `docker/press/postgres/README.md`
- [x] T007 [P] Create Postgres schema management tooling `press/tools/schema_manager.py` with basic API to create/drop schemas (tests will call this)
- [x] T008 [P] Add Redis 7.x compose service and `press/tools/queue.py` worker skeleton
- [x] T009 [P] Add MinIO compose service and `press/tools/minio_client.py` wrapper for buckets and object operations
- [x] T010 [P] Add Traefik 3.x compose service with basic dynamic configuration in `docker/press/traefik/` and dev TLS config
- [x] T011 Implement Press Manager API scaffold `press/manager/app.py` with OpenAPI contract stub from `specs/001-press-saas-platform/contracts/press-api.yaml`
- [x] T012 [P] Add healthcheck endpoints for manager and workers (e.g., `/health`) and configure Compose healthchecks
- [x] T013 Configure environment management `.env.example` and `docker/compose.override.yml` for secret injection (documented in `docs/`)
- [x] T047 Reconcile Keycloak port & Press Manager port across spec, plan, and compose files; add validation tests and CI check
- [x] T044 Implement soft-delete lifecycle for sites (FR-014): `press/manager/site_lifecycle.py`, `press/worker/lifecycle_worker.py`, tests `tests/unit/test_site_lifecycle.py` and integration tests


Checkpoint: After these are implemented the infrastructure should stand up locally and the API scaffold should be reachable

---

## Phase 3: User Story 1 - Démarrer l'infrastructure complète (Priority: P1) 🎯 MVP

Goal: 1-command dev experience: `docker compose up -d` boots full stack healthy

Independent Test: `tests/integration/test_boot_stack.py` which runs compose and checks all services become healthy

### Tests for User Story 1 (TDD-first)

- [x] T014 [P] [US1] Add integration test `tests/integration/test_boot_stack.py` asserting `docker compose up -d` and health of services (press-manager, postgres, redis, minio, keycloak, traefik)

### Implementation for User Story 1

- [x] T015 [US1] Implement `docker/compose.yaml` healthchecks and service definitions (fill missing pieces from Phase 1)
- [x] T016 [US1] Implement `press/manager/health.py` and wire into manager `app.py`
- [x] T017 [US1] Add scripted local mapping instructions in `docs/quickstart.md` for hosts and TLS entries

Checkpoint: `docker compose up -d` should bring a healthy stack and `tests/integration/test_boot_stack.py` passes

---

## Phase 4: User Story 2 - Créer un nouveau site Frappe (Priority: P1)

Goal: Admin can create a new Frappe site via Press API and site is reachable

Independent Test: API contract + integration test that posts to `/api/sites` and asserts site exists and is reachable

### Tests for User Story 2 (TDD-first)

- [x] T018 [P] [US2] Add contract test `tests/contract/test_create_site.py` validating OpenAPI `POST /api/sites` behavior
- [x] T019 [US2] Add integration test `tests/integration/test_create_site_flow.py` that exercises create → schema create → site runner start → site reachable

### Implementation for User Story 2

- [x] T020 [P] [US2] Implement `press/manager/api/sites.py` POST handler to validate request and enqueue provisioning job
- [x] T021 [US2] Implement `press/worker/provision.py` worker that creates Postgres schema using `press/tools/schema_manager.py` and initializes site files
- [x] T022 [US2] Implement site runner template under `docker/press/bench/` which knows how to run a Frappe site with given schema
- [x] T023 [US2] Add database migration runner `press/tools/migrate.py` able to run Frappe migrations in a target schema
- [x] T024 [US2] Add tests for schema manager `tests/unit/test_schema_manager.py` (create, exists, drop)

Checkpoint: Site creation flow should be covered by contract and integration tests and be demonstrable locally

---

## Phase 5: User Story 3 - Authentification SSO via Keycloak (Priority: P2)

Goal: Users can authenticate via Keycloak OIDC; fallback to local auth when Keycloak is down

Independent Test: Contract/integration tests that perform OIDC flow and fallback scenario

### Tests for User Story 3 (TDD-first)

- [x] T025 [P] [US3] Add contract test `tests/contract/test_sso_oidc.py` for OIDC endpoints and expected responses
- [x] T026 [US3] Add integration test `tests/integration/test_sso_fallback.py` simulating Keycloak down -> local auth used

### Implementation for User Story 3

- [x] T027 [P] [US3] Implement Keycloak realm config and press `press/integrations/keycloak.py` (setup OIDC client)
- [x] T028 [US3] Implement manager login endpoints to redirect to Keycloak and handle callbacks `press/manager/auth.py`
- [x] T029 [US3] Add fallback login flow `press/manager/auth_local.py` that activates when Keycloak unreachable

Checkpoint: OIDC flow validated and local fallback works when Keycloak unreachable

---

## Phase 6: User Story 4 - Stockage S3 pour les fichiers (Priority: P2)

Goal: Files uploaded to Frappe sites are stored in MinIO

Independent Test: Integration test uploading a file to a site and verifying object in MinIO

### Tests for User Story 4 (TDD-first)

- [x] T030 [P] [US4] Add integration test `tests/integration/test_file_upload_minio.py` that uploads to a site and checks MinIO bucket

### Implementation for User Story 4

- [x] T031 [US4] Configure Frappe site template to use MinIO via `press/bench/minio_config.py` and ensure credentials come from `.env`
- [x] T032 [US4] Add MinIO bucket creation script in `press/tools/minio_client.py` and ensure bucket policy for uploads
- [x] T033 [US4] Add unit tests for MinIO client wrapper `tests/unit/test_minio_client.py`

Checkpoint: Files saved to MinIO and retrievable; tests verify this

---

## Phase 7: User Story 5 - Backup automatique des sites (Priority: P3)

Goal: Daily backups of each site's schema + files to MinIO, restore within 30-day retention

Independent Test: Integration tests schedule and trigger backup, restore, and retention pruning

### Tests for User Story 5 (TDD-first)

- [x] T034 [P] [US5] Add integration test `tests/integration/test_backup_and_restore.py` that triggers backup, verifies object in MinIO, simulates restore, and verifies retention

### Implementation for User Story 5

- [x] T035 [P] [US5] Implement `press/worker/backup.py` to perform per-schema pg_dump and upload to MinIO
- [x] T036 [US5] Implement restore functionality `press/worker/restore.py` to run per-schema restore from MinIO
- [x] T037 [US5] Implement scheduled job `press/cron/backup_scheduler.py` and retention pruning job `press/cron/prune_backups.py`

Checkpoint: Backups created daily, retained 30 days, restore works for soft-deleted sites

---

## Phase 8: Polish & Cross-Cutting Concerns

- [x] T038 [P] Add comprehensive integration CI workflow `/.github/workflows/integration.yml` that runs smoke tests against docker-compose
- [x] T038b [P] Add full live integration CI `/.github/workflows/integration-live.yml` that boots compose and runs integration + e2e tests against real containers
- [x] T039 [P] Add logging and monitoring scaffolding `press/monitoring/` (health & simple metrics)
- [x] T040 [P] Add documentation polish: finalize `specs/001-press-saas-platform/quickstart.md`, `README.md`, and operator playbooks
- [x] T041 Add end-to-end acceptance tests `tests/e2e/test_create_site_to_backup_to_restore.py`
- [x] T041b Add live e2e tests and site-runner scaffolding (tests/e2e/test_site_live.py, docker/press/bench)
- [x] T045 [P] Add secret-management checks and Docker secrets guidance for production (move from .env to Docker secrets) and CI validation
- [x] T046 [P] Decide Grafana policy: add Grafana service and dashboards OR update constitution to remove Grafana; add validation task
- [x] T049 [P] [Performance] Add boot time performance test `tests/performance/test_boot_time.py` validating NFR-001 (all containers healthy within 2 minutes)
- [x] T050 [P] [Performance] Add multi-site load test `tests/performance/test_multi_site_load.py` validating NFR-002 (10+ concurrent sites with acceptable performance)

---

## Phase 9: Edge Case Handling (MVP-Critical)

Purpose: Handle critical edge cases affecting data integrity and system stability

### Tests for Edge Cases (TDD-first)

- [x] T051 [P] [Edge] Add unit test `tests/unit/test_postgres_startup_retry.py` for Press Manager startup behavior when PostgreSQL is initially unavailable
- [x] T052 [P] [Edge] Add unit test `tests/unit/test_duplicate_site_name.py` for duplicate site name handling (expect 409 Conflict)

### Implementation for Edge Cases

- [x] T053 [Edge] Implement PostgreSQL connection retry logic in `press/manager/db_connection.py` with exponential backoff (max 5 retries, 2s initial delay)
- [x] T054 [Edge] Implement duplicate site name validation in `press/manager/api/sites.py` — check schema existence before creating, return HTTP 409 with clear error

---

## Phase 10: Edge Case Handling (Deferrable)

Purpose: Handle non-critical edge cases improving robustness (not MVP blockers)

### Tests for Deferrable Edge Cases (TDD-first)

- [x] T055 [P] [Edge] Add integration test `tests/integration/test_minio_quota_exceeded.py` for MinIO quota handling
- [x] T056 [P] [Edge] Add unit test `tests/unit/test_orphan_container_cleanup.py` for orphan container detection

### Implementation for Deferrable Edge Cases

- [x] T057 [Edge] Implement MinIO quota error handling in `press/tools/minio_client.py` — detect S3 quota errors, raise custom `StorageQuotaExceededError`
- [x] T058 [Edge] Implement orphan container cleanup utility in `press/tools/container_cleanup.py` — list orphaned `fcs-press-site-*` containers, provide dry-run and force modes
- [x] T059 [Edge] Add integration test `tests/integration/test_keycloak_fallback_live.py` for live Keycloak fallback scenario (stop Keycloak container during test)

---

## Phase 11: Performance & Observability Remediation

Purpose: Close performance checklist gaps (CHK001-CHK035) identified in hive-mind remediation analysis

**Context**: Constitution v1.1.0 added 10 new sections addressing performance SLA, edge cases, observability, and operational requirements. This phase implements those constitutional principles.

**Documentation**: See `/docs/hive-mind-remediation/` for gap analysis, traceability matrix, and test suite design.

### Documentation Tasks

- [x] T060 [P2] [Performance] Create workload profile documentation in `docs/performance/workload-profiles.md` — define measurable workload characteristics for "10+ sites" requirement: average/peak requests per site, background job concurrency, site footprint, user behavior patterns (addresses CHK007)

- [x] T061 [P2] [Performance] Define RTO/RPO metrics in `docs/operations/backup-sla.md` — specify RTO < 15 minutes, RPO 24-hour max, backup success rate 99%, alert thresholds for failed backups (addresses CHK004, CHK010)

- [x] T062 [P2] [Performance] Document failure scenarios in `docs/operations/failure-scenarios.md` — define expected behavior for postgres unavailable (retry 5x), MinIO unavailable (queue uploads, 5min retry), Keycloak unavailable (local auth fallback), slow startup >2min (log timing, alert operator) (addresses CHK003)

- [x] T063 [P3] [Operations] Create sizing guide in `docs/operations/sizing-guide.md` — provide host sizing recommendations: Dev (4 cores, 8GB RAM, 50GB disk for 1-3 sites), Staging (8 cores, 16GB RAM, 200GB for 5-10 sites), Production (16 cores, 32GB RAM, 500GB SSD for 10+ sites), per-site incremental costs (addresses CHK006)

- [x] T064 [P2] [Operations] Create operator playbooks in `docs/operations/playbooks/` — recovery and scaling procedures: `restore-from-backup.md` (step-by-step site restoration), `scale-hosts.md` (detecting and remediating overload), `troubleshoot-boot.md` (debugging slow or failed boot) (addresses CHK019, CHK024)

- [x] T065 [P3] [Performance] Document environment criteria in `docs/performance/environment-criteria.md` — distinguish performance expectations by environment: Dev (boot <3min, 1-3 sites max, no backup SLA), Staging (boot <2min, 5-10 sites, daily backups no SLA), Production (boot <2min, 10+ sites, backup SLA 99%) (addresses CHK015)

- [x] T066 [P3] [Performance] Document env differences in `docs/operations/environment-differences.md` — clarify resource allocation assumptions: Dev (smaller instances, `.env.override` for local tuning), Production (full resources, Docker secrets instead of `.env`), Staging (mid-tier, production-like config) (addresses CHK030)

### Testing Tasks (TDD-first)

- [x] T067 [P2] [Edge] Add test `tests/integration/test_minio_unavailable_on_create.py` — validate graceful handling when MinIO is down: stop MinIO container, attempt site creation via Press API, assert site creation fails with clear error, assert no orphaned containers or schemas, restart MinIO and retry successfully (addresses CHK003, CHK018)

- [x] T068 [P2] [Edge] Add test `tests/integration/test_backup_failure_retry.py` — validate backup retry and alerting: create site with data, simulate MinIO failure (stop container or inject error), trigger backup job, assert backup retries (at least 3 attempts), assert alert logged or metric updated after final failure, restore MinIO and assert next backup succeeds (addresses CHK020)

- [x] T069 [P2] [Edge] Add test `tests/integration/test_disk_exhaustion.py` — validate behavior when host runs out of disk: create Docker volume with size limit (e.g., 100MB), create site and fill volume with large files, assert site enters read-only or degraded mode, assert clear error message logged, assert queue backpressure or throttling applied (addresses CHK021)

- [x] T070 [P2] [Edge] Add test `tests/integration/test_concurrent_schema_migrations.py` — validate multi-tenancy edge case: create 3 sites concurrently, trigger Frappe migrations on all 3 schemas simultaneously, assert no schema name collisions, assert no cross-schema lock conflicts, assert all migrations complete successfully (addresses CHK022)

- [x] T071 [P2] [Performance] Add test `tests/performance/test_burst_traffic.py` — validate alternate scenario (spike load): create 5 sites, send 1000 requests in 10 seconds (100 req/s spike), measure P95 response time/error rate/recovery time, assert P95 <1s during spike and <5% errors, assert system recovers to normal latency within 30s (addresses CHK017)

- [x] T072 [P2] [Performance] Add test `tests/performance/test_backup_rto.py` — measure restore time against RTO target: create site with known dataset (e.g., 1000 records), trigger backup, delete site (soft-delete), measure time to restore from backup, assert restore completes in <15 minutes (RTO), assert all data intact after restore (addresses CHK004)

### Implementation Tasks

- [x] T073 [P2] [Observability] Implement Prometheus metrics in `press/monitoring/metrics.py` — expose /metrics for Prometheus scraping: install prometheus_client library, expose metrics (site_count, request_latency_seconds histogram, backup_success_total counter, backup_failure_total counter), add /metrics endpoint to press-manager app, document metrics in `press/monitoring/README.md` (addresses CHK005, CHK025)

- [x] T074 [P2] [Observability] Implement structured logging in `press/common/logging.py` — standardize log format across services: use Python's structlog library, JSON format `{"timestamp": "ISO8601", "level": "INFO", "service": "press-manager", "message": "...", "context": {...}}`, configure all services to use structured logger, document in `docs/operations/logging-standard.md` (addresses CHK026)

- [x] T075 [P3] [Security] Implement secrets rotation in `scripts/rotate_secrets.py` — automate credential rotation for production: script to rotate POSTGRES_PASSWORD, MINIO_ROOT_PASSWORD, KEYCLOAK_ADMIN_PASSWORD, update Docker secrets atomically, rolling restart of affected services, validate connectivity after rotation, document rotation policy in `docs/operations/secrets-rotation.md` (addresses CHK027)

- [x] T076 [P2] [Operations] Add consistency validation in `scripts/validate_consistency.sh` — cross-check NFR values across spec/plan/tasks/compose: parse spec.md, plan.md, tasks.md, compose.yaml, extract boot time target/site count target/port allocations, assert all documents have consistent values, run in CI as pre-commit hook (addresses CHK011)

- [x] T077 [P3] [Operations] Add schedule conflict checker in `scripts/check_schedule_conflicts.py` — validate no overlapping scheduled jobs: parse cron schedules from backup_scheduler.py and prune_backups.py, check for time conflicts (e.g., both run at 02:00), alert if overlap detected, document in `docs/operations/scheduling.md` (addresses CHK032)

### Sprint Breakdown

**Sprint 1 (Week 1) - MVP Critical** (9 tasks, 36 hours):
- Documentation: T061, T062, T064 (8h)
- Testing: T067, T072, T076 (12h)
- Implementation: T073, T074 (16h)
- Coverage Target: 60% (21/35 CHK items)

**Sprint 2 (Weeks 2-3) - Quality Improvements** (6 tasks, 22 hours):
- Documentation: T060, T063 (6h)
- Testing: T068, T069, T070, T071 (16h)
- Coverage Target: 74% (26/35 CHK items)

**Sprint 3 (Month 2) - Polish & Automation** (4 tasks, 16 hours):
- Documentation: T065, T066 (4h)
- Implementation: T075, T077 (12h)
- Coverage Target: 86% (30/35 CHK items)

**Team Allocation**:
- Sprint 1: 3 people (Developer 1: T073/T074, Developer 2: T067/T072/T076, Technical Writer: T061/T062/T064)
- Sprint 2: 2 people (Developer 1: T068/T069/T070, Developer 2: T071/T060/T063)
- Sprint 3: 1 person (DevOps Engineer: T075/T077/T065/T066)

Checkpoint: After Phase 11, all 35 CHK items from performance checklist are addressable via Constitution v1.1.0 and implemented/tested per sprint plan

---

## Dependencies & Execution Order

- Foundation (Phase 2) MUST finish before user stories begin (Phase 3+). Tests are written first and should fail.
- Parallel opportunities: many [P] tasks across phases can be implemented in parallel by different team members.

---

## Notes

- Each task mentions an exact file path so work can be started without further clarification
- Tests are prefixed and added before implementation tasks (TDD-first)
- After implementing tasks for each story, run the associated tests and CI to validate
