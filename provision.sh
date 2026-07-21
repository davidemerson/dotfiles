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
                nano htop btop nmap screen-- lsd mosh \
                i3 i3lock i3status dmenu xautolock st-- \
                dbus dunst scrot xclip xsel xdotool xss-lock ImageMagick clipmenu \
                chromium audacity vlc
            ;;
        linux)
            apt-get update -qq
            apt-get install -y \
                curl wget git sudo build-essential unzip \
                nano micro htop btop nmap screen lsd tmux mosh \
                sway swaybg swaylock swayidle xwayland waybar wofi wob pamixer foot \
                grim slurp mako-notifier libnotify-bin \
                audacity vlc adwaita-qt6 \
                wl-clipboard cliphist \
                fzf fd-find git-delta \
                fwupd rasdaemon ethtool nvme-cli smartmontools lm-sensors \
                unattended-upgrades needrestart \
                nftables zram-tools systemd-oomd \
                pcscd libccid opensc pcsc-tools \
                flatpak

            # Non-free firmware for peripherals (e.g. the Realtek RTL8761BU
            # Bluetooth in the ASUS USB-BT500 needs rtl_bt/* from
            # firmware-realtek). Guarded: these live in the non-free-firmware
            # component (default on Debian 13) — warn instead of aborting the
            # whole run if it isn't enabled. Harmless no-ops on a VM.
            apt-get install -y firmware-realtek firmware-misc-nonfree 2>/dev/null \
                || log_warn "firmware-realtek/firmware-misc-nonfree unavailable; enable the non-free-firmware apt component."

            # Sublime Text
            if ! command -v subl >/dev/null 2>&1; then
                log_info "Installing Sublime Text..."
                wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg \
                    | gpg --dearmor | tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg > /dev/null
                echo "deb https://download.sublimetext.com/ apt/stable/" \
                    | tee /etc/apt/sources.list.d/sublime-text.list
                apt-get update -qq && apt-get install -y sublime-text
            fi

            # ZeroTier
            if ! command -v zerotier-cli >/dev/null 2>&1; then
                log_info "Installing ZeroTier..."
                ZT_SUITE="trixie"
                if [ -r /etc/os-release ]; then
                    ZT_SUITE="$(. /etc/os-release; printf '%s' "${VERSION_CODENAME:-trixie}")"
                fi
                wget -qO - https://download.zerotier.com/contact%40zerotier.com.gpg \
                    | gpg --dearmor > /usr/share/keyrings/zerotier.gpg
                echo "deb [signed-by=/usr/share/keyrings/zerotier.gpg] https://download.zerotier.com/debian/$ZT_SUITE $ZT_SUITE main" \
                    > /etc/apt/sources.list.d/zerotier.list
                apt-get update -qq && apt-get install -y zerotier-one
            fi

            # Google Chrome (upstream ships amd64 only)
            if ! command -v google-chrome >/dev/null 2>&1 \
                && [ "$(dpkg --print-architecture)" = "amd64" ]; then
                log_info "Installing Google Chrome..."
                wget -qO - https://dl.google.com/linux/linux_signing_key.pub \
                    | gpg --dearmor > /usr/share/keyrings/google-chrome.gpg
                echo "deb [signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
                    > /etc/apt/sources.list.d/google-chrome.list
                apt-get update -qq && apt-get install -y google-chrome-stable
            fi

            # 1Password (desktop app + CLI). The app requires debsig-verify
            # per-package signature checking, so we install its policy and a
            # second copy of the signing key under /etc/debsig + /usr/share/debsig.
            # "stable" is 1Password's own suite (distro-agnostic), so there is
            # nothing codename-specific to track. Repo serves amd64 and arm64.
            if ! command -v 1password >/dev/null 2>&1; then
                log_info "Installing 1Password..."
                OP_ARCH="$(dpkg --print-architecture)"
                wget -qO - https://downloads.1password.com/linux/keys/1password.asc \
                    | gpg --dearmor > /usr/share/keyrings/1password-archive-keyring.gpg
                echo "deb [arch=$OP_ARCH signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$OP_ARCH stable main" \
                    > /etc/apt/sources.list.d/1password.list
                mkdir -p /etc/debsig/policies/AC2D62742012EA22
                wget -qO - https://downloads.1password.com/linux/debian/debsig/1password.pol \
                    > /etc/debsig/policies/AC2D62742012EA22/1password.pol
                mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
                wget -qO - https://downloads.1password.com/linux/keys/1password.asc \
                    | gpg --dearmor > /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
                apt-get update -qq && apt-get install -y 1password 1password-cli
            fi

            # Zoom (official .deb; Zoom publishes no apt repo, so this is a
            # one-shot install and Zoom self-updates in-app). amd64 only. Runs
            # under XWayland on Sway. Downloaded over HTTPS from zoom.us.
            if ! command -v zoom >/dev/null 2>&1 \
                && [ "$(dpkg --print-architecture)" = "amd64" ]; then
                log_info "Installing Zoom..."
                zoom_deb="/tmp/zoom_amd64.$$.deb"
                if wget -qO "$zoom_deb" https://zoom.us/client/latest/zoom_amd64.deb; then
                    apt-get install -y "$zoom_deb" || log_warn "Zoom install failed."
                    rm -f "$zoom_deb"
                else
                    log_warn "Zoom download failed; skipping."
                fi
            fi

            # GitHub Desktop — COMMUNITY build (GitHub ships no official Linux
            # app). shiftkey/desktop's own apt host (apt.packages.shiftkey.dev)
            # has recurring TLS-cert breakage, so we use the maintained @mwt
            # mirror instead. Wrapped so a broken third-party repo only warns
            # and never aborts the rest of provisioning. amd64 only.
            if ! command -v github-desktop >/dev/null 2>&1 \
                && [ "$(dpkg --print-architecture)" = "amd64" ]; then
                log_info "Installing GitHub Desktop (community shiftkey build, @mwt mirror)..."
                ghd_key="/tmp/ghd-key.$$"
                if wget -qO "$ghd_key" https://mirror.mwt.me/shiftkey-desktop/gpgkey; then
                    gpg --dearmor < "$ghd_key" > /usr/share/keyrings/mwt-desktop.gpg 2>/dev/null \
                        || cp "$ghd_key" /usr/share/keyrings/mwt-desktop.gpg
                    rm -f "$ghd_key"
                    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/mwt-desktop.gpg] https://mirror.mwt.me/shiftkey-desktop/deb/ any main" \
                        > /etc/apt/sources.list.d/shiftkey-packages.list
                    apt-get update -qq && apt-get install -y github-desktop || log_warn "GitHub Desktop install failed; continuing."
                else
                    log_warn "GitHub Desktop key download failed; skipping."
                fi
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
                bash git nano micro htop btop nmap lsd tmux mosh || true
            brew install --cask wezterm 1password 1password-cli \
                audacity vlc zoom github || true
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
ZIG=""  # path to a usable zig, resolved by ensure_zig

