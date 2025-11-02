#!/usr/bin/env bash
# install-lamp-secure.sh
# Refactored LAMP installation script supporting interactive and non-interactive (--auto) modes,
# persistent logging to /var/log/lamp_install.log, and automatic SSL via Certbot.
#
# Target: Ubuntu 24.04 Server
#
# Usage:
#  Interactive: sudo ./install-lamp-secure.sh
#  Non-interactive: sudo ./install-lamp-secure.sh --auto --domain example.com --email admin@example.com \
#                   --ip 203.0.113.10 --mysql-root-pass 'P@ssw0rd!' --phpmyadmin-pass 'AnotherP@ss1'
#
set -euo pipefail

# -----------------------
# Basic configuration
# -----------------------
LOGFILE="/var/log/lamp_install.log"
exec > >(tee -a "$LOGFILE") 2>&1   # persistent logging (stdout+stderr)
trap 'echo "[ERROR] Script failed on line $LINENO"; exit 1' ERR

# Colours (for interactive terminal only)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# -----------------------
# Helper functions
# -----------------------
log()    { printf "${GREEN}[%s]${NC} %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
warn()   { printf "${YELLOW}[WARNING] %s${NC}\n" "$*"; }
error()  { printf "${RED}[ERROR] %s${NC}\n" "$*"; exit 1; }

generate_password() {
    # Generate a 24-character URL-safe password
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-24
}

validate_password() {
    local pw="$1"
    local min_len=8
    [[ ${#pw} -ge $min_len ]] || return 1
    [[ $pw =~ [A-Z] ]] && [[ $pw =~ [a-z] ]] && [[ $pw =~ [0-9] ]] && [[ $pw =~ [^A-Za-z0-9] ]]
}

validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r a b c d <<< "$ip"
        for oct in $a $b $c $d; do
            ((oct >= 0 && oct <= 255)) || return 1
        done
        return 0
    fi
    return 1
}

validate_domain() {
    local d="$1"
    # basic FQDN check (allows subdomains)
    [[ $d =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]
}

# Check if domain resolves to the specified IP (best-effort)
domain_resolves_to_ip() {
    local domain="$1"; local ip="$2"
    local resolved
    resolved=$(getent hosts "$domain" | awk '{print $1}' || true)
    [[ -n "$resolved" && "$resolved" = "$ip" ]]
}

# Ask yes/no in interactive mode
ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local ans
    read -rp "$prompt " ans
    ans=${ans:-$default}
    [[ $ans =~ ^[Yy] ]]
}

usage() {
    cat <<EOF
Usage:
  Interactive: sudo $0
  Auto mode:  sudo $0 --auto --domain example.com --email admin@example.com [options]

Options (non-interactive --auto):
  --auto                      Run in non-interactive mode (required for automation)
  --domain <domain>           Primary FQDN (required in auto mode)
  --email <admin email>       Email for Let's Encrypt (required in auto mode)
  --ip <server IP>            Server public IP (optional if auto-detectable)
  --mysql-root-pass <pass>    MySQL root password (optional; generated if not provided)
  --phpmyadmin-pass <pass>    phpmyadmin DB password (optional; generated if not provided)
  --allow-ssh                 Allow OpenSSH through UFW (default: allow)
  -h, --help                  Show this help

EOF
}

# -----------------------
# Parse CLI args
# -----------------------
AUTO=false
DOMAIN=""
CERTBOT_EMAIL=""
MANUAL_IP=""
MYSQL_ROOT_PASSWORD=""
PHPMYADMIN_PASSWORD=""
ALLOW_SSH=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto) AUTO=true; shift ;;
        --domain) DOMAIN="$2"; shift 2 ;;
        --email) CERTBOT_EMAIL="$2"; shift 2 ;;
        --ip) MANUAL_IP="$2"; shift 2 ;;
        --mysql-root-pass) MYSQL_ROOT_PASSWORD="$2"; shift 2 ;;
        --phpmyadmin-pass) PHPMYADMIN_PASSWORD="$2"; shift 2 ;;
        --allow-ssh) ALLOW_SSH=true; shift ;;
        --no-ssh) ALLOW_SSH=false; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown arg: $1"; usage; exit 1 ;;
    esac
