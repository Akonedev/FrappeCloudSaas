# 🏗️ Frappe Cloud - Local SaaS Platform

> Deploy Frappe/ERPNext locally with Podman - No cloud providers needed!

## 📋 Table of Contents

- [Overview](#-overview)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Architecture](#-architecture)
- [Services](#-services)
- [Site Management](#-site-management)
- [Backup & Restore](#-backup--restore)
- [Troubleshooting](#-troubleshooting)

## 🎯 Overview

This project provides a complete local Frappe/ERPNext platform using:

| Component | Purpose | URL |
|-----------|---------|-----|
| **Traefik** | Reverse proxy & routing | http://traefik.localhost |
| **MinIO** | S3-compatible storage | http://minio.localhost |
| **Registry** | Container image registry | http://registry.localhost |
| **MariaDB** | Database server | Internal |
| **Redis** | Cache & Queue | Internal |
| **Frappe** | Backend framework | http://erp.localhost |

## 📦 Prerequisites

### Fedora/RHEL
```bash
# Install Podman & Compose
sudo dnf install -y podman podman-compose

# Enable Podman socket (for rootless)
systemctl --user enable --now podman.socket
```

### Ubuntu/Debian
```bash
# Install Podman
sudo apt install -y podman podman-compose

# Enable Podman socket
systemctl --user enable --now podman.socket
```

### Verify Installation
```bash
podman --version
podman-compose --version
```

## 🚀 Quick Start

### 1. Clone & Setup
```bash
cd /path/to/frappe_docker_git

# Copy environment file
cp .env.example .env

# Edit with your values
nano .env
```

### 2. Configure /etc/hosts
Add these entries to `/etc/hosts`:
```
127.0.0.1 traefik.localhost
127.0.0.1 minio.localhost
127.0.0.1 s3.localhost
127.0.0.1 registry.localhost
127.0.0.1 registry-ui.localhost
127.0.0.1 erp.localhost
```

Or use the helper:
```bash
echo "127.0.0.1 traefik.localhost minio.localhost s3.localhost registry.localhost registry-ui.localhost erp.localhost" | sudo tee -a /etc/hosts
```

### 3. Start Services
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Start all services
podman compose up -d

# Watch logs
podman compose logs -f
```

### 4. Create Your First Site
```bash
# Wait for services to be ready (check configurator logs)
podman logs -f configurator

# Create site (once configurator completes)
./scripts/create-site.sh erp.localhost admin
```

### 5. Access Your Site
Open http://erp.localhost in your browser
- **Username:** Administrator
- **Password:** admin (or your custom password)

## 🏛️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         TRAEFIK                                 │
│                    (Reverse Proxy)                              │
│              http://traefik.localhost:80                        │
└─────────────────────────────────────────────────────────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   MinIO     │ │  Registry   │ │   Frappe    │ │  WebSocket  │
│ (S3 Store)  │ │  (Images)   │ │  (Backend)  │ │ (Socket.IO) │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼                  ▼
             ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
             │  MariaDB    │   │ Redis Cache │   │ Redis Queue │
             │ (Database)  │   │             │   │             │
             └─────────────┘   └─────────────┘   └─────────────┘
```

## 🔧 Services

### Infrastructure (`compose/infra.yaml`)

| Service | Image | Purpose |
|---------|-------|---------|
| traefik | traefik:v3.2 | Reverse proxy, TLS, routing |
| minio | minio/minio | S3-compatible object storage |
| registry | registry:2 | Docker/Podman image registry |
| registry-ui | joxit/docker-registry-ui | Web UI for registry |
| coredns | coredns/coredns | Local DNS (optional) |

### Frappe Stack (`compose/frappe.yaml`)

| Service | Image | Purpose |
|---------|-------|---------|
| mariadb | mariadb:10.11 | Database server |
| redis-cache | redis:7-alpine | Caching |
| redis-queue | redis:7-alpine | Background jobs |
| frappe-backend | frappe/erpnext:v15 | Gunicorn (Python) |
| frappe-websocket | frappe/erpnext:v15 | Socket.IO (Node.js) |
| frappe-scheduler | frappe/erpnext:v15 | Scheduled tasks |
| frappe-worker-short | frappe/erpnext:v15 | Short queue jobs |
| frappe-worker-long | frappe/erpnext:v15 | Long queue jobs |
| configurator | frappe/erpnext:v15 | One-time setup |

## 📁 Project Structure

```
frappe_docker_git/
├── compose.yaml              # Main compose file (includes others)
├── .env.example              # Environment template
├── compose/
│   ├── infra.yaml           # Infrastructure services
│   └── frappe.yaml          # Frappe/ERPNext services
├── config/
│   ├── traefik/
│   │   └── dynamic.yaml     # Traefik routing rules
│   └── coredns/
│       └── Corefile         # DNS configuration
└── scripts/
    ├── create-site.sh       # Create new Frappe site
    ├── backup.sh            # Backup sites to MinIO
    └── init-minio.sh        # Initialize MinIO buckets
```

## 🌐 Site Management

### Create a New Site
```bash
# Basic site with ERPNext
./scripts/create-site.sh mysite.localhost admin

# Site without ERPNext
./scripts/create-site.sh mysite.localhost admin no
```

### List Sites
```bash
podman exec frappe-backend ls /home/frappe/frappe-bench/sites
```

### Switch Default Site
```bash
podman exec frappe-backend bench use mysite.localhost
```

### Access Bench Console
```bash
podman exec -it frappe-backend bench console
```

### Run Bench Commands
```bash
podman exec frappe-backend bench --site mysite.localhost migrate
podman exec frappe-backend bench --site mysite.localhost clear-cache
```

## 💾 Backup & Restore

### Backup
```bash
# Backup all sites
./scripts/backup.sh all

# Backup specific site
./scripts/backup.sh mysite.localhost
```

### Restore
```bash
# Restore from backup file
podman exec frappe-backend bench --site mysite.localhost restore /path/to/backup.sql.gz
```

## 🔍 Troubleshooting

### Check Container Status
```bash
podman ps -a
podman compose ps
```

### View Logs
```bash
# All logs
podman compose logs -f

# Specific service
podman compose logs -f frappe-backend
podman compose logs -f configurator
```

### Common Issues

#### Podman Socket Not Found
```bash
# Enable user socket
systemctl --user enable --now podman.socket

# Verify
ls -la /run/user/$(id -u)/podman/podman.sock
```

#### Permission Denied on Volumes
```bash
# Fix with :Z flag (SELinux)
# Already included in compose files
```

#### Site Not Accessible
1. Check /etc/hosts
2. Verify Traefik is running: `podman logs traefik`
3. Check Frappe backend: `podman logs frappe-backend`

### Reset Everything
```bash
# Stop and remove all
podman compose down -v

# Remove all volumes
podman volume prune -f

# Start fresh
podman compose up -d
```

## 📚 Additional Resources

- [Frappe Documentation](https://frappeframework.com/docs)
- [ERPNext Documentation](https://docs.erpnext.com)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Podman Documentation](https://docs.podman.io)

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.
