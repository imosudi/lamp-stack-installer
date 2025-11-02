#!/usr/bin/env bash
# mysql.sh - MySQL installation and hardening (sourced)

set -euo pipefail

install_mysql() {
    log "Installing MySQL server and client..."
    DEBIAN_FRONTEND=noninteractive apt install -y mysql-server mysql-client
    systemctl enable --now mysql
}

configure_mysql_root() {
    local rootpw="$1"
    log "Configuring MySQL root authentication..."
    set +e
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${rootpw}';" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        warn "Direct ALTER USER failed; trying via here-doc"
        mysql <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${rootpw}';
FLUSH PRIVILEGES;
SQL
    fi
    set -e

    # Create temporary client config
    cat > /root/.my.cnf <<EOF
[client]
user=root
password='${rootpw}'
EOF
    chmod 600 /root/.my.cnf

    # Hardening
    log "Hardening MySQL..."
    mysql -e "DELETE FROM mysql.user WHERE User='';"
    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -e "DROP DATABASE IF EXISTS test;"
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    mysql -e "FLUSH PRIVILEGES;"

    cat > /etc/mysql/mysql.conf.d/security.cnf <<'EOF'
[mysqld]
bind-address = 127.0.0.1
local-infile = 0
max_connections = 100
max_user_connections = 50
max_allowed_packet = 64M
log_error = /var/log/mysql/error.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
EOF

    systemctl restart mysql
}
