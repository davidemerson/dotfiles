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
IS_HEADLESS=""

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

# -------------------------------------------------------------------
# Headless detection
# -------------------------------------------------------------------
# A host with nothing plugged into it gets no desktop: no GUI packages, no
# greeter, no console font. Those three are the parts of this script that are
# actively harmful on a server — the greeter's setfont ExecStartPre fails hard
# on a box with no framebuffer and leaves greetd.service permanently failed.
#
# Detected from the DRM connectors: if every connector reads "disconnected"
# (or the machine has none at all), nothing is attached. A workstation
# provisioned with its monitor unplugged would trip this, so it is logged
# loudly and NNIX_HEADLESS overrides it in either direction.
detect_headless() {
    case "${NNIX_HEADLESS:-}" in
        1|yes|true)
            IS_HEADLESS=1
            log_info "Headless: yes (forced by NNIX_HEADLESS)"
            return
            ;;
        0|no|false)
            IS_HEADLESS=0
            log_info "Headless: no (forced by NNIX_HEADLESS)"
            return
            ;;
    esac

    if [ "$OS_TYPE" != "linux" ]; then
        IS_HEADLESS=0
        return
    fi

    IS_HEADLESS=1
    for status in /sys/class/drm/card*-*/status; do
        [ -e "$status" ] || continue
        if [ "$(cat "$status" 2>/dev/null)" = "connected" ]; then
            IS_HEADLESS=0
            break
        fi
    done

    if [ "$IS_HEADLESS" = "1" ]; then
        log_warn "Headless: yes (no connected display) — skipping desktop packages, greeter, and console font."
        log_warn "  If this machine has a monitor that is merely off or unplugged, re-run with NNIX_HEADLESS=0."
    else
        log_info "Headless: no (display attached)"
    fi
}

