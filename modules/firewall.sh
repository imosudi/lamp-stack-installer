#!/usr/bin/env bash
# firewall.sh - UFW configuration (sourced)

set -euo pipefail

configure_ufw() {
    local allow_ssh="${ALLOW_SSH:-true}"   # default to true if not set
    log "Configuring UFW firewall..."

    if ! command -v ufw >/dev/null 2>&1; then
        log "Installing UFW..."
        apt install -y ufw
    fi

    local status
    status=$(ufw status | grep -Po '(?<=Status: ).*' || echo "inactive")

    if [[ "$status" = "inactive" ]]; then
        log "Enabling UFW with default deny incoming"
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw --force enable
    else
        log "UFW already active"
    fi

    # Allow SSH (if permitted)
    if [[ "$allow_ssh" == "true" ]]; then
        if ! ufw status | grep -q "OpenSSH"; then
            log "Allowing SSH access"
            ufw allow OpenSSH
        fi
    fi

    # Always allow HTTP and HTTPS
    ufw allow 80/tcp || true
    ufw allow 443/tcp || true

    log "UFW status summary:"
    ufw status verbose || true

    log "Firewall configuration complete."
}
