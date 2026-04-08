#!/bin/sh

# Dotfiles provisioning script - supports Linux (Debian) and OpenBSD
# Run as root: sh provision.sh

set -eu

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SALT_CONFIG_DIR="/srv/salt"
PILLAR_CONFIG_DIR="/srv/pillar"
OS_TYPE=""

# Logging
log_info()  { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Linux)   OS_TYPE="linux" ;;
        OpenBSD) OS_TYPE="openbsd" ;;
        *)       log_error "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac
    log_info "Detected OS: $OS_TYPE"
}

# Check root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root."
        exit 1
    fi
}

# Install prerequisites and Salt - Linux (Debian)
install_linux() {
    log_info "Installing prerequisites (Linux)..."
    apt-get update -qq
    apt-get install -y curl git sudo

    if command -v salt-call >/dev/null 2>&1; then
        log_info "Salt is already installed."
        return 0
    fi

    log_info "Installing Salt via bootstrap..."
    curl -sL https://github.com/saltstack/salt-bootstrap/releases/latest/download/bootstrap-salt.sh -o /tmp/bootstrap-salt.sh
    sh /tmp/bootstrap-salt.sh
    rm -f /tmp/bootstrap-salt.sh

    if ! command -v salt-call >/dev/null 2>&1; then
        log_error "Salt installation failed."
        exit 1
    fi
    log_info "Salt installed."
}

# Install prerequisites and Salt - OpenBSD
install_openbsd() {
    log_info "Installing prerequisites (OpenBSD)..."
    pkg_add -U bash git curl

    if command -v salt-call >/dev/null 2>&1; then
        log_info "Salt is already installed."
        return 0
    fi

    log_info "Installing Salt..."
    pkg_add salt

    if ! command -v salt-call >/dev/null 2>&1; then
        log_error "Salt installation failed."
        exit 1
    fi
    log_info "Salt installed."
}

# Get username
get_username() {
    printf "${GREEN}[INFO]${NC} Enter the username for provisioning: "
    read username

    if [ -z "$username" ]; then
        log_error "Username cannot be empty."
        exit 1
    fi

    if id "$username" >/dev/null 2>&1; then
        log_info "User $username exists."
    else
        log_warn "User $username does not exist."
        printf "${GREEN}[INFO]${NC} Create this user? (y/N) "
        read create_user
        case "$create_user" in
            [Yy]*)
                if [ "$OS_TYPE" = "openbsd" ]; then
                    groupadd "$username" 2>/dev/null || true
                    useradd -m -g "$username" -G wheel -s /usr/local/bin/bash "$username"
                else
                    useradd -m -s /bin/bash "$username"
                fi
                log_info "User $username created."
                ;;
            *)
                log_error "Cannot proceed without a valid user."
                exit 1
                ;;
        esac
    fi
}

# Configure hostname
configure_hostname() {
    current_hostname=$(hostname)
    log_info "Current hostname: $current_hostname"
    printf "${GREEN}[INFO]${NC} Press [enter] to keep, or type new hostname: "
    read new_hostname

    if [ -n "$new_hostname" ] && [ "$new_hostname" != "$current_hostname" ]; then
        if [ "$OS_TYPE" = "openbsd" ]; then
            printf "%s\n" "$new_hostname" > /etc/myname
            hostname "$new_hostname"
        else
            hostnamectl set-hostname "$new_hostname"
        fi
        log_info "Hostname set to $new_hostname"
    else
        log_info "Hostname unchanged."
    fi
}

# Configure doas on OpenBSD
configure_doas() {
    log_info "Configuring doas..."
    cat > /etc/doas.conf << 'DOAS'
permit persist :wheel
DOAS
    chmod 600 /etc/doas.conf
    log_info "doas configured for wheel group."
}

# Configure Salt pillar
configure_pillar() {
    log_info "Configuring Salt pillar..."
    mkdir -p "$PILLAR_CONFIG_DIR"

    cat > "$PILLAR_CONFIG_DIR/top.sls" << EOF
base:
  '*':
    - user_config
    - system_config
EOF

    cat > "$PILLAR_CONFIG_DIR/user_config.sls" << EOF
username: $username
user_home: /home/$username
EOF

    cat > "$PILLAR_CONFIG_DIR/system_config.sls" << EOF
timezone: UTC
ntp_servers:
  - 0.pool.ntp.org
  - 1.pool.ntp.org
EOF
}

# Deploy Salt states
deploy_salt_states() {
    log_info "Deploying Salt states..."
    mkdir -p /etc/salt
    cp "$SCRIPT_DIR/minion" /etc/salt/minion

    rm -rf "$SALT_CONFIG_DIR"
    mkdir -p "$SALT_CONFIG_DIR"
    cp -R "$SCRIPT_DIR/salt/"* "$SALT_CONFIG_DIR/"
    log_info "Salt states deployed."
}

# Apply Salt highstate
apply_salt_states() {
    log_info "Applying Salt highstate..."
    if salt-call --local state.highstate; then
        log_info "Salt highstate applied successfully."
    else
        log_error "Salt highstate failed. Check /var/log/salt/minion for details."
        exit 1
    fi
}

# Post-install
post_install() {
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f
        log_info "Font cache updated."
    fi
}

# Main
main() {
    log_info "Starting dotfiles provisioning..."

    check_root
    detect_os

    if [ "$OS_TYPE" = "openbsd" ]; then
        install_openbsd
    else
        install_linux
    fi

    get_username
    configure_hostname

    if [ "$OS_TYPE" = "openbsd" ]; then
        configure_doas
    fi

    configure_pillar
    deploy_salt_states
    apply_salt_states
    post_install

    log_info "Provisioning completed for user $username!"
    log_info "Reboot recommended for all changes to take effect."
}

main "$@"
