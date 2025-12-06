# 🔧 Guide d'Installation

## Prérequis

### Système

| Composant | Minimum | Recommandé |
|-----------|---------|------------|
| OS | Ubuntu 22.04 / Fedora 39 | Ubuntu 24.04 / Fedora 40 |
| CPU | 4 cores | 8 cores |
| RAM | 8 GB | 16 GB |
| Storage | 100 GB SSD | 500 GB NVMe |
| Network | 100 Mbps | 1 Gbps |

### Logiciels

```bash
# Docker ou Podman
docker --version  # >= 24.0
# ou
podman --version  # >= 4.0

# Docker Compose
docker compose version  # >= 2.20
# ou
podman-compose --version

# Git
git --version  # >= 2.30
```

### DNS

Vous devez avoir :
- Un domaine (ex: `moncloud.com`)
- Accès aux enregistrements DNS
- Capacité à créer des wildcards

```dns
# Enregistrements requis
A     cloud.moncloud.com    → IP_SERVEUR
A     *.moncloud.com        → IP_SERVEUR
MX    mail.moncloud.com     → IP_SERVEUR (optionnel, pour Postal)
```

---

## Installation Rapide

### 1. Cloner le projet

```bash
cd /opt
git clone https://github.com/votre-org/frappe-cloud-selfhosted.git
cd frappe-cloud-selfhosted
```

### 2. Configurer l'environnement

```bash
# Copier le template
cp .env.example .env

# Éditer avec vos valeurs
nano .env
```

**Variables obligatoires** :

```bash
# Domaine
DOMAIN=moncloud.com
ACME_EMAIL=admin@moncloud.com

# Sécurité (générer avec: openssl rand -hex 32)
MARIADB_ROOT_PASSWORD=votre_mot_de_passe_securise
ENCRYPTION_KEY=votre_cle_encryption_32_chars
AGENT_PASSWORD=votre_mot_de_passe_agent

# MinIO
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=votre_mot_de_passe_minio

# Lago
LAGO_API_KEY=votre_cle_lago
```

### 3. Initialiser l'infrastructure

```bash
# Rendre le script exécutable
chmod +x scripts/init.sh

# Lancer l'initialisation
./scripts/init.sh
```

### 4. Démarrer les services

```bash
# Mode développement
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Mode production
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### 5. Vérifier le déploiement

```bash
# Vérifier les conteneurs
docker compose ps

# Vérifier les logs
docker compose logs -f

# Tester l'accès
curl -I https://cloud.moncloud.com
```

---

## Installation Détaillée

### Étape 1 : Préparer le serveur

```bash
# Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# Installer les dépendances
sudo apt install -y \
    curl \
    git \
    htop \
    vim \
    ufw

# Configurer le firewall
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### Étape 2 : Installer Docker

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com | sudo sh

# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER

# Redémarrer pour appliquer
newgrp docker
```

Ou pour **Podman** (Fedora) :

```bash
sudo dnf install -y podman podman-compose
```

### Étape 3 : Configurer les volumes

```bash
# Créer les répertoires de données
sudo mkdir -p /data/{mariadb,redis,minio,traefik,sites,logs}
sudo chown -R 1000:1000 /data
```

### Étape 4 : Générer les secrets

```bash
# Script pour générer les secrets
cat > generate-secrets.sh << 'EOF'
#!/bin/bash
echo "MARIADB_ROOT_PASSWORD=$(openssl rand -hex 16)"
echo "ENCRYPTION_KEY=$(openssl rand -hex 32)"
echo "AGENT_PASSWORD=$(openssl rand -hex 16)"
echo "MINIO_ROOT_PASSWORD=$(openssl rand -hex 16)"
echo "LAGO_API_KEY=$(openssl rand -hex 32)"
EOF

chmod +x generate-secrets.sh
./generate-secrets.sh >> .env
```

### Étape 5 : Configurer Traefik

```bash
# Créer le réseau Docker
docker network create traefik-public

# Configurer ACME (Let's Encrypt)
mkdir -p docker/traefik/acme
touch docker/traefik/acme/acme.json
chmod 600 docker/traefik/acme/acme.json
```

### Étape 6 : Premier démarrage

```bash
# Démarrer uniquement l'infrastructure de base d'abord
docker compose up -d traefik mariadb redis minio

# Attendre que MariaDB soit prêt
docker compose logs -f mariadb
# Attendre "ready for connections"

# Démarrer Press
docker compose up -d press

# Initialiser Press
docker compose exec press bench --site cloud.moncloud.com install-app press
```

---

## Post-Installation

### Créer le premier admin

```bash
docker compose exec press bench --site cloud.moncloud.com add-user \
    admin@moncloud.com \
    --first-name Admin \
    --last-name System \
    --password VotreMotDePasse123!
```

### Configurer Press Settings

Accédez à `https://cloud.moncloud.com/app/press-settings` :

1. **Domain** : Sélectionnez votre Root Domain
2. **Cluster** : Default
3. **Docker Registry** : Configurez si nécessaire

### Créer le premier Release Group

1. Allez dans **Release Group** > **New**
2. Ajoutez les apps (frappe, erpnext, etc.)
3. Déployez le premier bench

---

## Dépannage

### Les conteneurs ne démarrent pas

```bash
# Vérifier les logs
docker compose logs SERVICE_NAME

# Vérifier les ressources
docker stats

# Redémarrer un service
docker compose restart SERVICE_NAME
```

### Problèmes de certificat SSL

```bash
# Vérifier Traefik
docker compose logs traefik

# Vérifier la config ACME
cat docker/traefik/acme/acme.json

# Forcer le renouvellement
docker compose restart traefik
```

### MariaDB refuse les connexions

```bash
# Vérifier le status
docker compose exec mariadb mysqladmin status -u root -p

# Réinitialiser si nécessaire
docker compose down mariadb
docker volume rm frappe-cloud_mariadb_data
docker compose up -d mariadb
```

### L'Agent ne répond pas

```bash
# Vérifier l'agent
docker compose exec press curl http://localhost:25052/ping

# Redémarrer l'agent
docker compose exec press supervisorctl restart agent
```

---

## Mise à Jour

### Mise à jour standard

```bash
# Arrêter les services
docker compose down

# Récupérer les dernières modifications
git pull

# Reconstruire les images
docker compose build

# Redémarrer
docker compose up -d
```

### Mise à jour avec migration

```bash
# Backup avant mise à jour
./scripts/backup.sh

# Mettre à jour
git pull
docker compose build

# Migrer la base de données
docker compose up -d
docker compose exec press bench --site cloud.moncloud.com migrate

# Vérifier
docker compose logs press
```

---

## Désinstallation

⚠️ **Attention** : Cette action est irréversible !

```bash
# Arrêter et supprimer les conteneurs
docker compose down -v

# Supprimer les données (DANGEREUX)
sudo rm -rf /data/*

# Supprimer les images
docker image prune -a
```