# issy requires Zig 0.15.x: 0.16 moved std.fs under std.Io.Dir and issy
# fails its own comptime version gate. So never trust a bare `zig` on
# PATH — verify the version of whatever we find or install.
zig_ok() {
    case "$("$1" version 2>/dev/null)" in
        0.15.*) return 0 ;;
        *)      return 1 ;;
    esac
}

ensure_zig() {
    if command -v zig >/dev/null 2>&1 && zig_ok zig; then
        ZIG="zig"
        return 0
    fi

    case "$OS_TYPE" in
        macos)
            # brew's main `zig` formula tracks latest (0.16+), which issy
            # rejects; use the keg-only zig@0.15 pin instead.
            brew install zig@0.15 >/dev/null 2>&1 || true
            ZIG="$(brew --prefix zig@0.15 2>/dev/null)/bin/zig"
            ;;
        openbsd)
            pkg_add -I zig >/dev/null 2>&1 || true
            ZIG="zig"
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
            ZIG="/usr/local/bin/zig"
            ;;
    esac

    [ -n "$ZIG" ] && zig_ok "$ZIG"
}

install_issy() {
    # macOS: if Homebrew manages issy (davidemerson/issy tap), let brew own
    # it. A source build into /usr/local/bin would be shadowed by
    # /opt/homebrew/bin on PATH, and the HEAD-vs-installed check would
    # then trigger a futile rebuild on every run (release tags trail the
    # formula-bump commit at HEAD).
    if [ "$OS_TYPE" = "macos" ] && command -v brew >/dev/null 2>&1 && \
       brew list issy >/dev/null 2>&1; then
        log_info "issy is Homebrew-managed; updating via brew."
        brew upgrade issy >/dev/null 2>&1 || true
        return
    fi

    if command -v issy >/dev/null 2>&1; then
        issy_bin="$(command -v issy)"
        # On OpenBSD a sysupgrade bumps libc/base libs and breaks old
        # from-source binaries, so rebuild if issy no longer links.
        if [ "$OS_TYPE" = "openbsd" ] && ! ldd "$issy_bin" >/dev/null 2>&1; then
            log_warn "issy present but not linking (post-upgrade?); rebuilding."
        else
            # Otherwise rebuild only if upstream is newer than what's installed.
            # `issy --version` prints e.g. "issy 1.0.0 (eab3e42 release)".
            have=$(issy --version 2>&1 | sed -n 's/.*(\([0-9a-f][0-9a-f]*\).*/\1/p')
            want=$(git ls-remote https://github.com/davidemerson/issy.git HEAD 2>/dev/null | awk '{print $1}')
            if [ -z "$want" ]; then
                log_info "issy installed; upstream unreachable, keeping current build."
                return
            fi
            if [ -n "$have" ]; then
                case "$want" in "$have"*)
                    log_info "issy already at latest (${have})."
                    return ;;
                esac
            fi
            log_info "issy out of date (have ${have:-unknown}, latest $(echo "$want" | cut -c1-7)); rebuilding."
        fi
    fi

    log_info "Building issy from source..."

    if ! ensure_zig; then
        log_warn "Could not install Zig 0.15.x. Skipping issy build."
        log_warn "Install Zig ${ZIG_VERSION} (issy needs 0.15.x, not 0.16+) and re-run."
        return
    fi

    src_dir="/tmp/issy-src.$$"
    rm -rf "$src_dir"
    if ! git clone --depth 1 https://github.com/davidemerson/issy.git "$src_dir" >/dev/null 2>&1; then
        log_warn "Failed to clone issy repository. Skipping."
        return
    fi

    if ! (cd "$src_dir" && "$ZIG" build -Doptimize=ReleaseSafe); then
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
# pfetch — minimal, dependency-free system fetch (single POSIX script).
# Not packaged on OpenBSD/Debian, so fetch the script for those; macOS
# has a Homebrew formula. Idempotent: skips if already on PATH.
# -------------------------------------------------------------------
install_pfetch() {
    if command -v pfetch >/dev/null 2>&1; then
        log_info "pfetch already installed."
        return
    fi

    if [ "$OS_TYPE" = "macos" ]; then
        brew install pfetch >/dev/null 2>&1 && log_info "pfetch installed." \
            || log_warn "brew install pfetch failed."
        return
    fi

    log_info "Installing pfetch..."
    url="https://raw.githubusercontent.com/dylanaraps/pfetch/master/pfetch"
    if curl -fsSL -o /tmp/pfetch.$$ "$url"; then
        install -m 0755 /tmp/pfetch.$$ /usr/local/bin/pfetch && \
            log_info "pfetch installed at /usr/local/bin/pfetch."
        rm -f /tmp/pfetch.$$
    else
        log_warn "Could not download pfetch. Skipping."
    fi
}

# -------------------------------------------------------------------
# herdr — agent multiplexer (https://herdr.dev). Upstream ships prebuilt
# binaries only (Linux x86_64/aarch64, macOS via homebrew-core); it's a
# Rust project with no documented source build and no OpenBSD assets, so
# OpenBSD is skipped. Idempotent: skips if already on PATH.
# -------------------------------------------------------------------
install_herdr() {
    if command -v herdr >/dev/null 2>&1; then
        log_info "herdr already installed."
        return
    fi

    case "$OS_TYPE" in
        macos)
            brew install herdr >/dev/null 2>&1 && log_info "herdr installed." \
                || log_warn "brew install herdr failed."
            ;;
        linux)
            case "$(uname -m)" in
                x86_64)  herdr_arch="x86_64" ;;
                aarch64) herdr_arch="aarch64" ;;
                *) log_warn "No herdr binary for $(uname -m). Skipping."; return ;;
            esac
            url="https://github.com/ogulcancelik/herdr/releases/latest/download/herdr-linux-${herdr_arch}"
            log_info "Installing herdr..."
            if curl -fsSL -o /tmp/herdr.$$ "$url"; then
                install -m 0755 /tmp/herdr.$$ /usr/local/bin/herdr
                rm -f /tmp/herdr.$$
                log_info "herdr installed at /usr/local/bin/herdr."
            else
                rm -f /tmp/herdr.$$
                log_warn "Could not download herdr. Skipping."
            fi
            ;;
        openbsd)
            log_warn "herdr publishes no OpenBSD builds; skipping."
            ;;
    esac
}

