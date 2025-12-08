# Requirements Checklist - Press SaaS Platform

**Feature**: 001-press-saas-platform  
**Generated**: 2025-12-07  
**Status**: Pending Validation

---

## Functional Requirements Validation

| ID | Requirement | Testable | Clear | Status |
|----|-------------|----------|-------|--------|
| FR-001 | Démarrage via `docker compose up -d` | ✅ | ✅ | ⬜ |
| FR-002 | PostgreSQL 16 comme DB | ✅ | ✅ | ⬜ |
| FR-003 | Press sur port HTTPS 48543 | ✅ | ✅ | ⬜ |
| FR-004 | Création sites via Press UI | ✅ | ✅ | ⬜ |
| FR-005 | Stockage fichiers MinIO S3 | ✅ | ✅ | ⬜ |
| FR-006 | Auth Keycloak OAuth2/OIDC | ✅ | ✅ | ⬜ |
| FR-007 | Préfixe containers `fcs-press-*` | ✅ | ✅ | ⬜ |
| FR-008 | Ports dans plage 48510-49800 | ✅ | ✅ | ⬜ |
| FR-009 | Healthchecks services critiques | ✅ | ✅ | ⬜ |
| FR-010 | Backups vers MinIO S3 | ✅ | ✅ | ⬜ |
| FR-011 | Fallback auth local if Keycloak down | ✅ | ✅ | ⬜ |
| FR-012 | Tenancy: schema-per-site on single Postgres server | ✅ | ✅ | ⬜ |
| FR-013 | Backups per-schema (per-site) and restorable independently | ✅ | ✅ | ⬜ |
| FR-014 | Soft-delete lifecycle (30-day retention) | ✅ | ✅ | ⬜ |
| FR-015 | Daily backups with 30-day retention and automatic pruning | ✅ | ✅ | ⬜ |

---

## Non-Functional Requirements Validation

| ID | Requirement | Measurable | Status |
|----|-------------|------------|--------|
| NFR-001 | Démarrage < 2 minutes | ✅ | ⬜ |
| NFR-002 | Support 10+ sites | ✅ | ⬜ |
| NFR-003 | Logs via docker compose | ✅ | ⬜ |
| NFR-004 | Config externalisée .env | ✅ | ⬜ |
| NFR-005 | Gestion secrets | ✅ | ⬜ |

---

## User Stories Coverage

| Story | Priority | Independent | Testable | Status |
|-------|----------|-------------|----------|--------|
| US-1: Démarrer infrastructure | P1 | ✅ | ✅ | ⬜ |
| US-2: Créer site Frappe | P1 | ✅ | ✅ | ⬜ |
| US-3: Auth SSO Keycloak | P2 | ✅ | ✅ | ⬜ |
| US-4: Stockage S3 | P2 | ✅ | ✅ | ⬜ |
| US-5: Backup automatique | P3 | ✅ | ✅ | ⬜ |

---

## Success Criteria Validation

| ID | Criteria | Measurable | Status |
|----|----------|------------|--------|
| SC-001 | Démarrage < 2 min | ✅ | ⬜ |
| SC-002 | Création site < 5 min | ✅ | ⬜ |
| SC-003 | SSO sans config user | ✅ | ⬜ |
| SC-004 | Fichiers dans MinIO | ✅ | ⬜ |
| SC-005 | Backup/Restore sans perte | ✅ | ⬜ |
| SC-006 | Daily backups scheduled + 30-day retention | ✅ | ⬜ |

---

## Edge Cases Identified

- [ ] PostgreSQL indisponible au démarrage
- [ ] Nom de site en double
- [ ] MinIO quota atteint
- [ ] Keycloak down (fallback)
- [ ] Site soft-delete lifecycle/retention (30 days)
- [ ] Sites orphelins

---

## Quality Score

| Criteria | Score |
|----------|-------|
| Requirements testables | 10/10 |
| Requirements clairs | 10/10 |
| User stories indépendantes | 5/5 |
| Success criteria mesurables | 5/5 |
| Edge cases documentés | 5/5 |
| **Total** | **35/35** |

✅ **Specification VALIDATED** - Ready for `/speckit.plan`