# Guard for the desktop-only sections.
headless() { [ "$IS_HEADLESS" = "1" ]; }

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
            export DEBIAN_FRONTEND=noninteractive
            export NEEDRESTART_MODE=a
            apt-get update -qq
            # Base set — everything a machine needs whether or not it has a
            # display. Kept separate from the desktop set so a headless host
            # doesn't pull in a Wayland compositor and a greeter.
            apt-get install -y \
                curl wget git sudo build-essential unzip \
                nano micro htop btop nmap screen lsd tmux mosh \
                fzf fd-find git-delta \
                fwupd rasdaemon ethtool nvme-cli smartmontools lm-sensors \
                unattended-upgrades needrestart \
                nftables zram-tools systemd-oomd \
                pcscd libccid opensc pcsc-tools

            # Desktop set — compositor, bar, launcher, greeter, notifications,
            # clipboard, media, GTK/Qt theming. Skipped on headless hosts.
            if headless; then
                log_info "Headless — skipping desktop packages."
            else
                apt-get install -y \
                    sway swaybg swaylock swayidle xwayland waybar wofi wob pamixer pavucontrol foot \
                    greetd tuigreet \
                    grim slurp mako-notifier libnotify-bin \
                    audacity vlc adwaita-qt6 adwaita-qt \
                    wl-clipboard cliphist \
                    dconf-cli dconf-gsettings-backend \
                    flatpak \
                    bluez rfkill \
                    pipewire pipewire-pulse wireplumber libspa-0.2-bluetooth \
                    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
                    alsa-utils
            fi

            # Non-free firmware for peripherals (e.g. the Realtek RTL8761BU
            # Bluetooth in the ASUS USB-BT500 needs rtl_bt/* from
            # firmware-realtek). Guarded: these live in the non-free-firmware
            # component (default on Debian 13) — warn instead of aborting the
            # whole run if it isn't enabled. Harmless no-ops on a VM.
            apt-get install -y firmware-realtek firmware-misc-nonfree 2>/dev/null \
                || log_warn "firmware-realtek/firmware-misc-nonfree unavailable; enable the non-free-firmware apt component."

            install -d -m 0755 /usr/share/keyrings

            # Sublime Text — dedicated keyring + signed-by scoping (never the
            # global /etc/apt/trusted.gpg.d, which would trust this key for
            # every repo). The key/list setup runs on every provision so a
            # re-run migrates an older global-trust install to the scoped key.
            if headless; then
                log_info "Headless — skipping Sublime Text."
            else
                wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg \
                    | gpg --dearmor > /usr/share/keyrings/sublimehq-archive-keyring.gpg
                printf 'deb [signed-by=/usr/share/keyrings/sublimehq-archive-keyring.gpg] https://download.sublimetext.com/ apt/stable/\n' \
                    > /etc/apt/sources.list.d/sublime-text.list
                rm -f /etc/apt/trusted.gpg.d/sublimehq-archive.gpg
                if ! command -v subl >/dev/null 2>&1; then
                    log_info "Installing Sublime Text..."
                    apt-get update -qq && apt-get install -y sublime-text \
                        || log_warn "Sublime Text install failed."
                fi
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
                apt-get update -qq && apt-get install -y zerotier-one \
                    || log_warn "ZeroTier install failed."
            fi

            # Google Chrome (upstream ships amd64 only)
            if headless; then
                log_info "Headless — skipping Google Chrome."
            elif ! command -v google-chrome >/dev/null 2>&1 \
                && [ "$(dpkg --print-architecture)" = "amd64" ]; then
                log_info "Installing Google Chrome..."
                wget -qO - https://dl.google.com/linux/linux_signing_key.pub \
                    | gpg --dearmor > /usr/share/keyrings/google-chrome.gpg
                echo "deb [signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
                    > /etc/apt/sources.list.d/google-chrome.list
                apt-get update -qq && apt-get install -y google-chrome-stable \
                    || log_warn "Google Chrome install failed."
            fi
            # The google-chrome-stable package ships its own deb822
            # google-chrome.sources; drop our bootstrap .list so the repo is
            # not fetched twice (idempotent cleanup, runs on every provision).
            if [ -f /etc/apt/sources.list.d/google-chrome.sources ]; then
                rm -f /etc/apt/sources.list.d/google-chrome.list
            fi

            # 1Password (desktop app + CLI). The app requires debsig-verify
            # per-package signature checking, so we install its policy and a
            # second copy of the signing key under /etc/debsig + /usr/share/debsig.
            # "stable" is 1Password's own suite (distro-agnostic), so there is
            # nothing codename-specific to track. Repo serves amd64 and arm64.
            # On a headless host the CLI still earns its place (scripts read
            # secrets with a service-account token) but the GUI app does not,
            # so only the desktop build is skipped there.
            if headless; then
                op_pkgs="1password-cli"
                op_have="op"
            else
                op_pkgs="1password 1password-cli"
                op_have="1password"
            fi
            if ! command -v "$op_have" >/dev/null 2>&1; then
                log_info "Installing 1Password ($op_pkgs)..."
                OP_ARCH="$(dpkg --print-architecture)"
                wget -qO - https://downloads.1password.com/linux/keys/1password.asc \
                    | gpg --dearmor > /usr/share/keyrings/1password-archive-keyring.gpg
                echo "deb [arch=$OP_ARCH signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$OP_ARCH stable main" \
                    > /etc/apt/sources.list.d/1password.list
                # debsig per-package signature checking is a requirement of the
                # desktop package only; the CLI installs without it.
                if ! headless; then
                    mkdir -p /etc/debsig/policies/AC2D62742012EA22
                    wget -qO - https://downloads.1password.com/linux/debian/debsig/1password.pol \
                        > /etc/debsig/policies/AC2D62742012EA22/1password.pol
                    mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
                    wget -qO - https://downloads.1password.com/linux/keys/1password.asc \
                        | gpg --dearmor > /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
                fi
                # shellcheck disable=SC2086
                apt-get update -qq && apt-get install -y $op_pkgs \
                    || log_warn "1Password install failed."
            fi

            # Zoom (official .deb; Zoom publishes no apt repo, so this is a
            # one-shot install and Zoom self-updates in-app). amd64 only. Runs
            # under XWayland on Sway. Downloaded over HTTPS from zoom.us.
            if headless; then
                log_info "Headless — skipping Zoom."
            elif ! command -v zoom >/dev/null 2>&1 \
                && [ "$(dpkg --print-architecture)" = "amd64" ]; then
                log_info "Installing Zoom..."
                zoom_deb="/tmp/zoom_amd64.$$.deb"
                # Sanity-gate the download (a Debian archive begins "!<arch>")
                # so a 200-with-error-body never reaches dpkg.
                if wget -qO "$zoom_deb" https://zoom.us/client/latest/zoom_amd64.deb \
                    && head -c 8 "$zoom_deb" 2>/dev/null | grep -qa '^!<arch>'; then
                    apt-get install -y "$zoom_deb" || log_warn "Zoom install failed."
                    rm -f "$zoom_deb"
                else
                    log_warn "Zoom download failed or not a .deb; skipping."
                    rm -f "$zoom_deb"
                fi
            fi

            # GitHub Desktop — COMMUNITY build (GitHub ships no official Linux
            # app). shiftkey/desktop's own apt host (apt.packages.shiftkey.dev)
            # has recurring TLS-cert breakage, so we use the maintained @mwt
            # mirror instead. Wrapped so a broken third-party repo only warns
            # and never aborts the rest of provisioning. amd64 only.
            if headless; then
                log_info "Headless — skipping GitHub Desktop."
            elif ! command -v github-desktop >/dev/null 2>&1 \
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

            # VMware tools (auto-detected). The -desktop variant pulls in X11
            # integration, so a headless guest takes the plain package.
            if grep -q VMware /sys/class/dmi/id/sys_vendor 2>/dev/null; then
                if headless; then
                    apt-get install -y open-vm-tools
                else
                    apt-get install -y open-vm-tools-desktop
                fi
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
                x86_64)  zig_arch="x86_64"
                         zig_sha="02aa270f183da276e5b5920b1dac44a63f1a49e55050ebde3aecc9eb82f93239" ;;
                aarch64) zig_arch="aarch64"
                         zig_sha="958ed7d1e00d0ea76590d27666efbf7a932281b3d7ba0c6b01b0ff26498f667f" ;;
                *) log_warn "No Zig tarball for $(uname -m)."; return 1 ;;
            esac
            tarball="zig-${zig_arch}-linux-${ZIG_VERSION}.tar.xz"
            url="https://ziglang.org/download/${ZIG_VERSION}/${tarball}"
            tmp="/tmp/zig.tar.xz"
            log_info "Downloading Zig ${ZIG_VERSION}..."
            curl -fsSL -o "$tmp" "$url" || return 1
            # Verify the pinned SHA-256 before unpacking/building as root.
            if command -v sha256sum >/dev/null 2>&1; then
                zig_got="$(sha256sum "$tmp" | awk '{print $1}')"
                if [ "$zig_got" != "$zig_sha" ]; then
                    log_error "Zig checksum mismatch (want $zig_sha, got $zig_got); skipping."
                    rm -f "$tmp"
                    return 1
                fi
            fi
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
    if curl -fsSL -o /tmp/pfetch.$$ "$url" \
        && head -c 2 /tmp/pfetch.$$ 2>/dev/null | grep -qa '#'; then
        install -m 0755 /tmp/pfetch.$$ /usr/local/bin/pfetch && \
            log_info "pfetch installed at /usr/local/bin/pfetch."
        rm -f /tmp/pfetch.$$
    else
        log_warn "Could not download pfetch (or bad content). Skipping."
        rm -f /tmp/pfetch.$$
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
            if curl -fsSL -o /tmp/herdr.$$ "$url" \
                && head -c 4 /tmp/herdr.$$ 2>/dev/null | grep -qa 'ELF'; then
                install -m 0755 /tmp/herdr.$$ /usr/local/bin/herdr
                rm -f /tmp/herdr.$$
                log_info "herdr installed at /usr/local/bin/herdr."
            else
                rm -f /tmp/herdr.$$
                log_warn "Could not download herdr (or bad content). Skipping."
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
    headless && { log_info "Headless — skipping Todoist."; return 0; }
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
                if wget -qO /opt/todoist/Todoist.AppImage https://todoist.com/linux_app/appimage \
                    && head -c 4 /opt/todoist/Todoist.AppImage 2>/dev/null | grep -qa 'ELF'; then
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
    headless && { log_info "Headless — skipping Fastmail."; return 0; }
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
    # Desktop client only — unrelated to a self-hosted Joplin *server*, which
    # this script does not manage.
    headless && { log_info "Headless — skipping Joplin desktop."; return 0; }
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
                    if wget -qO /opt/joplin/Joplin.AppImage "https://objects.joplinusercontent.com/v${jver}/Joplin-${jver}.AppImage" \
                        && head -c 4 /opt/joplin/Joplin.AppImage 2>/dev/null | grep -qa 'ELF'; then
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
        # System timezone: US Eastern (EST/EDT, auto-DST). The waybar UTC clock
        # uses its own explicit override, so it stays UTC regardless.
        ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime

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
        # System timezone: US Eastern (EST/EDT, auto-DST). The waybar UTC clock
        # keeps its own override, so it stays UTC regardless.
        timedatectl set-timezone America/New_York 2>/dev/null || true

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
        # Login manager: greetd + tuigreet — a minimal TUI greeter on vt7. gdm
        # stays masked. sway is started via /usr/local/bin/sway-session, a login
        # shell so the graphical session inherits ~/.bashrc's environment
        # (cursor theme, Qt dark, PATH, ssh-agent socket). getty stays on the
        # other VTs as a fallback console; .bashrc still launches sway from a
        # tty1 login *if* greetd isn't running, so a broken greeter never locks
        # you out of the desktop.
        #
        # None of this applies to a headless host: there is no display to greet
        # anyone on, and the console-font ExecStartPre below fails hard on a box
        # with no framebuffer (setfont exits 71/OSERR against the dummy console
        # driver), which leaves greetd.service permanently failed and trips
        # every health check on the machine.
        if headless; then
            log_info "Headless — skipping greeter and console font; booting to multi-user.target."
            systemctl set-default multi-user.target 2>/dev/null || true
        else
        systemctl mask gdm.service 2>/dev/null || true
        cat > /usr/local/bin/sway-session <<'SWAYSESS'
