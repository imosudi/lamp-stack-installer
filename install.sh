#!/usr/bin/env bash
# ==========================================================
#  LAMP Stack Secure Installer (Modular)
#  Author: Mosudi I. O.
#  Version: 1.0
#  Date: 2025-11-02
# ==========================================================

set -euo pipefail
trap 'echo "[ERROR] Installation aborted. Check log for details." >&2' ERR

# --- Project root ---
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/lamp_install.log"

# --- Source core modules ---
source "$BASE_DIR/modules/config.sh"
source "$BASE_DIR/modules/helpers.sh"

# --- Log header ---
log "=========================================================="
log "  LAMP STACK SECURE INSTALLER - INITIALISATION"
log "=========================================================="

# --- Execute each installation phase ---
source "$BASE_DIR/modules/install_packages.sh"
install_base_packages

source "$BASE_DIR/modules/apache.sh"
install_apache

source "$BASE_DIR/modules/php.sh"
install_php

source "$BASE_DIR/modules/mysql.sh"
install_mysql

source "$BASE_DIR/modules/phpmyadmin.sh"
setup_phpmyadmin

source "$BASE_DIR/modules/firewall.sh"
configure_ufw

source "$BASE_DIR/modules/certbot.sh"
install_certbot_and_get_certs

source "$BASE_DIR/modules/cleanup.sh"
write_credentials

log "=========================================================="
log "Installation completed successfully."
log "Log file: $LOG_FILE"
log "=========================================================="
