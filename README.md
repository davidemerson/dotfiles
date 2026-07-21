# Workstation Dotfiles

Personal workstation configuration for **Debian Linux**, **OpenBSD**, and **macOS**.

A single POSIX shell script handles OS detection, package installation, service configuration, and dotfile deployment. No Salt, Ansible, or other configuration management tools required. The script is idempotent, safe to re-run after pulling updates.

Full documentation: https://nnix.com/projects/dotfiles

## Quick Start

### Linux (Debian)

```
su -
apt update && apt install git
git clone https://github.com/davidemerson/dotfiles.git /tmp/dotfiles
cd /tmp/dotfiles
sh provision.sh
```

### OpenBSD

```
pkg_add git
git clone https://github.com/davidemerson/dotfiles.git /tmp/dotfiles
cd /tmp/dotfiles
sh provision.sh    # as root
```

### macOS

```
git clone https://github.com/davidemerson/dotfiles.git ~/dotfiles
cd ~/dotfiles
sh provision.sh    # as your normal user
```

On Linux/OpenBSD the script prompts for the username to provision (creating it if needed, adding it to sudo/wheel, and setting bash as the login shell) and for a hostname. Reboot when it finishes.

## What Gets Installed

| Component | Linux (Debian) | OpenBSD | macOS |
|-----------|---------------|---------|-------|
| Window Manager | Sway (Wayland) | i3 (X11) | |
| Greeter | greetd + tuigreet | xenodm | |
| Terminal | foot | st (patched) | WezTerm |
| Status Bar | waybar | i3bar + i3status | |
| Launcher | wofi | dmenu (patched) | |
| Lock Screen | swaylock | i3lock via `lock` script | |
| Notifications | mako | dunst | |
| Volume | pamixer + wob | sndioctl via `volnotify` | |
| Privilege | sudo | doas | sudo (built-in) |
| Browser | Google Chrome | Chromium | |
| Editor | issy (default), micro, nano, Sublime Text | issy (default), nano | issy (default), micro, nano |
| Shell | bash | bash (pkg_add) | zsh (default) |
| Multiplexers | tmux, herdr | tmux (base) | tmux, herdr |
| Remote shell | mosh | mosh | mosh |
| Fetch | pfetch + sysinfo | pfetch + sysinfo | pfetch + sysinfo |
| Password manager | 1Password + CLI | | 1Password + CLI |
| Notes | Joplin | | Joplin |
| Tasks | Todoist | | Todoist |
| Mail | Fastmail | | Fastmail |
| Media | VLC, Audacity | VLC, Audacity | VLC, Audacity |
| Meetings | Zoom | | Zoom |
| Git GUI | GitHub Desktop (community) | | GitHub Desktop |
| Clipboard | wl-clipboard + cliphist | clipmenu | |
| Firmware / ECC | fwupd, rasdaemon | | |
| Smart card | pcscd + libccid + opensc | | |
| Tools | htop, btop, nmap, screen, lsd, ethtool | htop, btop, nmap, screen, lsd | htop, btop, nmap, lsd |
| Font | Berkeley Mono | Berkeley Mono | Berkeley Mono |

## How It Works

### OS-Conditional Config Files

Files that need OS-specific lines use simple markers. From `.bashrc`:

```
# @@IF_OPENBSD@@
if [ "$(tty)" = "/dev/ttyC0" ]; then
	startx
fi
# @@END_IF@@
# @@IF_LINUX@@
if [ "$(tty)" = "/dev/tty1" ]; then
	WLR_NO_HARDWARE_CURSORS=1 sway
fi
# @@END_IF@@
```

At deploy time, `provision.sh` strips blocks for other OSes via `sed`, keeping only the current OS's blocks. A `@@HOME@@` marker is replaced with the target user's home directory. No template engine required.

### issy (default editor)

