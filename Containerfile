FROM ubuntu:24.04 AS builder

USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    git curl jq python3-pip python3-venv build-essential \
    libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev \
    && rm -rf /var/lib/apt/lists/*

# Force Node 24 and Yarn globally
RUN curl -fsSL https://nodesource.com | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn

RUN useradd -ms /bin/bash frappe
USER frappe
WORKDIR /home/frappe/frappe-bench

# Bootstrap environment
RUN python3 -m venv env \
    && ./env/bin/pip install --no-cache-dir --upgrade pip wheel setuptools \
    && ./env/bin/pip install --quiet legacy-cgi

# Clean absolute Git clone structures
RUN mkdir -p apps sites

RUN git clone --depth 1 --branch version-16 https://github.com apps/frappe
RUN git clone --depth 1 --branch version-16 https://github.com apps/erpnext
RUN git clone --depth 1 --branch v16.15.0 https://github.com apps/hrms
RUN git clone --depth 1 --branch version-16 https://github.com apps/payments
RUN git clone --depth 1 --branch main https://github.com apps/ecommerce_integrations
RUN git clone --depth 1 --branch v16.3.0 https://github.com apps/lending
RUN git clone --depth 1 --branch v3.0.0 https://github.com apps/wiki
RUN git clone --depth 1 --branch develop https://github.com apps/print_designer
RUN git clone --depth 1 --branch version-16 https://github.com apps/offsite_backups
RUN git clone --depth 1 --branch develop https://github.com apps/raven

# Resolve structural application links inside python environment context
RUN ./env/bin/pip install -r apps/frappe/requirements.txt \
    && ./env/bin/pip install -r apps/erpnext/requirements.txt \
    && ./env/bin/pip install -e apps/frappe \
    && ./env/bin/pip install -e apps/erpnext \
    && ./env/bin/pip install --quiet legacy-cgi \
       -e apps/hrms \
       -e apps/payments \
       -e apps/ecommerce_integrations \
       -e apps/lending \
       -e apps/wiki \
       -e apps/print_designer \
       -e apps/offsite_backups \
       -e apps/raven

# Build frontend compiled visual components
RUN printf "frappe\nerpnext\nhrms\npayments\necommerce_integrations\nlending\nwiki\nprint_designer\noffsite_backups\nraven\n" > sites/apps.txt \
    && yarn --cwd apps/frappe install

# Runtime target stage mapping 
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y python3 nodejs git mariadb-client && rm -rf /var/lib/apt/lists/*
RUN useradd -ms /bin/bash frappe
USER frappe
WORKDIR /home/frappe/frappe-bench

COPY --from=builder --chown=frappe:frappe /home/frappe/frappe-bench /home/frappe/frappe-bench
ENV PATH="/home/frappe/frappe-bench/env/bin:$PATH"