#!/bin/bash --login
# Launch sway as a login shell so the session inherits ~/.bashrc's environment.
#
# Two pieces of hardware adaptation happen here, both detected at runtime so
# this same wrapper works unchanged on every machine these dotfiles build:
#
#  1. sway refuses to start on the proprietary NVIDIA driver unless it is
#     passed --unsupported-gpu.
#  2. On server boards the BMC (ASPEED/Matrox) exposes a DRM device whose
#     output always reads "connected", because the IPMI virtual KVM is
#     always attached. wlroots can pick that headless device as primary and
#     render the session to a screen nobody is looking at. Prefer a real GPU
#     when one is present.

# --- 1. NVIDIA proprietary driver needs --unsupported-gpu -------------------
sway_args=()
if [ -d /proc/driver/nvidia ] || lsmod 2>/dev/null | grep -q '^nvidia_drm'; then
    sway_args+=(--unsupported-gpu)
fi

# --- 2. Prefer a real GPU over BMC display hardware ------------------------
# Drivers that are BMC/management video rather than a usable desktop GPU.
bmc_drivers='ast|mgag200|hyperv_drm'

if [ -z "$WLR_DRM_DEVICES" ] && [ -d /dev/dri/by-path ]; then
    preferred=() fallback=()
    for dev in /dev/dri/by-path/*-card; do
        [ -e "$dev" ] || continue
        card=$(basename "$(readlink -f "$dev")")
        drv=$(basename "$(readlink -f "/sys/class/drm/$card/device/driver")" 2>/dev/null)
        if printf '%s' "$drv" | grep -qE "^($bmc_drivers)$"; then
            fallback+=("$dev")
        else
            preferred+=("$dev")
        fi
    done
    # Only pin when we actually found a real GPU *and* something to exclude;
    # on a single-GPU machine leave wlroots to its own defaults.
    if [ ${#preferred[@]} -gt 0 ] && [ ${#fallback[@]} -gt 0 ]; then
        WLR_DRM_DEVICES=$(IFS=:; printf '%s' "${preferred[*]}")
        export WLR_DRM_DEVICES
    fi
fi

exec sway "${sway_args[@]}"
SWAYSESS
        chmod 0755 /usr/local/bin/sway-session
        if command -v tuigreet >/dev/null 2>&1 && [ -d /etc/greetd ]; then
            cat > /etc/greetd/config.toml <<GREETD
[terminal]
vt = 7

[default_session]
command = "tuigreet --time --time-format '%Y-%m-%d %H:%M:%S' --asterisks --asterisks-char '•' --greeting '$(hostname)' --theme 'action=black;button=black' --cmd /usr/local/bin/sway-session"
user = "_greetd"
GREETD
            # The greeter runs on vt7, which console-setup (tty1-6) never
            # touches, so load the Berkeley Mono console font on vt7 before
            # tuigreet draws. (Mask char is • not ※ — Berkeley Mono has no
            # U+203B glyph, so ※ would render as tofu in the console font.)
            mkdir -p /etc/systemd/system/greetd.service.d
            # The leading "-" makes the font load advisory: setfont fails on any
            # console the kernel won't accept a font for (no framebuffer, dummy
            # console driver, an oversized glyph cell), and a cosmetic font is
            # never a reason to refuse to start the login greeter.
            cat > /etc/systemd/system/greetd.service.d/console-font.conf <<'GFONT'
[Service]
ExecStartPre=-/usr/bin/setfont /usr/share/consolefonts/BerkeleyMonoNNIX.psf.gz -C /dev/tty7
GFONT
            # Rename the prompt-box title "Authenticate into <hostname>" to
            # "Login": the hostname is already in the --greeting line, so the
            # title is redundant. tuigreet has no flag for this and compiles its
            # locale strings into the binary, so we patch the binary in place.
            # That patch is reverted on a tuigreet upgrade, so install the script
            # to a stable path and register an APT hook that re-applies it (it's
            # idempotent) after any package change — an upgrade never leaves the
            # wrong title behind.
            install -m 0755 "$SCRIPT_DIR/scripts/patch-tuigreet-title.sh" \
                /usr/local/sbin/patch-tuigreet-title
            cat > /etc/apt/apt.conf.d/99-tuigreet-title <<'APTHOOK'
// Re-apply the tuigreet "Login" title patch after any apt/dpkg run so a
// tuigreet upgrade or reinstall doesn't revert it. The script is idempotent
// and a no-op when tuigreet is absent or its embedded string has changed.
DPkg::Post-Invoke { "test -x /usr/local/sbin/patch-tuigreet-title && /usr/local/sbin/patch-tuigreet-title >/dev/null 2>&1 || true"; };
APTHOOK
            /usr/local/sbin/patch-tuigreet-title || true
            systemctl set-default graphical.target 2>/dev/null || true
            systemctl enable greetd 2>/dev/null || true
        else
            # No greeter available — boot to a console; .bashrc launches sway.
            systemctl set-default multi-user.target 2>/dev/null || true
        fi

        # Console font: Berkeley Mono (NNIX) — a ~16x32 bitmap rasterized from
        # bmv.otf (see scripts/build-console-font.sh), so tty1-6 and the greeter
        # match st/dmenu/waybar. Ship the prebuilt .psf.gz rather than build it
        # here: otf2bdf/bdf2psf need a fiddly XLFD fixup, and the result is
        # deterministic. setupcon uses FONT= directly when set; clearing
        # FONTFACE/FONTSIZE keeps it from falling back to a stock face.
        install -m 0644 "$SCRIPT_DIR/scripts/BerkeleyMonoNNIX.psf.gz" \
            /usr/share/consolefonts/BerkeleyMonoNNIX.psf.gz
        sed -i 's/^FONTFACE=.*/FONTFACE=""/' /etc/default/console-setup
        sed -i 's/^FONTSIZE=.*/FONTSIZE=""/' /etc/default/console-setup
        if grep -q '^FONT=' /etc/default/console-setup; then
            sed -i 's|^FONT=.*|FONT="BerkeleyMonoNNIX.psf.gz"|' /etc/default/console-setup
        else
            printf 'FONT="BerkeleyMonoNNIX.psf.gz"\n' >> /etc/default/console-setup
        fi
        setupcon --force 2>/dev/null || true
        fi  # end: not headless (greeter + console font)

        # Dark mode for GTK4/libadwaita, the xdg portal, and Chrome/Electron/
        # web `prefers-color-scheme`. libadwaita ignores the legacy GtkSettings
        # dark flag and reads org.gnome.desktop.interface color-scheme, so set
        # it as a system dconf default (headless-safe; no session bus needed).
        # (Skipped on headless hosts — dconf-cli is not installed there and
        # there is no GTK app to theme.)
        if ! headless; then
            mkdir -p /etc/dconf/db/local.d /etc/dconf/profile
            [ -f /etc/dconf/profile/user ] || printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
            cat > /etc/dconf/db/local.d/00-nnix-theme <<'DCONF'
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
DCONF
            dconf update 2>/dev/null || true
        fi

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

        # Admin tools live in /usr/sbin and /sbin, which Debian leaves off a
        # non-root PATH — so rfkill, swapon, smartctl, nvme and ethtool are all
        # "command not found" for the very user who provisioned the box. Add
        # them back, but only for users who can actually use them.
        cat > /etc/profile.d/zz-sbin-path.sh <<'SBINPATH'