# -------------------------------------------------------------------
# Patched st (OpenBSD terminal). Built from bakkeby/st-flexipatch with
# our st/config.h + st/patches.h, which enable: clipboard (selection
# auto-copies to the system CLIPBOARD), keyboard-select (mouseless
# copy), scrollback (+ mouse wheel), anysize, bold-is-not-bright, and
# boxdraw. Font is Berkeley Mono Variable NNIX. The packaged st (kept
# in the pkg list) provides terminfo and a fallback if the build fails.
# Idempotent: skips when the pinned commit is already installed.
# -------------------------------------------------------------------
ST_FLEXIPATCH_COMMIT="1d3f20096c9b5cea0452343a97c644f5987da6d9"

install_st() {
    [ "$OS_TYPE" = "openbsd" ] || return 0

    # Stamp on commit + OS release. A sysupgrade bumps Xenocara/base libs,
    # so the old binary stops loading even though the commit is unchanged;
    # the uname -r component (and the ldd link check) force a rebuild then.
    stamp=/usr/local/share/st-flexipatch.commit
    # Also confirm the on-disk binary is OUR build (Berkeley Mono compiled
    # in): `pkg_add -u` reinstalls the stock st package over it, which the
    # stamp+ldd check alone would not notice (reverts font/patches).
    want="$ST_FLEXIPATCH_COMMIT $(uname -r)"
    if [ -x /usr/local/bin/st ] && [ "$(cat "$stamp" 2>/dev/null)" = "$want" ] && \
       ldd /usr/local/bin/st >/dev/null 2>&1 && \
       strings /usr/local/bin/st 2>/dev/null | grep -q "Berkeley Mono Variable NNIX"; then
        log_info "Patched st already installed (Berkeley Mono, links OK)."
        return
    fi

    log_info "Building patched st (st-flexipatch)..."
    src="/tmp/st-flexipatch.$$"
    rm -rf "$src"
    if ! git clone -q https://github.com/bakkeby/st-flexipatch.git "$src"; then
        log_warn "Failed to clone st-flexipatch. Keeping packaged st."
        return
    fi
    ( cd "$src" && git checkout -q "$ST_FLEXIPATCH_COMMIT" ) 2>/dev/null || \
        log_warn "Could not pin st-flexipatch commit; building tip."
    cp "$SCRIPT_DIR/st/config.h"  "$src/config.h"
    cp "$SCRIPT_DIR/st/patches.h" "$src/patches.h"
    if ! ( cd "$src" && make >/dev/null 2>&1 ); then
        log_warn "st build failed. Keeping packaged st."
        rm -rf "$src"
        return
    fi
    # Overwrites the pkg-owned binary; terminfo from the package stays.
    install -m 0755 "$src/st" /usr/local/bin/st
    printf '%s\n' "$want" > "$stamp"
    rm -rf "$src"
    log_info "Patched st installed to /usr/local/bin/st."
}

# -------------------------------------------------------------------
# Patched dmenu (OpenBSD launcher). Built from bakkeby/dmenu-flexipatch
# with our dmenu/config.h + dmenu/patches.h, which enable: fuzzy match +
# highlight, case-insensitive, centered, line-height padding, and a
# border. Font is Berkeley Mono Variable NNIX, palette grayscale+navy/blue.
# OpenBSD keeps freetype headers under /usr/X11R6, so FREETYPEINC is
# overridden. Packaged dmenu stays as a fallback. Idempotent via stamp.
# -------------------------------------------------------------------
DMENU_FLEXIPATCH_COMMIT="c59af646f2d8ccbc31f799111b0ff7a1282efa63"

install_dmenu() {
    [ "$OS_TYPE" = "openbsd" ] || return 0

    # Rebuild on commit OR OS-release change (sysupgrade bumps base libs) OR
    # if the binary no longer links — see install_st() for the rationale.
    stamp=/usr/local/share/dmenu-flexipatch.commit
    want="$DMENU_FLEXIPATCH_COMMIT $(uname -r)"
    if [ -x /usr/local/bin/dmenu ] && [ "$(cat "$stamp" 2>/dev/null)" = "$want" ] && \
       ldd /usr/local/bin/dmenu >/dev/null 2>&1 && \
       strings /usr/local/bin/dmenu 2>/dev/null | grep -q "Berkeley Mono Variable NNIX"; then
        log_info "Patched dmenu already installed (Berkeley Mono, links OK)."
        return
    fi

    log_info "Building patched dmenu (dmenu-flexipatch)..."
    src="/tmp/dmenu-flexipatch.$$"
    rm -rf "$src"
    if ! git clone -q https://github.com/bakkeby/dmenu-flexipatch.git "$src"; then
        log_warn "Failed to clone dmenu-flexipatch. Keeping packaged dmenu."
        return
    fi
    ( cd "$src" && git checkout -q "$DMENU_FLEXIPATCH_COMMIT" ) 2>/dev/null || \
        log_warn "Could not pin dmenu-flexipatch commit; building tip."
    cp "$SCRIPT_DIR/dmenu/config.h"  "$src/config.h"
    cp "$SCRIPT_DIR/dmenu/patches.h" "$src/patches.h"
    if ! ( cd "$src" && make FREETYPEINC=/usr/X11R6/include/freetype2 >/dev/null 2>&1 ); then
        log_warn "dmenu build failed. Keeping packaged dmenu."
        rm -rf "$src"
        return
    fi
    install -m 0755 "$src/dmenu" /usr/local/bin/dmenu
    printf '%s\n' "$want" > "$stamp"
    rm -rf "$src"
    log_info "Patched dmenu installed to /usr/local/bin/dmenu."
}

