#!/bin/bash
# =============================================================================
# Frappe Cloud - Backup Script
# Backs up sites to MinIO S3
# =============================================================================
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Default values
SITE_NAME="${1:-all}"
BUCKET_NAME="${BUCKET_NAME:-backups}"
MINIO_ALIAS="${MINIO_ALIAS:-local}"

# Banner
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           💾 Frappe Cloud - Backup                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Configure MinIO client
configure_mc() {
    log_info "Configuring MinIO client..."
    podman exec frappe-cloud-minio mc alias set "$MINIO_ALIAS" http://localhost:9000 \
        "${MINIO_ROOT_USER:-minioadmin}" \
        "${MINIO_ROOT_PASSWORD:-minioadmin123}" 2>/dev/null || true
    
    # Create bucket if not exists
    podman exec frappe-cloud-minio mc mb "$MINIO_ALIAS/$BUCKET_NAME" 2>/dev/null || true
}

# Backup a single site
backup_site() {
    local site="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="/home/frappe/frappe-bench/sites/$site/private/backups"
    
    log_info "Backing up site: $site"
    
    # Create backup
    podman exec frappe-cloud-backend bench --site "$site" backup --with-files
    
    # Get latest backup files
    local latest_db=$(podman exec frappe-cloud-backend ls -t "$backup_dir"/*.sql.gz 2>/dev/null | head -1)
    local latest_files=$(podman exec frappe-cloud-backend ls -t "$backup_dir"/*-files.tar 2>/dev/null | head -1)
    local latest_private=$(podman exec frappe-cloud-backend ls -t "$backup_dir"/*-private-files.tar 2>/dev/null | head -1)
    
    # Copy to MinIO
    if [ -n "$latest_db" ]; then
        log_info "Uploading database backup..."
        podman cp "frappe-cloud-backend:$latest_db" "/tmp/${site}_${timestamp}_db.sql.gz"
        podman exec frappe-cloud-minio mc cp "/tmp/${site}_${timestamp}_db.sql.gz" "$MINIO_ALIAS/$BUCKET_NAME/$site/"
    fi
    
    log_success "Backup complete for $site"
}

# Main
configure_mc

if [ "$SITE_NAME" == "all" ]; then
    log_info "Backing up all sites..."
    sites=$(podman exec frappe-cloud-backend ls /home/frappe/frappe-bench/sites | grep -v "^assets$\|^apps\.\|^common_")
    for site in $sites; do
        backup_site "$site"
    done
else
    backup_site "$SITE_NAME"
fi

log_success "All backups completed!"
