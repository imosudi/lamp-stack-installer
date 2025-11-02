#!/usr/bin/env bash
# install_packages.sh - install base packages (sourced)

set -euo pipefail

install_base_packages() {
    log "Updating package lists..."
    apt update -y
    apt upgrade -y

    log "Installing prerequisites..."
    apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release unzip || true
}
