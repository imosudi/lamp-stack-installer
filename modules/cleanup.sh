#!/usr/bin/env bash
# cleanup.sh - Final tasks (sourced)

set -euo pipefail

write_credentials() {
    # Use exported vars from config.sh with safe defaults
    local domain="${DOMAIN:-localhost}"
    local serverip="${SERVER_IP:-127.0.0.1}"
    local mysqlpw="${MYSQL_ROOT_PASSWORD:-unknown}"
    local phpmydbpw="${PHPMYADMIN_PASSWORD:-unknown}"

    log "Writing credential file to /root/lamp_credentials.txt (permissions 600)"

    cat > /root/lamp_credentials.txt <<EOF
=================================================
LAMP Stack Installation Credentials
=================================================
Generated on: $(date -u)
Server: ${domain} (${serverip})

MYSQL ROOT CREDENTIALS:
  Username: root
  Password: ${mysqlpw}

PHPMYADMIN DATABASE USER:
  Username: phpmyadmin
  Password: ${phpmydbpw}

ACCESS URLS:
  - Main Website (IP):      http://${serverip}
  - Main Website (domain):  http://${domain}
  - phpMyAdmin (HTTP):      http://phpmyadmin.${domain}
  - phpMyAdmin (HTTPS):     https://phpmyadmin.${domain}  (if SSL obtained)

Security Notes:
  - MySQL is bound to 127.0.0.1 (local access only)
  - Keep this file secure and remove it when no longer needed
=================================================
EOF

    chmod 600 /root/lamp_credentials.txt
    log "Credential file created successfully at /root/lamp_credentials.txt"
}

remove_temp_mysql_cfg() {
    rm -f /root/.my.cnf || true
    log "Temporary MySQL credentials file removed"
}