done

# -----------------------
# Start
# -----------------------
log "Starting LAMP installation (persistent log: $LOGFILE)"
if [[ $EUID -ne 0 ]]; then
    error "Please run this script with sudo/root."
fi

# -----------------------
# Get server IP and domain (interactive or auto)
# -----------------------
if [[ "$AUTO" = true ]]; then
    log "Running in non-interactive (--auto) mode"
    # domain and email are required in auto mode
    [[ -n "$DOMAIN" ]] || error "In --auto mode you must pass --domain"
    [[ -n "$CERTBOT_EMAIL" ]] || error "In --auto mode you must pass --email"

    if [[ -n "$MANUAL_IP" ]]; then
        SERVER_IP="$MANUAL_IP"
        validate_ip "$SERVER_IP" || error "Provided IP is invalid: $SERVER_IP"
    else
        SERVER_IP=$(hostname -I | awk '{print $1}' || true)
        if [[ -z "$SERVER_IP" ]]; then
            error "Unable to auto-detect server IP. Provide --ip in --auto mode."
        fi
    fi

    validate_domain "$DOMAIN" || error "Invalid domain provided: $DOMAIN"
    PHPMYADMIN_DOMAIN="phpmyadmin.$DOMAIN"
else
    # Interactive mode
    echo ""
    echo "=== Server Configuration ==="
    # Detect IP and ask
    DETECTED_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || true)
    if [[ -n "$DETECTED_IP" ]]; then
        echo "Detected IP address: $DETECTED_IP"
        if ask_yes_no "Use this IP address? (Y/n):"; then
            SERVER_IP="$DETECTED_IP"
        fi
    fi
    while [[ -z "${SERVER_IP:-}" ]]; do
        read -rp "Enter server IP address: " SERVER_IP
        if validate_ip "$SERVER_IP"; then
            log "Using IP: $SERVER_IP"
        else
            warn "Invalid IP address. Try again."
            unset SERVER_IP
        fi
    done

    # Domain
    while true; do
        read -rp "Enter server fully qualified domain name (FQDN): " DOMAIN
        if validate_domain "$DOMAIN"; then
            break
        else
            warn "Invalid domain format. Example: server.example.com"
        fi
    done
    PHPMYADMIN_DOMAIN="phpmyadmin.$DOMAIN"
fi

log "Server IP: $SERVER_IP"
log "Domain: $DOMAIN"
log "PHPMyAdmin domain: $PHPMYADMIN_DOMAIN"

# -----------------------
# Passwords (auto generate if missing)
# -----------------------
if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
    if [[ "$AUTO" = true ]]; then
        MYSQL_ROOT_PASSWORD=$(generate_password)
        log "Generated MySQL root password (auto)"
    else
        # Interactive prompt
        while true; do
            read -rsp "Enter MySQL root password (leave empty to auto-generate): " tmp_pw; echo
            if [[ -z "$tmp_pw" ]]; then
                MYSQL_ROOT_PASSWORD=$(generate_password)
                log "Generated MySQL root password"
                break
            elif validate_password "$tmp_pw"; then
                read -rsp "Confirm MySQL root password: " tmp_pw2; echo
                [[ "$tmp_pw" = "$tmp_pw2" ]] || { warn "Passwords do not match"; continue; }
                MYSQL_ROOT_PASSWORD="$tmp_pw"
                break
            else
                warn "Password must be >=8 chars, include upper, lower, digit and special"
            fi
        done
    fi
fi

if [[ -z "$PHPMYADMIN_PASSWORD" ]]; then
    if [[ "$AUTO" = true ]]; then
        PHPMYADMIN_PASSWORD=$(generate_password)
        log "Generated phpmyadmin DB password (auto)"
    else
        while true; do
            read -rsp "Enter phpmyadmin DB password (leave empty to auto-generate): " tmp_pw; echo
            if [[ -z "$tmp_pw" ]]; then
                PHPMYADMIN_PASSWORD=$(generate_password)
                log "Generated phpmyadmin DB password"
                break
            elif validate_password "$tmp_pw"; then
                read -rsp "Confirm phpmyadmin DB password: " tmp_pw2; echo
                [[ "$tmp_pw" = "$tmp_pw2" ]] || { warn "Passwords do not match"; continue; }
                PHPMYADMIN_PASSWORD="$tmp_pw"
                break
            else
                warn "Password must be >=8 chars, include upper, lower, digit and special"
            fi
        done
    fi
