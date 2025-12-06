# 05 - Configuration

## Variables d'Environnement

### Domain & SSL

| Variable | Description | Défaut | Requis |
|----------|-------------|--------|--------|
| `DOMAIN` | Domaine principal | `localhost` | Oui |
| `ACME_EMAIL` | Email Let's Encrypt | - | Production |

### Base de Données (MariaDB)

| Variable | Description | Défaut | Requis |
|----------|-------------|--------|--------|
| `MARIADB_ROOT_PASSWORD` | Mot de passe root | - | Oui |
| `MARIADB_HOST` | Hôte MariaDB | `mariadb` | Non |
| `MARIADB_PORT` | Port MariaDB | `3306` | Non |

### Redis

| Variable | Description | Défaut | Requis |
|----------|-------------|--------|--------|
| `REDIS_CACHE_HOST` | Hôte cache Redis | `redis-cache` | Non |
| `REDIS_QUEUE_HOST` | Hôte queue Redis | `redis-queue` | Non |

### Frappe/Press

| Variable | Description | Défaut | Requis |
|----------|-------------|--------|--------|
| `FRAPPE_SITE_NAME` | Nom du site principal | `cloud.localhost` | Oui |
| `ADMIN_PASSWORD` | Mot de passe admin | `admin` | Oui |
| `ENCRYPTION_KEY` | Clé de chiffrement (32 chars) | - | Oui |

### Agent

| Variable | Description | Défaut | Requis |
|----------|-------------|--------|--------|
| `AGENT_PASSWORD` | Mot de passe agent | - | Oui |
| `AGENT_PORT` | Port de l'agent | `25052` | Non |

### MinIO (S3)

| Variable | Description | Défaut | Requis |
|----------|-------------|--------|--------|
| `MINIO_ROOT_USER` | Utilisateur MinIO | `minioadmin` | Oui |
| `MINIO_ROOT_PASSWORD` | Mot de passe MinIO | - | Oui |
| `MINIO_ENDPOINT` | Endpoint MinIO | `minio:9000` | Non |

### Lago (Facturation)

| Variable | Description | Défaut | Requis |
|----------|-------------|--------|--------|
| `LAGO_SECRET_KEY` | Clé secrète Lago (64 chars) | - | Oui |
| `LAGO_DB_PASSWORD` | Mot de passe PostgreSQL | - | Oui |
| `LAGO_API_URL` | URL API Lago | `http://lago-api:3000` | Non |

### Keycloak (SSO)

| Variable | Description | Défaut | Requis |
|----------|-------------|--------|--------|
| `KEYCLOAK_ADMIN` | Admin Keycloak | `admin` | Oui |
| `KEYCLOAK_ADMIN_PASSWORD` | Mot de passe admin | - | Oui |
| `KEYCLOAK_DB_PASSWORD` | Mot de passe PostgreSQL | - | Oui |

### Ports

| Variable | Description | Défaut |
|----------|-------------|--------|
| `HTTP_PORT` | Port HTTP Traefik | `30080` |
| `HTTPS_PORT` | Port HTTPS Traefik | `30443` |
| `TRAEFIK_DASHBOARD_PORT` | Port dashboard Traefik | `30008` |

---

## Configuration Press

### Site Configuration

Après le démarrage, configurer Press via l'interface admin :

1. **Aller à** : `http://cloud.localhost:30080/app/press-settings`

2. **Configurer** :
   - **Domain** : `localhost`
   - **Self-Hosted** : Activé
   - **Agent Password** : (même que `AGENT_PASSWORD`)

### Server Configuration

1. **Créer un Server** :
   - Type : `App Server`
   - Hostname : `localhost`
   - IP : `host.docker.internal` ou IP locale
   - Agent Port : `25052`

2. **Créer un Database Server** :
   - Hostname : `mariadb`
   - Port : `3306`
   - Root Password : (même que `MARIADB_ROOT_PASSWORD`)

### MinIO Configuration

