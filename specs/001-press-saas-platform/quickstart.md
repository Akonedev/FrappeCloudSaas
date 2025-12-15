# Quickstart — Press SaaS Platform (Frappe v16 + PostgreSQL 16)

Guide de démarrage rapide pour lancer la plateforme Press SaaS en mode développement local avec Frappe v16 et PostgreSQL 16.

## Prérequis

- **Podman** ou Docker (20.x+) avec Compose v2
- **Linux** (ou WSL2 sur Windows)
- **8 GB RAM** minimum
- **10 GB d'espace disque**

## 🚀 Démarrage en 3 étapes

### 1. Créer le réseau

```bash
podman network create fcs-press-network
```

### 2. Lancer le stack complet

```bash
podman compose \
  -f compose.yaml \
  -f overrides/compose.postgres.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.noproxy.yaml \
  -f overrides/compose.networks.yaml \
  up -d
```

### 3. Créer le premier site (attendre 2 minutes)

```bash
# Attendre que tous les services démarrent
sleep 120

# Créer le site press.localhost
podman exec frappe_docker_git-backend-1 bench new-site press.localhost \
  --admin-password admin \
  --db-type postgres \
  --db-host fcs-press-db \
  --db-port 5432 \
  --db-root-username postgres \
  --db-root-password fcs_press_secure_password_2025 \
  --install-app erpnext \
  --set-default
```

## 🌐 Accéder à l'application

### Option 1 : Via localhost (Redirection automatique) ✨

**Ouvrir dans le navigateur** : <http://localhost:48580>

Le navigateur sera **automatiquement redirigé** vers `http://press.localhost:48580`

### Option 2 : Via hostname direct (Nécessite /etc/hosts)

Ajouter dans `/etc/hosts`:

```bash
echo "127.0.0.1 press.localhost" | sudo tee -a /etc/hosts
```

Puis ouvrir directement: **<http://press.localhost:48580>**

### 🔧 Comment ça marche ?

Nginx redirige automatiquement `localhost` vers `press.localhost` :

```text
http://localhost:48580
  ↓ Nginx 301 Redirect
http://press.localhost:48580
  ↓ Frappe trouve le site
✅ Page de login
```

**Configuration** : Redirection définie dans `overrides/compose.localhost-redirect.yaml`

### Identifiants

- **Username**: `Administrator`
- **Password**: `admin`

## 📋 Vérifier le statut

```bash
# Status de tous les containers
podman ps --filter "name=fcs-press" --filter "name=frappe_docker_git"

# Logs du frontend
podman logs -f fcs-press-frontend

# Logs du backend
podman logs -f frappe_docker_git-backend-1

# Logs de PostgreSQL
podman logs -f fcs-press-db
```

## 🛠️ Commandes utiles

### Gestion des sites

```bash
# Lister les apps installées
podman exec frappe_docker_git-backend-1 bench --site press.localhost list-apps

# Console Python Frappe
podman exec -it frappe_docker_git-backend-1 bench --site press.localhost console

# Migrate la base de données
podman exec frappe_docker_git-backend-1 bench --site press.localhost migrate

# Backup du site
podman exec frappe_docker_git-backend-1 bench --site press.localhost backup
```

### Créer un nouveau site

```bash
podman exec frappe_docker_git-backend-1 bench new-site NOMSITE.localhost \
  --admin-password PASSWORD \
  --db-type postgres \
  --db-host fcs-press-db \
  --db-port 5432 \
  --db-root-username postgres \
  --db-root-password fcs_press_secure_password_2025 \
  --install-app erpnext
```

### Arrêter et nettoyer

```bash
# Arrêter tous les services
podman compose \
  -f compose.yaml \
  -f overrides/compose.postgres.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.noproxy.yaml \
  -f overrides/compose.networks.yaml \
  down

# Tout supprimer (y compris volumes)
podman compose \
  -f compose.yaml \
  -f overrides/compose.postgres.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.noproxy.yaml \
  -f overrides/compose.networks.yaml \
  down -v
```

## 🏗️ Architecture déployée

### Services actifs

