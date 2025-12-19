# Data Model — Press SaaS Platform

Generated: 2025-12-08

## Overview
This document describes the main domain entities for Press and how they map to database objects. The platform follows a schema-per-site model on PostgreSQL 16.

## Primary Entities

### Site
- Description: A hosted Frappe/ERPNext site managed by Press.
- Storage: Frappe content lives in its own Postgres schema and a files bucket in MinIO.
- Key attributes:
  - id: uuid (Press-managed identifier)
  - name: string (unique per account and used for URL/subdomain)
  - display_name: string
  - domain: string (e.g., site.example.com or {site}.localhost)
  - schema_name: string (the Postgres schema allocated)
  - status: enum [provisioning, running, healthy, failed, soft_deleted, deleted]
  - created_at: timestamp
  - deleted_at: timestamp | null
  - retention_until: timestamp | null (used when soft_deleted)
  - apps: list[string] (apps installed like erpnext)
  - config: jsonb (site-specific configuration passed to Frappe)
- Indexes: unique(name), index(schema_name)

### TenantSchema
- Description: Low-level representation of the DB schema for a Site. Maps schema_name → metadata.
- Key attributes:
  - schema_name: string (primary key)
  - owner_role: string (postgres role)
  - created_at: timestamp
  - last_backup_at: timestamp | null
  - size_bytes: bigint

### Backup
- Description: Metadata for a per-site backup (schema dump + files snapshot in MinIO).
- Key attributes:
  - id: uuid
  - site_id: uuid (FK to Site)
  - backup_time: timestamp
  - object_key: string (minio path or object locator)
  - type: enum [full, incremental]
  - status: enum [pending, success, failed]
  - size_bytes: bigint
- Indexes: index(site_id, backup_time)

### User (Press admin accounts)
- Description: Users who can create/manage Sites.
- Attributes: id, email, name, role (admin/operator/dev), created_at, last_login
- Authentication: prefers OIDC (Keycloak) — fallback local password stored in Frappe-managed auth tables

### WorkerJob
- Description: Background job records for site provisioning, backup, restore, and other long tasks
- Attributes: id, type, site_id, status, started_at, completed_at, logs (text), attempts

## State transitions (important)
- Site provisioning: (new) -> provisioning -> running -> healthy
- Failures: provisioning -> failed (needs operator action)
- Deletion lifecycle: running -> soft_deleted (deleted_at set) -> deleted (after retention expires)
- Restore workflow: soft_deleted + backup available -> restoring -> running

## Validation rules
- Site.name must be ASCII-safe, DNS-safe, and unique per deployment
- schema_name must be sanitized and unique
- backups cannot be removed before retention policy expiry

## Notes on tenancy
- Every site is associated with a separate Postgres schema. Frappe migrations and operations are executed against that schema.
- The Press manager only needs a single Postgres connection but must be capable of switching schema contexts and running schema-level SQL and migrations.

## Data retention & backups
- Daily backups for every site at configured window
- Backups stored in MinIO and tagged by site_id and timestamp
- Backups retained for 30 days by default; policy configurable per deployment


For more details about operations (provisioning, backup/restore), see plan.md and the tasks in tasks.md.