```python
# Dans Press Settings
{
    "s3_endpoint": "http://minio:9000",
    "s3_access_key": "minioadmin",
    "s3_secret_key": "MINIO_ROOT_PASSWORD",
    "s3_bucket_backups": "backups",
    "s3_bucket_private": "private",
    "s3_bucket_public": "public"
}
```

---

## Configuration Lago

### Première Configuration

1. **Accéder** : `http://billing.localhost:30080`
2. **Créer un compte admin**
3. **Générer une API Key**

### Intégration avec Press

```python
# Ajouter dans Press Settings
frappe.conf.lago_api_url = "http://lago-api:3000"
frappe.conf.lago_api_key = "YOUR_LAGO_API_KEY"
```

### Créer les Plans de Facturation

1. **Plans** :
   - Starter : 29€/mois
   - Business : 99€/mois
   - Enterprise : 299€/mois

2. **Métriques** :
   - Sites actifs
   - Stockage utilisé
   - Bande passante

---

## Configuration Keycloak

### Créer un Realm

1. **Accéder** : `http://auth.localhost:30080`
2. **Admin Console** → Login avec admin
3. **Créer Realm** : `frappe-cloud`

### Configurer le Client

1. **Clients** → **Create**
2. **Client ID** : `press`
3. **Root URL** : `http://cloud.localhost:30080`
4. **Valid Redirect URIs** : `http://cloud.localhost:30080/*`

### Intégration OIDC avec Press

```python
# Configuration Social Login
{
    "provider_name": "Keycloak",
    "client_id": "press",
    "client_secret": "CLIENT_SECRET",
    "authorization_url": "http://auth.localhost:30080/realms/frappe-cloud/protocol/openid-connect/auth",
    "token_url": "http://auth.localhost:30080/realms/frappe-cloud/protocol/openid-connect/token",
    "userinfo_url": "http://auth.localhost:30080/realms/frappe-cloud/protocol/openid-connect/userinfo"
}
```

---

## Configuration Traefik

### Mode Développement (HTTP)

Le docker-compose.yml est configuré par défaut pour HTTP.

### Mode Production (HTTPS)

1. **Décommenter dans docker-compose.yml** :

```yaml
command:
  # Activer ces lignes
  - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
  - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
  - "--certificatesresolvers.letsencrypt.acme.email=${ACME_EMAIL}"
  - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
  - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
```

2. **Ajouter aux labels des services** :

```yaml
labels:
  - "traefik.http.routers.press.tls=true"
  - "traefik.http.routers.press.tls.certresolver=letsencrypt"
```

### Wildcard SSL (pour les sous-domaines dynamiques)

Utiliser le challenge DNS avec votre provider :

```yaml
- "--certificatesresolvers.letsencrypt.acme.dnschallenge=true"
- "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=cloudflare"
```

---

## Sécurité

### Checklist Production

- [ ] Changer tous les mots de passe par défaut
- [ ] Activer HTTPS
- [ ] Configurer les backups automatiques
- [ ] Activer le rate limiting Traefik
- [ ] Configurer les headers de sécurité
- [ ] Restreindre l'accès au dashboard Traefik
- [ ] Activer 2FA sur Keycloak
- [ ] Auditer les logs régulièrement

### Firewall (UFW)

```bash
# Autoriser uniquement les ports nécessaires
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 30080/tcp  # Fermer en production
sudo ufw enable
```

---

## Monitoring

### Logs

```bash
# Voir tous les logs
./scripts/setup.sh logs

# Logs d'un service spécifique
./scripts/setup.sh logs press

# Suivre en temps réel
docker-compose logs -f press
```

### Health Checks

```bash
# Status des services
./scripts/setup.sh status

# Vérifier Press
curl http://cloud.localhost:30080/api/method/ping

# Vérifier Lago
curl http://billing-api.localhost:30080/health

# Vérifier Keycloak
curl http://auth.localhost:30080/health
```
