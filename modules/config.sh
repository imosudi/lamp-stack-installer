#!/usr/bin/env bash
# ==========================================================
# config.sh - CLI parsing, global variables, and interactive fallbacks
# ==========================================================

set -euo pipefail

# --- Defaults ---
AUTO=false
DOMAIN=""
CERTBOT_EMAIL=""
MANUAL_IP=""
MYSQL_ROOT_PASSWORD=""
PHPMYADMIN_PASSWORD=""
ALLOW_SSH=true

# --- Parse CLI arguments ---
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
        -h|--help)
            cat <<EOF
Usage:
  Interactive: sudo ./install.sh
  Auto mode:   sudo ./install.sh --auto --domain example.com --email admin@example.com [options]

Options:
  --auto
  --domain <domain>
  --email <email>
  --ip <server IP>
  --mysql-root-pass <password>
  --phpmyadmin-pass <password>
  --allow-ssh | --no-ssh
EOF
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# --- Ensure root privileges ---
if [[ $EUID -ne 0 ]]; then
    echo "Please run as root or via sudo."
    exit 1
fi

# --- Interactive mode (fallbacks) ---
if [[ "$AUTO" = false ]]; then
    echo "==== LAMP Secure Installer (Interactive Mode) ===="
    if [[ -z "$DOMAIN" ]]; then
        read -rp "Enter your primary domain (e.g., example.com): " DOMAIN
        DOMAIN=${DOMAIN:-localhost}
    fi
    if [[ -z "$CERTBOT_EMAIL" ]]; then
        read -rp "Enter email for SSL certificate (Certbot): " CERTBOT_EMAIL
        CERTBOT_EMAIL=${CERTBOT_EMAIL:-admin@$DOMAIN}
    fi
    if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
        read -rsp "Enter MySQL root password (leave blank to auto-generate): " MYSQL_ROOT_PASSWORD
        echo
        MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-$(openssl rand -base64 16)}
    fi
    if [[ -z "$PHPMYADMIN_PASSWORD" ]]; then
        read -rsp "Enter phpMyAdmin admin password (leave blank to auto-generate): " PHPMYADMIN_PASSWORD
        echo
        PHPMYADMIN_PASSWORD=${PHPMYADMIN_PASSWORD:-$(openssl rand -base64 16)}
    fi
fi

# --- Derived values ---
PHPMYADMIN_DOMAIN="phpmyadmin.${DOMAIN}"
SERVER_IP="${MANUAL_IP:-$(hostname -I | awk '{print $1}')}"
LOGFILE=${LOGFILE:-/var/log/lamp_install.log}

# --- Exports for other modules ---
export AUTO DOMAIN CERTBOT_EMAIL SERVER_IP MYSQL_ROOT_PASSWORD \
       PHPMYADMIN_PASSWORD PHPMYADMIN_DOMAIN ALLOW_SSH LOGFILE
