#!/bin/bash
# ============================================
# Frappe Press - Configuration Script
# ============================================

set -e

# Configuration
SITE_NAME="${FRAPPE_SITE_NAME:-press.localhost}"
DB_HOST="${DB_HOST:-mariadb}"
DB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-password}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
REDIS_CACHE="${REDIS_CACHE:-redis-cache:6379}"
REDIS_QUEUE="${REDIS_QUEUE:-redis-queue:6379}"

echo "========================================"
echo "Frappe Cloud - Configuration"
echo "========================================"

# Wait for MariaDB
echo "Waiting for MariaDB..."
max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if mariadb -h"$DB_HOST" -uroot -p"$DB_ROOT_PASSWORD" -e "SELECT 1" 2>/dev/null; then
        echo "MariaDB is ready!"
        break
    fi
    attempt=$((attempt + 1))
    echo "Attempt $attempt/$max_attempts..."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "ERROR: MariaDB not available"
    exit 1
fi

cd /home/frappe/frappe-bench

# Create common_site_config.json
echo "Creating site configuration..."
mkdir -p sites
cat > sites/common_site_config.json << EOF
{
  "db_host": "$DB_HOST",
  "db_port": 3306,
  "redis_cache": "redis://$REDIS_CACHE",
  "redis_queue": "redis://$REDIS_QUEUE",
  "socketio_port": 9000,
  "webserver_port": 8000,
  "serve_default_site": true
}
EOF

# Check if site exists
if [ ! -d "sites/$SITE_NAME" ]; then
    echo "Creating site: $SITE_NAME"
    bench new-site "$SITE_NAME" \
        --db-host "$DB_HOST" \
        --db-root-password "$DB_ROOT_PASSWORD" \
        --admin-password "$ADMIN_PASSWORD" \
        --no-mariadb-socket
    
    echo "Site created!"
else
    echo "Site $SITE_NAME already exists"
fi

# Set default site
bench use "$SITE_NAME"

# Check if Press app exists
if [ ! -d "apps/press" ]; then
    echo "Getting Press app..."
    bench get-app --branch develop press https://github.com/frappe/press.git || {
        echo "Failed to get Press, trying alternate method..."
        git clone --depth 1 --branch develop https://github.com/frappe/press.git apps/press
        bench pip install -e apps/press
    }
fi

# Install Press on site
echo "Installing Press..."
bench --site "$SITE_NAME" install-app press || echo "Press may already be installed"

# Build assets
echo "Building assets..."
bench build --apps press || true

echo "========================================"
echo "Configuration complete!"
echo "Site: $SITE_NAME"
echo "Admin password: $ADMIN_PASSWORD"
echo "========================================"
