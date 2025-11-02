#!/usr/bin/env bash
# firewall.sh - UFW configuration (sourced)

set -euo pipefail

configure_ufw() {
    local allow_ssh="$1"
    log "Configuring UFW firewall..."
    if ! command -v ufw >/dev/null 2>&1; then
        apt install -y ufw
    fi

    local status
    status=$(ufw status | grep -Po '(?<=Status: ).*' || echo "inactive")
    if [[ "$status" = "inactive" ]]; then
        log "Enabling UFW with default deny incoming"
        echo "y" | ufw enable
    else
        log "UFW already active"
    fi

    if [[ "$allow_ssh" = true ]]; then
        if ! ufw status | grep -q "OpenSSH"; then
            ufw allow OpenSSH
        fi
    fi

    ufw allow 80/tcp || true
    ufw allow 443/tcp || true

    log "UFW status:"
    ufw status verbose || true
}