`provision.sh` builds [issy](https://github.com/davidemerson/issy) from source and installs it to `/usr/local/bin/issy`. Zig 0.15.x is required (0.16+ breaks the build), so provisioning verifies any zig already on PATH and otherwise installs a pinned one: `zig@0.15` via Homebrew on macOS, `pkg_add` on OpenBSD, or the official 0.15.2 tarball on Linux. `.bashrc` and `.zshrc` set issy as `EDITOR`. The step is idempotent: re-runs compare the installed commit (`issy --version`) against upstream `HEAD` and rebuild only when upstream is newer (or the binary stops linking after an OpenBSD `sysupgrade`). If Homebrew already manages issy on macOS, brew keeps ownership and the script just upgrades it.

### Patched st and dmenu (OpenBSD)

The stock st/dmenu packages stay installed as fallbacks (and for terminfo), but the binaries are replaced with builds from [st-flexipatch](https://github.com/bakkeby/st-flexipatch) and [dmenu-flexipatch](https://github.com/bakkeby/dmenu-flexipatch), pinned to specific commits, using the `st/` and `dmenu/` headers in this repo. st gets clipboard sync, keyboard-select, scrollback with mouse wheel, anysize, bold-is-not-bright, and boxdraw; dmenu gets fuzzy match with highlighting, case-insensitivity, centering, line-height padding, and a border. Rebuilds trigger on commit change, OS release change, `ldd` failure, or when the on-disk binary is not our build.

### workstation (mosh into the admin box)

`~/.local/bin/workstation` moshes into the admin workstation: it loads the SSH
key into the agent, probes the primary overlay path, falls back to the
secondary automatically (fallback is optional), and `exec`s mosh. Where it
points lives in `~/.config/workstation.conf` (labels, hosts, ssh aliases,
user, key) — the file is seeded once by `provision.sh` and never overwritten
on re-runs, so each machine can point at a different box. The tracked conf is
intentionally blank (this repo is public); fill in real values per machine —
the script refuses to run until you do. `workstation -h` shows the configured
paths; `workstation <label>` forces one.

### System Configuration (Linux/OpenBSD)

- **sshd**: key-only auth (`PasswordAuthentication no`, `KbdInteractiveAuthentication no`); the candidate config is validated with `sshd -t` before replacing the real one.
- **Timezone**: UTC on both.
- **NTP (Linux)**: systemd-timesyncd pinned to pool servers with a cloudflare fallback.
- **NTP (OpenBSD)**: `/etc/ntpd.conf` with pool + cloudflare + the vmt0 host-time sensor + HTTPS constraints, and `ntpd -s` to step at boot. A clock-guard cron job (every 10 minutes) restarts ntpd with an `rdate` step if the vmt0 sensor shows more than 10 seconds of drift, since a running OpenNTPD only slews.
- **OpenBSD extras**: doas for wheel (`permit persist :wheel`), noatime on all FFS partitions, xenodm enabled (Xorg needs root aperture access on VMware, no DRM), xconsole disabled, solid black greeter background, Spleen 8x16 console font where supported, and a VMware Xorg snippet with a 4K default mode.
- **Linux extras**: Terminus 14 console font, gdm masked in favor of a **greetd + tuigreet** greeter (minimal TUI on vt7; sway starts via the `sway-session` login-shell wrapper), Sublime Text from the official apt repo, open-vm-tools-desktop when VMware is detected. Google Chrome is set as the default browser (update-alternatives for `x-www-browser`/`gnome-www-browser`, plus the per-user xdg default). **rasdaemon** is enabled to log ECC/MCE hardware error events (effective wherever the kernel EDAC layer exposes memory controllers; a no-op without ECC). **fwupd** is installed but firmware is never auto-flashed from the script — that is a deliberate, out-of-band action (`fwupdmgr refresh && fwupdmgr update`).

### ssh-agent

`.bashrc` starts one shared per-user `ssh-agent` bound to a fixed socket in `$XDG_RUNTIME_DIR` and reuses it across every shell and the WM session it launches (macOS uses the launchd agent instead, so this is Linux/OpenBSD only). Without it a fresh Sway/i3 session has no agent, and `workstation` and SSH commit signing have nowhere to load the key. `workstation` also starts the same shared agent itself if one isn't already reachable.

### Clipboard (Linux)

On Sway, `wl-paste --primary --watch wl-copy` mirrors the primary selection into the clipboard, so selecting text in any terminal or app makes it pasteable everywhere with Ctrl+Shift+V (matching the OpenBSD st behavior). `wl-paste --watch cliphist store` keeps a history so a selection that clobbers a copied value can be recovered; `$mod+v` opens the history in a wofi picker.

### Desktop applications

- **1Password** (Linux apt repo with debsig-verify + CLI; macOS cask): `$mod+p` quick access, `$mod+Shift+p` main window, `$mod+Shift+z` lock. Chrome is in 1Password's default browser allowlist, so no custom allowlist is needed.
- **Todoist** (`$mod+t`), **Joplin** — installed as the official upstream AppImages under `/opt` with a `/usr/local/bin` wrapper + `.desktop` launcher on Linux; official casks on macOS.
- **Fastmail** (`$mod+e`) — official Flatpak (`com.fastmail.Fastmail`) on Linux via Flathub; official cask on macOS.
- **VLC**, **Audacity** — packaged on all platforms. **Zoom** — official `.deb` (no upstream apt repo; self-updates in-app) on Linux, cask on macOS. **GitHub Desktop** — *community* `shiftkey` build on Linux (GitHub ships no official Linux app); the genuine cask on macOS.

### System maintenance (Linux)

Beyond Debian's stock `fstrim`/`logrotate`/`fwupd-refresh` timers, `provision.sh` (`configure_maintenance`) adds:

- **Automatic updates** — `unattended-upgrades` installs all Debian updates (main + updates + security), removes unused deps and old kernels, and **never auto-reboots** — a needed reboot is only flagged, never forced.
- **needrestart** — after upgrades, reports which services need restarting and whether a kernel reboot is required (report-only; never auto-restarts a service).
- **Bounded logs** — the persistent journal is capped at `SystemMaxUse=1G`.
- **SMART monitoring** — `smartmontools` (`smartd`) watches drive health.
- **Weekly health check** — `/usr/local/bin/healthcheck` (from `scripts/healthcheck`) runs via `healthcheck.timer` and logs a summary to the journal: reboot-required, disk usage, failed units, SMART/NVMe wear, ECC error counts, temperatures, pending updates. View with `journalctl -t healthcheck` (the target user is added to the `systemd-journal` group so no sudo is needed). Every probe is guarded, so it's a harmless no-op where a subsystem is absent (e.g. a VM).

### Hardening & reliability (Linux)

`provision.sh` (`configure_hardening`) adds:

- **Host firewall** — nftables, default-deny inbound, allowing only loopback, established/related, ICMP, and the services actually used (SSH, mosh UDP 60000–61000, ZeroTier UDP 9993); outbound is open. Other listening services need an explicit rule added.
- **Kernel/network hardening** — a conservative `sysctl` drop-in (`kptr_restrict`, `dmesg_restrict`, reverse-path filtering, no redirects/source-routing, syncookies, `fs.protected_*`).
- **zram** — compressed (zstd) swap sized to 50% of RAM, so memory spikes stay in RAM instead of hitting the (wear-limited) NVMe.
- **systemd-oomd** — graceful low-memory handling before the machine locks up.

Also in the desktop layer: **grim/slurp screenshots** (`Print` / `Shift+Print` via the Wayland-aware `shot`), **mako** notifications (palette-themed), **swayidle idle-lock** (swaylock at 15 min and before sleep), **fzf + fd** shell integration, git **sane defaults** + **delta** diff pager, and Qt apps forced dark via `adwaita-qt6`.

### File Routing

Not every file deploys on every OS:

| File | Linux | OpenBSD | macOS |
|------|-------|---------|-------|
| `.bashrc`, `.bash_profile` | yes | yes | — |
| `.zshrc` | — | — | yes |
| `.wezterm.lua` | — | — | yes |
| `.xinitrc` | — | yes | — |
| `.config/sway/*`, `foot/*`, `waybar/*`, `wofi/*`, `swaylock/*` | yes | — | — |
| `.config/i3/*`, `i3status/*` | — | yes | — |
| Everything else (git, ssh, tmux, issy, fonts, cursors, theming, `.Xresources`, `.local/bin/*`) | yes | yes | yes |

`.config/workstation.conf` is seeded once and never overwritten, so per-machine values survive re-provisioning.

### Desktop Flow

- **Linux**: greetd + tuigreet greeter on vt7 → `/usr/local/bin/sway-session` (a login shell, so the session inherits `.bashrc`'s environment) launches sway → foot terminal, waybar, wofi. Fallback: a tty1 console login launches sway from `.bashrc` when greetd isn't running.
- **OpenBSD**: xenodm greeter → `~/.xsession` launches i3 → st terminal, dmenu, i3bar (a ttyC0 console login still works: `.bashrc` runs `startx`, and `.xinitrc` mirrors `.xsession`)
- **macOS**: Open WezTerm → `.zshrc` loads prompt, aliases, environment

## Re-applying Changes

```
cd /path/to/dotfiles
git pull
sh provision.sh
```

Package installs, from-source builds, and file deploys are idempotent.

## Manual Steps After Installation

1. Place the SSH key at `~/.ssh/id_d_nnix.pem` (plus matching `.pub`). Both `.ssh/config` and `.gitconfig` reference that path for auth and commit signing — copy the key from another machine, or generate a new one and register it on GitHub as both an authentication key and a signing key. If you use a different key, edit `dotfiles/.gitconfig`, `dotfiles/.ssh/config`, and `dotfiles/.config/git/allowed_signers` to match before running `provision.sh`. If the private key has no sibling `.pub`, generate one (`ssh-keygen -y -f <key> > <key>.pub`) so `workstation` can tell when it's already loaded.
2. Fill in `~/.config/workstation.conf` if you want the `workstation` command.
3. Sign in to 1Password, then enable its browser integration in Chrome (Chrome is allow-listed by default).

## Keybindings (Sway / i3)

| Key | Action |
|-----|--------|
| Mod4 + Return | Terminal |
| Mod4 + d | Launcher (wofi / dmenu) |
| Mod4 + b | Browser (Chrome / Chromium) |
| Mod4 + t | Todoist |
| Mod4 + e | Fastmail |
| Mod4 + p | 1Password quick access (Sway) |
| Mod4 + Shift+p | 1Password main window (Sway) |
| Mod4 + c | Clipboard history picker (Sway) |
| Mod4 + z | Lock screen |
| Mod4 + Shift+z | 1Password lock (Sway) |
| Print / Shift+Print | Screenshot: full / region (Sway) |
| Mod4 + Shift+q | Kill window |
| Mod4 + Shift+e | Exit (with confirmation) |
| Mod4 + Shift+s | Shutdown (with confirmation) |
| Mod4 + j/k/i/l | Focus left/down/up/right |
| Mod4 + Shift+j/k/i/l | Move window |
| Mod4 + h/v | Split horizontal/vertical |
| Mod4 + 1-0 | Switch workspace |
| Mod4 + Shift+1-0 | Move to workspace |
| Mod4 + Shift+space | Toggle floating |
| Mod4 + m/n | Volume up/down |
| Mod4 + r | Resize mode |
| Mod4 + Shift+c | Reload config |
| Mod4 + Shift+r | Restart WM |

i3 (OpenBSD) additions:

| Key | Action |
|-----|--------|
| Mod4 + w | Kill window (alias) |
| Mod4 + Shift+m | Mute toggle |
| Mod4 + c | Clipboard history (clipmenu) |
| Mod4 + ` | Scratchpad terminal |
| Print or Mod4 + p | Screenshot, full screen |
| Mod4 + Print or Mod4 + Shift+p | Screenshot, select region |

## Repository Structure

```
provision.sh              # Single provisioning script (POSIX sh)
validate.sh               # Check that all expected files exist
Makefile                  # make validate / make provision / make backup
DEPENDENCIES.md           # Platform and package inventory
scripts/healthcheck       # Weekly system health check (installed to /usr/local/bin, Linux)
st/config.h, patches.h    # Patched st build config (OpenBSD)
dmenu/config.h, patches.h # Patched dmenu build config (OpenBSD)
dotfiles/
├── .bashrc               # Bash: prompt, aliases, sway/startx autostart (OS-conditional)
├── .bash_profile         # Sources .profile then .bashrc
├── .zshrc                # Zsh: same prompt and aliases (macOS)
├── .xinitrc              # xrdb, cursor, caps→escape, key repeat, dbus + i3 (OpenBSD)
├── .Xresources           # Crisp Xft rendering, plan9 cursor
├── .gitconfig            # Identity + SSH commit signing
├── .ssh/config           # GitHub + Overleaf host entries
├── .tmux.conf            # tmux behavior + palette
├── .wezterm.lua          # WezTerm config (macOS)
├── .issyrc               # issy editor settings
├── .fonts/bmv.otf        # Berkeley Mono Variable NNIX
├── .icons/plan9/         # plan9 cursor theme
├── .local/bin/           # workstation, lock, shot, volnotify, sysinfo
└── .config/
    ├── sway/, waybar/, foot/, swaylock/, wofi/   # Linux desktop (waybar/loadgraph.sh = load histogram)
    ├── i3/, i3status/                            # OpenBSD desktop
    ├── dunst/dunstrc                             # Notifications (OpenBSD)
    ├── fontconfig/fonts.conf                     # monospace = Berkeley Mono
    ├── gtk-3.0/, gtk-4.0/                        # Dark theme + cursor
    ├── btop/                                     # nnix theme
    ├── micro/, sublime-text-3/                   # Other editor settings
    ├── git/allowed_signers                       # SSH signature verification
    └── workstation.conf                          # Per-machine, seeded once
```

## After an OpenBSD `sysupgrade`

OpenBSD has no cross-release binary compatibility — a `sysupgrade` bumps the
base/Xenocara libraries, so binaries built from source (st, dmenu, issy) stop
loading (`ld.so: ... can't load library ...`; symptom: st/dmenu won't launch).
To recover:

```
doas pkg_add -u                          # resync packages to the new release
doas sh /path/to/dotfiles/provision.sh   # rebuilds st/dmenu/issy vs new libs
```

Note `pkg_add -u` also **reinstalls the stock `st`/`dmenu` packages over the
patched builds** (symptom: the font reverts from Berkeley Mono and the
clipboard/scrollback patches disappear) — so always run `provision.sh` *after*
`pkg_add -u`, not before. `provision.sh` is idempotent and rebuilds st/dmenu
when the build stamp's OS release (`uname -r`) changes, when the binary fails
`ldd`, **or when the on-disk binary isn't our build** (it checks that Berkeley
Mono is compiled in), so the re-run restores them. Reboot if the network or X
session did not come back cleanly from the upgrade.

## Troubleshooting

- **OpenBSD disk space**: `/usr/local` needs at least 2GB for packages
- **OpenBSD UTF-8**: The `.bashrc` sets `LANG=en_US.UTF-8` for st/btop
- **OpenBSD console font**: Cannot be changed on VMware arm64 (simplefb limitation)
- **Debian console font**: Set to Terminus 14 via console-setup
- **macOS Homebrew**: Installed automatically if missing
- **macOS fonts**: CoreText doesn't scan `~/.fonts`, so the font is also copied to `~/Library/Fonts`

For more details: https://nnix.com/projects/dotfiles
