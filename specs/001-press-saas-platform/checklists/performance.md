# Non-Functional / Performance Checklist — Press SaaS Platform

**Feature**: 001-press-saas-platform
**Domain**: Non-Functional / Performance
**Audience**: PR Reviewers
**Depth**: Deep
**Generated**: 2025-12-08

This checklist validates the *quality of the written requirements* for performance, boot-time, scalability, observability, backups and operability. The checks below do not test implementation — they test whether the requirements themselves are complete, clear, measurable, and unambiguous.

IDs increment from CHK001.

## Requirement Completeness

- [ ] CHK001 - Are measurable startup-time targets specified for the whole stack and for critical services (e.g., "All containers start and become healthy in < 2 minutes")? [Completeness, Spec §NFR-001, FR-001]
- [ ] CHK002 - Is the performance requirement for supporting at least 10 simultaneous sites specified with measurable constraints (e.g., CPU cores/site, memory/site, test artifact describing scenario and data volume)? [Completeness, Spec §NFR-002]
- [ ] CHK003 - Are failure/slow-path acceptance criteria defined for boot failures and long-startup situations (e.g., when Postgres or MinIO are slow/unavailable)? [Completeness, Edge Cases]
- [ ] CHK004 - Are the retention and RTO/RPO requirements for backups fully specified (daily schedule, 30-day retention, expected restore time and success criteria)? [Completeness, Spec §FR-015, FR-010]
- [ ] CHK005 - Are observability requirements present for metrics and tracing (what metrics, endpoints, cardinality, retention and dashboards can be expected)? [Completeness, Spec §Observability]
- [ ] CHK006 - Are resource constraints and sizing guidance for production and dev environments specified (e.g., host sizing to support 10+ sites)? [Completeness, NFR-002]

## Requirement Clarity

- [ ] CHK007 - Is the term "support at least 10 sites" quantified with a workload profile (e.g., expected average and peak requests per site, background job concurrency, average site footprint)? [Clarity, Spec §NFR-002]
- [ ] CHK008 - Is the meaning of "healthy" for each service defined precisely (HTTP 200 on /health, DB pg_isready, MinIO health endpoint, Keycloak readiness)? [Clarity, Spec §FR-009]
- [ ] CHK009 - Are SLA-like targets (P95 latency goals, acceptable background-worker throughput, resource budget) defined for critical paths such as site creation and dashboard requests? [Clarity, NFRs]
- [ ] CHK010 - Is the acceptable backup & restore success rate defined (e.g., 99% successful restores in typical conditions) and how failures are surfaced/observed? [Clarity, FR-015]

## Requirement Consistency

- [ ] CHK011 - Are all non-functional sizing/scale requirements consistent across `spec.md`, `plan.md` and `tasks.md` (no conflicting numbers for site scale or startup times)? [Consistency, Spec vs Plan vs Tasks]
- [ ] CHK012 - Are backup retention/restore windows consistent with the soft-delete lifecycle (30-day retention) and stated restore behavior? [Consistency, Spec §FR-014, FR-015]
- [ ] CHK013 - Is the logging/observability requirement consistent with the stated debugging and recovery workflows (e.g., logs must be available via docker compose logs and integrate with the monitoring plan)? [Consistency, NFR-003]

## Acceptance Criteria Quality

- [ ] CHK014 - Are acceptance criteria measurable and testable (e.g., provide exact thresholds / commands to validate startup < 2 minutes and support for 10 sites)? [Acceptance Criteria, Spec §SC-001, SC-002]
- [ ] CHK015 - Do acceptance criteria specify which environment (dev vs staging vs prod) the metric applies to, and how they differ? [Acceptance Criteria, Spec §Environments]

## Scenario Coverage (Primary/Alternate/Exception/Recovery)

- [ ] CHK016 - Are primary performance scenarios described (normal day-to-day traffic load patterns and background job schedules)? [Coverage]
- [ ] CHK017 - Are alternate scenarios covered (burst traffic, high number of concurrent site creations)? [Coverage]
- [ ] CHK018 - Are exception and recovery scenarios defined and measurable (e.g., lost DB connectivity before boot, MinIO full/quota reached, Keycloak unavailable)? [Coverage, Edge Cases]
- [ ] CHK019 - Are clear recovery acceptance criteria specified and traceable to a playbook (e.g., fast restore from the latest successful daily backup within X minutes)? [Coverage, FR-010/FR-013]

## Edge Case Coverage

- [ ] CHK020 - Is the behavior defined when backups fail for a site during scheduled windows (retries, alerts, partial failures)? [Edge Case, FR-015]
- [ ] CHK021 - Is the expected behavior defined if the host runs out of disk/IO resources (site read-only, degraded mode, queue backpressure)? [Edge Case]
- [ ] CHK022 - Are multi-tenancy edge cases enumerated and tested in the requirements (e.g., schema name collisions, concurrent schema migrations, per-schema restore conflicts)? [Edge Case, FR-012]

## Non-Functional Requirements (detailed checks)

- [ ] CHK023 - Is the exact startup timing requirement for the entire stack stated clearly, with an explicit test harness to verify it (e.g., CI smoke test measures time between compose up and all /health endpoints reporting success)? [NFR-001, SC-001]
- [ ] CHK024 - Are runbook/playbook expectations defined for overloaded hosts (how to detect, remediate, and scale; which metrics trigger scaling)? [NFR-002]
- [ ] CHK025 - Are observability & telemetry expectations specified (Prometheus metrics list, tracing, retention, dashboards and required alerts)? [NFR-003]
- [ ] CHK026 - Are logs required to follow structured format and be output to stdout/stderr in production and dev (for docker compose logs and centralized shipping)? [NFR-003]
- [ ] CHK027 - Are secrets and credential rotation policies described for production (how frequently to rotate keys, what to do on compromise)? [NFR-005]
- [ ] CHK028 - Are performance acceptance criteria anchored to measurable units (requests/sec, P95 latency in ms, time-to-create-site in minutes)? [NFRs, SC-001, SC-002]

## Dependencies & Assumptions

- [ ] CHK029 - Are external dependencies (Keycloak, MinIO, external DNS or Let’s Encrypt) listed with required version ranges and expected compatibility constraints? [Dependencies, Spec §Technical Constraints]
- [ ] CHK030 - Are assumptions about developer vs production resource differences documented (e.g., dev uses smaller machines, environment variable overrides allowed)? [Assumptions]

## Ambiguities & Conflicts

- [ ] CHK031 - Are any ambiguous terms used in the NFRs (e.g., "fast", "scalable") accompanied by precise, measurable replacements? [Ambiguity]
- [ ] CHK032 - Are there conflicts between the stated daily backup schedule and any other scheduled maintenance mentioned elsewhere in the plan or tasks? [Conflict]

## Traceability

- [ ] CHK033 - Does each NFR item include at least one direct traceability reference to the spec or plan (e.g., [Spec §NFR-001])? [Traceability]
- [ ] CHK034 - Is there a clear mapping from each non-functional requirement to a test or CI validation (e.g., T014 validates boot-time; performance harness tests for 10+ sites)? [Traceability, Tasks mapping]

## Final checks

- [ ] CHK035 - Is the checklist clear, concise and ready for use by PR reviewers — each question should be answerable by reading the spec/plan/tasks alone? [PR readiness]
