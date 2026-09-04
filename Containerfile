# --- STAGE 1: Builder Asset Engine ---
FROM ubuntu:24.04 AS builder

USER root
ENV DEBIAN_FRONTEND=noninteractive

# Install core development tools and Node 24 requirement
RUN apt-get update && apt-get install -y \
    git curl jq python3-pip python3-venv build-essential python3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://nodesource.com | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn

# Set up dedicated frappe ecosystem user 
RUN useradd -ms /bin/bash frappe
USER frappe
WORKDIR /home/frappe

# Install global bench command tool natively
RUN python3 -m venv venv \
    && ./venv/bin/pip install --no-cache-dir --upgrade pip wheel setuptools \
    && ./venv/bin/pip install frappe-bench

# Initialize clean bench configuration structure targeting v16 core
RUN ./venv/bin/bench init --frappe-branch version-16 --skip-redis-config-generation --skip-assets-generation frappe-bench

WORKDIR /home/frappe/frappe-bench

# Fetch applications cleanly using absolute https://github.com URL layouts
RUN ../venv/bin/bench get-app --branch version-16 erpnext https://github.com/frappe/erpnext \
    && ../venv/bin/bench get-app --branch v16.15.0 hrms https://github.com/frappe/hrms \
    && ../venv/bin/bench get-app --branch version-16 payments https://github.com/frappe/payments \
    && ../venv/bin/bench get-app --branch main ecommerce_integrations https://github.comecommerce_integrations/frappe/ \
    && ../venv/bin/bench get-app --branch v16.3.0 lending https://github.com/frappe/lending \
    && ../venv/bin/bench get-app --branch v3.0.0 wiki https://github.com/frappe/wiki \
    && ../venv/bin/bench get-app --branch develop print_designer https://github.com/frappe/print_designer \
    && ../venv/bin/bench get-app --branch version-16 offsite_backups https://github.com/frappe/offsite_backups \
    && ../venv/bin/bench get-app --branch develop raven https://github.com/frappe/raven

# Compile production-ready JavaScript and Vue visual assets
RUN ../venv/bin/bench build --apps frappe,erpnext,hrms,payments,ecommerce_integrations,lending,wiki,print_designer,offsite_backups,raven


# --- STAGE 2: Immutable Runtime Target ---
FROM ubuntu:24.04

USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    python3 nodejs git mariadb-client curl \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash frappe
USER frappe
WORKDIR /home/frappe

# Copy the fully compiled, working environment from the builder stage
COPY --from=builder --chown=frappe:frappe /home/frappe /home/frappe

WORKDIR /home/frappe/frappe-bench
ENV PATH="/home/frappe/venv/bin:/home/frappe/frappe-bench/env/bin:$PATH"

EXPOSE 8000
CMD ["bench", "start"]
