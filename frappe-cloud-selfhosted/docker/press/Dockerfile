# ============================================
# Frappe Press v16 - Dockerfile (Simplified)
# ============================================
# Utilise l'image officielle frappe/bench
# Build: podman build -t frappe-press:v16 .
# ============================================

FROM docker.io/frappe/bench:latest

LABEL maintainer="Frappe Cloud Self-Hosted"
LABEL version="1.0.0"
LABEL description="Frappe Press v16 for self-hosted cloud"

# Arguments
ARG FRAPPE_VERSION=version-16
ARG PRESS_BRANCH=develop

# Environment
ENV PYTHONUNBUFFERED=1 \
    FRAPPE_USER=frappe \
    BENCH_DIR=/home/frappe/frappe-bench

# Switch to root for system installations
USER root

# Install additional dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    redis-tools \
    mariadb-client \
    curl \
    procps \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy entrypoint scripts
COPY scripts/docker-entrypoint.sh /usr/local/bin/
COPY scripts/healthcheck.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Switch to frappe user
USER frappe
WORKDIR /home/frappe/frappe-bench

# Initialize bench with Frappe v16
RUN bench init --skip-redis-config-generation --frappe-branch version-16 /home/frappe/frappe-bench || true

# Get Press app (using develop branch as v16 tag may not exist)
RUN cd /home/frappe/frappe-bench && bench get-app --branch develop press || true

# Copy configuration
COPY --chown=frappe:frappe config/common_site_config.json /home/frappe/frappe-bench/sites/common_site_config.json

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=5 \
    CMD /usr/local/bin/healthcheck.sh

# Entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["start"]