# -------------------------------------------------------------------
# Todoist — no official .deb, so install the official AppImage (Doist's
# real native app) on Linux and the official cask on macOS. No OpenBSD
# build exists, so it is skipped there. Idempotent: the AppImage is only
# re-downloaded when absent; the wrapper + launcher are rewritten each run.
# -------------------------------------------------------------------
install_todoist() {
    case "$OS_TYPE" in
        linux)
            # upstream publishes x86_64 only
            [ "$(dpkg --print-architecture)" = "amd64" ] || { log_warn "Todoist AppImage is x86_64-only; skipping."; return 0; }
            if [ ! -x /opt/todoist/Todoist.AppImage ]; then
                log_info "Installing Todoist (official AppImage)..."
                # AppImages need FUSE 2 at runtime (libfuse2t64 on trixie)
                apt-get install -y libfuse2t64 >/dev/null 2>&1 || apt-get install -y libfuse2 >/dev/null 2>&1 || true
                mkdir -p /opt/todoist
                # the /linux_app/appimage endpoint 302-redirects to the latest
                # versioned build, so this stays version-agnostic across re-runs
                if wget -qO /opt/todoist/Todoist.AppImage https://todoist.com/linux_app/appimage; then
                    chmod 0755 /opt/todoist/Todoist.AppImage
                    # extract the bundled icon for the launcher (no FUSE needed)
                    td_tmp="$(mktemp -d)"
                    ( cd "$td_tmp" && /opt/todoist/Todoist.AppImage --appimage-extract >/dev/null 2>&1 ) || true
                    td_icon="$(find "$td_tmp/squashfs-root" -name 'todoist.png' 2>/dev/null | head -1)"
                    [ -z "$td_icon" ] && td_icon="$td_tmp/squashfs-root/.DirIcon"
                    [ -e "$td_icon" ] && cp -L "$td_icon" /opt/todoist/todoist.png 2>/dev/null || true
                    rm -rf "$td_tmp"
                else
                    log_warn "Todoist AppImage download failed; skipping."
                    rm -f /opt/todoist/Todoist.AppImage
                    return 0
                fi
            fi
            # wrapper (Electron → native Wayland where supported) + launcher entry
            cat > /usr/local/bin/todoist <<'TDWRAP'
#!/bin/sh
exec /opt/todoist/Todoist.AppImage --ozone-platform-hint=auto "$@"
TDWRAP
            chmod 0755 /usr/local/bin/todoist
            cat > /usr/share/applications/todoist.desktop <<'TDDESK'
[Desktop Entry]
Type=Application
Name=Todoist
Comment=Task manager
Exec=/usr/local/bin/todoist %U
Icon=/opt/todoist/todoist.png
Terminal=false
Categories=Office;ProjectManagement;
StartupWMClass=Todoist
TDDESK
            log_info "Todoist installed (/opt/todoist, launcher: todoist)."
            ;;
        macos)
            brew install --cask todoist-app || true
            ;;
        openbsd)
            log_info "No Todoist build for OpenBSD; skipping."
            ;;
    esac
}

# -------------------------------------------------------------------
# Fastmail — Fastmail shipped official native desktop apps in Oct 2025.
# On Linux the official distribution is a Flatpak on Flathub (published
# by Fastmail); on macOS it is the official cask. No OpenBSD build, and
# no Flatpak on OpenBSD, so it is skipped there (use the Fastmail web app
# in a browser). Flatpak itself is installed via apt in install_packages.
# -------------------------------------------------------------------
install_fastmail() {
    case "$OS_TYPE" in
        linux)
            command -v flatpak >/dev/null 2>&1 || { log_warn "flatpak missing; skipping Fastmail."; return 0; }
            flatpak remote-add --if-not-exists flathub \
                https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
            if ! flatpak info com.fastmail.Fastmail >/dev/null 2>&1; then
                log_info "Installing Fastmail (official Flatpak)..."
                flatpak install -y --noninteractive flathub com.fastmail.Fastmail || \
                    log_warn "Fastmail Flatpak install failed."
            else
                log_info "Fastmail Flatpak already installed."
            fi
            ;;
        macos)
            brew install --cask fastmail || true
            ;;
        openbsd)
            log_info "No Fastmail desktop app for OpenBSD; use the web app in a browser."
            ;;
    esac
}

# -------------------------------------------------------------------
# Joplin — official Linux distribution is an AppImage (from Joplin's own
# object store; latest version resolved via the GitHub releases API). We
# install it system-wide under /opt like Todoist, with a wrapper + launcher,
# rather than piping their installer to a shell. macOS uses the official cask.
# No OpenBSD build.
# -------------------------------------------------------------------
install_joplin() {
    case "$OS_TYPE" in
        linux)
            [ "$(dpkg --print-architecture)" = "amd64" ] || { log_warn "Joplin AppImage is x86_64-only; skipping."; return 0; }
            if [ ! -x /opt/joplin/Joplin.AppImage ]; then
                log_info "Installing Joplin (official AppImage)..."
                apt-get install -y libfuse2t64 >/dev/null 2>&1 || apt-get install -y libfuse2 >/dev/null 2>&1 || true
                jver=$(wget -qO- https://api.github.com/repos/laurent22/joplin/releases/latest 2>/dev/null \
                    | grep -oE '"tag_name"[ :]*"v[0-9.]+"' | grep -oE '[0-9][0-9.]*' | head -1)
                if [ -n "$jver" ]; then
                    mkdir -p /opt/joplin
                    if wget -qO /opt/joplin/Joplin.AppImage "https://objects.joplinusercontent.com/v${jver}/Joplin-${jver}.AppImage"; then
                        chmod 0755 /opt/joplin/Joplin.AppImage
                        j_tmp="$(mktemp -d)"
                        ( cd "$j_tmp" && /opt/joplin/Joplin.AppImage --appimage-extract >/dev/null 2>&1 ) || true
                        j_icon="$(find "$j_tmp/squashfs-root" -name 'joplin.png' 2>/dev/null | head -1)"
                        [ -z "$j_icon" ] && j_icon="$j_tmp/squashfs-root/.DirIcon"
                        [ -e "$j_icon" ] && cp -L "$j_icon" /opt/joplin/joplin.png 2>/dev/null || true
                        rm -rf "$j_tmp"
                    else
                        log_warn "Joplin download failed; skipping."
                        rm -f /opt/joplin/Joplin.AppImage
                        return 0
                    fi
                else
                    log_warn "Could not resolve latest Joplin version (GitHub API); skipping."
                    return 0
                fi
            fi
            cat > /usr/local/bin/joplin <<'JOPWRAP'
