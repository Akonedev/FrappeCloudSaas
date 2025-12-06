#!/bin/bash
# ============================================
# Frappe Cloud Self-Hosted - Setup Script
# ============================================
# Ce script initialise l'environnement complet
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Banner
echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════╗
║     Frappe Cloud Self-Hosted - Setup v1.0.0           ║
║     Frappe v16 + Press v16 + Lago + Keycloak          ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check Docker/Podman
    if command -v podman &> /dev/null; then
        CONTAINER_CMD="podman"
        COMPOSE_CMD="podman-compose"
        log_info "Using Podman"
    elif command -v docker &> /dev/null; then
        CONTAINER_CMD="docker"
        COMPOSE_CMD="docker compose"
        log_info "Using Docker"
    else
        log_error "Docker or Podman is required!"
        exit 1
    fi
    
    # Check compose
    if ! command -v $COMPOSE_CMD &> /dev/null; then
        log_error "$COMPOSE_CMD is required!"
        exit 1
    fi
    
    log_info "Prerequisites OK!"
}

# Generate secrets
generate_secrets() {
    log_step "Generating secrets..."
    
    # Generate random passwords
    MARIADB_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
    MINIO_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
    ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
    LAGO_SECRET=$(openssl rand -base64 64 | tr -dc 'a-zA-Z0-9' | head -c 64)
    KEYCLOAK_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
    AGENT_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
    
    log_info "Secrets generated!"
}

# Create .env file
create_env_file() {
    log_step "Creating .env file..."
    
    if [ -f "$PROJECT_DIR/.env" ]; then
        log_warn ".env file already exists. Backing up..."
        mv "$PROJECT_DIR/.env" "$PROJECT_DIR/.env.backup.$(date +%Y%m%d%H%M%S)"
    fi
    
    cat > "$PROJECT_DIR/.env" << EOF
# ============================================
# Frappe Cloud Self-Hosted - Generated Config
# Generated: $(date)
# ============================================

# Domain Configuration
DOMAIN=${DOMAIN:-localhost}
ACME_EMAIL=${ACME_EMAIL:-admin@localhost}

# Database
MARIADB_ROOT_PASSWORD=${MARIADB_PASSWORD}

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=${MINIO_PASSWORD}

# Frappe/Press
FRAPPE_SITE_NAME=cloud.${DOMAIN:-localhost}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin}
ENCRYPTION_KEY=${ENCRYPTION_KEY}

# Agent
AGENT_PASSWORD=${AGENT_PASSWORD}

# Lago
LAGO_SECRET_KEY=${LAGO_SECRET}
LAGO_DB_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)

# Keycloak
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_PASSWORD}
KEYCLOAK_DB_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)

# Ports
HTTP_PORT=30080
HTTPS_PORT=30443
TRAEFIK_DASHBOARD_PORT=30008
AGENT_PORT=25052
EOF

    chmod 600 "$PROJECT_DIR/.env"
    log_info ".env file created!"
}

# Create MinIO buckets init script
create_minio_init() {
    log_step "Creating MinIO initialization..."
    
    mkdir -p "$PROJECT_DIR/docker/minio"
    
    cat > "$PROJECT_DIR/docker/minio/init-buckets.sh" << 'EOF'
#!/bin/bash
# Wait for MinIO to be ready
sleep 10

# Configure mc client
mc alias set local http://minio:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}

# Create buckets
mc mb local/backups --ignore-existing
mc mb local/private --ignore-existing
mc mb local/public --ignore-existing

# Set public bucket policy
mc anonymous set download local/public

echo "MinIO buckets initialized!"
EOF

    chmod +x "$PROJECT_DIR/docker/minio/init-buckets.sh"
    log_info "MinIO init script created!"
}

# Create MariaDB init
create_mariadb_init() {
    log_step "Creating MariaDB initialization..."
    
    mkdir -p "$PROJECT_DIR/docker/mariadb/init"
    
    cat > "$PROJECT_DIR/docker/mariadb/init/01-init.sql" << 'EOF'
-- Create Press database
CREATE DATABASE IF NOT EXISTS press 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

-- Grant permissions
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

    log_info "MariaDB init script created!"
}

