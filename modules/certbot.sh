#!/usr/bin/env bash
# certbot.sh - Certbot install and certificate obtainment (sourced)

set -euo pipefail

install_certbot_and_get_certs() {
    local domain="${DOMAIN:-localhost}"
    local phpmy="phpmyadmin.${DOMAIN:-localhost}"
    local email="${EMAIL:-admin@${DOMAIN:-localhost}}"

    log "Installing Certbot via snap..."

    if ! command -v snap >/dev/null 2>&1; then
        log "Installing snapd..."
        apt install -y snapd
    fi

    # Ensure snap core is available
    snap install core >/dev/null 2>&1 || snap refresh core >/dev/null 2>&1
    snap install --classic certbot >/dev/null 2>&1
    ln -sf /snap/bin/certbot /usr/bin/certbot
    
    log "Obtaining SSL certificates via Let's Encrypt for ${domain} and ${phpmy}..."
    #log "Requesting certificates for ${domain} and ${phpmy}..."
    ufw allow 80/tcp >/dev/null 2>&1 || true

    if certbot --apache --non-interactive --agree-tos \
        --email "${email}" \
        -d "${domain}" -d "${phpmy}"; then
        systemctl reload apache2 || true
        log "Certificates obtained successfully for ${domain} and ${phpmy}"
    else
        warn "Certbot failed to obtain certificates. Please verify DNS and port accessibility."
    fi
}
