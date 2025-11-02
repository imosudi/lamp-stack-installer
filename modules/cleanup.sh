#!/usr/bin/env bash
# cleanup.sh - final tasks (sourced)

set -euo pipefail

write_credentials() {
    local domain="$1"
    local serverip="$2"
    local mysqlpw="$3"
    local phpmydbpw="$4"

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
- Main Website: http://${serverip}
- Main Website (domain): http://${domain}
- PHPMyAdmin (IP): http://${serverip}/phpmyadmin
- PHPMyAdmin (domain): https://phpmyadmin.${domain}  (if SSL obtained)
- PHPMyAdmin (domain HTTP): http://phpmyadmin.${domain}

Security notes:
- MySQL bound to 127.0.0.1
- Keep this file secure and remove when not needed.
=================================================
EOF
    chmod 600 /root/lamp_credentials.txt
}

remove_temp_mysql_cfg() {
    rm -f /root/.my.cnf || true
    log "Temporary MySQL credentials file removed"
}
