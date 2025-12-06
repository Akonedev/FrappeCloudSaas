#!/bin/bash
# ============================================
# Frappe Agent - Docker Entrypoint
# ============================================

set -e

AGENT_DIR="/home/frappe/agent"
AGENT_PORT="${AGENT_PORT:-25052}"
AGENT_PASSWORD="${AGENT_PASSWORD:-agent_password}"

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

# Apply patches for HTTP mode
apply_patches() {
    log_info "Applying patches for HTTP mode..."
    
    # Patch agent.py for HTTP communication
    if [ -f "/home/frappe/patches/agent_http.patch" ]; then
        cd /home/frappe/agent
        patch -p1 < /home/frappe/patches/agent_http.patch 2>/dev/null || true
        log_info "Patches applied!"
    fi
}

# Configure agent
configure_agent() {
    log_info "Configuring Agent..."
    
    cd "$AGENT_DIR"
    
    # Create config directory if not exists
    mkdir -p config
    
    # Generate config file
    cat > config/agent.json << EOF
{
    "name": "local-agent",
    "password": "${AGENT_PASSWORD}",
    "port": ${AGENT_PORT},
    "redis_host": "${REDIS_HOST:-redis-queue}",
    "redis_port": ${REDIS_PORT:-6379},
    "benches_directory": "/home/frappe/frappe-bench",
    "tls_enabled": false,
    "log_level": "INFO"
}
EOF
    
    log_info "Agent configured!"
}

# Wait for Redis
wait_for_redis() {
    log_info "Waiting for Redis..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if redis-cli -h "${REDIS_HOST:-redis-queue}" ping 2>/dev/null | grep -q PONG; then
            log_info "Redis is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    log_warn "Redis not available, continuing anyway..."
}

# Start agent
start_agent() {
    log_info "Starting Frappe Agent on port ${AGENT_PORT}..."
    cd "$AGENT_DIR"
    
    # Start with Python
    exec python -m agent.main \
        --port "${AGENT_PORT}" \
        --password "${AGENT_PASSWORD}" \
        --benches-directory /home/frappe/frappe-bench
}

# Main
main() {
    case "${1:-start}" in
        start)
            apply_patches
            configure_agent
            wait_for_redis
            start_agent
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
