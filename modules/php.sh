#!/usr/bin/env bash
# php.sh - PHP installation (sourced)

set -euo pipefail

install_php() {
    log "Installing PHP and common extensions..."
    apt install -y php php-fpm php-mysql php-cli php-curl php-gd php-mbstring php-xml php-zip php-json php-bcmath php-bz2 php-intl php-readline php-xmlrpc php-soap libapache2-mod-php || true

    USE_PHP_FPM=false
    if command -v php-fpm >/dev/null 2>&1 || ls /run/php/php*-fpm.sock >/dev/null 2>&1; then
        USE_PHP_FPM=true
    fi
    export USE_PHP_FPM
}
