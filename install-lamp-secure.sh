#!/usr/bin/env bash
# install-lamp-secure.sh - main orchestrator (executable)
# Usage:
#  sudo ./install-lamp-secure.sh
#  sudo ./install-lamp-secure.sh --auto --domain example.com --email admin@example.com --ip 1.2.3.4

set -euo pipefail
trap 'echo "[ERROR] Script failed on line $LINENO"; exit 1' ERR

# location: assume modules are in same directory as this script
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="/var/log/lamp_install.log"

# Source modules
# Ensure they exist
for f in helpers.sh config.sh install_packages.sh apache.sh php.sh mysql.sh phpmyadmin.sh firewall.sh certbot.sh cleanup.sh; do
    if [[ ! -f "${BASEDIR}/${f}" ]]; then
        echo "Required file missing: ${f} in ${BASEDIR}"
        exit 1
    fi
done

# shellcheck source=/dev/null
source "${BASEDIR}/helpers.sh"
# shellcheck source=/dev/null
source "${BASEDIR}/config.sh"
# source other units
# shellcheck source=/dev/null
source "${BASEDIR}/install_packages.sh"
# shellcheck source=/dev/null
source "${BASEDIR}/apache.sh"
# shellcheck source=/dev/null
source "${BASEDIR}/php.sh"
# shellcheck source=/dev/null
source "${BASEDIR}/mysql.sh"
# shellcheck source=/dev/null
source "${BASEDIR}/phpmyadmin.sh"
# shellcheck source=/dev/null
source "${BASEDIR}/firewall.sh"
# shellcheck source=/dev/null
source "${BASEDIR}/certbot.sh"
# shellcheck source=/dev/null
source "${BASEDIR}/cleanup.sh"

log "Starting LAMP installation (log: $LOGFILE)"

# Determine server IP & domain (interactive or auto)
if [[ "$AUTO" = true ]]; then
    log "Running in non-interactive (--auto) mode"
    [[ -n "$DOMAIN" ]] || error "In --auto mode you must pass --domain"
    [[ -n "$CERTBOT_EMAIL" ]] || error "In --auto mode you must pass --email"

    if [[ -n "$MANUAL_IP" ]]; then
        SERVER_IP="$MANUAL_IP"
        validate_ip "$SERVER_IP" || error "Provided IP invalid: $SERVER_IP"
    else
        SERVER_IP=$(hostname -I | awk '{print $1}' || true)
        if [[ -z "$SERVER_IP" ]]; then
            error "Unable to auto-detect server IP. Provide --ip in --auto mode."
        fi
    fi

    validate_domain "$DOMAIN" || error "Invalid domain: $DOMAIN"
    PHPMYADMIN_DOMAIN="phpmyadmin.${DOMAIN}"
else
    # Interactive
    echo ""
    echo "=== Server Configuration ==="
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

    while true; do
        read -rp "Enter server FQDN (e.g. server.example.com): " DOMAIN
        if validate_domain "$DOMAIN"; then
            break
        else
            warn "Invalid domain format. Try again."
        fi
    done
    PHPMYADMIN_DOMAIN="phpmyadmin.${DOMAIN}"
fi

log "Server IP: $SERVER_IP"
log "Domain: $DOMAIN"
log "phpMyAdmin domain: $PHPMYADMIN_DOMAIN"

# Password generation / prompts
if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
    if [[ "$AUTO" = true ]]; then
        MYSQL_ROOT_PASSWORD=$(generate_password)
        log "Generated MySQL root password (auto)"
    else
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

# Sanity checks
if ! validate_domain "$DOMAIN"; then
    error "Domain appears invalid: $DOMAIN"
fi

if domain_resolves_to_ip "$DOMAIN" "$SERVER_IP"; then
    log "DNS check: ${DOMAIN} resolves to ${SERVER_IP}"
else
    warn "DNS check: ${DOMAIN} does not resolve to ${SERVER_IP} (or resolution failed). Ensure A record set."
fi

if domain_resolves_to_ip "$PHPMYADMIN_DOMAIN" "$SERVER_IP"; then
    log "DNS check: ${PHPMYADMIN_DOMAIN} resolves to ${SERVER_IP}"
else
    warn "DNS check: ${PHPMYADMIN_DOMAIN} does not resolve to ${SERVER_IP} (or resolution failed)."
fi

# Install flow
install_base_packages

install_apache
install_php
configure_php_handler

install_mysql
configure_mysql_root "$MYSQL_ROOT_PASSWORD"

install_phpmyadmin "$PHPMYADMIN_PASSWORD" "$PHPMYADMIN_DOMAIN"

# Apply permissions and basic hardening
log "Setting file permissions and basic Apache hardening..."
chown -R www-data:www-data /var/www/html || true
chmod -R 755 /var/www/html || true
chown -R www-data:www-data /var/www/phpmyadmin || true
chmod -R 755 /var/www/phpmyadmin || true
chmod 644 /var/www/phpmyadmin/config.inc.php || true

if ! grep -q "ServerSignature Off" /etc/apache2/conf-available/security.conf 2>/dev/null; then
    sed -i '/^# ServerSignature/s/^# //' /etc/apache2/conf-available/security.conf || true
    echo "ServerSignature Off" >> /etc/apache2/conf-available/security.conf || true
    echo "ServerTokens Prod" >> /etc/apache2/conf-available/security.conf || true
    a2enconf security.conf || true
fi
systemctl reload apache2 || true

# Firewall
configure_ufw "$ALLOW_SSH"

# Obtain certs if email provided
if [[ -n "${CERTBOT_EMAIL:-}" ]]; then
    install_certbot_and_get_certs "$DOMAIN" "$PHPMYADMIN_DOMAIN" "$CERTBOT_EMAIL" || warn "Automatic SSL failed"
else
    warn "Certbot email not provided; skipping automatic SSL. Provide --email in --auto or run certbot later."
    if [[ "$AUTO" = false ]]; then
        read -rp "Would you like to run Certbot now? (y/N): " run_cert
        if [[ $run_cert =~ ^[Yy]$ ]]; then
            read -rp "Enter email for Let's Encrypt: " CERTBOT_EMAIL
            install_certbot_and_get_certs "$DOMAIN" "$PHPMYADMIN_DOMAIN" "$CERTBOT_EMAIL" || warn "Automatic SSL failed"
        fi
    fi
fi

# Cleanup and credentials file
write_credentials "$DOMAIN" "$SERVER_IP" "$MYSQL_ROOT_PASSWORD" "$PHPMYADMIN_PASSWORD"
remove_temp_mysql_cfg

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