#!/bin/sh
exec /opt/joplin/Joplin.AppImage --ozone-platform-hint=auto "$@"
JOPWRAP
            chmod 0755 /usr/local/bin/joplin
            cat > /usr/share/applications/joplin.desktop <<'JOPDESK'
[Desktop Entry]
Type=Application
Name=Joplin
Comment=Note taking and to-do
Exec=/usr/local/bin/joplin %U
Icon=/opt/joplin/joplin.png
Terminal=false
Categories=Office;
StartupWMClass=Joplin
JOPDESK
            log_info "Joplin installed (/opt/joplin, launcher: joplin)."
            ;;
        macos)
            brew install --cask joplin || true
            ;;
        openbsd)
            log_info "No Joplin build for OpenBSD; skipping."
            ;;
    esac
}

# -------------------------------------------------------------------
# Services
# -------------------------------------------------------------------
configure_services() {
    if [ "$OS_TYPE" = "macos" ]; then return; fi

    log_info "Configuring services..."

    if [ "$OS_TYPE" = "openbsd" ]; then
        ln -sf /usr/share/zoneinfo/UTC /etc/localtime

        # NTP: pin the pool + cloudflare with HTTPS constraints. The -s flag
        # steps the clock at startup, so a suspended/cloned VM corrects a
        # large offset immediately instead of slewing for weeks. "sensor *"
        # uses the vmt0 VMware host-time sensor (host = compton, kept accurate)
        # as a fast, local time reference.
        #
        # Caveat: OpenNTPD only *steps* at startup; a running daemon only
        # slews. So if the guest clock jumps mid-run (clone/snapshot/suspend),
        # ntpd will not self-correct a large offset -- yews-clock-guard (below)
        # restarts ntpd to force a fresh -s step.
        cat > /etc/ntpd.conf <<'NTPD'
servers 0.pool.ntp.org
servers 1.pool.ntp.org
server time.cloudflare.com
sensor *
constraints from "www.google.com"
NTPD
        rcctl set ntpd flags -s
        rcctl enable ntpd 2>/dev/null || true
        rcctl restart ntpd 2>/dev/null || true

        # yews-clock-guard: OpenNTPD only steps at startup; a running daemon
        # only slews, so a mid-run jump (VM clone/snapshot/suspend) never
        # self-corrects a large offset. The VMware host (compton) keeps
        # accurate time, so the vmt0 sensor delta is how far this guest has
        # drifted; if it exceeds the threshold, force a clean re-step.
        cat > /usr/local/sbin/yews-clock-guard <<'GUARD'
#!/bin/sh
THRESH=10
d=$(sysctl -n hw.sensors.vmt0.timedelta0 2>/dev/null | awk '{print $1+0}')
[ -z "$d" ] && exit 0
a=${d#-}
if awk -v a="$a" -v t="$THRESH" 'BEGIN{exit !(a>t)}'; then
    logger -t clock-guard "vmt0 delta ${d}s exceeds ${THRESH}s; re-stepping clock via ntpd restart"
    rcctl stop ntpd
    rdate -nv time.cloudflare.com
    rcctl start ntpd
fi
GUARD
        chmod 0755 /usr/local/sbin/yews-clock-guard
        # install the cron entry idempotently, preserving the rest of root's tab
        crontab -l 2>/dev/null > /tmp/ct.$$ || true
        grep -v yews-clock-guard /tmp/ct.$$ 2>/dev/null > /tmp/ct.new.$$ || true
        echo "*/10 * * * * /usr/local/sbin/yews-clock-guard >/dev/null 2>&1" >> /tmp/ct.new.$$
        crontab /tmp/ct.new.$$
        rm -f /tmp/ct.$$ /tmp/ct.new.$$
        log_info "yews-clock-guard installed (cron */10)."

        # Mount FFS partitions noatime (skip access-time writes -> less I/O),
        # persisted in fstab and applied live. Idempotent. softdep is omitted
        # deliberately: it is a silent no-op on modern OpenBSD.
        if grep '[[:space:]]ffs[[:space:]]' /etc/fstab | grep -qv noatime; then
            awk '$3=="ffs" && $4 !~ /noatime/ { $4=$4",noatime" } {print}' /etc/fstab > /etc/fstab.new && \
                mv /etc/fstab.new /etc/fstab && chmod 644 /etc/fstab
            for mp in $(awk '$3=="ffs"{print $2}' /etc/fstab); do
                mount -u -o noatime "$mp" 2>/dev/null || true
            done
            log_info "FFS partitions set to noatime."
        fi

        # Remove default i3 config (conflicts with user config)
        rm -f /etc/i3/config

        # Set console font to Spleen 8x16 if the display supports it
        # (simplefb on VMware arm64 does not support font switching)
        if wsconsctl "display.font=Spleen 8x16" >/dev/null 2>&1; then
            grep -q 'display.font' /etc/wsconsctl.conf 2>/dev/null || \
                echo 'display.font=Spleen 8x16' >> /etc/wsconsctl.conf
            log_info "Console font set to Spleen 8x16."
        fi

        # Disable xconsole launched by xenodm Xsetup_0. xconsole is started
        # before the user session; once i3 takes over it grabs xconsole as
        # the only window and tiles it fullscreen.
        xs=/etc/X11/xenodm/Xsetup_0
        if [ -f "$xs" ] && grep -q '^[^#].*xconsole' "$xs"; then
            sed 's|^\([^#].*xconsole.*\)$|# \1|' "$xs" > "${xs}.new" && \
                mv "${xs}.new" "$xs" && \
                log_info "Disabled xconsole in $xs."
        fi

        # Paint the xenodm login background solid black (default Xsetup_0
        # draws a gray root_weave bitmap).
        if [ -f "$xs" ] && grep -q root_weave "$xs"; then
            sed 's|.*root_weave.*|${exec_prefix}/bin/xsetroot -solid black|' "$xs" > "${xs}.new" && \
                mv "${xs}.new" "$xs" && \
                log_info "Set xenodm login background to solid black."
        fi

        # The sed > new && mv pattern above resets the file mode to 0644;
        # xenodm execve()s the setup script, so it must stay executable.
        [ -f "$xs" ] && chmod 755 "$xs"

        # Enable xenodm. The VMware SVGA II adapter has no DRM/KMS driver on
        # OpenBSD (no /dev/drm*), so Xorg needs aperture access — which means
        # running as root. xenodm provides that without making Xorg setuid.
        rcctl enable xenodm 2>/dev/null || true

        # On VMware, install an Xorg snippet that pins the vmware driver and
        # sets a 4K default mode with a generous virtual size. open-vm-tools
        # is not packaged for OpenBSD, so dynamic host-window resize isn't
        # available; user can xrandr between the listed Modes.
        if [ "$(sysctl -n hw.vendor 2>/dev/null)" = "VMware, Inc." ]; then
            mkdir -p /etc/X11/xorg.conf.d
            cat > /etc/X11/xorg.conf.d/10-vmware.conf <<'VMWARE_XORG'
Section "Device"
    Identifier "VMware SVGA II"
    Driver     "vmware"
EndSection

Section "Monitor"
    Identifier "Monitor0"
    Option     "PreferredMode" "3840x2160"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device     "VMware SVGA II"
    Monitor    "Monitor0"
    DefaultDepth 24
    SubSection "Display"
        Depth   24
        Modes   "3840x2160" "2560x1440" "1920x1080" "1280x768"
        Virtual 5120 2880
    EndSubSection
EndSection
VMWARE_XORG
            log_info "Installed VMware Xorg config (4K default)."
        fi
    else
        timedatectl set-timezone UTC 2>/dev/null || true

        # NTP: pin servers for systemd-timesyncd.
        mkdir -p /etc/systemd/timesyncd.conf.d
        cat > /etc/systemd/timesyncd.conf.d/dotfiles.conf <<'TSYNC'
[Time]
NTP=0.pool.ntp.org 1.pool.ntp.org
FallbackNTP=time.cloudflare.com
TSYNC
        systemctl enable systemd-timesyncd 2>/dev/null || true
        systemctl restart systemd-timesyncd 2>/dev/null || true
        timedatectl set-ntp true 2>/dev/null || true
        # Display manager: we boot to tty1 and hand off to sway from .bashrc.
        # gdm.service is static (no [Install] section), so `systemctl disable`
        # is a silent no-op on it. Mask the unit, drop the SysV runlevel links,
        # and stop booting into graphical.target so getty@tty1 actually runs.
        systemctl mask gdm.service 2>/dev/null || true
        update-rc.d -f gdm3 remove 2>/dev/null || true
        systemctl set-default multi-user.target 2>/dev/null || true

        # Set console font to Terminus 14 (small, clean bitmap font)
        sed -i 's/^FONTFACE=.*/FONTFACE="Terminus"/' /etc/default/console-setup
        sed -i 's/^FONTSIZE=.*/FONTSIZE="14"/' /etc/default/console-setup
        setupcon --force 2>/dev/null || true

        # Make Google Chrome the default browser: system-wide alternatives
        # for CLI callers, plus the per-user xdg default for GUI apps that
        # open links (xdg-settings writes ~/.config/mimeapps.list; it needs
        # no running session for the generic backend).
        if command -v google-chrome-stable >/dev/null 2>&1; then
            update-alternatives --set x-www-browser /usr/bin/google-chrome-stable 2>/dev/null || true
            update-alternatives --set gnome-www-browser /usr/bin/google-chrome-stable 2>/dev/null || true
            su - "$username" -c 'xdg-settings set default-web-browser google-chrome.desktop' 2>/dev/null || true
        fi

        # rasdaemon: log ECC/MCE hardware error events. Effective wherever the
        # kernel EDAC layer exposes memory controllers (ECC workstations and
        # servers); a harmless no-op on machines/VMs without ECC. fwupd is left
        # to its own metadata-refresh timer — firmware is never auto-flashed
        # from here, since that is irreversible and reboots the machine.
        if dpkg -s rasdaemon >/dev/null 2>&1; then
            systemctl enable --now rasdaemon.service 2>/dev/null || true
        fi

        # Smart card daemon: pcscd is socket-activated, so ensure its socket is
        # enabled and readers (e.g. the ACR1552, supported by the stock CCID
        # driver) work on demand. Harmless if no reader is attached.
        if dpkg -s pcscd >/dev/null 2>&1; then
            systemctl enable --now pcscd.socket 2>/dev/null || true
        fi

        # Never suspend/sleep (this is a workstation). Mask the sleep targets so
        # nothing — logind idle action, lid events, a stray `systemctl suspend`
        # — can put it to sleep. The display still blanks after 30 min via
        # swayidle; this only blocks actual system sleep. Reversible with
        # `systemctl unmask`. Harmless on a VM.
        systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
    fi

    log_info "Services configured."
}

# -------------------------------------------------------------------
# System maintenance (Linux): automatic updates, bounded logs, drive/SMART
# monitoring, and a weekly health check. Debian already ships the
# fstrim/logrotate/fwupd-refresh timers, so this only adds what's missing.
# Idempotent: config files are rewritten and units re-enabled on every run.
# -------------------------------------------------------------------
configure_maintenance() {
    [ "$OS_TYPE" = "linux" ] || return 0
    log_info "Configuring system maintenance..."

    # Automatic updates: install all Debian updates (main + updates + security),
    # remove unused deps/kernels, but never auto-reboot (needrestart and the
    # health check flag a needed reboot instead).
    cat > /etc/apt/apt.conf.d/20auto-upgrades <<'AUTOUP'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
AUTOUP
    cat > /etc/apt/apt.conf.d/52unattended-upgrades-nnix <<'UUP'
// Managed by dotfiles provision.sh.
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename},label=Debian";
    "origin=Debian,codename=${distro_codename}-updates";
    "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::MinimalSteps "true";
UUP
    systemctl enable unattended-upgrades 2>/dev/null || true

    # needrestart: report only — never auto-restart services (esp. during an
    # unattended upgrade); it still records when a reboot is required.
    if dpkg -s needrestart >/dev/null 2>&1; then
        mkdir -p /etc/needrestart/conf.d
        cat > /etc/needrestart/conf.d/nnix.conf <<'NRC'
# report only; do not interactively prompt or auto-restart services
$nrconf{restart} = 'l';
NRC
    fi

    # Bound the (persistent) journal so it can't grow toward ~10% of the disk.
    mkdir -p /etc/systemd/journald.conf.d
    cat > /etc/systemd/journald.conf.d/nnix.conf <<'JRN'
[Journal]
Storage=persistent
SystemMaxUse=1G
JRN
    systemctl restart systemd-journald 2>/dev/null || true

    # SMART drive-health monitoring (unit is smartmontools.service on Debian;
    # smartd.service is only a linked alias, which systemctl refuses to enable).
    systemctl enable --now smartmontools.service 2>/dev/null \
        || systemctl enable --now smartd.service 2>/dev/null || true

    # Weekly health check -> journal (journalctl -t healthcheck).
    if [ -f "$SCRIPT_DIR/scripts/healthcheck" ]; then
        install -m 0755 "$SCRIPT_DIR/scripts/healthcheck" /usr/local/bin/healthcheck
        cat > /etc/systemd/system/healthcheck.service <<'HCS'
[Unit]
Description=nnix system health check

[Service]
Type=oneshot
ExecStart=/usr/local/bin/healthcheck
HCS
        cat > /etc/systemd/system/healthcheck.timer <<'HCT'
[Unit]
Description=Weekly nnix system health check

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
HCT
        systemctl daemon-reload 2>/dev/null || true
        systemctl enable healthcheck.timer 2>/dev/null || true
    fi

    log_info "System maintenance configured."
}

