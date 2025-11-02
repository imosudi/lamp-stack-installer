#!/usr/bin/env bash
# phpmyadmin.sh - phpMyAdmin installation (sourced)

set -euo pipefail

PHPMYADMIN_VERSION="${PHPMYADMIN_VERSION:-5.2.1}"

install_phpmyadmin() {
    local dbpw="$1"
    local phpmydomain="$2"

    log "Installing phpMyAdmin ${PHPMYADMIN_VERSION}..."
    cd /tmp
    wget -q "https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz"
    tar xzf "phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz"

    rm -rf /var/www/phpmyadmin
    mv "phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages" /var/www/phpmyadmin
    chown -R www-data:www-data /var/www/phpmyadmin

    local blowfish
    blowfish=$(openssl rand -base64 32)

    cat > /var/www/phpmyadmin/config.inc.php <<EOF
<?php
\$cfg['blowfish_secret'] = '${blowfish}';
\$i = 0;
\$i++;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['host'] = 'localhost';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
\$cfg['CheckConfigurationPermissions'] = false;
\$cfg['DefaultLang'] = 'en';
\$cfg['ServerDefault'] = 1;
\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
\$cfg['LoginCookieValidity'] = 3600;
\$cfg['LoginCookieRecall'] = false;
\$cfg['LoginCookieDeleteAll'] = true;
\$cfg['Servers'][\$i]['DisableIS'] = true;
\$cfg['ShowServerInfo'] = false;
\$cfg['hide_db'] = '^(information_schema|performance_schema|mysql|sys)\$';
EOF

    chown www-data:www-data /var/www/phpmyadmin/config.inc.php
    chmod 644 /var/www/phpmyadmin/config.inc.php

    # Create DB and user
    log "Creating phpMyAdmin database and user..."
    if mysql -e "SELECT User FROM mysql.user WHERE User='phpmyadmin'" | grep -q phpmyadmin; then
        mysql -e "DROP USER 'phpmyadmin'@'localhost';" || true
    fi
    mysql -e "CREATE USER IF NOT EXISTS 'phpmyadmin'@'localhost' IDENTIFIED BY '${dbpw}';"
    if mysql -e "SHOW DATABASES LIKE 'phpmyadmin'" | grep -q phpmyadmin; then
        mysql -e "DROP DATABASE phpmyadmin;"
    fi
    mysql -e "CREATE DATABASE phpmyadmin;"
    mysql -e "GRANT ALL PRIVILEGES ON phpmyadmin.* TO 'phpmyadmin'@'localhost';"
    if [ -f /var/www/phpmyadmin/sql/create_tables.sql ]; then
        mysql phpmyadmin < /var/www/phpmyadmin/sql/create_tables.sql || warn "Import create_tables.sql failed"
    else
        warn "phpMyAdmin create_tables.sql not found"
    fi
    mysql -e "GRANT SELECT ON mysql.user TO 'phpmyadmin'@'localhost';"
    mysql -e "GRANT SELECT ON mysql.db TO 'phpmyadmin'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"

    # Apache vhost
    log "Creating Apache virtual host for phpMyAdmin..."
    cat > /etc/apache2/sites-available/phpmyadmin.conf <<EOF
<VirtualHost *:80>
    ServerName ${phpmydomain}
    DocumentRoot /var/www/phpmyadmin

    Header always set X-Content-Type-Options nosniff
    Header always set X-Frame-Options DENY
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"

    <Directory /var/www/phpmyadmin>
        Options -Indexes
        AllowOverride All
        Require all granted

        <Files "setup.php">
            Require all denied
        </Files>
        <FilesMatch "\.(dist|md|yml)$">
            Require all denied
        </FilesMatch>
    </Directory>

    php_admin_value upload_max_filesize 128M
    php_admin_value post_max_size 128M
    php_admin_value max_execution_time 600
    php_admin_value max_input_vars 5000

    ErrorLog \${APACHE_LOG_DIR}/phpmyadmin_error.log
    CustomLog \${APACHE_LOG_DIR}/phpmyadmin_access.log combined
</VirtualHost>
EOF

    a2ensite phpmyadmin.conf || true
    systemctl reload apache2 || true
}
