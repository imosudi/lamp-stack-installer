#!/usr/bin/env bash
# phpmyadmin.sh — phpMyAdmin installation and configuration

setup_phpmyadmin() {
  log "Installing phpMyAdmin manually..."

  local PMA_VERSION="5.2.1"
  local PMA_DIR="/var/www/phpmyadmin"
  local PHPMYADMIN_DOMAIN="phpmyadmin.${DOMAIN:-localhost}"
  local PMA_PASS="${PHPMYADMIN_PASS:-$(generate_password)}"

  mkdir -p "$PMA_DIR"
  cd /tmp || exit 1

  log "Downloading phpMyAdmin $PMA_VERSION..."
  wget -q "https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-all-languages.tar.gz"
  tar xzf "phpMyAdmin-${PMA_VERSION}-all-languages.tar.gz" -C "$PMA_DIR" --strip-components=1

  log "Creating phpMyAdmin configuration..."
  cat > "$PMA_DIR/config.inc.php" <<EOF
<?php
\$cfg['blowfish_secret'] = '$(openssl rand -hex 16)';
\$i = 1;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
?>
EOF

  chown -R www-data:www-data "$PMA_DIR"
  chmod -R 755 "$PMA_DIR"

  log "Creating Apache virtual host for phpMyAdmin..."
  cat > /etc/apache2/sites-available/phpmyadmin.conf <<EOF
<VirtualHost *:80>
    ServerName $PHPMYADMIN_DOMAIN
    DocumentRoot $PMA_DIR

    <Directory $PMA_DIR>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/phpmyadmin_error.log
    CustomLog \${APACHE_LOG_DIR}/phpmyadmin_access.log combined
</VirtualHost>
EOF

  a2ensite phpmyadmin.conf >/dev/null
  systemctl reload apache2

  log "phpMyAdmin successfully configured at: http://$PHPMYADMIN_DOMAIN/"
}
