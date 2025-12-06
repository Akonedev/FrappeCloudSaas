# 🚀 Frappe Cloud Self-Hosted

**Plateforme SaaS B2B/B2C Self-Hosted** basée sur Frappe Press avec solutions 100% open source.

> ⚠️ **Status**: Développement actif - Phase 2 complétée (Press fonctionnel)

## 🎯 Objectif

Permettre à un client de :
1. S'inscrire sur la plateforme
2. Choisir un plan d'abonnement
3. Payer (via passerelle intégrée)
4. Avoir son site ERPNext/Frappe créé automatiquement
5. Accéder immédiatement à ses applications

## ✅ Status d'Implémentation

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Infrastructure de base | ✅ Complète |
| 2 | Press + Workers | ✅ Complète |
| 3 | Lago Billing | ⏳ À faire |
| 4 | Keycloak SSO | ⏳ À faire |
| 5 | Production ready | ⏳ À faire |

## 📦 Stack Technique

| Composant | Solution | Version | Status |
|-----------|----------|---------|--------|
| **Framework** | Frappe | v15 | ✅ Fonctionnel |
| **Cloud Manager** | Press | v15 | ✅ Fonctionnel |
| **Agent** | Frappe Agent | - | ⏳ À configurer |
| **Billing** | Lago | v1.x | ⏳ À intégrer |
| **Reverse Proxy** | Traefik | v3.2 | ✅ Fonctionnel |
| **Object Storage** | MinIO | latest | ✅ Fonctionnel |
| **SSO** | Keycloak | 26.x | ⏳ À intégrer |
| **Database** | MariaDB | 11.4 | ✅ Fonctionnel |
| **Cache** | Redis | 7.4 | ✅ Fonctionnel |
| **Container** | Podman/Docker | latest | ✅ Fonctionnel |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     TRAEFIK (Ingress)                           │
│   *.moncloud.com → SSL Auto (Let's Encrypt)                     │
└─────────────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  PRESS CENTRAL  │  │  LAGO BILLING   │  │  TENANT SITES   │
│  (Dashboard)    │  │  (Facturation)  │  │  (Clients)      │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     AGENT (Orchestrateur)                       │
│   Flask API + RQ Workers → bench commands                       │
└─────────────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│    MariaDB      │  │     Redis       │  │     MinIO       │
│   (Databases)   │  │  (Cache+Queue)  │  │   (Storage)     │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

## 📚 Documentation

- [Architecture détaillée](docs/01-ARCHITECTURE.md)
- [Plan d'implémentation](docs/02-IMPLEMENTATION-PLAN.md)
- [Roadmap](docs/03-ROADMAP.md)
- [Guide d'installation](docs/04-INSTALLATION.md)
- [Configuration](docs/05-CONFIGURATION.md)
- [API Reference](docs/06-API.md)

## 🚀 Démarrage Rapide

### Prérequis

- Podman ou Docker
- 8GB RAM minimum
- 20GB espace disque

### Installation

```bash
# 1. Ajouter l'entrée DNS locale
echo "127.0.0.1 press.localhost" | sudo tee -a /etc/hosts

# 2. Lancer les services
./start.sh

# 3. Accéder au dashboard
# URL: http://press.localhost:30080
# Login: Administrator / admin
```

### Ports utilisés

| Service | Port | URL |
|---------|------|-----|
| Press (HTTP) | 30080 | http://press.localhost:30080 |
| Press (HTTPS) | 30443 | https://press.localhost:30443 |
| Traefik Dashboard | 30008 | http://localhost:30008 |

## 🔧 Commandes Utiles

```bash
# Voir les logs du backend
podman logs -f frappe-backend

# Accéder au bench
podman exec -it frappe-backend bash

# Rebuild des assets
podman exec frappe-backend bench build --force

# Créer un nouveau site
podman exec frappe-backend bench new-site monsite.localhost --admin-password=monpass
```
./scripts/init.sh
docker compose up -d

# Accéder au dashboard
open https://cloud.localhost
```

## 📄 Licence

AGPL-3.0 - Open Source
