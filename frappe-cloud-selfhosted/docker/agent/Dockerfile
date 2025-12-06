# ============================================
# Frappe Agent - Dockerfile
# ============================================
# Agent pour la gestion des serveurs/sites
# Communication HTTP avec Press
# ============================================

FROM python:3.12-slim

LABEL maintainer="Frappe Cloud Self-Hosted"
LABEL version="1.0.0"
LABEL description="Frappe Agent for server management"

# Environment
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    AGENT_USER=frappe \
    AGENT_PORT=25052

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    mariadb-client \
    docker.io \
    supervisor \
    sudo \
    procps \
    nano \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create frappe user with docker access
RUN groupadd -g 1000 frappe \
    && useradd -u 1000 -g frappe -m -s /bin/bash frappe \
    && usermod -aG docker frappe \
    && echo "frappe ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Clone Agent repository
WORKDIR /home/frappe
RUN git clone --depth 1 https://github.com/frappe/agent.git

WORKDIR /home/frappe/agent

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -e .

# Copy configuration and scripts
COPY config/agent.conf /etc/supervisor/conf.d/agent.conf
COPY scripts/docker-entrypoint.sh /usr/local/bin/
COPY patches/ /home/frappe/patches/

# Apply patches for HTTP communication (non-HTTPS local)
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Create necessary directories
RUN mkdir -p /home/frappe/agent/logs \
    && mkdir -p /home/frappe/frappe-bench/sites \
    && chown -R frappe:frappe /home/frappe

WORKDIR /home/frappe/agent
USER frappe

# Expose agent port
EXPOSE ${AGENT_PORT}

# Entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["start"]