# Admin tools live in /usr/sbin and /sbin. Debian omits these from a non-root
# PATH, which hides rfkill, swapon, smartctl, nvme, ethtool, etc.
if id -nG 2>/dev/null | tr ' ' '\n' | grep -qx sudo; then
    case ":$PATH:" in
        *:/usr/sbin:*) ;;
        *) PATH="$PATH:/usr/sbin:/sbin" ;;
    esac
fi
SBINPATH
        chmod 0644 /etc/profile.d/zz-sbin-path.sh

        # Bluetooth: the kernel brings the adapter up on its own, but without
        # the BlueZ userspace there is no bluetoothd and no bluetoothctl, so
        # nothing can ever pair — a BT mouse or headset simply never appears.
        # Desktop-only: a headless host has no use for it.
        if ! headless && dpkg -s bluez >/dev/null 2>&1; then
            systemctl enable --now bluetooth.service 2>/dev/null || true
        fi

        # Audio + screen capture: PipeWire, not PulseAudio.
        #
        # Debian pulls the PulseAudio daemon in as a dependency of the desktop
        # set, and both it and pipewire-pulse ship enabled user units that fight
        # over the same socket — whichever wins, the other is dead weight. Pin
        # this to PipeWire, which is the Debian 13 default and is also what
        # xdg-desktop-portal-wlr needs for ScreenCast (Chrome/Zoom screen share,
        # OBS). Without it those silently fail on sway.
        #
        # --global writes to /etc/systemd/user, so this applies to every user
        # without needing a login session to be running while provisioning.
        if ! headless && dpkg -s pipewire >/dev/null 2>&1; then
            systemctl --global mask pulseaudio.service pulseaudio.socket 2>/dev/null || true
            systemctl --global enable pipewire.socket pipewire.service \
                wireplumber.service pipewire-pulse.socket pipewire-pulse.service 2>/dev/null || true
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
# -------------------------------------------------------------------
# Host firewall
# -------------------------------------------------------------------
# Default-deny inbound: loopback, established/related, ICMP, and the services
# we always want (SSH, mosh, ZeroTier). Outbound stays open.
#
# Three rules learned the hard way on a server:
#
#   1. Never touch the firewall if ufw or firewalld is already running. Two
#      managers means every packet is judged by both and the stricter one wins
#      silently, which looks exactly like a broken application.
#   2. Never `flush ruleset`. That wipes ufw's and Docker's tables too, on every
#      single start of nftables.service. Replace only our own table.
#   3. Never drop in the forward hook on a machine with a container runtime.
#      Docker publishes ports by DNAT, and DNAT'd traffic is *forwarded*, not
#      input — a forward drop blackholes every container's networking,
#      including its outbound path to the internet.
#
# Per-host open ports live in /etc/nnix/firewall.conf, seeded once and never
# overwritten on re-provision (same contract as ~/.config/workstation.conf).
configure_firewall() {
    if systemctl is-active --quiet ufw 2>/dev/null; then
        log_warn "ufw is active — leaving the firewall to it (set of record). Skipping nftables."
        return 0
    fi
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        log_warn "firewalld is active — leaving the firewall to it. Skipping nftables."
        return 0
    fi

    if [ ! -f /etc/nnix/firewall.conf ]; then
        log_info "Seeding /etc/nnix/firewall.conf (edit it to open per-host ports)."
        mkdir -p /etc/nnix
        cat > /etc/nnix/firewall.conf <<'FWCONF'
# Per-host inbound exceptions, on top of the always-open SSH / mosh / ZeroTier.
# Seeded once by provision.sh and never overwritten, so edits here survive a
# re-provision. Space-separated; ranges are allowed ("9100-9200").
# Apply changes with: nft -f /etc/nftables.conf

EXTRA_TCP_PORTS=""
EXTRA_UDP_PORTS=""

# Subnets allowed to reach *any* port on this host — the practical answer for
# a LAN server whose services use dynamic or hard-to-enumerate ports.
# e.g. TRUSTED_SUBNETS="10.62.14.0/24 10.142.26.0/24"
TRUSTED_SUBNETS=""
FWCONF
        chmod 0644 /etc/nnix/firewall.conf
    fi

    EXTRA_TCP_PORTS=""
    EXTRA_UDP_PORTS=""
    TRUSTED_SUBNETS=""
    # shellcheck disable=SC1091
    . /etc/nnix/firewall.conf

    extra_rules=""
    for subnet in $TRUSTED_SUBNETS; do
        case "$subnet" in
            *:*) extra_rules="$extra_rules
        ip6 saddr $subnet accept" ;;
            *)   extra_rules="$extra_rules
        ip saddr $subnet accept" ;;
        esac
    done
    for port in $EXTRA_TCP_PORTS; do
        extra_rules="$extra_rules
        tcp dport $port accept"
    done
    for port in $EXTRA_UDP_PORTS; do
        extra_rules="$extra_rules
        udp dport $port accept"
    done

    if command -v dockerd >/dev/null 2>&1 || command -v podman >/dev/null 2>&1; then
        forward_policy="accept"
        log_info "Container runtime detected — forward hook left open for it."
    else
        forward_policy="drop"
    fi

    # "table ... / delete table ..." is the atomic replace-our-own-table idiom:
    # the bare declaration creates it when absent so the delete never errors,
    # and nothing outside table inet nnix is touched.
    # Render to a temp file and syntax-check it before it becomes the live
    # config: a typo in the hand-edited per-host port list must not be able to
    # leave the machine with a half-loaded or unloadable ruleset.
    fw_tmp="$(mktemp)"
    cat > "$fw_tmp" <<NFT
