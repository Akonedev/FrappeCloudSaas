# 06 - API Reference

## Press API

### Authentication

Toutes les requêtes API nécessitent une authentification via token.

```bash
# Obtenir un token
curl -X POST http://cloud.localhost:30080/api/method/frappe.auth.get_logged_user \
  -H "Content-Type: application/json" \
  -d '{"usr": "Administrator", "pwd": "admin"}'
```

### Sites

#### Créer un site

```bash
POST /api/method/press.api.site.new
```

```json
{
  "site": {
    "name": "mysite",
    "apps": ["frappe", "erpnext"],
    "plan": "Starter"
  }
}
```

#### Lister les sites

```bash
GET /api/method/press.api.site.list
```

#### Archiver un site

```bash
POST /api/method/press.api.site.archive
```

```json
{
  "name": "mysite.cloud.localhost"
}
```

### Servers

#### Lister les serveurs

```bash
GET /api/method/press.api.server.list
```

#### Status d'un serveur

```bash
GET /api/method/press.api.server.status
```

```json
{
  "server": "app-server-1"
}
```

---

## Agent API

L'Agent expose une API REST sur le port 25052.

### Ping

```bash
GET /agent/ping
Authorization: Bearer <agent_password>
```

Response:
```json
{"status": "ok", "agent": "1.0.0"}
```

### Execute Job

```bash
POST /agent/job
Authorization: Bearer <agent_password>
```

```json
{
  "job_type": "New Site",
  "data": {
    "name": "mysite",
    "apps": ["frappe"],
    "admin_password": "secret"
  }
}
```

### Job Status

```bash
GET /agent/job/<job_id>
Authorization: Bearer <agent_password>
```

---

## Lago API

### Customers

#### Créer un client

```bash
POST /api/v1/customers
Authorization: Bearer <lago_api_key>
```

```json
{
  "customer": {
    "external_id": "customer_001",
    "name": "Acme Corp",
    "email": "billing@acme.com"
  }
}
```

### Subscriptions

#### Créer une souscription

```bash
POST /api/v1/subscriptions
Authorization: Bearer <lago_api_key>
```

```json
{
  "subscription": {
    "external_customer_id": "customer_001",
    "plan_code": "starter_monthly",
    "external_id": "sub_001"
  }
}
```

### Usage Events

#### Envoyer un événement

```bash
POST /api/v1/events
Authorization: Bearer <lago_api_key>
```

```json
{
  "event": {
    "transaction_id": "evt_001",
    "external_subscription_id": "sub_001",
    "code": "storage_gb",
    "properties": {
      "gb_used": 5.5
    }
  }
}
```

---

## Keycloak API

### Token Endpoint

```bash
POST /realms/frappe-cloud/protocol/openid-connect/token
```

```bash
curl -X POST http://auth.localhost:30080/realms/frappe-cloud/protocol/openid-connect/token \
  -d "client_id=press" \
  -d "client_secret=<client_secret>" \
  -d "grant_type=client_credentials"
```

### User Info

```bash
GET /realms/frappe-cloud/protocol/openid-connect/userinfo
Authorization: Bearer <access_token>
```

---

## MinIO S3 API

### Compatible AWS S3

MinIO est 100% compatible avec l'API S3.

```python
import boto3

s3 = boto3.client(
    's3',
    endpoint_url='http://s3.localhost:30080',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='<minio_password>'
)

# Upload
s3.upload_file('backup.sql', 'backups', 'backup.sql')

# Download
s3.download_file('backups', 'backup.sql', 'local_backup.sql')

# List
response = s3.list_objects_v2(Bucket='backups')
for obj in response.get('Contents', []):
    print(obj['Key'])
```

---

## Webhooks

### Press Webhooks

Configurer dans Press Settings > Webhooks.

```json
{
  "event": "site.created",
  "url": "https://your-webhook.com/press",
  "headers": {
    "X-Secret": "your-secret"
  }
}
```

### Lago Webhooks

Configurer dans Lago > Settings > Webhooks.

```json
{
  "webhook_endpoint": {
    "webhook_url": "https://your-webhook.com/lago",
    "signature_algo": "hmac"
  }
}
```

---

## Rate Limiting

| Service | Limite | Fenêtre |
|---------|--------|---------|
| Press API | 100 req | 1 min |
| Agent API | 50 req | 1 min |
| Lago API | 1000 req | 1 min |

---

## Codes d'Erreur

| Code | Description |
|------|-------------|
| 400 | Bad Request - Paramètres invalides |
| 401 | Unauthorized - Token manquant ou invalide |
| 403 | Forbidden - Permissions insuffisantes |
| 404 | Not Found - Ressource introuvable |
| 429 | Too Many Requests - Rate limit dépassé |
| 500 | Internal Server Error |
