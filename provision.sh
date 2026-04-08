#!/bin/sh

# Dotfiles provisioning script — Debian Linux, OpenBSD, macOS
# Idempotent: safe to re-run after pulling updated dotfiles.
# Run as root (Linux/OpenBSD) or as your user (macOS).

set -eu

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OS_TYPE=""

log_info()  { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# -------------------------------------------------------------------
# OS detection
# -------------------------------------------------------------------
detect_os() {
    case "$(uname -s)" in
        Linux)   OS_TYPE="linux" ;;
        OpenBSD) OS_TYPE="openbsd" ;;
        Darwin)  OS_TYPE="macos" ;;
        *)       log_error "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac
    log_info "Detected OS: $OS_TYPE"
}

check_root() {
    if [ "$OS_TYPE" = "macos" ]; then
        return  # macOS runs as normal user with sudo for brew
    fi
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root."
        exit 1
    fi
}

# -------------------------------------------------------------------
# Package installation
# -------------------------------------------------------------------
install_packages() {
    log_info "Installing packages..."

    case "$OS_TYPE" in
        openbsd)
            pkg_add -U \
                bash curl wget git unzip-- \
                nano htop nmap screen-- lsd \
                i3 i3lock i3status dmenu xautolock \
                firefox-esr neomutt-- msmtp
            ;;
        linux)
            apt-get update -qq
            apt-get install -y \
                curl wget git sudo ntpdate build-essential unzip \
                nano micro htop nmap screen lsd \
                sway swaybg swaylock swayidle xwayland waybar wofi wob pamixer foot \
                firefox-esr neomutt msmtp

            # Sublime Text
            if ! command -v subl >/dev/null 2>&1; then
                log_info "Installing Sublime Text..."
                wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg \
                    | gpg --dearmor | tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg > /dev/null
                echo "deb https://download.sublimetext.com/ apt/stable/" \
                    | tee /etc/apt/sources.list.d/sublime-text.list
                apt-get update -qq && apt-get install -y sublime-text
            fi

            # VMware tools (auto-detected)
            if grep -q VMware /sys/class/dmi/id/sys_vendor 2>/dev/null; then
                apt-get install -y open-vm-tools-desktop
            fi
            ;;
        macos)
            # Install Homebrew if missing
            if ! command -v brew >/dev/null 2>&1; then
                log_info "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi

            brew install \
                bash git nano micro htop nmap lsd neomutt msmtp || true
            brew install --cask wezterm || true
            ;;
    esac

    log_info "Packages installed."
}

# -------------------------------------------------------------------
# Services
# -------------------------------------------------------------------
configure_services() {
    if [ "$OS_TYPE" = "macos" ]; then return; fi

    log_info "Configuring services..."

    if [ "$OS_TYPE" = "openbsd" ]; then
        ln -sf /usr/share/zoneinfo/UTC /etc/localtime
        rcctl enable ntpd 2>/dev/null || true
        rcctl start ntpd 2>/dev/null || true
    else
        timedatectl set-timezone UTC 2>/dev/null || true
        systemctl enable systemd-timesyncd 2>/dev/null || true
        systemctl start systemd-timesyncd 2>/dev/null || true
        systemctl disable gdm 2>/dev/null || true
    fi

    log_info "Services configured."
}

