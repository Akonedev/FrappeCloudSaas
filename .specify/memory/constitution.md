<!--
Sync Impact Report:
- Version change: 0.0.0 → 1.0.0
- Initial constitution creation
- All placeholders replaced
- Follow-up TODOs: None
-->

# Press SaaS Platform Constitution

## Core Principles

### I. Docker-First Infrastructure
All services MUST be containerized using Docker/Podman Compose. No bare-metal installations.
- Every component runs as a container with defined resource limits
- Container naming convention: `fcs-press-{service-name}`
- Network isolation between frontend, backend, database, and monitoring layers
- All images MUST specify explicit versions (no `:latest` tags in production)

### II. Port Range Compliance
All external ports MUST be in the range **48510-49800** to avoid conflicts with other services.
- Traefik entrypoint: 48580 (HTTP), 48543 (HTTPS)
- PostgreSQL: 48532 (internal only)
- Redis: 48579 (cache), 48511 (queue)
- Grafana: 48530
- MinIO: 48590 (API), 48591 (Console)

### III. Configuration via Environment
All secrets and configuration MUST be externalized via environment variables or Docker secrets.
- NO hardcoded credentials in source code
- `.env.example` MUST document all required variables
- Secrets MUST use Docker secrets in production (not env vars)
- Configuration files use `${VAR:-default}` syntax

### IV. Technology Stack (NON-NEGOTIABLE)
- **Framework**: Frappe v16 (version-16 branch)
- **Database**: PostgreSQL 16 (`db_type: postgres` per official Frappe docs)
- **Cache/Queue**: Redis 7.x
- **Reverse Proxy**: Traefik 3.x with automatic HTTPS
- **Object Storage**: MinIO (S3-compatible)
- **SSO**: Keycloak 22.x+ (OAuth2/OIDC)
- **Billing**: Stripe API (test mode for dev)
- **Runtime**: Python 3.11, Node.js 18.x

### V. Documentation Required
Every feature MUST have:
- spec.md: What and why (requirements)
- plan.md: How (architecture decisions)
- tasks.md: Implementation steps
- quickstart.md: Getting started guide
- README.md: Overview and usage

### VI. Observability & Debugging
All containers MUST expose:
- Health check endpoints (`/health` or equivalent)
- Structured JSON logging to stdout/stderr
- Prometheus metrics where applicable
- Log aggregation via Loki/Promtail

### VII. Test-Driven Development
- Tests MUST be written BEFORE implementation code
- Minimum 80% code coverage for new features
- Contract tests for API endpoints
- Integration tests for multi-service flows

## Security Requirements

- All external traffic MUST use TLS (mkcert for dev, Let's Encrypt for prod)
- OAuth2/OIDC for authentication (Keycloak)
- Network isolation: database network MUST be internal-only
- Secrets rotation policy: 90 days maximum
- OWASP Top 10 compliance mandatory

## Performance Standards

- Site creation: < 5 minutes end-to-end
- Dashboard response: P95 < 2 seconds
- Concurrent site creation: 5 sites/minute minimum
- Database queries: < 100ms for list operations
- 99.9% uptime target (30-day rolling window)

## Development Workflow

1. **Specification**: Define requirements in `specs/` directory
2. **Planning**: Create implementation plan with architecture decisions
3. **Tasks**: Break down into atomic, testable tasks
4. **Implementation**: TDD cycle (Red → Green → Refactor)
5. **Review**: PR with checklist validation
6. **Validation**: End-to-end testing before merge

## Governance

- This constitution supersedes all other development practices
- Amendments require:
  - Documentation of change rationale
  - Version increment (semantic versioning)
  - Migration plan for breaking changes
- All PRs MUST verify compliance with these principles
- Deviations require explicit justification and approval

**Version**: 1.0.0 | **Ratified**: 2025-12-07 | **Last Amended**: 2025-12-07
