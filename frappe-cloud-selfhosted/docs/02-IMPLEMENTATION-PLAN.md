# 📋 Plan d'Implémentation

## Vue d'ensemble

Ce plan détaille les étapes pour implémenter la plateforme SaaS self-hosted.

**Durée estimée** : 2-3 semaines
**Prérequis** : Docker/Podman, domaine DNS, serveur Linux

---

## Phase 1 : Infrastructure de Base (Jours 1-3)

### 1.1 Configuration Docker Compose

**Fichiers à créer** :

```
docker-compose.yml          # Stack principale
docker-compose.dev.yml      # Override développement
docker-compose.prod.yml     # Override production
.env.example                # Variables template
```

**Services Phase 1** :

- [ ] Traefik (reverse proxy)
- [ ] MariaDB 11.x
- [ ] Redis 7.x (cache + queue)
- [ ] MinIO (object storage)

### 1.2 Traefik Configuration

```yaml
# Fonctionnalités à configurer
- Entrypoints (HTTP/HTTPS)
- Certificats Let's Encrypt (DNS challenge)
- Wildcard *.domain.com
- Dashboard sécurisé
```

### 1.3 Réseau et Volumes

```yaml
# Réseaux
- frontend (Traefik ↔ Apps)
- backend (Apps ↔ DB)
- storage (Apps ↔ MinIO)

# Volumes persistants
- mariadb_data
- redis_data
- minio_data
- traefik_certs
```

### Livrables Phase 1

- [ ] `docker-compose.yml` avec services de base
- [ ] Traefik fonctionnel avec SSL wildcard
- [ ] MariaDB accessible en interne
- [ ] MinIO avec console admin
- [ ] Script `scripts/init.sh`

---

## Phase 2 : Press + Agent (Jours 4-7)

### 2.1 Build Image Press v16

```dockerfile
# Image custom avec :
- Frappe v16
- Press app
- Apps marketplace (ERPNext, HRMS, CRM, etc.)
- Patches self-hosted
```

### 2.2 Configuration Press pour Self-Hosted

**Patches nécessaires** :

```python
# press/agent.py - Communication HTTP locale
# press/utils/__init__.py - Passwords locaux
# press/api/site.py - Création site simplifiée
```

**Press Settings** :

```yaml
Domain: cloud.domain.com
Cluster: Default (local)
Build Server: localhost
Docker Registry: local ou Harbor
```

### 2.3 Agent Setup

```yaml
# Configuration
- benches_directory: /home/frappe/benches
- press_url: http://press:8000
- redis_host: redis-queue
- agent_password: ****
```

### 2.4 Intégration Press ↔ Agent

```
Press                    Agent
  │                        │
  ├─── POST /jobs ────────►│
  │    (New Site job)      │
  │                        │
  │◄─── GET /jobs/:id ─────┤
  │    (Status update)     │
  │                        │
  ├─── Callback ──────────►│
  │    (Job completed)     │
```

### Livrables Phase 2

- [ ] Dockerfile Press v16 custom
- [ ] Agent configuré et fonctionnel
- [ ] Communication Press ↔ Agent OK
- [ ] Création site via Agent OK
- [ ] Nginx config générée automatiquement

---

## Phase 3 : Lago Billing (Jours 8-10)

### 3.1 Déploiement Lago

```yaml
services:
  lago-api:
    image: getlago/api
  lago-front:
    image: getlago/front
  lago-worker:
    image: getlago/api
  lago-clock:
    image: getlago/api
```

### 3.2 Configuration Plans

```yaml
Plans:
  - Starter:
      price: 29€/mois
      sites: 1
      users: 5
      apps: [erpnext]
      
  - Business:
      price: 99€/mois
      sites: 3
      users: 25
      apps: [erpnext, crm, hrms]
      
  - Enterprise:
      price: custom
      sites: unlimited
      users: unlimited
      apps: all
```

### 3.3 Webhooks Lago → Press

