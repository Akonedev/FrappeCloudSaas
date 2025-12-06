#!/bin/bash
# ============================================
# Frappe Cloud Self-Hosted - Backup Script
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_DIR/backups}"
DATE=$(date +%Y%m%d_%H%M%S)

# Load environment
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup MariaDB
backup_mariadb() {
    log_info "Backing up MariaDB..."
    
    docker exec mariadb mariadb-dump \
        -u root \
        -p"${MARIADB_ROOT_PASSWORD}" \
        --all-databases \
        --single-transaction \
        --routines \
        --triggers \
        > "$BACKUP_DIR/mariadb_${DATE}.sql"
    
    gzip "$BACKUP_DIR/mariadb_${DATE}.sql"
    log_info "MariaDB backup: mariadb_${DATE}.sql.gz"
}

# Backup Frappe sites
backup_sites() {
    log_info "Backing up Frappe sites..."
    
    docker exec press tar -czf - -C /home/frappe/frappe-bench sites \
        > "$BACKUP_DIR/sites_${DATE}.tar.gz"
    
    log_info "Sites backup: sites_${DATE}.tar.gz"
}

# Backup MinIO data
backup_minio() {
    log_info "Backing up MinIO buckets..."
    
    # Use mc to mirror buckets
    docker run --rm \
        --network frappe-cloud-backend \
        -v "$BACKUP_DIR:/backup" \
        minio/mc \
        mirror minio/backups /backup/minio_backups_${DATE}
    
    tar -czf "$BACKUP_DIR/minio_${DATE}.tar.gz" -C "$BACKUP_DIR" "minio_backups_${DATE}"
    rm -rf "$BACKUP_DIR/minio_backups_${DATE}"
    
    log_info "MinIO backup: minio_${DATE}.tar.gz"
}

# Upload to MinIO (optional)
upload_to_minio() {
    log_info "Uploading backups to MinIO..."
    
    docker run --rm \
        --network frappe-cloud-backend \
        -v "$BACKUP_DIR:/backup" \
        minio/mc \
        cp "/backup/*_${DATE}*" minio/backups/
    
    log_info "Backups uploaded to MinIO!"
}

# Cleanup old backups
cleanup_old_backups() {
    RETENTION_DAYS=${RETENTION_DAYS:-7}
    
    log_info "Cleaning up backups older than ${RETENTION_DAYS} days..."
    
    find "$BACKUP_DIR" -type f -name "*.gz" -mtime +${RETENTION_DAYS} -delete
    
    log_info "Cleanup complete!"
}

# Main
main() {
    case "${1:-all}" in
        all)
            backup_mariadb
            backup_sites
            backup_minio
            cleanup_old_backups
            ;;
        mariadb)
            backup_mariadb
            ;;
        sites)
            backup_sites
            ;;
        minio)
            backup_minio
            ;;
        upload)
            upload_to_minio
            ;;
        cleanup)
            cleanup_old_backups
            ;;
        *)
            echo "Usage: $0 {all|mariadb|sites|minio|upload|cleanup}"
            exit 1
            ;;
    esac
    
    log_info "Backup completed: $BACKUP_DIR"
}

main "$@"