#!/usr/sbin/nft -f
# Managed by dotfiles provision.sh. Per-host ports: /etc/nnix/firewall.conf
# Only the "nnix" table is replaced — ufw/Docker/podman tables are left alone.

table inet nnix
delete table inet nnix

table inet nnix {
    chain input {
        type filter hook input priority filter; policy drop;
        iif "lo" accept
        ct state established,related accept
        ct state invalid drop
        meta l4proto ipv6-icmp accept
        ip protocol icmp accept
        tcp dport 22 accept
        udp dport 60000-61000 accept
        udp dport 9993 accept$extra_rules
    }
    chain forward { type filter hook forward priority filter; policy $forward_policy; }
    chain output  { type filter hook output priority filter; policy accept; }
}
NFT
    if ! nft -c -f "$fw_tmp"; then
        rm -f "$fw_tmp"
        log_error "Generated nftables ruleset is invalid — check EXTRA_*_PORTS/TRUSTED_SUBNETS in /etc/nnix/firewall.conf."
        log_warn "Leaving the existing firewall untouched."
        return 0
    fi

    cat "$fw_tmp" > /etc/nftables.conf
    rm -f "$fw_tmp"
    chmod 0755 /etc/nftables.conf
    systemctl enable nftables 2>/dev/null || true
    if nft -f /etc/nftables.conf; then
        log_info "Firewall loaded (forward: $forward_policy)."
    else
        log_warn "nftables ruleset failed to load."
    fi
}

