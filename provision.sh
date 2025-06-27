#!/bin/bash

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# Color codes for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SALT_CONFIG_DIR="/srv/salt"
readonly PILLAR_CONFIG_DIR="/srv/pillar"
readonly MIN_SALT_VERSION="3004"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if script is run as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root."
        exit 1
    fi
}

# Function to check if a package is installed
ensure_installed() {
    local package="$1"
    if ! dpkg -l | grep -qw "$package"; then
        log_info "Installing $package..."
        apt update && apt install -y "$package"
    else
        log_info "$package is already installed."
    fi
}

# Install essential packages
install_prerequisites() {
    log_info "Installing prerequisite packages..."
    local packages=(curl micro git sudo ntpdate)
    
    for package in "${packages[@]}"; do
        ensure_installed "$package"
    done
}

# Install Salt if not present
install_salt() {
    if command -v salt-minion &> /dev/null; then
        log_info "salt-minion is already installed."
        return 0
    fi

    log_info "Installing Salt via bootstrap script..."
    
    # Download and verify bootstrap script
    curl -L https://github.com/saltstack/salt-bootstrap/releases/latest/download/bootstrap-salt.sh -o bootstrap-salt.sh
    chmod +x bootstrap-salt.sh

    # Run the bootstrap script
    if ./bootstrap-salt.sh -M; then
        log_info "Salt bootstrap completed successfully."
        
        # Wait for salt-minion to be available
        local timeout=60
        local elapsed=0
        while ! command -v salt-minion &> /dev/null; do
            sleep 1
            elapsed=$((elapsed + 1))
            if [ $elapsed -ge $timeout ]; then
                log_error "Timeout waiting for salt-minion installation."
                exit 1
            fi
        done
        
        log_info "salt-minion is now available."
    else
        log_error "Bootstrap script failed."
        exit 1
    fi
    
    # Clean up bootstrap script
    rm -f bootstrap-salt.sh
}

# Get username for provisioning
get_username() {
    local username
    
    while true; do
        log_info "Enter the username for provisioning (sudoers, dotfiles):"
        read -r username
        
        if [[ -z "$username" ]]; then
            log_warn "Username cannot be empty. Please try again."
            continue
        fi
        
        if id -u "$username" >/dev/null 2>&1; then
            echo "$username"
            return 0
        else
            log_warn "User $username does not exist."
            log_info "Would you like to create this user? (y/N)"
            read -r create_user
            if [[ "$create_user" =~ ^[Yy]$ ]]; then
                useradd -m -s /bin/bash "$username"
                log_info "User $username created."
                echo "$username"
                return 0
            fi
        fi
    done
}

# Configure hostname
configure_hostname() {
    local current_hostname
    current_hostname=$(hostname)
    
    log_info "Current hostname: $current_hostname"
    log_info "Press [enter] to keep current hostname, or type a new hostname:"
    read -r new_hostname
    
    if [[ -n "$new_hostname" && "$new_hostname" != "$current_hostname" ]]; then
        hostnamectl set-hostname "$new_hostname"
        log_info "Hostname set to $new_hostname"
    else
        log_info "Hostname unchanged."
    fi
}

# Configure Salt pillar
configure_pillar() {
    local username="$1"
    
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
    
    # Copy minion configuration
    cp "$SCRIPT_DIR/minion" /etc/salt/minion
    
    # Remove old salt states and copy new ones
    rm -rf "$SALT_CONFIG_DIR"
    mkdir -p "$SALT_CONFIG_DIR"
    cp -R "$SCRIPT_DIR/salt/"* "$SALT_CONFIG_DIR/"
    
    log_info "Salt states deployed successfully."
}

# Apply Salt configuration
apply_salt_states() {
    log_info "Applying Salt highstate..."
    
    if salt-call --local state.highstate; then
        log_info "Salt highstate applied successfully."
    else
        log_error "Salt highstate failed. Check logs for details."
        exit 1
    fi
}

# Configure system services
configure_services() {
    log_info "Configuring system services..."
    
    # Update font cache
    fc-cache -fv
    log_info "Font cache updated."
}

# Main function
main() {
    log_info "Starting dotfiles provisioning..."
    
    check_root
    install_prerequisites
    install_salt
    
    local username
    username=$(get_username)
    
    configure_hostname
    configure_pillar "$username"
    deploy_salt_states
    apply_salt_states
    configure_services
    
    log_info "Provisioning completed successfully for user $username!"
    log_info "You may need to reboot for all changes to take effect."
}

# Run main function
main "$@"
