#!/usr/bin/env bash
# phpmyadmin.sh - phpMyAdmin installation and configuration (sourced)

set -euo pipefail

setup_phpmyadmin() {
    local domain="${DOMAIN:-localhost}"
    local phpmydomain="phpmyadmin.${DOMAIN:-localhost}"
    local phpmydbpw="${PHPMYADMIN_PASSWORD:-$(openssl rand -base64 18)}"

    log "Installing phpMyAdmin..."
    apt install -y phpmyadmin

    log "Configuring Apache for phpMyAdmin access..."

    # --- Allow phpMyAdmin via IP and domain ---
    local apache_conf="/etc/apache2/conf-available/phpmyadmin.conf"

    # Ensure default phpMyAdmin alias for IP-based access
    if ! grep -q "/phpmyadmin" "$apache_conf"; then
        cat <<'EOF' > "$apache_conf"
Alias /phpmyadmin /usr/share/phpmyadmin

<Directory /usr/share/phpmyadmin>
    Options FollowSymLinks
    DirectoryIndex index.php
    AllowOverride All
    Require all granted
</Directory>
EOF
    fi

    # --- Create VirtualHost for phpmyadmin.domain.com ---
    local vhost_file="/etc/apache2/sites-available/phpmyadmin.conf"
    cat <<EOF > "$vhost_file"
<VirtualHost *:80>
    ServerName ${phpmydomain}
    DocumentRoot /usr/share/phpmyadmin

    <Directory /usr/share/phpmyadmin>
        Options FollowSymLinks
        DirectoryIndex index.php
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/phpmyadmin_error.log
    CustomLog \${APACHE_LOG_DIR}/phpmyadmin_access.log combined
</VirtualHost>
EOF

    # Enable site & reload Apache
    a2ensite phpmyadmin.conf >/dev/null 2>&1 || true
    systemctl reload apache2 || true

    log "phpMyAdmin configured successfully."
    log "Access URLs:"
    log "  - http://${domain}/phpmyadmin"
    log "  - http://${phpmydomain}"
    log "  - http://${SERVER_IP:-127.0.0.1}/phpmyadmin"

    # Export password for cleanup.sh
    export PHPMYADMIN_PASSWORD="$phpmydbpw"
}
