# Workstation Configuration

Personal dotfiles managed with SaltStack for automated workstation setup on **Debian Linux** and **OpenBSD**.

## Quick Start

### Linux (Debian)

```bash
apt install -y git
git clone https://github.com/demerson/dotfiles.git /tmp/dotfiles
cd /tmp/dotfiles
sudo sh provision.sh
```

### OpenBSD

```bash
pkg_add git
git clone https://github.com/demerson/dotfiles.git /tmp/dotfiles
cd /tmp/dotfiles
sh provision.sh    # run as root
```

The provisioning script detects the OS and installs the appropriate packages, configures services, and deploys dotfiles.

## What Gets Installed

| Component | Linux | OpenBSD |
|-----------|-------|---------|
| Desktop | Sway + waybar | Sway + swaybar/i3status |
| Terminal | foot | foot |
| Editors | micro, nano, Sublime Text | nano |
| Launcher | wofi | wofi |
| Lock screen | swaylock | swaylock |
| Browser | Firefox ESR | Firefox ESR |
| Email | neomutt + msmtp | neomutt + msmtp |
| Volume | pamixer + wob | sndioctl |
| Privilege | sudo | doas |
| Shell | bash | bash (installed via pkg_add) |
| Tools | htop, nmap, screen, lsd, curl, wget, git | htop, nmap, screen, lsd, curl, wget, git |

See [DEPENDENCIES.md](DEPENDENCIES.md) for the complete list.

## Configuration Structure

```
salt/
├── top.sls           # State orchestration
├── base.sls          # Core system setup
├── packages.sls      # Package management (OS-aware)
├── services.sls      # System services (OS-aware)
├── dotfiles.sls      # User configuration (OS-aware)
└── dotfiles/         # Actual dotfiles (Jinja-templated)
    ├── .bashrc
    ├── .gitconfig
    ├── .config/
    │   ├── sway/       # Sway config (OS-aware volume/bar)
    │   ├── waybar/     # Waybar (Linux)
    │   ├── i3status/   # i3status for swaybar (OpenBSD)
    │   ├── foot/
    │   ├── swaylock/
    │   ├── wofi/
    │   ├── micro/
    │   └── sublime-text-3/
    └── .ssh/
```

Config files use Jinja2 templates with Salt grains to adapt per OS. The sway config automatically uses waybar on Linux and swaybar+i3status on OpenBSD, with appropriate volume controls.

## Customization

1. Edit files in `salt/dotfiles/` to customize configurations
2. Modify `salt/packages.sls` to add/remove software
3. Re-run `salt-call --local state.highstate` to apply changes

## Re-applying Changes

After updating the repo, re-deploy as root:

```bash
cd /path/to/dotfiles
cp -R salt/* /srv/salt/
salt-call --local state.highstate
```

## Manual Steps After Installation

1. Generate SSH keys: `ssh-keygen -t ed25519 -C "your-email@example.com"`
2. Set up email credentials: create `~/.secrets/mailpass`
3. Install custom fonts to `~/.fonts/` and run `fc-cache -f`

## Troubleshooting

- **Salt errors**: Check `/var/log/salt/minion` for details
- **Permission issues**: Ensure the script runs as root
- **OpenBSD packages**: Ensure `/etc/installurl` is set correctly

For more details: https://nnix.com/projects/dotfiles