# -------------------------------------------------------------------
# Hardening + reliability (Linux): a minimal default-deny host firewall,
# conservative kernel/network sysctls, zram compressed swap, and graceful
# OOM handling. Idempotent. The firewall preserves SSH / mosh / ZeroTier.
# -------------------------------------------------------------------
configure_hardening() {
    [ "$OS_TYPE" = "linux" ] || return 0
    log_info "Configuring hardening + reliability..."

    # Host firewall: default-deny inbound; allow loopback, established/related,
    # ICMP, and only the services we use (SSH, mosh, ZeroTier). Outbound open.
    cat > /etc/nftables.conf <<'NFT'
#!/usr/sbin/nft -f
# Managed by dotfiles provision.sh.
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        iif "lo" accept
        ct state established,related accept
        ct state invalid drop
        meta l4proto ipv6-icmp accept
        ip protocol icmp accept
        tcp dport 22 accept
        udp dport 60000-61000 accept
        udp dport 9993 accept
    }
    chain forward { type filter hook forward priority filter; policy drop; }
    chain output  { type filter hook output priority filter; policy accept; }
}
NFT
    chmod 0755 /etc/nftables.conf
    systemctl enable nftables 2>/dev/null || true
    nft -f /etc/nftables.conf 2>/dev/null || log_warn "nftables ruleset failed to load."

    # Conservative kernel/network hardening.
    cat > /etc/sysctl.d/99-nnix-hardening.conf <<'SYSCTL'