fi

# -----------------------
# Pre-install sanity checks
# -----------------------
if ! validate_domain "$DOMAIN"; then
    error "Domain appears invalid: $DOMAIN"
fi

# If domain resolves, warn if mismatch
if domain_resolves_to_ip "$DOMAIN" "$SERVER_IP"; then
    log "DNS check: $DOMAIN resolves to $SERVER_IP"
else
    warn "DNS check: $DOMAIN does not resolve to $SERVER_IP (or resolution failed). Ensure DNS A record points to server IP before requesting certificates."
fi
if domain_resolves_to_ip "$PHPMYADMIN_DOMAIN" "$SERVER_IP"; then
    log "DNS check: $PHPMYADMIN_DOMAIN resolves to $SERVER_IP"
else
    warn "DNS check: $PHPMYADMIN_DOMAIN does not resolve to $SERVER_IP (or resolution failed)."
fi

# -----------------------
# Update & Prereqs
# -----------------------
log "Updating system packages..."
apt update -y
apt upgrade -y

log "Installing prerequisites..."
apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release unzip

# -----------------------
# Apache
# -----------------------
if ! command -v apache2 >/dev/null 2>&1; then
    log "Installing Apache2..."
    apt install -y apache2
else
    log "Apache2 already installed"
fi

# -----------------------
# PHP (install FPM + common extensions)
# -----------------------
log "Installing PHP and extensions..."
# Install default supported PHP version from Ubuntu repos (should be 8.x on Ubuntu 24.04)
apt install -y php php-fpm php-mysql php-cli php-curl php-gd php-mbstring php-xml php-zip php-json php-bcmath php-bz2 php-intl php-readline php-xmlrpc php-soap libapache2-mod-php || true

# Detect whether php-fpm is present (prefer php-fpm for modern setups)
USE_PHP_FPM=false
if command -v php-fpm >/dev/null 2>&1 || ls /run/php/php*-fpm.sock >/dev/null 2>&1; then
    USE_PHP_FPM=true
fi

# Enable apache modules and confs
log "Enabling Apache modules..."
a2enmod rewrite headers ssl expires

