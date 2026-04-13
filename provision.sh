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
                nano htop btop nmap screen-- lsd \
                i3 i3lock i3status dmenu xautolock st-- \
                firefox-esr neomutt-- msmtp
            ;;
        linux)
            apt-get update -qq
            apt-get install -y \
                curl wget git sudo build-essential unzip \
                nano micro htop btop nmap screen lsd \
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
                bash git nano micro htop btop nmap lsd neomutt msmtp || true
            brew install --cask wezterm || true
            ;;
    esac

    log_info "Packages installed."
}

# -------------------------------------------------------------------
# issy — clone the latest source from GitHub and build with Zig,
# then install the resulting binary as /usr/local/bin/issy.
# Building from source (rather than downloading a prebuilt binary)
# keeps this portable across Linux, macOS, and OpenBSD without
# depending on which release assets happen to be published.
# Idempotent: skips if already installed.
# -------------------------------------------------------------------
ZIG_VERSION="0.15.2"

ensure_zig() {
    if command -v zig >/dev/null 2>&1; then
        return 0
    fi

    case "$OS_TYPE" in
        macos)
            brew install zig >/dev/null 2>&1 || return 1
            ;;
        openbsd)
            pkg_add -I zig >/dev/null 2>&1 || return 1
            ;;
        linux)
            case "$(uname -m)" in
                x86_64)  zig_arch="x86_64" ;;
                aarch64) zig_arch="aarch64" ;;
                *) log_warn "No Zig tarball for $(uname -m)."; return 1 ;;
            esac
            tarball="zig-${zig_arch}-linux-${ZIG_VERSION}.tar.xz"
            url="https://ziglang.org/download/${ZIG_VERSION}/${tarball}"
            tmp="/tmp/zig.tar.xz"
            log_info "Downloading Zig ${ZIG_VERSION}..."
            curl -fsSL -o "$tmp" "$url" || return 1
            mkdir -p /opt/zig
            tar xf "$tmp" -C /opt/zig --strip-components=1 || return 1
            ln -sf /opt/zig/zig /usr/local/bin/zig
            rm -f "$tmp"
            ;;
    esac

    command -v zig >/dev/null 2>&1
}

install_issy() {
    if command -v issy >/dev/null 2>&1; then
        log_info "issy already installed at $(command -v issy)."
        return
    fi

    log_info "Building issy from source..."

    if ! ensure_zig; then
        log_warn "Could not install Zig. Skipping issy build."
        log_warn "Install Zig ${ZIG_VERSION}+ manually and re-run to get issy."
        return
    fi

    src_dir="/tmp/issy-src.$$"
    rm -rf "$src_dir"
    if ! git clone --depth 1 https://github.com/davidemerson/issy.git "$src_dir" >/dev/null 2>&1; then
        log_warn "Failed to clone issy repository. Skipping."
        return
    fi

    if ! (cd "$src_dir" && zig build -Doptimize=ReleaseSafe); then
        log_warn "zig build failed for issy. Skipping install."
        rm -rf "$src_dir"
        return
    fi

    bin="$src_dir/zig-out/bin/issy"
    if [ ! -x "$bin" ]; then
        log_warn "issy binary not produced at $bin. Skipping."
        rm -rf "$src_dir"
        return
    fi

    dest="/usr/local/bin/issy"
    if [ "$OS_TYPE" = "macos" ]; then
        sudo install -m 0755 "$bin" "$dest"
    else
        install -m 0755 "$bin" "$dest"
    fi
    rm -rf "$src_dir"

    log_info "issy installed at $dest."
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

        # Remove default i3 config (conflicts with user config)
        rm -f /etc/i3/config

        # Set console font to Spleen 8x16 if the display supports it
        # (simplefb on VMware arm64 does not support font switching)
        if wsconsctl "display.font=Spleen 8x16" >/dev/null 2>&1; then
            grep -q 'display.font' /etc/wsconsctl.conf 2>/dev/null || \
                echo 'display.font=Spleen 8x16' >> /etc/wsconsctl.conf
            log_info "Console font set to Spleen 8x16."
        fi
    else
        timedatectl set-timezone UTC 2>/dev/null || true
        systemctl enable systemd-timesyncd 2>/dev/null || true
        systemctl start systemd-timesyncd 2>/dev/null || true
        systemctl disable gdm 2>/dev/null || true

        # Set console font to Terminus 14 (small, clean bitmap font)
        sed -i 's/^FONTFACE=.*/FONTFACE="Terminus"/' /etc/default/console-setup
        sed -i 's/^FONTSIZE=.*/FONTSIZE="14"/' /etc/default/console-setup
        setupcon --force 2>/dev/null || true
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
        # Ensure user is in the right privilege group
        if [ "$OS_TYPE" = "openbsd" ]; then
            usermod -G wheel "$username" 2>/dev/null || true
        else
            usermod -aG sudo "$username" 2>/dev/null || true
        fi
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
        # OS-specific file skips
        case "$rel" in
            *.xinitrc) [ "$OS_TYPE" != "openbsd" ] && skip=true ;;
            *.bashrc|*.bash_profile) [ "$OS_TYPE" = "macos" ] && skip=true ;;
            *.zshrc) [ "$OS_TYPE" != "macos" ] && skip=true ;;
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

    # .xinitrc must be executable or xinit falls back to launching xterm
    chmod +x "$home_dir/.xinitrc" 2>/dev/null || true

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
    install_issy
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
