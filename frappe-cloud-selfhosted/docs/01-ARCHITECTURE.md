# 📐 Architecture Détaillée

## Vue d'ensemble

Cette architecture est conçue pour être :

- **100% Self-Hosted** : Aucune dépendance cloud externe
- **Scalable** : De 10 à 1000+ sites
- **Sécurisée** : SSL automatique, isolation des données
- **Maintenable** : Docker/Podman, CI/CD ready

## Composants Principaux

### 1. Traefik (Ingress Controller)

**Rôle** : Reverse proxy, SSL termination, routing

```yaml
# Fonctionnalités
- Wildcard SSL via Let's Encrypt (DNS Challenge)
- Auto-discovery des conteneurs (labels Docker)
- Load balancing
- Middlewares (auth, rate-limit, headers)
```

**Routing** :

| Pattern | Service | Description |
|---------|---------|-------------|
| `cloud.domain.com` | Press Dashboard | Interface admin |
| `billing.domain.com` | Lago | Facturation |
| `*.domain.com` | Tenant Sites | Sites clients |

### 2. Press Central (Frappe Press v16)

**Rôle** : Orchestration de la plateforme

```yaml
Fonctionnalités:
  - Gestion des sites (CRUD)
  - Gestion des benches
  - App Marketplace
  - User/Team management
  - Billing integration (via Lago webhooks)
  - Agent communication (HTTP API)
```

**DocTypes clés** :

- `Site` : Représente un site client
- `Bench` : Environnement Frappe (apps + sites)
- `Server` : Serveur physique/virtuel
- `Release Group` : Groupe de versions d'apps
- `Agent Job` : Job envoyé à l'agent

### 3. Agent (Frappe Agent)

**Rôle** : Exécution des commandes sur le bench

```yaml
Architecture:
  - Flask API (port 25052)
  - RQ Workers (Redis Queue)
  - SQLite local (jobs.sqlite3)

Jobs supportés:
  - New Site
  - Install App
  - Backup Site
  - Migrate Site
  - Update Site
  - Archive Site
```

### 4. Lago Billing

**Rôle** : Gestion des abonnements et facturation

```yaml
Fonctionnalités:
  - Plans d'abonnement (mensuel/annuel)
  - Usage-based billing
  - Invoices automatiques
  - Webhooks → Press

Intégration:
  - Webhook on payment success → Create Site
  - Webhook on subscription cancel → Archive Site
  - API sync avec Press pour usage
```

### 5. MinIO (Object Storage)

**Rôle** : Stockage S3-compatible

```yaml
Buckets:
  - backups/     # Backups des sites
  - private/     # Fichiers privés
  - public/      # Assets publics

Fonctionnalités:
  - Compatible AWS S3 API
  - Versioning
  - Lifecycle policies
```

### 6. Keycloak (SSO)

**Rôle** : Authentification centralisée

```yaml
Fonctionnalités:
  - SSO pour Dashboard Press
  - SSO pour sites clients (optionnel)
  - Social login (Google, GitHub)
  - 2FA/MFA

Realms:
  - master (admin)
  - cloud (utilisateurs)
```

### 7. Postal (Email)

**Rôle** : Serveur SMTP self-hosted

```yaml
Fonctionnalités:
  - Envoi emails transactionnels
  - Tracking (open, click)
  - Templates
  - Multi-organization
```

## Flux de Données