# Add hosts entries
setup_hosts() {
    log_step "Setting up /etc/hosts entries..."
    
    DOMAIN=${DOMAIN:-localhost}
    
    HOSTS_ENTRIES="
# Frappe Cloud Self-Hosted
127.0.0.1 cloud.${DOMAIN}
127.0.0.1 traefik.${DOMAIN}
127.0.0.1 storage.${DOMAIN}
127.0.0.1 s3.${DOMAIN}
127.0.0.1 billing.${DOMAIN}
127.0.0.1 billing-api.${DOMAIN}
127.0.0.1 auth.${DOMAIN}
"
    
    if grep -q "Frappe Cloud Self-Hosted" /etc/hosts 2>/dev/null; then
        log_warn "Hosts entries already exist"
    else
        log_warn "Add these entries to /etc/hosts (requires sudo):"
        echo "$HOSTS_ENTRIES"
        
        read -p "Add automatically? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$HOSTS_ENTRIES" | sudo tee -a /etc/hosts > /dev/null
            log_info "Hosts entries added!"
        fi
    fi
}

# Build images
build_images() {
    log_step "Building Docker images..."
    
    cd "$PROJECT_DIR"
    
    log_info "Building Press image..."
    $CONTAINER_CMD build -t frappe-press:v16 ./docker/press/
    
    log_info "Building Agent image..."
    $CONTAINER_CMD build -t frappe-agent:latest ./docker/agent/
    
    log_info "Images built successfully!"
}

# Start services
start_services() {
    log_step "Starting services..."
    
    cd "$PROJECT_DIR"
    
    # Start infrastructure first
    log_info "Starting infrastructure services..."
    $COMPOSE_CMD up -d traefik mariadb redis-cache redis-queue minio
    
    log_info "Waiting for infrastructure (30s)..."
    sleep 30
    
    # Start application
    log_info "Starting Press application..."
    $COMPOSE_CMD up -d press press-worker-default press-worker-short press-worker-long press-scheduler agent
    
    log_info "Waiting for Press to initialize (120s)..."
    sleep 120
    
    # Start billing and auth
    log_info "Starting billing and auth services..."
    $COMPOSE_CMD up -d lago-db lago-redis lago-api lago-front lago-worker lago-clock lago-pdf
    $COMPOSE_CMD up -d keycloak-db keycloak
    
    log_info "All services started!"
}

# Show status
show_status() {
    log_step "Service Status"
    
    cd "$PROJECT_DIR"
    $COMPOSE_CMD ps
    
    DOMAIN=${DOMAIN:-localhost}
    HTTP_PORT=${HTTP_PORT:-30080}
    
    echo ""
    log_info "Access URLs:"
    echo -e "  ${GREEN}Press Dashboard:${NC}  http://cloud.${DOMAIN}:${HTTP_PORT}"
    echo -e "  ${GREEN}Traefik Dashboard:${NC} http://traefik.${DOMAIN}:${TRAEFIK_DASHBOARD_PORT:-30008}"
    echo -e "  ${GREEN}MinIO Console:${NC}    http://storage.${DOMAIN}:${HTTP_PORT}"
    echo -e "  ${GREEN}Lago Billing:${NC}     http://billing.${DOMAIN}:${HTTP_PORT}"
    echo -e "  ${GREEN}Keycloak Auth:${NC}    http://auth.${DOMAIN}:${HTTP_PORT}"
    echo ""
    log_info "Credentials (check .env file for passwords):"
    echo -e "  ${GREEN}Press Admin:${NC}      Administrator / ${ADMIN_PASSWORD:-admin}"
    echo -e "  ${GREEN}MinIO:${NC}            minioadmin / (see .env)"
    echo -e "  ${GREEN}Keycloak:${NC}         admin / (see .env)"
}

# Main menu
main() {
    case "${1:-setup}" in
        setup)
            check_prerequisites
            generate_secrets
            create_env_file
            create_minio_init
            create_mariadb_init
            setup_hosts
            build_images
            start_services
            show_status
            ;;
        build)
            check_prerequisites
            build_images
            ;;
        start)
            check_prerequisites
            start_services
            show_status
            ;;
        stop)
            cd "$PROJECT_DIR"
            $COMPOSE_CMD down
            log_info "Services stopped"
            ;;
        restart)
            cd "$PROJECT_DIR"
            $COMPOSE_CMD restart
            show_status
            ;;
        status)
            show_status
            ;;
        logs)
            cd "$PROJECT_DIR"
            $COMPOSE_CMD logs -f ${2:-}
            ;;
        clean)
            cd "$PROJECT_DIR"
            $COMPOSE_CMD down -v
            log_warn "All volumes deleted!"
            ;;
        *)
            echo "Usage: $0 {setup|build|start|stop|restart|status|logs|clean}"
            exit 1
            ;;
    esac
}

main "$@"
