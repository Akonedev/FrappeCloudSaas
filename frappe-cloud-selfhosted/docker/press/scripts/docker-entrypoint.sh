#!/bin/bash
# ============================================
# Frappe Press - Docker Entrypoint
# ============================================

set -e

BENCH_DIR="${BENCH_DIR:-/home/frappe/frappe-bench}"
SITE_NAME="${FRAPPE_SITE_NAME:-cloud.localhost}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Wait for database
wait_for_db() {
    log_info "Waiting for MariaDB..."
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if mariadb -h"${DB_HOST:-mariadb}" -uroot -p"${DB_ROOT_PASSWORD:-password}" -e "SELECT 1" &>/dev/null; then
            log_info "MariaDB is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    log_error "MariaDB is not available after $max_attempts attempts"
    exit 1
}

# Wait for Redis
wait_for_redis() {
    log_info "Waiting for Redis..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if redis-cli -h redis-cache ping &>/dev/null && redis-cli -h redis-queue ping &>/dev/null; then
            log_info "Redis is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    log_error "Redis is not available after $max_attempts attempts"
    exit 1
}

# Initialize site if not exists
init_site() {
    cd "$BENCH_DIR"
    
    if [ ! -d "sites/${SITE_NAME}" ]; then
        log_info "Creating new site: ${SITE_NAME}"
        
        # Create site
        bench new-site "${SITE_NAME}" \
            --db-host="${DB_HOST:-mariadb}" \
            --db-port="${DB_PORT:-3306}" \
            --db-root-password="${DB_ROOT_PASSWORD:-password}" \
            --admin-password="${ADMIN_PASSWORD:-admin}" \
            --no-mariadb-socket \
            --install-app press
        
        log_info "Site created successfully!"
        
        # Set as default site
        bench use "${SITE_NAME}"
        
        # Configure Press settings
        configure_press
    else
        log_info "Site ${SITE_NAME} already exists"
        bench use "${SITE_NAME}"
    fi
}

# Configure Press application
configure_press() {
    log_info "Configuring Press..."
    
    # Set Press configuration via bench
    bench --site "${SITE_NAME}" set-config developer_mode 0
    
    # MinIO configuration
    if [ -n "${MINIO_ENDPOINT}" ]; then
        bench --site "${SITE_NAME}" set-config minio_endpoint "${MINIO_ENDPOINT}"
        bench --site "${SITE_NAME}" set-config minio_access_key "${MINIO_ACCESS_KEY}"
        bench --site "${SITE_NAME}" set-config minio_secret_key "${MINIO_SECRET_KEY}"
    fi
    
    log_info "Press configured!"
}

# Run migrations
run_migrate() {
    log_info "Running migrations..."
    cd "$BENCH_DIR"
    bench --site "${SITE_NAME}" migrate --skip-failing
    log_info "Migrations completed!"
}

# Start Frappe
start_frappe() {
    log_info "Starting Frappe..."
    cd "$BENCH_DIR"
    
    # Use gunicorn for production
    exec gunicorn \
        --bind 0.0.0.0:8000 \
        --workers "${GUNICORN_WORKERS:-4}" \
        --timeout 120 \
        --graceful-timeout 30 \
        --worker-class gthread \
        --threads 4 \
        --max-requests 5000 \
        --max-requests-jitter 500 \
        --access-logfile - \
        --error-logfile - \
        frappe.app:application
}

# Main
main() {
    case "${1:-start}" in
        start)
            wait_for_db
            wait_for_redis
            init_site
            start_frappe
            ;;
        migrate)
            wait_for_db
            run_migrate
            ;;
        worker)
            wait_for_db
            wait_for_redis
            exec bench worker --queue "${2:-default}"
            ;;
        schedule)
            wait_for_db
            wait_for_redis
            exec bench schedule
            ;;
        console)
            exec bench --site "${SITE_NAME}" console
            ;;
        shell)
            exec /bin/bash
            ;;
        *)
            exec "$@"
            ;;
    esac
}

main "$@"