### Création d'un nouveau site

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          FLUX: NOUVEAU SITE                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  1. CLIENT                                                                   │
│     │                                                                        │
│     ▼ S'inscrit + Choisit plan                                              │
│  ┌──────────────┐                                                           │
│  │ Press        │                                                           │
│  │ Dashboard    │ ──────────────────────────────────────┐                   │
│  └──────────────┘                                       │                   │
│     │                                                   │                   │
│     ▼ Redirige vers paiement                           │                   │
│  ┌──────────────┐                                       │                   │
│  │ Lago         │                                       │                   │
│  │ Checkout     │                                       │                   │
│  └──────────────┘                                       │                   │
│     │                                                   │                   │
│     ▼ Paiement OK → Webhook                            │                   │
│  ┌──────────────┐                                       │                   │
│  │ Press        │ ◄─────────────────────────────────────┘                   │
│  │ Backend      │                                                           │
│  └──────────────┘                                                           │
│     │                                                                        │
│     ▼ Crée Agent Job "New Site"                                             │
│  ┌──────────────┐                                                           │
│  │ Agent        │                                                           │
│  │ API          │                                                           │
│  └──────────────┘                                                           │
│     │                                                                        │
│     ▼ Exécute via RQ Worker                                                 │
│  ┌──────────────┐                                                           │
│  │ bench        │                                                           │
│  │ new-site     │                                                           │
│  └──────────────┘                                                           │
│     │                                                                        │
│     ▼ Crée DB + Configure                                                   │
│  ┌──────────────┐  ┌──────────────┐                                         │
│  │ MariaDB      │  │ Traefik      │                                         │
│  │ (new DB)     │  │ (new route)  │                                         │
│  └──────────────┘  └──────────────┘                                         │
│     │                                                                        │
│     ▼ Callback → Press                                                      │
│  ┌──────────────┐                                                           │
│  │ Press        │ ──► Email via Postal                                      │
│  │ Update Site  │     "Votre site est prêt!"                                │
│  └──────────────┘                                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Réseau Docker

```yaml
networks:
  frontend:    # Traefik + services exposés
  backend:     # Services internes
  database:    # MariaDB + Redis
  storage:     # MinIO

# Isolation
- Traefik seul expose des ports (80, 443)
- Services communiquent via réseau interne
- MariaDB non exposé à l'extérieur
```

## Volumes Persistants

```yaml
volumes:
  # Données critiques
  mariadb_data:     # Bases de données
  redis_data:       # Cache persistant
  minio_data:       # Fichiers/Backups
  
  # Configuration
  traefik_certs:    # Certificats SSL
  press_sites:      # Sites Frappe
  press_logs:       # Logs applicatifs
  
  # Keycloak/Postal
  keycloak_data:    # Config SSO
  postal_data:      # Config email
```

## Ports Utilisés

| Port | Service | Exposé | Description |
|------|---------|--------|-------------|
| 80 | Traefik | Oui | HTTP (redirect HTTPS) |
| 443 | Traefik | Oui | HTTPS |
| 3306 | MariaDB | Non | Database |
| 6379 | Redis | Non | Cache/Queue |
| 9000 | MinIO | Non | S3 API |
| 9001 | MinIO Console | Non | Admin UI |
| 8080 | Keycloak | Non | SSO |
| 25052 | Agent | Non | Agent API |
| 8000 | Press | Non | Frappe App |

## Sécurité

### Réseau

- Tous les services internes sur réseaux privés
- Seul Traefik expose 80/443
- Communication inter-services via DNS Docker

### Authentification

- Keycloak pour SSO
- JWT tokens pour API
- Agent password pour Press ↔ Agent

### Données

- Encryption at rest (MariaDB, MinIO)
- TLS pour toutes les communications
- Backups chiffrés

### Secrets

```yaml
# Gestion via fichiers .env
- DATABASE_PASSWORD
- REDIS_PASSWORD
- MINIO_ACCESS_KEY
- MINIO_SECRET_KEY
- LAGO_API_KEY
- KEYCLOAK_ADMIN_PASSWORD
- AGENT_PASSWORD
- ENCRYPTION_KEY
```

## Scaling

### Horizontal

```yaml
# Réplicas possibles
- Press backend: N instances
- Agent workers: N workers
- Redis: Sentinel mode
- MariaDB: Galera cluster (avancé)
```

### Vertical

```yaml
# Ressources recommandées
Minimum (10 sites):
  - 4 CPU, 8GB RAM, 100GB SSD

Medium (100 sites):
  - 8 CPU, 16GB RAM, 500GB SSD

Large (500+ sites):
  - 16 CPU, 32GB RAM, 1TB SSD
  - Cluster multi-nodes recommandé
```