| Service | Container | Port | Description |
|---------|-----------|------|-------------|
| PostgreSQL 16 | `fcs-press-db` | 48532 | Base de données multi-tenant |
| Redis Cache | `fcs-press-redis-cache` | 48510 | Cache |
| Redis Queue | `fcs-press-redis-queue` | 48511 | Files d'attente RQ |
| **Frontend** | `fcs-press-frontend` | **48580** | Nginx (point d'entrée) |
| Backend | `frappe_docker_git-backend-1` | - | Gunicorn WSGI |
| WebSocket | `frappe_docker_git-websocket-1` | - | Socket.IO temps réel |
| Queue Short | `frappe_docker_git-queue-short-1` | - | Worker RQ short/default |
| Queue Long | `frappe_docker_git-queue-long-1` | - | Worker RQ long |
| Scheduler | `frappe_docker_git-scheduler-1` | - | Cron scheduler |

### Stack technique

- **Frappe**: v16.0.0-dev
- **ERPNext**: v16.0.0-dev
- **PostgreSQL**: 16 (schema-per-site multi-tenancy)
- **Redis**: 7-alpine
- **Python**: 3.12
- **Node.js**: 18
- **Nginx**: 1.22

## 🔧 Configuration

### Variables d'environnement (.env)

Les variables importantes sont déjà configurées dans `.env`:

```env
ERPNEXT_VERSION=v16
DB_PASSWORD=fcs_press_secure_password_2025
HTTP_PUBLISH_PORT=48580
CUSTOM_IMAGE=frappe/erpnext
CUSTOM_TAG=v16
RESTART_POLICY=unless-stopped
```

### Ports utilisés (plage 48510-49800)

- **48510**: Redis Cache
- **48511**: Redis Queue
- **48532**: PostgreSQL
- **48580**: Frontend Nginx ⭐ **Point d'entrée principal**

## 📦 Volumes persistants

Les données sont stockées dans des volumes Docker:

```bash
# Voir les volumes
podman volume ls | grep frappe_docker_git

# Volumes créés:
# - frappe_docker_git_sites     : Sites Frappe
# - frappe_docker_git_db-data   : PostgreSQL data
# - frappe_docker_git_redis-queue-data : Redis queue
```

## 🔍 Dépannage

### Le site ne répond pas (404)

```bash
# Vérifier que le site existe
podman exec frappe_docker_git-backend-1 ls sites/

# Créer currentsite.txt si manquant
podman exec frappe_docker_git-backend-1 bash -c "echo 'press.localhost' > sites/currentsite.txt"

# Redémarrer le frontend
podman restart fcs-press-frontend
```

### Erreur de connexion PostgreSQL

```bash
# Vérifier que PostgreSQL est démarré
podman logs fcs-press-db

# Vérifier la connexion réseau
podman exec frappe_docker_git-backend-1 ping fcs-press-db
```

### Reset complet

```bash
# Tout supprimer (containers + volumes + network)
podman compose \
  -f compose.yaml \
  -f overrides/compose.postgres.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.noproxy.yaml \
  -f overrides/compose.networks.yaml \
  down -v

podman network rm fcs-press-network

# Relancer depuis le début
# (étapes 1, 2, 3 du quickstart)
```

## 📚 Documentation complète

- **[DEPLOYMENT.md](../../docs/DEPLOYMENT.md)** - Guide détaillé du déploiement
- **[spec.md](spec.md)** - Spécifications complètes du projet
- **[README.md](../../README.md)** - Vue d'ensemble du projet

## ✅ Solution standard

Ce déploiement utilise **100% la solution standard** frappe/frappe_docker:
- Images officielles `frappe/erpnext:v16`
- Compose modulaire avec overrides
- PostgreSQL 16 via override (au lieu de MariaDB)
- Compatible avec mises à jour officielles

## 🎯 Prochaines étapes

Après ce quickstart, vous pouvez:

1. **Installer d'autres apps Frappe**
2. **Configurer multi-sites** (plusieurs sites sur le même bench)
3. **Ajouter monitoring** (Prometheus/Grafana)
4. **Setup CI/CD** automatisé
5. **Déployer en production** avec Traefik SSL

---

**Version**: Frappe v16 + PostgreSQL 16
**Date**: Décembre 2025
**Support**: Voir [GitHub Issues](../../.github/)
