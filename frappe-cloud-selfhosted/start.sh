#!/bin/bash
# ============================================
# Frappe Cloud Self-Hosted - Quick Start Script
# ============================================
# Ce script lance la plateforme Press en mode dev
# Utilise Podman (compatible Docker)
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
export MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-jUbLMJPDraRnbRRwXpVk9cuH}"
export HTTP_PORT="${HTTP_PORT:-30080}"
export HTTPS_PORT="${HTTPS_PORT:-30443}"
export TRAEFIK_DASHBOARD_PORT="${TRAEFIK_DASHBOARD_PORT:-30008}"

# Vérifier l'image Press
if ! podman image exists localhost/frappe-press:v15-official 2>/dev/null; then
    echo -e "${YELLOW}Image frappe-press:v15-official non trouvée.${NC}"
    echo "Veuillez d'abord construire l'image avec build.sh"
    exit 1
fi

echo -e "${BLUE}🚀 Démarrage de Frappe Cloud Self-Hosted...${NC}"

# Créer les réseaux s'ils n'existent pas
echo -e "${GREEN}📡 Création des réseaux...${NC}"
podman network exists frappe-cloud-frontend 2>/dev/null || podman network create frappe-cloud-frontend
podman network exists frappe-cloud-backend 2>/dev/null || podman network create frappe-cloud-backend

# Démarrer l'infrastructure (via podman-compose si disponible, sinon manuellement)
if command -v podman-compose &>/dev/null; then
    echo -e "${GREEN}📦 Démarrage de l'infrastructure via podman-compose...${NC}"
    podman-compose up -d traefik mariadb redis-cache redis-queue minio
else
    echo -e "${YELLOW}⚠️  podman-compose non disponible, démarrage manuel...${NC}"
    
    # Démarrer les services manuellement
    for service in traefik mariadb redis-cache redis-queue minio; do
        if ! podman container exists $service 2>/dev/null; then
            echo "  Démarrage de $service..."
            # TODO: Ajouter les commandes podman run pour chaque service
        else
            podman start $service 2>/dev/null || true
        fi
    done
fi

# Attendre que MariaDB soit prêt
echo -e "${YELLOW}⏳ Attente de MariaDB...${NC}"
until podman exec mariadb healthcheck.sh --connect --innodb_initialized 2>/dev/null; do
    echo -n "."
    sleep 2
done
echo -e " ${GREEN}✓${NC}"

# Attendre que Redis soit prêt
echo -e "${YELLOW}⏳ Attente de Redis...${NC}"
until podman exec redis-cache redis-cli ping 2>/dev/null | grep -q PONG; do
    echo -n "."
    sleep 1
done
echo -e " ${GREEN}✓${NC}"

# Démarrer les services Frappe
echo -e "${GREEN}🔧 Démarrage des services Frappe...${NC}"

# Volume frappe-sites
SITES_VOLUME="frappe-cloud-dev_frappe-sites"

# Vérifier si le site existe
if ! podman volume inspect $SITES_VOLUME &>/dev/null; then
    echo -e "${YELLOW}⚠️  Volume sites non trouvé. Création...${NC}"
    podman volume create $SITES_VOLUME
fi

# Démarrer le backend
if podman container exists frappe-backend 2>/dev/null; then
    podman start frappe-backend
else
    echo "  Création du conteneur frappe-backend..."
    podman run -d --name frappe-backend \
        --network frappe-cloud-frontend \
        --network frappe-cloud-backend \
        -e DB_HOST=mariadb \
        -e REDIS_CACHE=redis-cache:6379 \
        -e REDIS_QUEUE=redis-queue:6379 \
        -v $SITES_VOLUME:/home/frappe/frappe-bench/sites \
        localhost/frappe-press:v15-official \
        bench serve --port 8000
fi

# Démarrer les workers
for worker in frappe-worker-default frappe-scheduler; do
    if podman container exists $worker 2>/dev/null; then
        podman start $worker
    else
        if [[ "$worker" == *scheduler* ]]; then
            CMD="bench schedule"
        else
            CMD="bench worker --queue default"
        fi
        echo "  Création du conteneur $worker..."
        podman run -d --name $worker \
            --network frappe-cloud-backend \
            -e DB_HOST=mariadb \
            -e REDIS_CACHE=redis-cache:6379 \
            -e REDIS_QUEUE=redis-queue:6379 \
            -v $SITES_VOLUME:/home/frappe/frappe-bench/sites \
            localhost/frappe-press:v15-official \
            $CMD
    fi
done

# Afficher le résumé
echo ""
echo -e "${GREEN}✅ Frappe Cloud Self-Hosted est démarré !${NC}"
echo ""
echo -e "📊 ${BLUE}Services:${NC}"
podman ps --format "table {{.Names}}\t{{.Status}}" | grep -E "traefik|mariadb|redis|minio|frappe"
echo ""
echo -e "🌐 ${BLUE}Accès:${NC}"
echo "   - Press Dashboard: http://press.localhost:$HTTP_PORT"
echo "   - Traefik Dashboard: http://localhost:$TRAEFIK_DASHBOARD_PORT"
echo ""
echo -e "🔐 ${BLUE}Identifiants par défaut:${NC}"
echo "   - Admin: Administrator / admin"
echo ""
echo -e "${YELLOW}💡 Conseil: Ajoutez '127.0.0.1 press.localhost' à /etc/hosts${NC}"