# Managed by dotfiles provision.sh.
kernel.kptr_restrict = 1
kernel.dmesg_restrict = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
SYSCTL
    sysctl --system >/dev/null 2>&1 || true

    # zram compressed swap (spikes stay in RAM, no NVMe wear).
    if dpkg -s zram-tools >/dev/null 2>&1; then
        cat > /etc/default/zramswap <<'ZRAM'
ALGO=zstd
PERCENT=50
PRIORITY=100
ZRAM
        systemctl enable --now zramswap 2>/dev/null || true
    fi

    # Graceful low-memory handling (kills the hog before the box locks up).
    systemctl enable --now systemd-oomd 2>/dev/null || true

    log_info "Hardening + reliability configured."
}

# -------------------------------------------------------------------
# Claude Code — native build (no node required), lands in ~/.local/bin.
#
# This is a per-user install, so on Linux it must run as the target
# user rather than root, or the binary ends up in /root/.local/bin.
# Must therefore be called after get_username. No OpenBSD build.
# -------------------------------------------------------------------
install_claude() {
    if [ "$OS_TYPE" = "openbsd" ]; then
        return 0
    fi

    if [ "$OS_TYPE" = "macos" ]; then
        if command -v claude >/dev/null 2>&1; then
            log_info "Claude Code already installed."
            return 0
        fi
        log_info "Installing Claude Code..."
        curl -fsSL https://claude.ai/install.sh | bash \
            || log_warn "Claude Code install failed."
        return 0
    fi

    if [ -x "/home/$username/.local/bin/claude" ]; then
        log_info "Claude Code already installed."
        return 0
    fi

    log_info "Installing Claude Code for $username..."
    su - "$username" -c 'curl -fsSL https://claude.ai/install.sh | bash' \
        || log_warn "Claude Code install failed."
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
        # Ensure user is in the right privilege group, and that bash is the
        # login shell — the dotfiles' .bashrc/.bash_profile won't be sourced
        # by ksh (OpenBSD's default) or sh.
        if [ "$OS_TYPE" = "openbsd" ]; then
            usermod -G wheel "$username" 2>/dev/null || true
            current_shell=$(getent passwd "$username" | cut -d: -f7)
            if [ "$current_shell" != "/usr/local/bin/bash" ] && [ -x /usr/local/bin/bash ]; then
                usermod -s /usr/local/bin/bash "$username" 2>/dev/null || true
                log_info "Login shell for $username changed to /usr/local/bin/bash."
            fi
        else
            usermod -aG sudo,systemd-journal "$username" 2>/dev/null || true
            current_shell=$(getent passwd "$username" | cut -d: -f7)
            if [ "$current_shell" != "/bin/bash" ] && [ -x /bin/bash ]; then
                usermod -s /bin/bash "$username" 2>/dev/null || true
                log_info "Login shell for $username changed to /bin/bash."
            fi
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
# sshd: key-only auth (these hosts deploy with SSH keys). Idempotent;
# validates the candidate config with `sshd -t` before replacing, so a
# bad edit can never lock you out. macOS keeps its own Remote Login.
# -------------------------------------------------------------------
configure_sshd() {
    [ "$OS_TYPE" = "macos" ] && return
    conf=/etc/ssh/sshd_config
    [ -f "$conf" ] || return 0

    log_info "Hardening sshd (key-only auth)..."
    sshd_bin="$(command -v sshd 2>/dev/null || echo /usr/sbin/sshd)"
    tmp="${conf}.dotfiles.$$"
    sed -e 's/^#*[[:space:]]*PasswordAuthentication[[:space:]].*/PasswordAuthentication no/' \
        -e 's/^#*[[:space:]]*KbdInteractiveAuthentication[[:space:]].*/KbdInteractiveAuthentication no/' \
        "$conf" > "$tmp"
    grep -qE '^PasswordAuthentication no'       "$tmp" || echo 'PasswordAuthentication no'       >> "$tmp"
    grep -qE '^KbdInteractiveAuthentication no' "$tmp" || echo 'KbdInteractiveAuthentication no' >> "$tmp"

    if "$sshd_bin" -t -f "$tmp" 2>/dev/null; then
        cat "$tmp" > "$conf"
        if [ "$OS_TYPE" = "openbsd" ]; then
            rcctl reload sshd 2>/dev/null || rcctl restart sshd 2>/dev/null || true
        else
            systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
        fi
        log_info "sshd set to key-only auth."
    else
        log_warn "Generated sshd_config failed validation; left unchanged."
    fi
    rm -f "$tmp"
}

# -------------------------------------------------------------------
# Deploy dotfiles
#
# Files use @@IF_OPENBSD@@/@@IF_LINUX@@/@@IF_MACOS@@/@@END_IF@@
# markers. At deploy time, the current OS's blocks are kept and
# all other OS blocks are stripped. Files without markers are
# copied as-is.
#
# Files may also contain @@HOME@@, which is replaced with the
# target user's home directory at deploy time (e.g. .issyrc
# uses this for the absolute font_file path).
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
        openbsd) SKIP_DIRS="sway swaylock waybar wofi foot mako" ;;
        linux)   SKIP_DIRS="i3 i3status" ;;
        macos)   SKIP_DIRS="sway swaylock waybar wofi foot i3 i3status mako" ;;
    esac

    cd "$SCRIPT_DIR/dotfiles"
    find . -type f ! -name .DS_Store | while read -r rel; do
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
            *.wezterm.lua) [ "$OS_TYPE" != "macos" ] && skip=true ;;
        esac
        if [ "$skip" = "true" ]; then continue; fi

        src="$SCRIPT_DIR/dotfiles/$rel"
        dst="$home_dir/$rel"

        # Per-machine configs: seed once, never clobber local edits.
        case "$rel" in
            *.config/workstation.conf) [ -f "$dst" ] && continue ;;
        esac

        mkdir -p "$(dirname "$dst")"

        has_os_markers=false
        has_home_marker=false
        grep -q '@@IF_'   "$src" 2>/dev/null && has_os_markers=true
        grep -q '@@HOME@@' "$src" 2>/dev/null && has_home_marker=true

        if [ "$has_os_markers" = "true" ]; then
            # Strip all OS blocks except the current one
            sed_expr=""
            for tag in OPENBSD LINUX MACOS; do
                if [ "$tag" != "$KEEP" ]; then
                    sed_expr="${sed_expr} -e '/# @@IF_${tag}@@/,/# @@END_IF@@/d'"
                fi
            done
            # Remove the kept OS's marker lines (but keep content between them)
            sed_expr="${sed_expr} -e '/# @@IF_${KEEP}@@/d' -e '/# @@END_IF@@/d'"
            if [ "$has_home_marker" = "true" ]; then
                eval sed $sed_expr '"$src"' | sed "s|@@HOME@@|${home_dir}|g" > "$dst"
            else
                eval sed $sed_expr '"$src"' > "$dst"
            fi
        elif [ "$has_home_marker" = "true" ]; then
            sed "s|@@HOME@@|${home_dir}|g" "$src" > "$dst"
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

    # macOS: CoreText doesn't scan ~/.fonts; register the font where the
    # OS actually looks so WezTerm and friends can resolve it.
    if [ "$OS_TYPE" = "macos" ] && [ -f "$home_dir/.fonts/bmv.otf" ]; then
        mkdir -p "$home_dir/Library/Fonts"
        cp "$home_dir/.fonts/bmv.otf" "$home_dir/Library/Fonts/bmv.otf"
    fi

    # .xinitrc must be executable or xinit falls back to launching xterm
    chmod +x "$home_dir/.xinitrc" 2>/dev/null || true

    # On OpenBSD, xenodm reads ~/.xsession (not ~/.xinitrc). Mirror so the
    # same window manager launches whether you use startx or xenodm.
    if [ "$OS_TYPE" = "openbsd" ] && [ -f "$home_dir/.xinitrc" ]; then
        cp "$home_dir/.xinitrc" "$home_dir/.xsession"
        chmod +x "$home_dir/.xsession"
        chown "${username}:${username}" "$home_dir/.xsession"
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
    install_issy
    install_pfetch
    install_herdr
    install_st
    install_dmenu
    install_todoist
    install_fastmail
    install_joplin
    get_username
    install_claude
    configure_hostname
    configure_doas
    configure_sshd
    configure_services
    configure_maintenance
    configure_hardening
    deploy_dotfiles
    update_fonts

    log_info "Provisioning completed for user $username!"
    if [ "$OS_TYPE" != "macos" ]; then
        log_info "Reboot recommended for all changes to take effect."
    fi
}

main "$@"
