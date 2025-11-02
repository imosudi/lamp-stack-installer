#!/usr/bin/env bash
# certbot.sh - Certbot install and certificate obtainment (sourced)

set -euo pipefail

install_certbot_and_get_certs() {
    local domain="$1"
    local phpmy="$2"
    local email="$3"

    log "Installing Certbot via snap..."
    if ! command -v snap >/dev/null 2>&1; then
        apt install -y snapd
    fi
    snap install core && snap refresh core
    snap install --classic certbot
    ln -sf /snap/bin/certbot /usr/bin/certbot

    log "Requesting certificates for ${domain} and ${phpmy}..."
    ufw allow 80/tcp || true

    certbot --apache --non-interactive --agree-tos --email "${email}" -d "${domain}" -d "${phpmy}" || {
        warn "Certbot failed to obtain certificates. Please check DNS and port accessibility."
        return 1
    }

    systemctl reload apache2 || true
    log "Certificates obtained"
    return 0
}