# -------------------------------------------------------------------
# User and group (Linux/OpenBSD only — macOS uses existing user)
# -------------------------------------------------------------------
get_username() {
    if [ "$OS_TYPE" = "macos" ]; then
        username="$(whoami)"
        log_info "Using current user: $username"
        return
    fi

    printf "${GREEN}[INFO]${NC} Enter the username for provisioning: "
    read username

    if [ -z "$username" ]; then
        log_error "Username cannot be empty."
        exit 1
    fi

    # Ensure group exists
    if ! getent group "$username" >/dev/null 2>&1; then
        groupadd "$username" 2>/dev/null || true
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
                    useradd -m -g "$username" -G wheel -s /usr/local/bin/bash "$username"
                else
                    useradd -m -g "$username" -s /bin/bash "$username"
                    usermod -aG sudo "$username" 2>/dev/null || true
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

# -------------------------------------------------------------------
# Hostname (Linux/OpenBSD only)
# -------------------------------------------------------------------
configure_hostname() {
    if [ "$OS_TYPE" = "macos" ]; then return; fi

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

    # Ensure hostname resolves locally
    h=$(hostname)
    if ! grep -q "$h" /etc/hosts 2>/dev/null; then
        printf "127.0.0.1 %s %s\n" "$h" "${h%%.*}" >> /etc/hosts
        printf "::1 %s %s\n" "$h" "${h%%.*}" >> /etc/hosts
        log_info "Added $h to /etc/hosts."
    fi
}

# -------------------------------------------------------------------
# doas (OpenBSD only)
# -------------------------------------------------------------------
configure_doas() {
    if [ "$OS_TYPE" != "openbsd" ]; then return; fi

    log_info "Configuring doas..."
    cat > /etc/doas.conf << 'DOAS'
permit persist :wheel
DOAS
    chmod 600 /etc/doas.conf
    log_info "doas configured for wheel group."
}

# -------------------------------------------------------------------
# Deploy dotfiles
#
# Files use @@IF_OPENBSD@@/@@IF_LINUX@@/@@IF_MACOS@@/@@END_IF@@
# markers. At deploy time, the current OS's blocks are kept and
# all other OS blocks are stripped. Files without markers are
# copied as-is.
#
# Configs are skipped per-OS: OpenBSD skips sway/waybar/foot
# (uses i3/X11), Linux skips i3 (uses sway/Wayland), macOS
# skips all window manager configs.
# -------------------------------------------------------------------
deploy_dotfiles() {
    if [ "$OS_TYPE" = "macos" ]; then
        home_dir="$HOME"
    else
        home_dir="/home/$username"
    fi

    log_info "Deploying dotfiles to $home_dir..."

    # Map OS_TYPE to marker tag
    case "$OS_TYPE" in
        openbsd) KEEP="OPENBSD" ;;
        linux)   KEEP="LINUX" ;;
        macos)   KEEP="MACOS" ;;
    esac

    # Directories to skip per OS
    case "$OS_TYPE" in
        openbsd) SKIP_DIRS="sway swaylock waybar wofi foot" ;;
        linux)   SKIP_DIRS="i3" ;;
        macos)   SKIP_DIRS="sway swaylock waybar wofi foot i3 i3status" ;;
    esac

    cd "$SCRIPT_DIR/dotfiles"
    find . -type f | while read -r rel; do
        # Skip configs not relevant to this OS
        skip=false
        for d in $SKIP_DIRS; do
            case "$rel" in
                *.config/$d/*) skip=true ;;
            esac
        done
        # .xinitrc is only for OpenBSD (startx/i3)
        case "$rel" in
            *.xinitrc) [ "$OS_TYPE" != "openbsd" ] && skip=true ;;
        esac
        if [ "$skip" = "true" ]; then continue; fi

        src="$SCRIPT_DIR/dotfiles/$rel"
        dst="$home_dir/$rel"
        mkdir -p "$(dirname "$dst")"

        if grep -q '@@IF_' "$src" 2>/dev/null; then
            # Strip all OS blocks except the current one
            sed_expr=""
            for tag in OPENBSD LINUX MACOS; do
                if [ "$tag" != "$KEEP" ]; then
                    sed_expr="${sed_expr} -e '/# @@IF_${tag}@@/,/# @@END_IF@@/d'"
                fi
            done
            # Remove the kept OS's marker lines (but keep content between them)
            sed_expr="${sed_expr} -e '/# @@IF_${KEEP}@@/d' -e '/# @@END_IF@@/d'"
            eval sed $sed_expr '"$src"' > "$dst"
        else
            cp "$src" "$dst"
        fi
    done

    # Ownership (not needed on macOS — files are already owned by user)
    if [ "$OS_TYPE" != "macos" ]; then
        chown -R "${username}:${username}" "$home_dir"
    fi

    # SSH permissions
    if [ -d "$home_dir/.ssh" ]; then
        chmod 700 "$home_dir/.ssh"
        chmod 600 "$home_dir/.ssh/config" 2>/dev/null || true
    fi

    log_info "Dotfiles deployed."
}

# -------------------------------------------------------------------
# Font cache
# -------------------------------------------------------------------
update_fonts() {
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f 2>/dev/null || true
        log_info "Font cache updated."
    fi
}

# -------------------------------------------------------------------
# Main
# -------------------------------------------------------------------
main() {
    log_info "Starting dotfiles provisioning..."

    detect_os
    check_root
    install_packages
    get_username
    configure_hostname
    configure_doas
    configure_services
    deploy_dotfiles
    update_fonts

    log_info "Provisioning completed for user $username!"
    if [ "$OS_TYPE" != "macos" ]; then
        log_info "Reboot recommended for all changes to take effect."
    fi
}

main "$@"
