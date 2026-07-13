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
| Terminal | foot | st (patched) | WezTerm |
| Status Bar | waybar | i3bar + i3status | |
| Launcher | wofi | dmenu (patched) | |
| Lock Screen | swaylock | i3lock via `lock` script | |
| Notifications | | dunst | |
| Volume | pamixer + wob | sndioctl via `volnotify` | |
| Privilege | sudo | doas | sudo (built-in) |
| Browser | Firefox ESR | Firefox ESR | |
| Email | neomutt + msmtp | neomutt + msmtp | neomutt + msmtp |
| Editor | issy (default), micro, nano, Sublime Text | issy (default), nano | issy (default), micro, nano |
| Shell | bash | bash (pkg_add) | zsh (default) |
| Multiplexers | tmux, herdr | tmux (base) | tmux, herdr |
| Remote shell | mosh | mosh | mosh |
| Fetch | pfetch + sysinfo | pfetch + sysinfo | pfetch + sysinfo |
| Tools | htop, btop, nmap, screen, lsd | htop, btop, nmap, screen, lsd | htop, btop, nmap, lsd |
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

`provision.sh` builds [issy](https://github.com/davidemerson/issy) from source and installs it to `/usr/local/bin/issy`. Zig 0.15.x is required (0.16+ breaks the build), so provisioning verifies any zig already on PATH and otherwise installs a pinned one: `zig@0.15` via Homebrew on macOS, `pkg_add` on OpenBSD, or the official 0.15.2 tarball on Linux. `.muttrc`, `.bashrc`, and `.zshrc` all set issy as `EDITOR`. The step is idempotent: re-runs compare the installed commit (`issy --version`) against upstream `HEAD` and rebuild only when upstream is newer (or the binary stops linking after an OpenBSD `sysupgrade`). If Homebrew already manages issy on macOS, brew keeps ownership and the script just upgrades it.

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
- **Linux extras**: Terminus 14 console font, gdm disabled, Sublime Text from the official apt repo, open-vm-tools-desktop when VMware is detected.

### File Routing

Not every file deploys on every OS:

| File | Linux | OpenBSD | macOS |
|------|-------|---------|-------|
| `.bashrc`, `.bash_profile` | yes | yes | — |
| `.zshrc` | — | — | yes |
| `.xinitrc` | — | yes | — |
| `.config/sway/*`, `foot/*`, `waybar/*`, `wofi/*`, `swaylock/*` | yes | — | — |
| `.config/i3/*`, `i3status/*` | — | yes | — |
| Everything else (git, ssh, tmux, mail, issy, fonts, cursors, theming, `.Xresources`, `.local/bin/*`) | yes | yes | yes |

`.config/workstation.conf` is seeded once and never overwritten, so per-machine values survive re-provisioning.

### Desktop Flow

- **Linux**: Login on tty1 → `.bashrc` auto-launches sway → foot terminal, waybar, wofi
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

1. Place the SSH key at `~/.ssh/id_d_nnix.pem` (plus matching `.pub`). Both `.ssh/config` and `.gitconfig` reference that path for auth and commit signing — copy the key from another machine, or generate a new one and register it on GitHub as both an authentication key and a signing key. If you use a different key, edit `dotfiles/.gitconfig`, `dotfiles/.ssh/config`, and `dotfiles/.config/git/allowed_signers` to match before running `provision.sh`.
2. Set up email credentials: create `~/.secrets/mailpass`
3. Fill in `~/.config/workstation.conf` if you want the `workstation` command.
4. Linux/OpenBSD: launch Firefox once, then run `firefox-rice` to install the dark chrome into the new profile.

## Keybindings (Sway / i3)

| Key | Action |
|-----|--------|
| Mod4 + Return | Terminal |
| Mod4 + d | Launcher (wofi / dmenu) |
| Mod4 + b | Firefox |
| Mod4 + z | Lock screen |
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
├── .muttrc, .msmtprc     # Email (secrets stay in ~/.secrets/mailpass)
├── .issyrc               # issy editor settings
├── .fonts/bmv.otf        # Berkeley Mono Variable NNIX
├── .icons/plan9/         # plan9 cursor theme
├── .local/bin/           # workstation, lock, shot, volnotify, firefox-rice, sysinfo
└── .config/
    ├── sway/, waybar/, foot/, swaylock/, wofi/   # Linux desktop
    ├── i3/, i3status/                            # OpenBSD desktop
    ├── dunst/dunstrc                             # Notifications (OpenBSD)
    ├── fontconfig/fonts.conf                     # monospace = Berkeley Mono
    ├── gtk-3.0/, gtk-4.0/                        # Dark theme + cursor
    ├── btop/                                     # nnix theme
    ├── firefox/                                  # user.js + userChrome.css
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