configure_hardening() {
    [ "$OS_TYPE" = "linux" ] || return 0
    log_info "Configuring hardening + reliability..."

    configure_firewall

    # Conservative kernel/network hardening.
    cat > /etc/sysctl.d/99-nnix-hardening.conf <<'SYSCTL'
# Managed by dotfiles provision.sh.
kernel.kptr_restrict = 1
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
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
# Tresorit — end-to-end encrypted file sync. Upstream ships a signed
# self-extracting .run installer for Linux and a cask on macOS; there is
# no OpenBSD build.
#
# This is a per-user install (the payload lands in ~/.local/share/tresorit
# and the launcher in ~/.local/share/applications), so like install_claude
# it must run as the target user rather than root, and therefore after
# get_username. Running it as root would install into /root and leave the
# real user unable to log in — which is exactly what upstream's own
# installer warns about when it detects root.
#
# Idempotent: skipped entirely when the binary is already present.
# Upstream also accepts `--update-v2 <dir>` for in-place upgrades, which
# is left to Tresorit's own updater rather than driven from here.
# -------------------------------------------------------------------
install_tresorit() {
    headless && { log_info "Headless — skipping Tresorit."; return 0; }
    case "$OS_TYPE" in
        linux)
            # upstream ships x86_64 and i686 only — no arm64 build
            [ "$(dpkg --print-architecture)" = "amd64" ] \
                || { log_warn "Tresorit is x86_64-only; skipping."; return 0; }

            if [ -x "/home/$username/.local/share/tresorit/tresorit" ]; then
                log_info "Tresorit already installed."
                return 0
            fi

            log_info "Installing Tresorit for $username..."
            tr_run="$(mktemp /tmp/tresorit_installer.XXXXXX.run)"
            if ! wget -qO "$tr_run" https://installer.tresorit.com/tresorit_installer.run; then
                log_warn "Tresorit download failed; skipping."
                rm -f "$tr_run"
                return 0
            fi

            # Make sure we got the installer and not an HTML error page or a
            # truncated transfer. The .run is a shell script carrying a signed
            # payload; it self-verifies with an embedded cksum and refuses to
            # run on mismatch, so this only needs to catch the obvious cases.
            if ! head -c 2 "$tr_run" | grep -qa '#!' \
                || ! grep -qam1 '^SIGNATURE=' "$tr_run"; then
                log_warn "Tresorit installer looks malformed; skipping."
                rm -f "$tr_run"
                return 0
            fi

            chmod 0755 "$tr_run"
            # The installer is interactive on a fresh install: it asks whether
            # to change the install directory, then whether to launch the GUI.
            # Answer N (keep the default ~/.local/share/tresorit) and n (do not
            # start a GUI from a provisioning run).
            if su - "$username" -c "printf 'N\nn\n' | '$tr_run'" >/dev/null 2>&1 \
                && [ -x "/home/$username/.local/share/tresorit/tresorit" ]; then
                log_info "Tresorit installed (~/.local/share/tresorit)."
            else
                log_warn "Tresorit install failed."
            fi
            rm -f "$tr_run"
            ;;
        macos)
            brew install --cask tresorit || true
            ;;
        openbsd)
            log_info "No Tresorit build for OpenBSD; skipping."
            ;;
    esac
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

    # Never prompt on a server or an unattended run: renaming a host that other
    # machines, certificates and monitoring refer to by name is not something to
    # do by accident, and a bare `read` against a closed stdin would abort the
    # whole script under `set -e`. Set NNIX_HOSTNAME to rename deliberately.
    if headless || [ ! -t 0 ]; then
        new_hostname="${NNIX_HOSTNAME:-}"
        if [ -z "$new_hostname" ]; then
            log_info "Non-interactive — keeping hostname (set NNIX_HOSTNAME to change it)."
        fi
    else
        printf "${GREEN}[INFO]${NC} Press [enter] to keep, or type new hostname: "
        read new_hostname || new_hostname=""
    fi

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

    # Ensure hostname resolves locally. Debian convention: the machine's own
    # name goes on a 127.0.1.1 line (127.0.0.1 stays localhost). Anchor the
    # guard so a substring of an unrelated entry can't mask a missing name.
    h=$(hostname)
    short="${h%%.*}"
    if [ "$h" = "$short" ]; then names="$h"; else names="$h $short"; fi
    if ! grep -qE "(^|[[:space:]])${h}([[:space:]]|\$)" /etc/hosts 2>/dev/null; then
        if [ "$OS_TYPE" = "openbsd" ]; then
            printf "127.0.0.1 %s\n" "$names" >> /etc/hosts
        else
            printf "127.0.1.1 %s\n" "$names" >> /etc/hosts
        fi
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

    # Prefer a drop-in so the packaged sshd_config is never rewritten. On
    # Debian the base file's `Include /etc/ssh/sshd_config.d/*.conf` sits above
    # any hand-set directive and sshd is first-match-wins, so a 99- drop-in
    # also wins over anything a later package drops in. The candidate is
    # validated with `sshd -t` before it is kept, so it can't lock you out.
    dropin_dir=/etc/ssh/sshd_config.d
    if [ "$OS_TYPE" != "openbsd" ] && \
       grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/' "$conf"; then
        mkdir -p "$dropin_dir"
        dst="${dropin_dir}/99-dotfiles-hardening.conf"
        cat > "$dst" <<'SSHDROP'
