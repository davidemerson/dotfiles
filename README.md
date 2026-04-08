# Workstation Configuration

Personal dotfiles with automated provisioning for **Debian Linux**, **OpenBSD**, and **macOS**.

No configuration management tools required — just a POSIX shell script.

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

The script detects the OS and installs the appropriate packages, configures services, and deploys dotfiles.

## What Gets Installed

| Component | Linux | OpenBSD | macOS |
|-----------|-------|---------|-------|
| Desktop | Sway + waybar | Sway + swaybar/i3status | — |
| Terminal | foot | foot | WezTerm |
| Editors | micro, nano, Sublime Text | nano | micro, nano |
| Launcher | wofi | wofi | — |
| Lock screen | swaylock | swaylock | — |
| Browser | Firefox ESR | Firefox ESR | — |
| Email | neomutt + msmtp | neomutt + msmtp | neomutt + msmtp |
| Volume | pamixer + wob | sndioctl | — |
| Privilege | sudo | doas | sudo (built-in) |
| Shell | bash | bash (pkg_add) | bash (brew) |
| Tools | htop, nmap, screen, lsd | htop, nmap, screen, lsd | htop, nmap, lsd |

## Configuration Structure

```
dotfiles/                  # Deployed to ~/
├── .bashrc                # OS-aware (@@IF_LINUX@@, @@IF_OPENBSD@@, @@IF_MACOS@@)
├── .gitconfig
├── .wezterm.lua           # macOS terminal config
├── .config/
│   ├── sway/config        # OS-aware volume/bar (Linux + OpenBSD only)
│   ├── waybar/            # Linux only
│   ├── i3status/          # OpenBSD only
│   ├── foot/
│   ├── swaylock/
│   ├── wofi/
│   ├── micro/
│   └── sublime-text-3/
└── .ssh/config
```

Files with `@@IF_LINUX@@` / `@@IF_OPENBSD@@` / `@@IF_MACOS@@` / `@@END_IF@@` markers are filtered at deploy time — the script strips blocks for other OSes and keeps the current one.

## Re-applying Changes

Pull the latest dotfiles and re-run:

```
cd /path/to/dotfiles
git pull
sh provision.sh       # root on Linux/OpenBSD, normal user on macOS
```

Package installs and file deploys are idempotent.

## Manual Steps After Installation

1. Generate SSH keys: `ssh-keygen -t ed25519 -C "your-email@example.com"`
2. Set up email credentials: create `~/.secrets/mailpass`
3. Install custom fonts to `~/.fonts/` and run `fc-cache -f`

## Troubleshooting

- **OpenBSD disk space**: Ensure `/usr/local` has at least 2GB free
- **OpenBSD package errors**: Verify `/etc/installurl` is set
- **macOS Homebrew**: Script installs Homebrew automatically if missing

For more details: https://nnix.com/projects/dotfiles
