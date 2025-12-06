#!/bin/bash
# =============================================================================
# Frappe Cloud - Setup Script
# Creates a new Frappe/ERPNext site
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
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Default values
SITE_NAME="${1:-erp.localhost}"
ADMIN_PASSWORD="${2:-admin}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-admin}"
INSTALL_ERPNEXT="${3:-yes}"

# Banner
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           🏗️  Frappe Cloud - Site Setup                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

log_info "Site Name: $SITE_NAME"
log_info "Install ERPNext: $INSTALL_ERPNEXT"

# Check if site already exists
if podman exec frappe-cloud-backend test -d "/home/frappe/frappe-bench/sites/$SITE_NAME" 2>/dev/null; then
    log_warning "Site $SITE_NAME already exists!"
    read -p "Do you want to drop and recreate it? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Dropping existing site..."
        podman exec frappe-cloud-backend bench drop-site "$SITE_NAME" --force --no-backup
    else
        log_info "Keeping existing site."
        exit 0
    fi
fi

# Create new site
log_info "Creating site $SITE_NAME..."
podman exec frappe-cloud-backend bench new-site "$SITE_NAME" \
    --db-root-password "$DB_ROOT_PASSWORD" \
    --admin-password "$ADMIN_PASSWORD" \
    --no-mariadb-socket

# Install ERPNext if requested
if [[ "$INSTALL_ERPNEXT" == "yes" ]]; then
    log_info "Installing ERPNext on $SITE_NAME..."
    podman exec frappe-cloud-backend bench --site "$SITE_NAME" install-app erpnext
fi

# Set as default site
log_info "Setting $SITE_NAME as default site..."
podman exec frappe-cloud-backend bench use "$SITE_NAME"

# Enable scheduler
log_info "Enabling scheduler..."
podman exec frappe-cloud-backend bench --site "$SITE_NAME" enable-scheduler

# Build assets
log_info "Building assets..."
podman exec frappe-cloud-backend bench build

log_success "Site $SITE_NAME created successfully!"
echo ""
echo -e "${GREEN}Access your site at: http://$SITE_NAME:32080${NC}"
echo -e "${YELLOW}Admin credentials:${NC}"
echo "  Username: Administrator"
echo "  Password: $ADMIN_PASSWORD"
echo ""
echo -e "${YELLOW}Don't forget to add this to /etc/hosts:${NC}"
echo "  127.0.0.1 $SITE_NAME"
