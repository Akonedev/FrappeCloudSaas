# Press SaaS Platform Constitution

<!--
═══════════════════════════════════════════════════════════════
SYNC IMPACT REPORT
═══════════════════════════════════════════════════════════════

VERSION CHANGE: 1.0.0 → 1.1.0 (MINOR - Performance & Edge Case Enhancement)

MODIFIED PRINCIPLES:
  ✅ VI. Observability - Expanded with detailed performance SLA, telemetry, and degradation modes
  ✅ II. Tenancy & Data Model - Enhanced with backup quality metrics and edge case handling
  ✅ Deployment & Operations - Added environment sizing and operational runbooks

ADDED SECTIONS (v1.1.0):
  ✅ Resource Sizing (under Performance SLA)
  ✅ Latency & Throughput Targets (under Performance SLA)
  ✅ Multi-Tenancy Edge Cases (under Tenancy & Data Model)
  ✅ Backup Quality Metrics (under Backup & Recovery)
  ✅ Backup Failure Handling (under Backup & Recovery)
  ✅ Telemetry & Tracing (under Observability)
  ✅ Graceful Degradation (under Observability)
  ✅ Environment Sizing (under Environment Parity)
  ✅ Environment-Specific Acceptance Criteria (under Environment Parity)
  ✅ Operational Runbooks (under Monitoring & Alerting)

REMOVED SECTIONS:
  - None (initial creation)

