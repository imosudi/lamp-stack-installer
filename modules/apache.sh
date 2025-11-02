#!/usr/bin/env bash
# apache.sh - Apache installation/configuration (sourced)

set -euo pipefail

install_apache() {
    if ! command -v apache2 >/dev/null 2>&1; then
        log "Installing Apache2..."
        apt install -y apache2
    else
        log "Apache2 already installed"
    fi

    log "Enabling Apache modules..."
    a2enmod rewrite headers ssl expires || true

    systemctl enable --now apache2
}

configure_php_handler() {
    # Enable php-fpm conf if present, otherwise attempt mod_php
    if command -v php-fpm >/dev/null 2>&1 || ls /run/php/php*-fpm.sock >/dev/null 2>&1; then
        a2enmod proxy_fcgi setenvif || true
        PHP_FPM_CONF=$(ls /etc/apache2/conf-available/*php*-fpm.conf 2>/dev/null | head -n1 || true)
        if [[ -n "$PHP_FPM_CONF" ]]; then
            a2enconf "$(basename "$PHP_FPM_CONF" .conf)" || true
            log "Enabled php-fpm conf"
        fi
    else
        if a2enmod php >/dev/null 2>&1; then
            log "Enabled mod_php"
        fi
    fi
    systemctl reload apache2 || true
}

setup_apache_virtualhost() {
    local domain=$1
    local doc_root=$2
    local vh_conf="/etc/apache2/sites-available/${domain}.conf"

    log "Setting up Apache virtual host for ${domain}..."

    cat > "$vh_conf" <<EOF  `
`<VirtualHost *:80>
    ServerName ${domain}
    DocumentRoot ${doc_root}

    <Directory ${doc_root}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${domain}_error.log
    CustomLog \${APACHE_LOG_DIR}/${domain}_access.log combined  
</VirtualHost>
EOF
    a2ensite "${domain}.conf" || true
    systemctl reload apache2 || true
}       
:`