# Press SaaS Platform - Frappe v16 + PostgreSQL 16

Plateforme Press SaaS complète utilisant **Frappe Framework v16** avec **PostgreSQL 16** dans une architecture containerisée standard.

## 🚀 Démarrage rapide

```bash
# Créer le réseau
podman network create fcs-press-network

# Lancer tous les services
podman compose \
  -f compose.yaml \
  -f overrides/compose.postgres.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.noproxy.yaml \
  -f overrides/compose.networks.yaml \
  up -d

# Attendre ~2 minutes que tous les services démarrent
sleep 120

# Créer le premier site
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

## 🌐 Accès

### Option 1 : Via localhost (Redirection automatique) ✨

**URL directe** : <http://localhost:48580>

Le navigateur sera **automatiquement redirigé** vers `http://press.localhost:48580`

**Identifiants** :

- Username: `Administrator`
- Password: `admin`

### Option 2 : Via hostname direct (Nécessite /etc/hosts)

```bash
# Ajouter dans /etc/hosts
echo "127.0.0.1 press.localhost" | sudo tee -a /etc/hosts

# Puis accéder directement
# URL: http://press.localhost:48580
```

### 🔧 Comment ça marche ?

Nginx est configuré pour **rediriger automatiquement** `localhost` vers `press.localhost` :

```text
http://localhost:48580
  ↓ Nginx 301 Redirect
http://press.localhost:48580
  ↓ Frappe trouve le site
✅ Page de login
```

**Configuration** : La redirection est définie dans [`overrides/compose.localhost-redirect.yaml`](overrides/compose.localhost-redirect.yaml)

## 📋 Architecture

### Services déployés

| Service | Container | Port | Description |
|---------|-----------|------|-------------|
| PostgreSQL 16 | `fcs-press-db` | 48532 | Base de données |
| Redis Cache | `fcs-press-redis-cache` | 48510 | Cache |
| Redis Queue | `fcs-press-redis-queue` | 48511 | Files d'attente |
| Frontend | `fcs-press-frontend` | **48580** | Nginx |
| Backend | `frappe_docker_git-backend-1` | - | Gunicorn |
| WebSocket | `frappe_docker_git-websocket-1` | - | Socket.IO |
| Workers | `frappe_docker_git-queue-*` | - | RQ workers |
| Scheduler | `frappe_docker_git-scheduler-1` | - | Cron tasks |

### Stack technique

- **Frappe Framework**: v16 (image officielle `frappe/erpnext:v16`)
- **ERPNext**: v16
- **PostgreSQL**: 16 (multi-tenancy schema-per-site)
- **Redis**: 7-alpine
- **Python**: 3.12 (dans image Frappe)
- **Node.js**: 18 (dans image Frappe)
- **Nginx**: 1.22 (dans image Frappe)

## 📚 Documentation

- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Guide complet de déploiement
- **[Specs](specs/001-press-saas-platform/)** - Spécifications complètes du projet

## 🛠️ Commandes utiles

### Gestion des containers

```bash
# Voir les logs
podman logs -f fcs-press-frontend
podman logs -f frappe_docker_git-backend-1

# Entrer dans un container
podman exec -it frappe_docker_git-backend-1 bash

# Arrêter tout
podman compose \
  -f compose.yaml \
  -f overrides/compose.postgres.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.noproxy.yaml \
  -f overrides/compose.networks.yaml \
  down

# Tout supprimer (avec volumes)
podman compose \
  -f compose.yaml \
  -f overrides/compose.postgres.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.noproxy.yaml \
  -f overrides/compose.networks.yaml \
  down -v
```

### Commandes Frappe Bench

```bash
# Lister les apps installées
podman exec frappe_docker_git-backend-1 bench --site press.localhost list-apps

# Console Python
podman exec -it frappe_docker_git-backend-1 bench --site press.localhost console

# Migrate la base de données
podman exec frappe_docker_git-backend-1 bench --site press.localhost migrate

# Backup
podman exec frappe_docker_git-backend-1 bench --site press.localhost backup

# Créer un nouveau site
podman exec frappe_docker_git-backend-1 bench new-site NOMSITE \
  --admin-password PASSWORD \
  --db-type postgres \
  --db-host fcs-press-db \
  --install-app erpnext
```

## 🔧 Configuration

### Variables d'environnement (.env)

```env
ERPNEXT_VERSION=v16
DB_PASSWORD=fcs_press_secure_password_2025
HTTP_PUBLISH_PORT=48580
CUSTOM_IMAGE=frappe/erpnext
CUSTOM_TAG=v16
```

### Ports utilisés (48510-49800)

- **48510**: Redis Cache
- **48511**: Redis Queue
- **48532**: PostgreSQL
- **48580**: Frontend Nginx ⭐

## 📁 Structure du projet

```
.
├── compose.yaml                    # Compose de base (frappe_docker)
├── overrides/                      # Overrides modulaires
│   ├── compose.postgres.yaml       # PostgreSQL 16
│   ├── compose.redis.yaml          # Redis 7
│   ├── compose.noproxy.yaml        # Exposition directe
│   └── compose.networks.yaml       # Réseau fcs-press-network
├── .env                            # Configuration environnement
├── docs/
│   ├── DEPLOYMENT.md               # Guide déploiement
│   └── FRAPPE_DOCKER_ORIGINAL.md   # README original frappe_docker
├── specs/                          # Spécifications du projet
└── scripts/                        # Scripts utilitaires
```

## ✅ Solution standard

Ce projet utilise **100% la solution standard** de [frappe/frappe_docker](https://github.com/frappe/frappe_docker):
- Images officielles frappe/erpnext
- Structure compose modulaire
- Overrides pour PostgreSQL 16
- Aucun code custom
- Compatible mises à jour officielles

## 🎯 Prochaines étapes

1. **Installer l'app Press** dans le bench
2. **Déployer le dashboard Press** (frappe-ui)
3. **Configurer multi-tenancy** avancé
4. **Ajouter monitoring** (Prometheus/Grafana)
5. **Setup CI/CD** avec GitHub Actions

## 📝 Licence

Ce projet utilise Frappe Framework sous licence MIT.

---

**Version**: Frappe v16 + PostgreSQL 16
**Date**: Décembre 2025
**Maintenu par**: @akone