TEMPLATES REQUIRING UPDATES:
  ✅ .specify/templates/plan-template.md
     - "Constitution Check" section (line 30) references constitution file
     - Template already compatible with principles
     - No updates required

  ✅ .specify/templates/spec-template.md
     - "Technical Constraints" section compatible with tech stack requirements
     - User story structure aligns with "Independent User Stories" principle
     - No updates required

  ✅ .specify/templates/tasks-template.md
     - Phase structure already aligns with TDD principle
     - Task organization supports parallel development principle
     - Test-first emphasis compatible with testing requirements
     - No updates required

  ✅ .claude/commands/*.md
     - Reviewed all command files for agent-specific references
     - Generic guidance maintained throughout
     - No CLAUDE-only references requiring updates

FOLLOW-UP TODOS:
  - None (all placeholders filled, all templates validated)

COMPLIANCE VALIDATION:
  ✅ No remaining bracket tokens ([PLACEHOLDER_NAME])
  ✅ Version matches report: 1.0.0
  ✅ Dates in ISO format: 2025-12-12
  ✅ Principles declarative and testable (MUST/RECOMMENDED clearly indicated)
  ✅ No vague language or unexplained exceptions

═══════════════════════════════════════════════════════════════
-->

## Core Principles

### I. Infrastructure Standards

#### Container Naming Convention (MUST)

- All containers MUST use the prefix `fcs-press-*`
- Examples: `fcs-press-postgresql`, `fcs-press-redis`, `fcs-press-traefik`, `fcs-press-keycloak`, `fcs-press-minio`
- No exceptions allowed; all containers must be identifiable at a glance

#### Port Allocation (MUST)

- Reserved port range: **48510-49800**
- No default ports (80, 443, 3000, 5432, etc.) allowed in development
- Port conflicts MUST be validated before deployment
- All port assignments MUST be documented in compose files

#### Technology Stack (MUST)

- PostgreSQL: **16.x only** (NOT MariaDB)
- Redis: **7.x**
- Traefik: **3.x**
- Keycloak: **22.x or higher**
- MinIO: **latest stable**
- Frappe Framework: **v16** (version-16 branch)

### II. Tenancy & Data Model

#### Multi-Tenancy Architecture (MUST)

- Schema-per-site isolation on single PostgreSQL instance
- Each tenant site gets dedicated PostgreSQL schema
- No shared tables between tenant schemas
- Schema naming convention: `site_[sanitized_sitename]`

#### Multi-Tenancy Edge Cases (MUST)

**Schema Name Collisions**:
- Validation: Check schema existence before creation
- Response: HTTP 409 Conflict with error message
- Prevention: Site name sanitization with UUID suffix if needed

**Concurrent Schema Migrations**:
- Locking: PostgreSQL advisory locks per schema during migrations
- Timeout: 5-minute migration lock timeout
- Conflict resolution: Queue pending migrations, process serially

**Per-Schema Restore Conflicts**:
- Validation: Verify target schema is empty or soft-deleted
- Behavior: Refuse restore if active site exists with same name
- Override: Admin-only force flag with confirmation workflow

#### Backup & Recovery (MUST)

- Per-schema backup capability required
- Independent restore operations per tenant
- Daily automated backups with 30-day retention
- Automatic pruning of backups older than 30 days
- Backup verification tests required in CI/CD

#### Backup Quality Metrics (MUST)

**Success Rate Targets**:
- Daily backups: ≥99% success rate over 30-day window
- Restore operations: ≥99% success rate (tested quarterly)

**Observability**:
- Metric: `backup_success_total`, `backup_failure_total` (per site)
- Dashboard: Backup health dashboard showing success rates, failures, retention
- Alerts: Immediate alert if backup fails 3 consecutive times for any site

**Validation**:
- Automated restore testing: Random site restore validation weekly
- Success criteria: Restored site boots and passes health checks

#### Backup Failure Handling (MUST)

- Retry policy: 3 attempts with exponential backoff (5min, 15min, 30min)
- Alert on failure: Immediate notification after 3 failed attempts
- Partial failures: Continue with other sites, log failed sites for manual intervention
- Monitoring: Track backup success rate, alert if < 95% over 7-day window
- Recovery: Manual backup trigger via API endpoint `/api/sites/{id}/backup`

#### Soft-Delete Lifecycle (MUST)

- Deleted sites retained for **30 days** in soft-deleted state
- Grace period allows customer-initiated recovery
- Permanent deletion occurs automatically after 30-day retention
- Recovery operations MUST be tested and documented

### III. Security & Authentication

#### Single Sign-On (MUST)

- Keycloak OAuth2/OIDC for centralized authentication
- SSO integration with Frappe Framework required
- Session management via Keycloak tokens

#### Authentication Fallback (MUST)

- Automatic fallback to local Frappe authentication when Keycloak unavailable
- Graceful degradation without service interruption
- Health check monitoring for Keycloak availability

#### Secrets Management (MUST)

- Development: `.env` files with `.env.example` template
- Production: Docker secrets or external secret management (Vault, AWS Secrets Manager)
- NO hardcoded credentials in source code or Docker images
- Secrets rotation procedures documented

### IV. Development Methodology

#### Test-Driven Development (MUST - NON-NEGOTIABLE)

- Tests MUST be written before implementation
- Red-Green-Refactor cycle strictly enforced
- No code merges without corresponding tests
- Test coverage minimum: 80% for critical paths

#### Testing Requirements (MUST)

- **Unit Tests**: Isolated component testing
- **Integration Tests**: Service-to-service interactions, database operations, API contracts
- **Acceptance Tests**: End-to-end user workflows, smoke tests, deployment validation

#### CI/CD Integration (MUST)

- Automated test execution on every commit
- Smoke tests for basic functionality
- Integration tests for service dependencies
- Failed tests block deployment pipeline

### V. API & Documentation

#### API Contract (MUST)

- OpenAPI 3.0/Swagger specification for Press Manager API
- Contract-first development approach
- API versioning with backward compatibility guarantees
- Contract tests validate implementation against specification

#### Documentation Standards (MUST)

- Quickstart guide for new developers
- Operator playbooks for common tasks
- Architecture decision records (ADRs) for significant choices
- API documentation auto-generated from OpenAPI spec

### VI. Observability

#### Health Checks (MUST)

All critical services MUST expose health endpoints:

- `fcs-press-postgresql`: Connection pool status, query responsiveness
- `fcs-press-redis`: PING response
- `fcs-press-traefik`: Routing table readiness
- `fcs-press-keycloak`: Realm availability, token validation
- `fcs-press-minio`: Bucket accessibility

Health check failures trigger alerts.

#### Telemetry & Tracing (MUST)

**Metrics Collection**:
- Prometheus-compatible metrics endpoints on all services
- Required metrics: `http_requests_total`, `http_request_duration_seconds`, `db_connection_pool_size`, `background_job_queue_depth`
- Metric retention: 30 days minimum
- Cardinality limits: < 10,000 unique metric series per service

**Tracing**:
- Distributed tracing with OpenTelemetry for cross-service requests
- Trace sampling rate: 10% in production, 100% in development
- Trace retention: 7 days

**Dashboards**:
- Pre-built Grafana dashboards for service health, site performance, resource utilization
- Dashboard definitions versioned in `docker/press/grafana/dashboards/`

#### Graceful Degradation (MUST)

**Disk Space Exhaustion** (>90% usage):
- Action: Switch sites to read-only mode
- Behavior: Block uploads, site creation, backups
- Recovery: Automatic restoration when usage drops below 85%

**Memory Pressure** (>90% usage):
- Action: Apply backpressure to background job queues
- Behavior: Pause non-critical jobs, prioritize user requests
- Recovery: Resume jobs when usage drops below 80%

**Database Connection Pool Exhaustion**:
- Action: Return HTTP 503 with `Retry-After` header
- Behavior: Reject new connections, preserve existing sessions
- Recovery: Automatic when connections available

#### Logging Standards (MUST)

- Structured logging in JSON format
- Logs accessible via `docker compose logs [service]`
- Log levels: DEBUG, INFO, WARN, ERROR, FATAL
- Sensitive data (passwords, tokens) MUST NOT be logged

#### Performance SLA (MUST)

- Boot time: Complete stack operational within **2 minutes**
- Response time: API endpoints < 200ms (p95)
- Database query performance monitoring
- Resource limits defined for all containers

#### Resource Sizing (MUST)

- Minimum host requirements: 8 CPU cores, 32GB RAM for 10 concurrent sites
- Per-site resource allocation: 0.5 CPU cores, 2GB RAM (average)
- Peak load assumptions: 50 req/sec per site, 5 concurrent background jobs
- Test scenario: `tests/performance/test_multi_site_load.py` validates 10+ sites

#### Latency & Throughput Targets (MUST)

**API Endpoints**:
- Site creation: < 2 minutes (P95)
- Site dashboard load: < 200ms (P95)
- File upload (10MB): < 5 seconds (P95)

**Background Workers**:
- Job pickup latency: < 5 seconds
- Backup job duration: < 15 minutes per site (P95)
- Migration job duration: < 10 minutes (P95)

**Database Queries**:
- Read queries: < 50ms (P95)
- Write queries: < 100ms (P95)
- Connection acquisition: < 100ms (P95)

---

## Deployment & Operations

### Environment Parity

#### Development-Production Parity (MUST)

- Development environment mirrors production configuration
- Same container images used in all environments
- Environment-specific configuration via environment variables only
- No "works on my machine" exceptions

#### Environment Sizing (MUST)

**Development Environment**:
- Minimum: 4 CPU cores, 16GB RAM
- Supports: 3-5 test sites concurrently
- Container resource limits: 50% of production allocations

**Production Environment**:
- Minimum: 16 CPU cores, 64GB RAM (for 10+ sites)
- Scaling guidance: Add 0.5 CPU cores + 2GB RAM per additional 2 sites
- Container resource limits defined in compose files

#### Environment-Specific Acceptance Criteria (MUST)

**Development Environment**:
- Boot time: < 3 minutes (relaxed)
- API latency: < 500ms (P95, acceptable for local debugging)
- Resource constraints: Minimal for laptop/desktop development

**Staging Environment**:
- Boot time: < 2 minutes (production-equivalent)
- API latency: < 200ms (P95, matches production)
- Resource constraints: Production-equivalent sizing

**Production Environment**:
- Boot time: < 2 minutes (strict enforcement)
- API latency: < 200ms (P95, SLA commitment)
- Resource constraints: Full production sizing with headroom

### Deployment Process

#### Blue-Green Deployment (RECOMMENDED)

- Zero-downtime deployments for production
- Health check validation before traffic switching
- Automated rollback on deployment failures

#### Database Migrations (MUST)

- Forward-only migrations required
- Migration rollback procedures documented
- Migrations tested in staging before production
- Schema changes backward compatible for one release cycle

### Monitoring & Alerting

#### Metrics Collection (MUST)

- Container resource utilization (CPU, memory, disk)
- Application metrics (request rate, error rate, latency)
- Database metrics (connections, query performance)
- Business metrics (sites created, active users)

#### Alert Thresholds (MUST)

- Service unavailability: Immediate alert
- Error rate > 5%: Warning alert
- Response time > 1s (p95): Warning alert
- Disk usage > 80%: Warning alert

#### Operational Runbooks (MUST)

**Required Playbooks** (location: `docs/playbooks/`):
1. **Overload Detection & Remediation**:
   - Trigger: CPU > 80%, memory > 85%, disk > 80%
   - Actions: Scale horizontally (add worker nodes), throttle background jobs
   - Metrics: Monitor `node_cpu_usage`, `node_memory_usage`, `disk_usage_percent`

2. **Scaling Procedures**:
   - Horizontal: Add worker nodes via Docker Swarm or Kubernetes scaling
   - Vertical: Resize containers (requires downtime, use maintenance window)
   - Database: Connection pool tuning, read replicas for heavy read loads

3. **Incident Response**:
   - Service down: Automated restart via health check failures
   - Data corruption: Restore from most recent backup (documented in playbook)
   - Security breach: Rotate all secrets, audit logs, notify affected users

---

## Quality Gates

### Code Review Requirements

#### Pull Request Standards (MUST)

All code changes via pull requests with minimum one approving review required.
CI/CD checks MUST pass before merge.

PR description includes:

- Purpose and context
- Testing performed
- Breaking changes (if any)

#### Review Checklist (MUST)

- [ ] Tests written and passing
- [ ] API contract compliance verified
- [ ] Security considerations addressed
- [ ] Documentation updated
- [ ] No hardcoded secrets
- [ ] Container naming conventions followed
- [ ] Port allocations within valid range

### Testing Gates

#### Pre-Merge Requirements (MUST)

- All unit tests pass
- Integration tests pass
- Code coverage threshold met (80%)
- No critical security vulnerabilities (from scanning tools)

#### Pre-Deployment Requirements (MUST)

- Smoke tests pass in staging
- Performance benchmarks within SLA
- Database migration successful
- Rollback procedure tested

---

## Governance

### Constitutional Authority

This Constitution supersedes all other development practices, guidelines, and conventions. Any conflicts between this Constitution and other documentation MUST be resolved in favor of the Constitution.

### Amendment Process

#### Proposing Amendments

1. Document rationale in Architecture Decision Record (ADR)
2. Demonstrate impact on existing systems
3. Provide migration plan for breaking changes
4. Obtain approval from technical leadership

#### Amendment Approval

- Consensus required from core maintainers
- Public comment period (minimum 7 days)
- Breaking changes require major version bump
- All amendments documented with ratification date

### Compliance Enforcement

#### Continuous Validation (MUST)

- Automated compliance checks in CI/CD pipeline
- Container name validation via `scripts/validate_container_names.sh`
- Port allocation validation via `scripts/validate_production_images.sh`
- API contract validation via OpenAPI schema tests

#### Non-Compliance Handling

- CI/CD blocks non-compliant code from merging
- Existing non-compliance tracked in technical debt backlog
- Remediation plans required for constitutional violations
- Exceptions require documented justification and time-bound resolution

### Constitutional Review

- Quarterly review of constitutional principles
- Annual comprehensive review and update
- Community feedback incorporated in amendments
- Version history maintained in git

---

**Version**: 1.1.0 | **Ratified**: 2025-12-12 | **Last Amended**: 2025-12-12 | **Amendment**: Added performance SLA details, edge case handling, observability requirements, and operational runbooks