# Managed by dotfiles provision.sh.
PasswordAuthentication no
KbdInteractiveAuthentication no
SSHDROP
        if "$sshd_bin" -t 2>/dev/null; then
            systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
            log_info "sshd set to key-only auth (drop-in 99-dotfiles-hardening.conf)."
        else
            rm -f "$dst"
            log_warn "sshd drop-in failed validation; removed, left unchanged."
        fi
        return
    fi

    # OpenBSD (no sshd_config.d Include): patch the main file in place, still
    # validating the candidate before it replaces the real one.
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
        linux)   SKIP_DIRS="i3 i3status dunst" ;;
        macos)   SKIP_DIRS="sway swaylock waybar wofi foot i3 i3status mako dunst" ;;
    esac

    # A headless host gets no desktop configuration at all. What it does keep is
    # the part that is useful over SSH: shell, prompt, git, ssh, tmux, editors,
    # btop, and ~/.local/bin. Fonts stay too — issy renders PDFs with bmv.otf.
    if headless; then
        SKIP_DIRS="$SKIP_DIRS sway swaylock waybar wofi foot mako gtk-3.0 gtk-4.0 fontconfig sublime-text-3"
    fi

    cd "$SCRIPT_DIR/dotfiles"
    # Read the file list from a temp file (not a pipe) so state accumulated in
    # the loop — the set of top-level home entries we actually wrote — survives
    # for a targeted chown instead of chowning all of $HOME.
    file_list="$(mktemp)"
    find . -type f ! -name .DS_Store > "$file_list"
    deployed_tops=""
    while read -r rel; do
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
            *.local/bin/lock|*.local/bin/volnotify) [ "$OS_TYPE" != "openbsd" ] && skip=true ;;
        esac
        # Desktop-only leaf files (X resources, cursor themes, screenshot
        # helper) — nothing on a headless host can use them.
        if headless; then
            case "$rel" in
                *.Xresources|*.icons/*|*.local/bin/shot) skip=true ;;
            esac
        fi
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

        # Record the top-level home entry (e.g. .config, .bashrc) so ownership
        # is fixed only for what we deployed.
        top="${rel#./}"; top="${top%%/*}"
        case " $deployed_tops " in
            *" $top "*) : ;;
            *) deployed_tops="$deployed_tops $top" ;;
        esac
    done < "$file_list"
    rm -f "$file_list"

    # Ownership: chown only the trees we deployed, not all of $HOME — a full
    # recursive chown re-stats gigabytes of .cache/.var/Downloads and could
    # reset the owner of unrelated files. macOS files are already user-owned.
    if [ "$OS_TYPE" != "macos" ]; then
        for top in $deployed_tops; do
            chown -R "${username}:${username}" "$home_dir/$top" 2>/dev/null || true
        done
    fi

    # SSH permissions
    if [ -d "$home_dir/.ssh" ]; then
        chmod 700 "$home_dir/.ssh"
        chmod 600 "$home_dir/.ssh/config" 2>/dev/null || true
    fi

    # SSH commit signing uses gpg.format=ssh with signingkey id_d_nnix.pub.
    # Agentless signing makes ssh-keygen find the private key by stripping the
    # ".pub" suffix -> id_d_nnix, so give it that name (a symlink to the real
    # .pem). Without it, commits/tags fail whenever the agent isn't loaded
    # (cron, sudo, a fresh boot before a terminal starts the shared agent).
    if [ "$OS_TYPE" != "macos" ] && [ -f "$home_dir/.ssh/id_d_nnix.pem" ] \
        && [ ! -e "$home_dir/.ssh/id_d_nnix" ]; then
        ln -s id_d_nnix.pem "$home_dir/.ssh/id_d_nnix"
        chown -h "${username}:${username}" "$home_dir/.ssh/id_d_nnix" 2>/dev/null || true
        log_info "Linked ~/.ssh/id_d_nnix -> id_d_nnix.pem for agentless SSH signing."
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
# GPU
# -------------------------------------------------------------------
# Debian installs nouveau for NVIDIA cards. On anything Turing or newer that
# means the GPU is stuck at boot clocks (nouveau cannot reclock Ampere), with
# no CUDA and no NVENC. Swap in the proprietary driver when an NVIDIA GPU is
# actually present.
#
# Everything here is conditional on detecting NVIDIA hardware, so the function
# is a no-op on AMD/Intel/VM machines and on headless hosts.
configure_gpu() {
    [ "$OS_TYPE" = "linux" ] || return 0
    if headless; then
        log_info "Headless — skipping GPU driver."
        return 0
    fi
    command -v lspci >/dev/null 2>&1 || return 0
    if ! lspci -nn 2>/dev/null | grep -qiE 'VGA|3D controller' \
        || ! lspci -nn 2>/dev/null | grep -iE 'VGA|3D controller' | grep -qi nvidia; then
        log_info "No NVIDIA GPU detected — leaving graphics drivers alone."
        return 0
    fi

    log_info "NVIDIA GPU detected — installing the proprietary driver."

    # nvidia-driver lives in contrib + non-free. A stock Debian 13 install
    # enables only "main non-free-firmware", so the driver is not merely
    # missing, it is uninstallable. Add the components idempotently, to
    # whichever source format this machine uses (one-line .list or deb822).
    local changed=0
    if [ -f /etc/apt/sources.list ]; then
        if grep -qE '^deb(-src)? .* main non-free-firmware$' /etc/apt/sources.list; then
            cp -n /etc/apt/sources.list /etc/apt/sources.list.nnix-bak 2>/dev/null || true
            sed -i -E '/^deb(-src)? /s/ main non-free-firmware$/ main contrib non-free non-free-firmware/' \
                /etc/apt/sources.list
            changed=1
        fi
    fi
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then
        if grep -q '^Components: main non-free-firmware$' /etc/apt/sources.list.d/debian.sources; then
            cp -n /etc/apt/sources.list.d/debian.sources \
                  /etc/apt/sources.list.d/debian.sources.nnix-bak 2>/dev/null || true
            sed -i 's/^Components: main non-free-firmware$/Components: main contrib non-free non-free-firmware/' \
                /etc/apt/sources.list.d/debian.sources
            changed=1
        fi
    fi
    [ "$changed" = "1" ] && apt-get update -qq

    # The driver builds via DKMS, which needs kernel headers. A stock install
    # has neither, and without them the module silently never gets built.
    apt-get install -y linux-headers-"$(dpkg --print-architecture)" dkms \
        || { log_warn "Kernel headers/DKMS unavailable; skipping NVIDIA driver."; return 0; }

    # nvidia-legacy-check aborts this install if the card is too old for the
    # current driver series, which is the correct outcome — do not force it.
    if ! apt-get install -y nvidia-driver; then
        log_warn "nvidia-driver install failed (card may need a legacy series); staying on nouveau."
        return 0
    fi

    # Wayland requires DRM kernel modesetting, and nvidia-drm ships with
    # modeset=0 by default — sway simply fails to start without this. fbdev=1
    # keeps a usable framebuffer console on the NVIDIA output, so a text VT is
    # still reachable if the graphical session breaks.
    #
    # Debian renames the module to nvidia-current-drm; set both names so this
    # survives a switch of the nvidia alternative.
    cat > /etc/modprobe.d/nvidia-modeset.conf <<'NVMODESET'
# Wayland compositors (sway/wlroots) require DRM kernel modesetting on NVIDIA.
options nvidia-current-drm modeset=1 fbdev=1
options nvidia-drm modeset=1 fbdev=1
NVMODESET

    # The nouveau blacklist and the modeset options both have to be in the
    # initramfs, or nouveau wins the race for the card on the next boot.
    update-initramfs -u -k all 2>/dev/null || log_warn "update-initramfs failed."

    log_warn "NVIDIA driver installed — reboot required to switch off nouveau."
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
usage() {
    cat <<'USAGE'
Usage: provision.sh [--headless | --desktop]

  --headless   Server mode: no desktop packages, no GUI apps, no greeter,
               no console font, and only the SSH-useful dotfiles.
  --desktop    Force the full desktop build.

With neither flag the mode is auto-detected from the attached display (see
detect_headless). NNIX_HEADLESS=1/0 does the same thing as the flags.
USAGE
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --headless) NNIX_HEADLESS=1; export NNIX_HEADLESS ;;
            --desktop)  NNIX_HEADLESS=0; export NNIX_HEADLESS ;;
            -h|--help)  usage; exit 0 ;;
            *)          log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
        shift
    done

    log_info "Starting dotfiles provisioning..."

    detect_os
    detect_headless
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
    install_tresorit
    configure_hostname
    configure_doas
    configure_sshd
    configure_services
    configure_maintenance
    configure_hardening
    configure_gpu
    deploy_dotfiles
    update_fonts

    # Say plainly what was and wasn't touched. A provisioner that silently
    # skips half its work — or silently declines to manage the firewall — is
    # indistinguishable from one that did everything, until something breaks.
    log_info "Provisioning completed for user $username!"
    printf '\n'
    log_info "Summary:"
    log_info "  host mode  : $(headless && echo 'headless (no desktop)' || echo 'desktop')"
    if [ "$OS_TYPE" = "linux" ]; then
        if systemctl is-active --quiet ufw 2>/dev/null; then
            log_info "  firewall   : left to ufw (nftables section skipped)"
        elif systemctl is-active --quiet firewalld 2>/dev/null; then
            log_info "  firewall   : left to firewalld (nftables section skipped)"
        else
            log_info "  firewall   : nftables, ports from /etc/nnix/firewall.conf"
        fi
        if headless; then
            log_info "  greeter    : none (boots to multi-user.target)"
        fi
    fi
    if [ "$OS_TYPE" != "macos" ]; then
        log_info "Reboot recommended for all changes to take effect."
    fi
}

main "$@"
