# --- STAGE 1: Static Compilation Layer ---
FROM frappe/erpnext:version-16 AS builder

USER root
RUN apt-get update && apt-get install -y git curl jq && rm -rf /var/lib/apt/lists/*

USER frappe
WORKDIR /home/frappe/frappe-bench

# 1. Clean out existing boilerplate apps to prevent link collisions
RUN rm -rf apps/erpnext apps/frappe

# 2. Pull down core framework and absolute target repositories (Fixed erpnext URL typo)
RUN git clone --depth 1 --branch version-16 https://github.com/frappe/frappe apps/frappe \
    && git clone --depth 1 --branch version-16 https://github.com/frappe/erpnext apps/erpnext \
    && git clone --depth 1 --branch v16.15.0 https://github.com/frappe/hrms apps/hrms \
    && git clone --depth 1 --branch version-16 https://github.com/frappe/payments apps/payments \
    && git clone --depth 1 --branch v1.20.3 https://github.com/frappe/ecommerce_integrations apps/ecommerce_integrations \
    && git clone --depth 1 --branch v16.3.0 https://github.com/frappe/lending apps/lending \
    && git clone --depth 1 --branch v3.0.0 https://github.com/frappe/wiki apps/wiki \
    && git clone --depth 1 --branch main https://github.com/frappe/print_designer apps/print_designer \
    && git clone --depth 1 --branch version-16 https://github.com/frappe/offsite_backups apps/offsite_backups \
    && git clone --depth 1 --branch main https://github.com/frappe/raven apps/raven

# 3. Synchronize Python virtual environment and link ecosystem packages
RUN ./env/bin/pip install --quiet legacy-cgi \
    -e apps/frappe \
    -e apps/erpnext \
    -e apps/hrms \
    -e apps/payments \
    -e apps/ecommerce_integrations \
    -e apps/lending \
    -e apps/wiki \
    -e apps/print_designer \
    -e apps/offsite_backups \
    -e apps/raven

# 4. Generate system manifest mappings
RUN printf "frappe\nerpnext\nhrms\npayments\necommerce_integrations\nlending\nwiki\nprint_designer\noffsite_backups\nraven\n" > sites/apps.txt

# 5. Compile global production visual assets statically
RUN bench build --apps frappe,erpnext,hrms,payments,ecommerce_integrations,lending,wiki,print_designer,offsite_backups,raven


# --- STAGE 2: Immutable Runtime Engine Target ---
FROM frappe/erpnext:version-16

USER root
WORKDIR /home/frappe/frappe-bench

# Purge fallback structural files to receive your custom compilations cleanly
RUN rm -rf apps sites

# Map everything over pre-compiled from Stage 1
COPY --from=builder --chown=frappe:frappe /home/frappe/frappe-bench/apps /home/frappe/frappe-bench/apps
COPY --from=builder --chown=frappe:frappe /home/frappe/frappe-bench/sites /home/frappe/frappe-bench/sites

USER frappe

# Re-link your contextual apps inside Stage 2 production Python pathways
RUN ./env/bin/pip install --quiet legacy-cgi \
    -e apps/hrms \
    -e apps/payments \
    -e apps/ecommerce_integrations \
    -e apps/lending \
    -e apps/wiki \
    -e apps/print_designer \
    -e apps/offsite_backups \
    -e apps/raven