if [[ "$USE_PHP_FPM" = true ]]; then
    # enable proxy_fcgi and conf for php-fpm
    a2enmod proxy_fcgi setenvif
    # enable php-fpm conf (try best-effort)
    PHP_FPM_CONF=$(ls /etc/apache2/conf-available/*php*-fpm.conf 2>/dev/null | head -n1 || true)
    if [[ -n "$PHP_FPM_CONF" ]]; then
        a2enconf "$(basename "$PHP_FPM_CONF" .conf)" || true
    fi
else
    # try enabling mod_php if present
    if a2enmod php >/dev/null 2>&1; then
        log "Enabled mod_php"
    fi
fi

systemctl enable --now apache2

# -----------------------
# MySQL
# -----------------------
log "Installing MySQL server..."
DEBIAN_FRONTEND=noninteractive apt install -y mysql-server mysql-client

systemctl enable --now mysql

# Secure MySQL root: try to set password and switch auth method if needed
log "Configuring MySQL root authentication..."
# Try setting root password and use mysql_native_password if required
set +e
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    warn "Direct ALTER USER failed; trying to run as root socket user"
    sudo mysql <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQL
fi
set -e

# Create temporary root config for non-interactive mysql commands
cat > /root/.my.cnf <<EOF
[client]
user=root
password='${MYSQL_ROOT_PASSWORD}'
EOF
chmod 600 /root/.my.cnf

# Harden MySQL
log "Hardening MySQL..."
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

# Apply stricter server config snippet
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

# -----------------------
# phpMyAdmin (manual installation)
# -----------------------
PHPMYADMIN_VERSION="5.2.1"   # can be updated if needed
log "Installing phpMyAdmin ${PHPMYADMIN_VERSION}..."
cd /tmp
wget -q "https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz"
tar xzf "phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz"

rm -rf /var/www/phpmyadmin
mv "phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages" /var/www/phpmyadmin
chown -R www-data:www-data /var/www/phpmyadmin

# Create config.inc.php
log "Creating phpMyAdmin configuration..."
BLOWFISH_SECRET=$(openssl rand -base64 32)

cat > /var/www/phpmyadmin/config.inc.php <<EOF
<?php
\$cfg['blowfish_secret'] = '${BLOWFISH_SECRET}';
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

# Create phpmyadmin DB and user
log "Creating phpMyAdmin database and user..."
# Drop existing user/db if present (safe in fresh installs)
if mysql -e "SELECT User FROM mysql.user WHERE User='phpmyadmin'" | grep -q phpmyadmin; then
    mysql -e "DROP USER 'phpmyadmin'@'localhost';" || true
fi

mysql -e "CREATE USER IF NOT EXISTS 'phpmyadmin'@'localhost' IDENTIFIED BY '${PHPMYADMIN_PASSWORD}';"
if mysql -e "SHOW DATABASES LIKE 'phpmyadmin'" | grep -q phpmyadmin; then
    mysql -e "DROP DATABASE phpmyadmin;"
fi

mysql -e "CREATE DATABASE phpmyadmin;"
mysql -e "GRANT ALL PRIVILEGES ON phpmyadmin.* TO 'phpmyadmin'@'localhost';"
# Import tables
if [ -f /var/www/phpmyadmin/sql/create_tables.sql ]; then
    mysql phpmyadmin < /var/www/phpmyadmin/sql/create_tables.sql
else
    warn "phpMyAdmin create_tables.sql not found"
fi
mysql -e "GRANT SELECT ON mysql.user TO 'phpmyadmin'@'localhost';"
mysql -e "GRANT SELECT ON mysql.db TO 'phpmyadmin'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# -----------------------
# Apache virtual host for phpMyAdmin
# -----------------------
log "Creating Apache virtual host for phpMyAdmin..."
cat > /etc/apache2/sites-available/phpmyadmin.conf <<EOF
<VirtualHost *:80>
    ServerName ${PHPMYADMIN_DOMAIN}
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

a2ensite phpmyadmin.conf
systemctl reload apache2

# -----------------------
# Permissions and safety
# -----------------------
log "Setting file permissions..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
chown -R www-data:www-data /var/www/phpmyadmin
chmod -R 755 /var/www/phpmyadmin
chmod 644 /var/www/phpmyadmin/config.inc.php

# Apache security hardening
log "Applying basic Apache security hardening..."
if ! grep -q "ServerSignature Off" /etc/apache2/conf-available/security.conf 2>/dev/null; then
    sed -i '/^# ServerSignature/s/^# //' /etc/apache2/conf-available/security.conf || true
    echo "ServerSignature Off" >> /etc/apache2/conf-available/security.conf
    echo "ServerTokens Prod" >> /etc/apache2/conf-available/security.conf
    a2enconf security.conf || true
fi
systemctl reload apache2

# -----------------------
# Firewall (UFW)
# -----------------------
log "Configuring UFW firewall..."
if ! command -v ufw >/dev/null 2>&1; then
    apt install -y ufw
fi

UFW_STATUS=$(ufw status | grep -Po '(?<=Status: ).*' || echo "inactive")
if [[ "$UFW_STATUS" = "inactive" ]]; then
    log "Enabling UFW with default deny incoming"
    echo "y" | ufw enable
else
    log "UFW already active"
fi

# Ensure SSH allowed to avoid lockout
if [[ "$ALLOW_SSH" = true ]]; then
    if ! ufw status | grep -q "OpenSSH"; then
        ufw allow OpenSSH
    fi
fi

# Allow HTTP/HTTPS
ufw allow 80/tcp || true
ufw allow 443/tcp || true

log "UFW status:"
ufw status verbose

# -----------------------
# Certbot (Let's Encrypt) automatic SSL
# -----------------------
install_certbot_and_get_certs() {
    log "Installing Certbot via snap..."
    if ! command -v snap >/dev/null 2>&1; then
        apt install -y snapd
    fi
    snap install core && snap refresh core
    snap install --classic certbot
    ln -sf /snap/bin/certbot /usr/bin/certbot

    log "Requesting certificates for ${DOMAIN} and ${PHPMYADMIN_DOMAIN}..."
    # Ensure http is open for challenge
    ufw allow 80/tcp || true

    # Non-interactive certificate request
    certbot --apache --non-interactive --agree-tos --email "${CERTBOT_EMAIL}" -d "${DOMAIN}" -d "${PHPMYADMIN_DOMAIN}" || {
        warn "Certbot failed to obtain certificates. Please check DNS and that ports 80/443 are reachable."
        return 1
    }

    log "Certificates obtained and Apache configured for HTTPS."
    systemctl reload apache2
    return 0
}

if [[ -n "${CERTBOT_EMAIL:-}" ]]; then
    install_certbot_and_get_certs || warn "Automatic SSL failed; you can run: sudo certbot --apache -d $DOMAIN -d $PHPMYADMIN_DOMAIN"
else
    warn "Certbot email not provided; skipping automatic SSL. Provide --email in --auto mode or set CERTBOT_EMAIL interactively."
    if [[ "$AUTO" = false ]]; then
        read -rp "Would you like to run Certbot now? (y/N): " run_cert
        if [[ $run_cert =~ ^[Yy]$ ]]; then
            read -rp "Enter email for Let's Encrypt: " CERTBOT_EMAIL
            install_certbot_and_get_certs || warn "Automatic SSL failed"
        fi
    fi
fi

# -----------------------
# Cleanup credentials and write file
# -----------------------
log "Writing credential file to /root/lamp_credentials.txt (permissions 600)"
cat > /root/lamp_credentials.txt <<EOF
=================================================
LAMP Stack Installation Credentials
=================================================
Generated on: $(date -u)
Server: ${DOMAIN} (${SERVER_IP})

MYSQL ROOT CREDENTIALS:
Username: root
Password: ${MYSQL_ROOT_PASSWORD}

PHPMYADMIN DATABASE USER:
Username: phpmyadmin
Password: ${PHPMYADMIN_PASSWORD}

ACCESS URLS:
- Main Website: http://${SERVER_IP}
- Main Website (domain): http://${DOMAIN}
- PHPMyAdmin (IP): http://${SERVER_IP}/phpmyadmin
- PHPMyAdmin (domain): https://${PHPMYADMIN_DOMAIN}  (if SSL obtained)
- PHPMyAdmin (domain HTTP): http://${PHPMYADMIN_DOMAIN}

SECURITY NOTES:
- MySQL is configured to bind to localhost.
- phpMyAdmin setup.php is blocked.
- Remove phpinfo.php and dbtest.php in production.
- TLS is configured with Let's Encrypt if certs obtained.
- Keep /root/lamp_credentials.txt secure and delete after noting credentials.

=================================================
EOF
chmod 600 /root/lamp_credentials.txt

# Remove temporary mysql credentials file
rm -f /root/.my.cnf
log "Temporary MySQL credentials file removed"

# -----------------------
# Final output
# -----------------------
log "LAMP installation complete."
echo
echo "Summary:"
echo "  Domain:        $DOMAIN"
echo "  PHPMyAdmin:    $PHPMYADMIN_DOMAIN"
echo "  Server IP:     $SERVER_IP"
echo "  Credentials:   /root/lamp_credentials.txt (chmod 600)"
echo
log "You can view the log at: $LOGFILE"
log "Recommended next steps:"
echo "  1) Verify DNS A records for ${DOMAIN} and ${PHPMYADMIN_DOMAIN} point to ${SERVER_IP}"
echo "  2) If certificate issuance failed, run: sudo certbot --apache -d ${DOMAIN} -d ${PHPMYADMIN_DOMAIN}"
echo "  3) Configure application-specific databases and users"
echo "  4) Setup regular backups for MySQL"
echo
log "End of script."