```python
# Événements à gérer
- subscription.started → Create Site
- subscription.terminated → Archive Site
- invoice.paid → Update Account
- invoice.payment_failed → Notify + Suspend
```

### 3.4 API Integration

```python
# Press → Lago
- Sync usage (storage, users)
- Get invoices
- Manage subscriptions

# Lago → Press
- Webhooks for billing events
```

### Livrables Phase 3

- [ ] Lago déployé et accessible
- [ ] Plans configurés
- [ ] Webhooks fonctionnels
- [ ] Checkout flow complet
- [ ] Invoices générées

---

## Phase 4 : Dashboard & UX (Jours 11-13)

### 4.1 Dashboard Client (Press Frontend)

```yaml
Pages:
  - /signup - Inscription
  - /login - Connexion
  - /dashboard - Vue d'ensemble
  - /sites - Liste des sites
  - /sites/:name - Détails site
  - /billing - Facturation
  - /settings - Paramètres
```

### 4.2 Keycloak SSO

```yaml
# Configuration
- Realm: cloud
- Client: press-dashboard
- Flows: Login, Registration
- Social: Google, GitHub (optionnel)
```

### 4.3 Postal Email

```yaml
# Templates
- welcome.html - Bienvenue
- site_ready.html - Site créé
- invoice.html - Facture
- password_reset.html - Reset mot de passe
```

### Livrables Phase 4

- [ ] Dashboard client fonctionnel
- [ ] SSO Keycloak intégré
- [ ] Emails transactionnels OK
- [ ] Flow inscription → site prêt complet

---

## Phase 5 : Production Ready (Jours 14-17)

### 5.1 Sécurité

```yaml
Checklist:
  - [ ] Secrets externalisés
  - [ ] Firewall configuré
  - [ ] Rate limiting actif
  - [ ] Audit logs
  - [ ] Backup automatique
```

### 5.2 Monitoring

```yaml
Stack:
  - Prometheus (métriques)
  - Grafana (dashboards)
  - Loki (logs)
  - Alertmanager (alertes)
```

### 5.3 Documentation

```yaml
Docs:
  - Guide utilisateur
  - Guide admin
  - API reference
  - Troubleshooting
```

### 5.4 CI/CD

```yaml
Pipeline:
  - Build images
  - Tests
  - Deploy staging
  - Deploy production
```

### Livrables Phase 5

- [ ] Stack monitoring
- [ ] Backups automatiques testés
- [ ] Documentation complète
- [ ] Pipeline CI/CD
- [ ] Runbook opérations

---

## Checklist Finale

### Infrastructure

- [ ] Docker Compose production-ready
- [ ] SSL wildcard fonctionnel
- [ ] DNS configuré
- [ ] Firewall actif

### Application

- [ ] Press v16 + patches
- [ ] Agent fonctionnel
- [ ] Lago billing intégré
- [ ] Emails transactionnels

### Opérations

- [ ] Backups automatiques
- [ ] Monitoring actif
- [ ] Alertes configurées
- [ ] Documentation à jour

### Business

- [ ] Plans tarifaires définis
- [ ] CGV/Mentions légales
- [ ] Support process
- [ ] Onboarding client

---

## Ressources Nécessaires

### Serveur Minimum

```yaml
CPU: 4 cores
RAM: 8 GB
Storage: 100 GB SSD
OS: Ubuntu 22.04 / Fedora 39+
```

### Domaine DNS

```yaml
Records:
  - A: cloud.domain.com → IP
  - A: *.domain.com → IP
  - MX: mail.domain.com (pour Postal)
```

### Temps Estimé

| Phase | Durée | Effort |
|-------|-------|--------|
| Phase 1 | 3 jours | Infrastructure |
| Phase 2 | 4 jours | Press + Agent |
| Phase 3 | 3 jours | Billing |
| Phase 4 | 3 jours | Dashboard |
| Phase 5 | 4 jours | Production |
| **Total** | **17 jours** | |
