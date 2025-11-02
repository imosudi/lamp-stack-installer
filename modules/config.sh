#!/usr/bin/env bash
# config.sh - CLI parsing and global variables (sourced)

set -euo pipefail

# Defaults
AUTO=false
DOMAIN=""
CERTBOT_EMAIL=""
MANUAL_IP=""
MYSQL_ROOT_PASSWORD=""
PHPMYADMIN_PASSWORD=""
ALLOW_SSH=true

# Parse args (simple loop)
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
  Interactive: sudo ./install-lamp-secure.sh
  Auto mode:  sudo ./install-lamp-secure.sh --auto --domain example.com --email admin@example.com [options]

Options:
  --auto
  --domain <domain>
  --email <email>
  --ip <server IP>
  --mysql-root-pass <pass>
  --phpmyadmin-pass <pass>
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

# Derived variables (may be set later)
SERVER_IP="${MANUAL_IP:-}"
PHPMYADMIN_DOMAIN=""
LOGFILE=${LOGFILE:-/var/log/lamp_install.log}

# Basic checks
if [[ $EUID -ne 0 ]]; then
    echo "Please run as root or via sudo."
    exit 1
fi
