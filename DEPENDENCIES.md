# Dependencies

## Supported Platforms
- Debian Linux (13+)
- OpenBSD (7.8+)
- macOS (with Homebrew)

## Installed Software

### All Platforms
- **Font**: Berkeley Mono Variable NNIX (`~/.fonts/bmv.otf`) — set as the generic `monospace` family via `~/.config/fontconfig/fonts.conf`, so every fontconfig client inherits it.
- **Cursor** (Linux/OpenBSD): [plan9 Xcursor theme](https://github.com/wintermute-cell/xcursor-plan9) vendored at `~/.icons/plan9`, set default via `~/.icons/default` + `Xcursor.theme` (X11) and `seat xcursor_theme` (sway/Wayland); `XCURSOR_THEME`/`SIZE` exported in the session.
- **Shell**: bash (Linux/OpenBSD), zsh (macOS default)
- **Editor**: [issy](https://github.com/davidemerson/issy) — built from source via Zig 0.15.x (0.16+ breaks the build; provisioning verifies the version) and installed to `/usr/local/bin/issy`. Set as `EDITOR` in `.bashrc`/`.zshrc`. Configured via `~/.issyrc`. Re-running `provision.sh` compares the installed commit (`issy --version`) against upstream `HEAD` and rebuilds when a newer one exists (or when it stops linking after an OpenBSD upgrade).
- **ssh-agent** (Linux/OpenBSD): `.bashrc` starts one shared per-user agent on a fixed `$XDG_RUNTIME_DIR` socket and reuses it across shells and the WM session (macOS uses the launchd agent). Needed for `workstation` and SSH commit signing.
- **Version Control**: git
- **Multiplexer**: tmux (in base on OpenBSD; via apt/brew elsewhere) — config at `~/.tmux.conf`
- **Agent multiplexer**: [herdr](https://herdr.dev) — homebrew-core on macOS, prebuilt release binary on Linux (x86_64/aarch64) at `/usr/local/bin/herdr`; no OpenBSD builds upstream, skipped there
- **Remote shell**: mosh (all platforms) + `~/.local/bin/workstation` — probes/falls back between overlay paths and moshes into the admin workstation; per-machine targets configured in `~/.config/workstation.conf` (seeded once by provisioning, never overwritten)
- **System fetch**: [pfetch](https://github.com/dylanaraps/pfetch) — minimal, dependency-free; runs on interactive shell login (outside tmux)
- **AI CLI**: [Claude Code](https://claude.com/claude-code) — per-user install via the upstream script → `~/.local/bin/claude` (Linux + macOS; skipped on OpenBSD)
- **Tools**: nano, htop, btop, nmap, lsd; curl + wget (Linux/OpenBSD; macOS uses the system `curl`)

### Linux (Sway Desktop)
- **Compositor**: Sway, swaybg, swayidle, xwayland
- **Terminal**: foot
- **Status Bar**: waybar
- **Launcher**: wofi
- **Lock Screen**: swaylock
- **Volume**: pamixer + wob (OSD); waybar `pulseaudio` module + `pavucontrol` — scroll = volume, left-click opens the output-device / per-app picker, right-click = mute
- **Editors**: micro, Sublime Text
- **Browser**: Google Chrome (upstream apt repo) — set as the default browser via update-alternatives + xdg
- **Clipboard**: wl-clipboard + cliphist — Sway autostarts `wl-paste --primary --watch wl-copy` (selection→clipboard) and `wl-paste --watch cliphist store` (history, `$mod+v` picker)
- **Password manager**: 1Password + `1password-cli` (`op`) — upstream apt repo with debsig-verify; `$mod+p`/`$mod+Shift+p`/`$mod+Shift+z`
- **Apps**: Todoist (official AppImage → `/opt/todoist`, `$mod+t`), Joplin (official AppImage → `/opt/joplin`), Fastmail (official Flatpak `com.fastmail.Fastmail`, `$mod+e`), VLC, Audacity, Zoom (official `.deb`), GitHub Desktop (community `shiftkey` build)
- **Packaging**: Flatpak + Flathub (for Fastmail and any Flatpaks)
- **Networking**: ZeroTier (`zerotier-one`; upstream apt repo, UDP 9993 opened in the firewall)
- **Hardware**: fwupd (firmware; not auto-flashed), rasdaemon (ECC/MCE logging, enabled), ethtool, nvme-cli, smartmontools, lm-sensors; non-free firmware (`firmware-realtek` + `firmware-misc-nonfree`, e.g. RTL8761BU Bluetooth)
- **Maintenance**: unattended-upgrades (all Debian updates, autoremove, no auto-reboot), needrestart (report-only), journald capped at 1G, smartd (SMART monitoring), and a weekly `healthcheck` timer logging to the journal (`journalctl -t healthcheck`)
- **Hardening**: nftables host firewall (default-deny inbound; SSH/mosh/ZeroTier allowed) + kernel/network sysctl hardening (`/etc/sysctl.d/99-nnix-hardening.conf`)
- **Reliability**: zram compressed swap (zstd, 50% of RAM, via `zram-tools`) + systemd-oomd for graceful low-memory handling
- **Notifications**: mako (Wayland; `~/.config/mako/config`, palette-themed)
- **Screenshots**: grim + slurp via `~/.local/bin/shot` (Wayland-aware; `Print` / `Shift+Print`) → saved to `~/pictures/screenshots` and copied to the clipboard
- **Shell tools**: fzf (Ctrl-R history, Ctrl-T files), fd (`fdfind`), git-delta (diff pager); Qt apps follow dark via `adwaita-qt`/`adwaita-qt6` + `QT_STYLE_OVERRIDE`, and GTK4/libadwaita + the xdg portal + Chrome via a `prefer-dark` dconf default
- **Smart card**: pcscd + libccid + opensc + pcsc-tools (pcscd.socket enabled; the stock CCID driver covers readers like the ACR1552)
- **VM Tools**: open-vm-tools-desktop (auto-detected)
- **Build**: build-essential
- **Console Font**: Terminus 14

### OpenBSD (i3 Desktop)
- **Window Manager**: i3
- **Terminal**: st (suckless) — built from [st-flexipatch](https://github.com/bakkeby/st-flexipatch) (pinned) with `st/config.h` + `st/patches.h`. Patches: clipboard (selection auto-copies to system CLIPBOARD), keyboard-select (mouseless copy), scrollback + mouse wheel, anysize, bold-is-not-bright, boxdraw. Falls back to the packaged `st` (which also provides terminfo) if the build fails.
- **Status Bar**: i3bar + i3status
- **Launcher**: dmenu — built from [dmenu-flexipatch](https://github.com/bakkeby/dmenu-flexipatch) (pinned) with `dmenu/config.h` + `dmenu/patches.h`: fuzzy match + highlight, case-insensitive, centered, line-height padding, border. Packaged `dmenu` is the fallback.
- **Notifications**: dunst (`~/.config/dunst/dunstrc`, palette-themed); `$mod+m/n/Shift+m` volume changes show an OSD via `~/.local/bin/volnotify`
- **Screenshots**: scrot + xclip via `~/.local/bin/shot` (`Print`/`$mod+p` full, `$mod+Shift+p` region) → saved to `~/pictures/screenshots` and copied to clipboard
- **Clipboard history**: clipmenu (`clipmenud` daemon; `$mod+c` picks via dmenu)
- **Lock Screen**: `~/.local/bin/lock` (scrot → ImageMagick pixelate → i3lock); triggered by xss-lock (X-screensaver idle) and xautolock; `$mod+z` manual
- **X resources**: `~/.Xresources` (crisp Xft) merged in `.xinitrc`; Caps→Escape, key-repeat tuning
- **Volume**: sndioctl (built-in)
- **Privilege**: doas (configured for wheel group)
- **Browser**: Chromium (`chromium`, launched as `chrome`; `$mod+b`) — Google Chrome has no OpenBSD build, so Chromium replaces it here
- **Apps**: VLC, Audacity (packaged). 1Password, Todoist, Joplin, Fastmail, Zoom, and GitHub Desktop have no OpenBSD builds and are skipped.

### macOS
- **Terminal**: WezTerm (via Homebrew cask)
- **Editors**: micro
- **Apps** (casks): 1Password + CLI, Todoist, Joplin, Fastmail, VLC, Audacity, Zoom, GitHub Desktop (official on macOS)
- **Package Manager**: Homebrew (installed automatically)

### Theming (palette-wide rice)
- **Colored man/less**: `LESS_TERMCAP` in the shell rc (light-blue headings, navy/white standout) — all platforms
- **GTK** (Linux/OpenBSD): `~/.config/gtk-{3,4}.0/settings.ini` — dark theme preference + plan9 cursor; on Linux `color-scheme='prefer-dark'` is also set as a system dconf default so libadwaita, the xdg portal, and Chrome honor dark
- **btop**: `~/.config/btop/themes/nnix.theme` (grayscale + navy/blue), selected in `btop.conf`
- **waybar**: on-brand gray→blue load + network histograms (`~/.config/waybar/{loadgraph,netgraph}.sh`) plus labeled ET/UTC clocks (`%Z` auto-labels EST/EDT)
