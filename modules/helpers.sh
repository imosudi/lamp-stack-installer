#!/usr/bin/env bash
# helpers.sh - common helper functions (sourced)

set -euo pipefail

# Logging (shared logfile)
#LOGFILE=${LOGFILE:-/var/log/lamp_install.log}
LOGFILE=${LOGFILE:-/var/log/lamp-installer/install.log}
mkdir -p "$(dirname "$LOGFILE")"

#exec > >(tee -a "$LOGFILE") 2>&1
if [[ "${LOGGING_INITIALISED:-false}" != "true" ]]; then
    mkdir -p "$(dirname "$LOGFILE")"
    exec > >(tee -a "$LOGFILE") 2>&1
    export LOGGING_INITIALISED=true
fi


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()    { printf "${GREEN}[%s]${NC} %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
warn()   { printf "${YELLOW}[WARNING] %s${NC}\n" "$*"; }
error()  { printf "${RED}[ERROR] %s${NC}\n" "$*"; exit 1; }

for dep in openssl getent tee; do
    command -v "$dep" >/dev/null 2>&1 || error "Missing dependency: $dep"
done


generate_password() {
    # Generate a 24-character URL-safe password
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-24
}

validate_password() {
    local pw="$1"
    [[ ${#pw} -ge 8 ]] || return 1
    [[ "$pw" =~ [A-Z] ]] || return 1
    [[ "$pw" =~ [a-z] ]] || return 1
    [[ "$pw" =~ [0-9] ]] || return 1
    [[ "$pw" =~ [^A-Za-z0-9] ]] || return 1
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
    [[ $d =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]
}

domain_resolves_to_ip() {
    local domain="$1"; local ip="$2"
    local resolved
    resolved=$(getent hosts "$domain" | awk '{print $1}' || true)
    [[ -n "$resolved" && "$resolved" = "$ip" ]]
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local ans
    read -rp "$prompt " ans
    ans=${ans:-$default}
    [[ $ans =~ ^[Yy] ]]
}
