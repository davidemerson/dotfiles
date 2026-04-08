# Workstation Dotfiles

Personal workstation configuration for **Debian Linux**, **OpenBSD**, and **macOS**.

A single POSIX shell script handles OS detection, package installation, service configuration, and dotfile deployment. No Salt, Ansible, or other configuration management tools required. The script is idempotent — safe to re-run after pulling updates.

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

## What Gets Installed

| Component | Linux (Debian) | OpenBSD | macOS |
|-----------|---------------|---------|-------|
| Window Manager | Sway (Wayland) | i3 (X11) | — |
| Terminal | foot | st | WezTerm |
| Status Bar | waybar | i3bar + i3status | — |
| Launcher | wofi | dmenu | — |
| Lock Screen | swaylock | i3lock + xautolock | — |
| Volume | pamixer + wob | sndioctl | — |
| Privilege | sudo | doas | sudo (built-in) |
| Browser | Firefox ESR | Firefox ESR | — |
| Email | neomutt + msmtp | neomutt + msmtp | neomutt + msmtp |
| Editor | micro, nano, Sublime Text | nano | micro, nano, Sublime Text |
| Shell | bash | bash (pkg_add) | zsh (default) |
| Tools | htop, btop, nmap, screen, lsd | htop, btop, nmap, screen, lsd | htop, btop, nmap, lsd |

## How It Works

### OS-Conditional Config Files

Files that need OS-specific lines use simple markers:

```
# @@IF_LINUX@@
bindsym $mod+Shift+s exec systemctl poweroff
# @@END_IF@@
# @@IF_OPENBSD@@
bindsym $mod+Shift+s exec doas shutdown -p now
# @@END_IF@@
```

At deploy time, `provision.sh` strips blocks for other OSes via `sed`, keeping only the current OS's blocks. No template engine required.

### File Routing

Not every file deploys on every OS:

| File | Linux | OpenBSD | macOS |
|------|-------|---------|-------|
| `.bashrc`, `.bash_profile` | yes | yes | — |
| `.zshrc` | — | — | yes |
| `.xinitrc` | — | yes | — |
| `.config/sway/*`, `foot/*`, `waybar/*`, `wofi/*`, `swaylock/*` | yes | — | — |
| `.config/i3/*`, `i3status/*` | — | yes | — |
| `.gitconfig`, `.ssh/config`, `.wezterm.lua`, `.fonts/*` | yes | yes | yes |

### Desktop Flow

- **Linux**: Login on tty1 → `.bashrc` auto-launches sway → foot terminal, waybar, wofi
- **OpenBSD**: Login on ttyC0 → `.bashrc` runs `startx` → `.xinitrc` launches i3 → st terminal, dmenu, i3bar
- **macOS**: Open WezTerm → `.zshrc` loads prompt, aliases, environment

## Re-applying Changes

```
cd /path/to/dotfiles
git pull
sh provision.sh
```

Package installs and file deploys are idempotent.

## Manual Steps After Installation

1. Generate SSH keys: `ssh-keygen -t ed25519 -C "your-email@example.com"`
2. Set up email credentials: create `~/.secrets/mailpass`
3. Install custom fonts to `~/.fonts/` and run `fc-cache -f`

## Keybindings (Sway / i3)

| Key | Action |
|-----|--------|
| Mod4 + Return | Terminal |
| Mod4 + d | Launcher (wofi / dmenu) |
| Mod4 + z | Lock screen |
| Mod4 + Shift+q | Kill window |
| Mod4 + Shift+e | Exit (with confirmation) |
| Mod4 + Shift+s | Shutdown (with confirmation) |
| Mod4 + j/k/i/l | Focus left/down/up/right |
| Mod4 + Shift+j/k/i/l | Move window |
| Mod4 + h/v | Split horizontal/vertical |
| Mod4 + 1-0 | Switch workspace |
| Mod4 + Shift+1-0 | Move to workspace |
| Mod4 + m/n | Volume up/down |
| Mod4 + r | Resize mode |

## Repository Structure

```
provision.sh              # Single provisioning script (POSIX sh)
validate.sh               # Check that all expected files exist
Makefile                  # make validate / make provision / make backup
dotfiles/
├── .bashrc               # Bash config (Linux + OpenBSD, OS-conditional)
├── .bash_profile          # Sources .profile then .bashrc
├── .zshrc                # Zsh config (macOS)
├── .xinitrc              # startx → i3 (OpenBSD)
├── .gitconfig
├── .wezterm.lua           # WezTerm config (macOS)
├── .ssh/config
├── .fonts/bmv.otf         # Berkeley Mono Variable
├── .config/
│   ├── sway/config        # Sway (Linux only)
│   ├── waybar/            # Waybar (Linux only)
│   ├── foot/foot.ini      # Foot terminal (Linux only)
│   ├── swaylock/config    # Swaylock (Linux only)
│   ├── wofi/style.css     # Wofi (Linux only)
│   ├── i3/config          # i3 (OpenBSD only)
│   ├── i3status/config    # i3status (OpenBSD only)
│   ├── micro/             # micro editor settings
│   └── sublime-text-3/    # Sublime Text settings
└── .muttrc, .msmtprc      # Email (in .gitignore)
```

## Troubleshooting

- **OpenBSD disk space**: `/usr/local` needs at least 2GB for packages
- **OpenBSD UTF-8**: The `.bashrc` sets `LANG=en_US.UTF-8` for st/btop
- **OpenBSD console font**: Cannot be changed on VMware arm64 (simplefb limitation)
- **Debian console font**: Set to Terminus 14 via console-setup
- **macOS Homebrew**: Installed automatically if missing

For more details: https://nnix.com/projects/dotfiles
